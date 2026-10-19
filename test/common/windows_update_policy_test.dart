import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bfclash/common/common.dart';
import 'package:bfclash/common/windows_update_policy.dart';
import 'package:bfclash/l10n/l10n.dart';

void main() {
  setUp(() async => AppLocalizations.load(const Locale('en')));

  test('enforced policy blocks installer and exit', () async {
    final actions = <String>[];
    await expectLater(
      launchUnsignedWindowsUpdate(
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
        await launchUnsignedWindowsUpdate(
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
        launchUnsignedWindowsUpdate(
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
