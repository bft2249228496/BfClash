import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;

import 'channel_config.dart';

void recordWindowsLifecycle(String event, {Object? error, StackTrace? stack}) {
  if (!Platform.isWindows) return;
  final localAppData = Platform.environment['LOCALAPPDATA'];
  if (localAppData == null || localAppData.isEmpty) return;
  try {
    final directory = Directory(
      path.join(
        localAppData,
        'BfClashDiagnostics',
        WindowsChannelConfig.updateChannel,
      ),
    )..createSync(recursive: true);
    final log = File(path.join(directory.path, 'lifecycle.jsonl'));
    if (log.existsSync() && log.lengthSync() >= 1024 * 1024) {
      final previous = File('${log.path}.previous');
      if (previous.existsSync()) previous.deleteSync();
      log.renameSync(previous.path);
    }
    final frames = stack
        ?.toString()
        .split('\n')
        .where((line) => line.contains('(package:bfclash/'))
        .take(8)
        .toList();
    final entry = {
      'time': DateTime.now().toUtc().toIso8601String(),
      'pid': pid,
      'event': event,
      if (error != null) 'errorType': error.runtimeType.toString(),
      if (error is StateError && error.message == 'No element')
        'reason': 'emptyStream',
      if (frames != null && frames.isNotEmpty) 'stack': frames,
    };
    log.writeAsStringSync(
      '${jsonEncode(entry)}\n',
      mode: FileMode.append,
      flush: true,
    );
  } on FileSystemException {
    // Diagnostics must never interrupt startup or Core communication.
  }
}
