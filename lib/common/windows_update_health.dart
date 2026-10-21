import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;

Future<bool> reportWindowsUpdateHealth({
  required String executablePath,
  required String localAppData,
  required String version,
  required int processId,
  DateTime? now,
}) async {
  try {
    if (localAppData.isEmpty) return false;
    final request = await _readUpdateRequest(
      executablePath: executablePath,
      version: version,
      now: now,
    );
    if (request == null) return false;
    final nonce = request['nonce'] as String;
    final result = File(
      path.join(localAppData, 'BfClashUpdateHealth', '$nonce.json'),
    );
    await result.parent.create(recursive: true);
    final temporary = File('${result.path}.tmp');
    await temporary.writeAsString(
      jsonEncode({
        'nonce': nonce,
        'version': version,
        'processId': processId,
        'protocol': 2,
      }),
      flush: true,
    );
    await temporary.rename(result.path);
    return true;
  } on Exception {
    return false;
  }
}

Future<Map<String, dynamic>?> _readUpdateRequest({
  required String executablePath,
  required String version,
  DateTime? now,
}) async {
  try {
    final pending = File(
      path.join(path.dirname(executablePath), '.bfclash-update-pending.json'),
    );
    if (!await pending.exists()) return null;
    final request = jsonDecode(await pending.readAsString());
    if (request is! Map<String, dynamic>) return null;
    final nonce = request['nonce'];
    final timestamp = request['createdUtc'];
    final created = timestamp is String ? DateTime.tryParse(timestamp) : null;
    final age = created == null
        ? null
        : (now ?? DateTime.now()).difference(created);
    if (nonce is! String ||
        !RegExp(r'^[a-f0-9]{32}$').hasMatch(nonce) ||
        request['version'] != version ||
        age == null ||
        age.isNegative ||
        age > const Duration(minutes: 5)) {
      return null;
    }
    return request;
  } on Exception {
    return null;
  }
}

Future<bool?> readWindowsUpdateRunningIntent({
  required String executablePath,
  required String version,
  DateTime? now,
}) async {
  final request = await _readUpdateRequest(
    executablePath: executablePath,
    version: version,
    now: now,
  );
  final running = request?['resumeRunning'];
  return running is bool ? running : null;
}
