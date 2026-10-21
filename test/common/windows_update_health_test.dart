import 'dart:convert';
import 'dart:io';

import 'package:bfclash/common/windows_update_health.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;

void main() {
  late Directory root;
  final now = DateTime.utc(2026, 10, 21, 8);
  const nonce = '0123456789abcdef0123456789abcdef';
  const version = '1.0.1-beta.1911';

  setUp(() async => root = await Directory.systemTemp.createTemp('bf-health-'));
  tearDown(() async => root.delete(recursive: true));

  Future<bool> report() => reportWindowsUpdateHealth(
    executablePath: path.join(root.path, 'BfClash-Beta.exe'),
    localAppData: path.join(root.path, 'local'),
    version: version,
    processId: 1234,
    now: now,
  );

  Future<void> pending({
    String token = nonce,
    String target = version,
    Duration age = const Duration(seconds: 10),
    bool? running,
  }) async {
    await File(
      path.join(root.path, '.bfclash-update-pending.json'),
    ).writeAsString(
      jsonEncode({
        'nonce': token,
        'resumeRunning': ?running,
        'version': target,
        'createdUtc': now.subtract(age).toIso8601String(),
      }),
    );
  }

  test(
    'restores either running intent only for the matching transaction',
    () async {
      for (final running in [true, false]) {
        await pending(running: running);
        expect(
          await readWindowsUpdateRunningIntent(
            executablePath: path.join(root.path, 'BfClash-Beta.exe'),
            version: version,
            now: now,
          ),
          running,
        );
      }
      await pending(running: true, target: 'old');
      expect(
        await readWindowsUpdateRunningIntent(
          executablePath: path.join(root.path, 'BfClash-Beta.exe'),
          version: version,
          now: now,
        ),
        isNull,
      );
    },
  );

  test('normal launch leaves no update state', () async {
    expect(await report(), isFalse);
    expect(await Directory(path.join(root.path, 'local')).exists(), isFalse);
  });

  test('acknowledges only the pending version and process', () async {
    await pending();
    expect(await report(), isTrue);
    final ack = File(
      path.join(root.path, 'local', 'BfClashUpdateHealth', '$nonce.json'),
    );
    expect(jsonDecode(await ack.readAsString()), {
      'nonce': nonce,
      'version': version,
      'processId': 1234,
      'protocol': 2,
    });
    expect(await File('${ack.path}.tmp').exists(), isFalse);
  });

  test('rejects an old or future transaction', () async {
    await pending(age: const Duration(minutes: 6));
    expect(await report(), isFalse);
    await pending(age: const Duration(seconds: -1));
    expect(await report(), isFalse);
  });

  test('rejects a mismatched version or path-like token', () async {
    await pending(target: '1.0.0-beta.1871');
    expect(await report(), isFalse);
    await pending(token: '../outside');
    expect(await report(), isFalse);
  });

  test('malformed state does not prevent app startup', () async {
    await File(
      path.join(root.path, '.bfclash-update-pending.json'),
    ).writeAsString('not json');
    expect(await report(), isFalse);
  });

  test('unexpected JSON structure does not prevent app startup', () async {
    await File(
      path.join(root.path, '.bfclash-update-pending.json'),
    ).writeAsString('[]');
    expect(await report(), isFalse);
  });
}
