import 'dart:io';

import 'package:bfclash/common/windows_preferences.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory root;
  late Directory beta;
  late File legacy;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('bfclash-preferences-');
    beta = Directory(p.join(root.path, 'com.bfclash.client.beta'));
    legacy = File(p.join(root.path, 'clash', 'shared_preferences.json'));
    await legacy.parent.create(recursive: true);
  });
  tearDown(() async => root.delete(recursive: true));
  test('copies existing settings while preserving the stable file', () async {
    const original = r'{"flutter.config":"{\"currentProfileId\":42}"}';
    await legacy.writeAsString(original);
    await migrateWindowsBetaPreferences(beta);
    final target = File(p.join(beta.path, 'shared_preferences.json'));
    expect(await target.readAsString(), original);
    await target.writeAsString('{"beta":"changed"}');
    expect(await legacy.readAsString(), original);
  });
  test('never replaces settings after the first migration', () async {
    await legacy.writeAsString('{"stable":"new"}');
    await beta.create();
    final target = File(p.join(beta.path, 'shared_preferences.json'));
    await target.writeAsString('{"beta":"existing"}');
    await migrateWindowsBetaPreferences(beta);
    expect(await target.readAsString(), '{"beta":"existing"}');
  });
  test('invalid legacy data is not copied into the beta file', () async {
    await legacy.writeAsString('broken');
    await expectLater(
      migrateWindowsBetaPreferences(beta),
      throwsFormatException,
    );
    expect(
      await File(p.join(beta.path, 'shared_preferences.json')).exists(),
      isFalse,
    );
  });
  test('fresh installation has no legacy file to migrate', () async {
    await migrateWindowsBetaPreferences(beta);
    expect(await beta.exists(), isFalse);
  });
}
