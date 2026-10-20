import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bfclash/common/common.dart';
import 'package:bfclash/common/windows_update_policy.dart';
import 'package:bfclash/l10n/l10n.dart';

void main() {
  setUp(() async => AppLocalizations.load(const Locale('en')));

  test(
    'signed update verifies publisher before launch under enforced policy',
    () async {
      final actions = <String>[];
      await launchWindowsUpdate(
        filePath: 'owned.exe',
        installDirectory: 'owned',
        expectedPublisher: 'CN=Owner',
        policyStateReader: () => 1,
        signatureVerifier: (file, publisher) async {
          expect(file, 'owned.exe');
          expect(publisher, 'CN=Owner');
          actions.add('verify');
          return true;
        },
        launcher: (_, _) {
          actions.add('launch');
          return true;
        },
        exitApplication: () async => actions.add('exit'),
      );
      expect(actions, ['verify', 'launch', 'exit']);
    },
  );

  test('untrusted signed update cannot launch or exit', () async {
    var launched = false;
    await expectLater(
      launchWindowsUpdate(
        filePath: 'owned.exe',
        installDirectory: 'owned',
        expectedPublisher: 'CN=Owner',
        signatureVerifier: (_, _) async => false,
        launcher: (_, _) {
          launched = true;
          return true;
        },
        exitApplication: () async {
          fail('must not exit');
        },
      ),
      throwsA(isA<MessageException>()),
    );
    expect(launched, isFalse);
  });

  test(
    'Authenticode result requires exact publisher trust timestamp and RSA',
    () async {
      final valid = {
        'valid': true,
        'publisher': 'CN=Owner',
        'timestamp': true,
        'rsa': true,
      };
      for (final response in [
        valid,
        {...valid, 'publisher': 'CN=Other'},
        {...valid, 'valid': false},
        {...valid, 'timestamp': false},
        {...valid, 'rsa': false},
      ]) {
        expect(
          await verifyWindowsInstallerSignature(
            "C:/owned ' setup.exe",
            'CN=Owner',
            processRunner: (executable, args) async {
              expect(executable, 'powershell.exe');
              expect(args, isNot(contains('-ExecutionPolicy')));
              return ProcessResult(0, 0, jsonEncode(response), '');
            },
          ),
          response == valid,
        );
      }
      expect(
        await verifyWindowsInstallerSignature(
          'owned.exe',
          'CN=Owner',
          processRunner: (_, _) async => ProcessResult(0, 1, '', 'failed'),
        ),
        isFalse,
      );
      expect(
        await verifyWindowsInstallerSignature(
          'owned.exe',
          'CN=Owner',
          processRunner: (_, _) async => ProcessResult(0, 0, 'invalid', ''),
        ),
        isFalse,
      );
    },
  );

  test('enforced policy blocks installer and exit', () async {
    final actions = <String>[];
    await expectLater(
      launchWindowsUpdate(
        filePath: 'owned setup.exe',
        installDirectory: 'owned app',
        policyStateReader: () => 1,
        launcher: (_, _) {
          actions.add('launch');
          return true;
        },
        exitApplication: () async => actions.add('exit'),
      ),
      throwsA(isA<MessageException>()),
    );
    expect(actions, isEmpty);
  });

  test(
    'explicitly confirmed unsigned update launches under enforced policy',
    () async {
      final actions = <String>[];
      await launchWindowsUpdate(
        filePath: 'owned setup.exe',
        installDirectory: 'owned app',
        policyStateReader: () => 1,
        allowUnsignedWhenEnforced: true,
        launcher: (file, args) {
          expect(file, 'owned setup.exe');
          expect(args, '/DIR="owned app" /NORESTART');
          actions.add('launch');
          return true;
        },
        exitApplication: () async => actions.add('exit'),
      );
      expect(actions, ['launch', 'exit']);
    },
  );

  test('policy state maps registry values to caution levels', () {
    expect(
      windowsApplicationControlState(policyStateReader: () => null),
      WindowsApplicationControlState.inactive,
    );
    for (final value in [0, 2]) {
      expect(
        windowsApplicationControlState(policyStateReader: () => value),
        WindowsApplicationControlState.inactive,
      );
    }
    expect(
      windowsApplicationControlState(policyStateReader: () => 1),
      WindowsApplicationControlState.enforced,
    );
    for (final reader in <int? Function()>[
      () => throw StateError('access denied'),
      () => 99,
    ]) {
      expect(
        windowsApplicationControlState(policyStateReader: reader),
        WindowsApplicationControlState.unknown,
      );
    }
  });

  test('unreadable or unknown policy fails closed', () {
    for (final reader in <int? Function()>[
      () => throw StateError('access denied'),
      () => 99,
    ]) {
      expect(
        () => ensureUnsignedWindowsUpdateAllowed(policyStateReader: reader),
        throwsA(isA<MessageException>()),
      );
    }
  });

  test(
    'supported non-enforcing states retain successful launch then exit',
    () async {
      for (final state in [null, 0, 2]) {
        final actions = <String>[];
        await launchWindowsUpdate(
          filePath: 'owned setup.exe',
          installDirectory: 'owned app',
          policyStateReader: () => state,
          launcher: (file, args) {
            expect(file, 'owned setup.exe');
            expect(args, '/DIR="owned app" /NORESTART');
            actions.add('launch');
            return true;
          },
          exitApplication: () async => actions.add('exit'),
        );
        expect(actions, ['launch', 'exit']);
      }
    },
  );

  test(
    'cancelled installer launch never exits the current application',
    () async {
      var exited = false;
      await expectLater(
        launchWindowsUpdate(
          filePath: 'owned setup.exe',
          installDirectory: 'owned app',
          policyStateReader: () => 0,
          launcher: (_, _) => false,
          exitApplication: () async {
            exited = true;
          },
        ),
        throwsA(isA<MessageException>()),
      );
      expect(exited, isFalse);
    },
  );
}
