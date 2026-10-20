import 'dart:io';

import 'package:bfclash/common/common.dart';
import 'package:path/path.dart' as p;

Future<void> launchLoopbackTool({
  bool Function(String command, String arguments)? launcher,
  String? executableDirectory,
}) async {
  final launch = launcher ?? windows?.runas;
  final command = p.join(
    executableDirectory ?? p.dirname(Platform.resolvedExecutable),
    'EnableLoopback.exe',
  );
  if (launch == null || !launch(command, '')) {
    throw MessageException(currentAppLocalizations.loopbackLaunchFailed);
  }
}
