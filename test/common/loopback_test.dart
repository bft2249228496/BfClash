import 'package:flutter/widgets.dart';
import 'package:bfclash/common/common.dart';
import 'package:bfclash/l10n/l10n.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  setUp(() async => AppLocalizations.load(const Locale('en')));

  test('loopback launcher receives the unquoted path with spaces', () async {
    String? command;
    String? arguments;
    await launchLoopbackTool(
      executableDirectory: p.join('owned fixture', 'BfClash Beta'),
      launcher: (file, params) {
        command = file;
        arguments = params;
        return true;
      },
    );
    expect(
      command,
      p.join('owned fixture', 'BfClash Beta', 'EnableLoopback.exe'),
    );
    expect(arguments, isEmpty);
  });

  test('denied loopback launch reports a localized failure', () async {
    await expectLater(
      launchLoopbackTool(launcher: (_, _) => false),
      throwsA(
        isA<MessageException>().having(
          (error) => error.message,
          'message',
          currentAppLocalizations.loopbackLaunchFailed,
        ),
      ),
    );
  });
}
