import 'dart:convert';

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
    return String.fromCharCodes(units);
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
    expect(script, contains(r'stop service '));
    expect(script, contains(r'Stop-Service -Name $service'));
    expect(script, contains(r'Start-Service -Name $service'));
    expect(script, contains('[IO.Compression.ZipFileExtensions]::ExtractToFile'));
    expect(script, contains('robocopy'));
    expect(script, contains('BfClashUpdateBackup'));
    expect(script, contains(r'$env:WINDIR'));
    expect(script, contains(r"'bfclash-portable-update.log'"));
    expect(script, isNot(contains('__ZIP__')));
    expect(script, isNot(contains('__DIR__')));
    expect(
      script,
      contains(base64Encode(utf8.encode(r'D:\程序\BfClash'))),
    );
    expect(
      script,
      contains(
        base64Encode(utf8.encode('The in-place update failed: {detail}\n\nLog: {log}')),
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
    );
    expect(command, windowsPowerShellPath);
    expect(arguments, contains('-EncodedCommand'));
    expect(exited, isTrue);
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
