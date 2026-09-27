import 'dart:io';

import 'package:bfclash/common/lock.dart';
import 'package:bfclash/common/path.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart';

void main() {
  late Directory home;

  setUp(() {
    home = Directory.systemTemp.createTempSync('bfclash-lock-');
    SingleInstanceLock.resolvePath = () async =>
        join(home.path, 'BfClash.lock');
  });

  tearDown(() async {
    SingleInstanceLock.resolvePath = () => appPath.lockFilePath;
    await SingleInstanceLock().release();
    if (home.existsSync()) home.deleteSync(recursive: true);
  });

  test('SingleInstanceLock is a singleton', () {
    expect(SingleInstanceLock(), same(singleInstanceLock));
  });

  test(
    'acquiring holds the lock file the second instance would test',
    () async {
      final path = join(home.path, 'BfClash.lock');
      expect(File(path).existsSync(), isFalse);

      expect(await SingleInstanceLock().acquire(), isTrue);

      expect(
        File(path).existsSync(),
        isTrue,
        reason:
            'the file is what a second process locks against; without it every '
            'launch would start another core.',
      );
    },
  );

  test('an unusable lock path is reported, not thrown', () async {
    SingleInstanceLock.resolvePath = () async =>
        join(home.path, 'missing-dir', 'BfClash.lock');

    expect(
      await SingleInstanceLock().acquire(),
      isFalse,
      reason:
          'acquire runs before the window exists, so a broken path has to come '
          'back as false rather than take the launch down.',
    );
  });

  test('a path that is a directory is reported, not thrown', () async {
    final directory = Directory(join(home.path, 'BfClash.lock'))
      ..createSync(recursive: true);
    SingleInstanceLock.resolvePath = () async => directory.path;

    expect(await SingleInstanceLock().acquire(), isFalse);
  });

  test('a failure to resolve the path is reported, not thrown', () async {
    SingleInstanceLock.resolvePath = () async =>
        throw const FileSystemException('no home directory');

    expect(await SingleInstanceLock().acquire(), isFalse);
  });
}
