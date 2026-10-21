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
    final pending = File(
      path.join(path.dirname(executablePath), '.bfclash-update-pending.json'),
    );
    if (!await pending.exists()) return false;
    final request = jsonDecode(await pending.readAsString());
    if (request is! Map<String, dynamic>) return false;
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
        age > const Duration(minutes: 5) ||
        localAppData.isEmpty) {
      return false;
    }
    final result = File(
      path.join(localAppData, 'BfClashUpdateHealth', '$nonce.json'),
    );
    await result.parent.create(recursive: true);
    final temporary = File('${result.path}.tmp');
    await temporary.writeAsString(
      jsonEncode({'nonce': nonce, 'version': version, 'processId': processId}),
      flush: true,
    );
    await temporary.rename(result.path);
    return true;
  } on Exception {
    return false;
  }
}
