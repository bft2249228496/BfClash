import 'dart:convert';
import 'dart:io';

import 'package:bfclash/common/common.dart';
import 'package:bfclash/common/windows_portable_update.dart';
import 'package:bfclash/l10n/l10n.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() async => AppLocalizations.load(const Locale('en')));

  String decodedScript(WindowsPortableUpdatePlan plan) {
    final bytes = base64Decode(plan.arguments.last);
    final units = <int>[];
    for (var index = 0; index < bytes.length; index += 2) {
      units.add(bytes[index] | (bytes[index + 1] << 8));
    }
    final bootstrap = String.fromCharCodes(units);
    final compressed = RegExp(
      "FromBase64String\\('([^']+)'\\)",
    ).firstMatch(bootstrap)!.group(1)!;
    return utf8.decode(gzip.decode(base64Decode(compressed)));
  }

  WindowsPortableUpdatePlan plan() => buildWindowsPortableUpdatePlan(
    parentProcessId: 4242,
    zipPath: r'C:\Users\张三\Temp\bfclash-update\BfClash-update.zip',
    installDirectory: r'D:\程序\BfClash',
    executablePath: r'D:\程序\BfClash\BfClash-Beta.exe',
    serviceName: 'BfClashHelperServiceBeta',
    targetVersion: '0.2.27-beta.1811',
    failureTitle: 'Update could not be completed',
    failureBodyTemplate: 'The in-place update failed: {detail}\n\nLog: {log}',
    temporaryDirectory: r'C:\Users\张三\Temp\bfclash-update',
  );

  test('helper script is ASCII and injects paths as base64 blobs', () {
    final updatePlan = plan();
    final script = decodedScript(updatePlan);

    expect(script.codeUnits.every((unit) => unit < 128), isTrue);
    expect(script, contains(r'$parentPid = 4242'));
    expect(script, contains(r'Stop-Installed'));
    expect(script, contains(r'Stop-Service -Name $service'));
    expect(script, contains(r'Start-Service -Name $service'));
    expect(
      script,
      contains('[IO.Compression.ZipFileExtensions]::ExtractToFile'),
    );
    expect(script, contains('robocopy'));
    expect(
      script,
      contains(r'Move-Item -LiteralPath $dir -Destination $backup'),
    );
    expect(script, contains('Wait-AppReady'));
    expect(script, contains('Wait-RestoredApp'));
    expect(script, contains(r'$env:WINDIR'));
    expect(script, contains(r"'bfclash-portable-update.log'"));
    expect(script, isNot(contains('__ZIP__')));
    expect(script, isNot(contains('__DIR__')));
    expect(script, contains(base64Encode(utf8.encode(r'D:\程序\BfClash'))));
    expect(
      script,
      contains(
        base64Encode(
          utf8.encode('The in-place update failed: {detail}\n\nLog: {log}'),
        ),
      ),
    );
  });

  test('encoded command argument list targets PowerShell', () {
    final updatePlan = plan();
    expect(updatePlan.arguments.first, '-NoProfile');
    expect(updatePlan.arguments, contains('-ExecutionPolicy'));
    expect(updatePlan.arguments, contains('Bypass'));
    expect(updatePlan.arguments, contains('-EncodedCommand'));
    expect(updatePlan.commandLine, isNot(contains('\n')));
    // Windows caps a command line at 32767 characters.
    expect(updatePlan.commandLine.length, lessThan(30000));
  });

  test('compressed command runs in Windows PowerShell', () async {
    final updatePlan = plan();
    final bytes = base64Decode(updatePlan.arguments.last);
    final units = <int>[];
    for (var index = 0; index < bytes.length; index += 2) {
      units.add(bytes[index] | (bytes[index + 1] << 8));
    }
    final bootstrap = String.fromCharCodes(units);
    final payload = RegExp(
      "FromBase64String\\('([^']+)'\\)",
    ).firstMatch(bootstrap)!.group(1)!;
    final command = bootstrap.replaceFirst(
      payload,
      base64Encode(
        gzip.encode(utf8.encode("[Console]::Write('healthy'); exit 7")),
      ),
    );
    final encoded = base64Encode([
      for (final unit in command.codeUnits) ...[unit & 0xff, unit >> 8],
    ]);
    final result = await Process.run(windowsPowerShellPath, [
      ...updatePlan.arguments.take(updatePlan.arguments.length - 1),
      encoded,
    ]);
    expect(result.exitCode, 7, reason: '${result.stderr}');
    expect(result.stdout, 'healthy');
  }, skip: !Platform.isWindows);

  test('launching the helper exits the app only after elevation', () async {
    String? command;
    String? arguments;
    var exited = false;
    await launchWindowsPortableUpdate(
      zipPath: 'update.zip',
      installDirectory: 'install',
      executablePath: 'install/BfClash-Beta.exe',
      serviceName: 'BfClashHelperServiceBeta',
      targetVersion: '0.2.27-beta.1811',
      launcher: (file, args) {
        command = file;
        arguments = args;
        return true;
      },
      exitApplication: () async => exited = true,
      waitForPreparation: (_) async {},
    );
    expect(command, windowsPowerShellPath);
    expect(arguments, contains('-EncodedCommand'));
    expect(exited, isTrue);
  });

  for (final status in ['ready', 'failed']) {
    test('preparation $status is read before exiting the app', () async {
      File? prepared;
      var exited = false;
      final operation = launchWindowsPortableUpdate(
        zipPath: 'update.zip',
        installDirectory: 'install',
        executablePath: 'install/BfClash-Beta.exe',
        serviceName: 'BfClashHelperServiceBeta',
        targetVersion: '1.0.1-beta.1911',
        launcher: (_, arguments) {
          final script = decodedScript(
            WindowsPortableUpdatePlan(
              script: '',
              arguments: arguments.split(' '),
            ),
          );
          final encoded = RegExp(
            r"\$prepared = Dec\('([^']+)'\)",
          ).firstMatch(script)!.group(1)!;
          prepared = File(utf8.decode(base64Decode(encoded)));
          prepared!.writeAsStringSync(
            '\ufeff${jsonEncode({'status': status, 'detail': 'blocked', 'log': 'fixture.log'})}',
          );
          return true;
        },
        exitApplication: () async => exited = true,
      );
      try {
        if (status == 'failed') {
          await expectLater(operation, throwsA(isA<MessageException>()));
          expect(exited, isFalse);
        } else {
          await operation;
          expect(exited, isTrue);
        }
      } finally {
        await prepared?.parent.delete(recursive: true);
      }
    });
  }

  test('failed preparation keeps the old app running', () async {
    var exited = false;
    await expectLater(
      launchWindowsPortableUpdate(
        zipPath: 'update.zip',
        installDirectory: 'install',
        executablePath: 'install/BfClash-Beta.exe',
        serviceName: 'BfClashHelperServiceBeta',
        targetVersion: '1.0.1-beta.1911',
        launcher: (_, _) => true,
        waitForPreparation: (_) async =>
            throw const MessageException('blocked'),
        exitApplication: () async => exited = true,
      ),
      throwsA(isA<MessageException>()),
    );
    expect(exited, isFalse);
  });

  test('a rejected elevation keeps the app running', () async {
    var exited = false;
    await expectLater(
      launchWindowsPortableUpdate(
        zipPath: 'update.zip',
        installDirectory: 'install',
        executablePath: 'install/BfClash-Beta.exe',
        serviceName: 'BfClashHelperServiceBeta',
        targetVersion: '0.2.27-beta.1811',
        launcher: (_, _) => false,
        exitApplication: () async => exited = true,
      ),
      throwsA(isA<MessageException>()),
    );
    expect(exited, isFalse);
  });
}
