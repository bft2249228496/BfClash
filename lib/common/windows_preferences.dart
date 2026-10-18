import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

Future<void> migrateWindowsBetaPreferences(Directory betaDirectory) async {
  final target = File(p.join(betaDirectory.path, 'shared_preferences.json'));
  if (await target.exists()) return;
  final legacy = File(
    p.join(betaDirectory.parent.path, 'clash', 'shared_preferences.json'),
  );
  if (!await legacy.exists()) return;
  final contents = await legacy.readAsString();
  final decoded = jsonDecode(contents);
  if (decoded is! Map<String, dynamic>) {
    throw const FormatException('Invalid legacy Windows preferences');
  }
  await betaDirectory.create(recursive: true);
  await target.writeAsString(contents, flush: true);
}
