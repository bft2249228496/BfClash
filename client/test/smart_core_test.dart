import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lansway/smart_core.dart';

void main() {
  late Directory tempDir;
  late SmartCoreEngine engine;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('smart_core_test_');
    engine = SmartCoreEngine(coreStorageDir: tempDir);
    await engine.initialize();
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('SmartCoreEngine', () {
    test('默认核心为 Mihomo v1.19.30', () {
      expect(engine.activeCore, equals(CoreType.mihomo));
      expect(engine.activeVersion, equals('v1.19.30'));
    });

    test('核心切换与持久化状态', () async {
      final ok = await engine.switchCore(
        CoreType.smartCore,
        targetVersion: 'v2.0.0-rc1',
      );
      expect(ok, isTrue);
      expect(engine.activeCore, equals(CoreType.smartCore));
      expect(engine.activeVersion, equals('v2.0.0-rc1'));

      // 重新实例化读取持久化状态
      final reloaded = SmartCoreEngine(coreStorageDir: tempDir);
      await reloaded.initialize();
      expect(reloaded.activeCore, equals(CoreType.smartCore));
      expect(reloaded.activeVersion, equals('v2.0.0-rc1'));
    });

    test('健康检查失败时自动回退至基准 Mihomo 核心', () async {
      await engine.switchCore(
        CoreType.smartCore,
        targetVersion: 'v2.0.0-broken',
      );
      expect(engine.activeCore, equals(CoreType.smartCore));

      final healthy = await engine.verifyAndRollbackOnFailure(false);
      expect(healthy, isFalse);
      expect(engine.activeCore, equals(CoreType.mihomo));
      expect(engine.activeVersion, equals('v1.19.30'));
    });
  });
}
