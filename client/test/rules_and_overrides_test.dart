import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lansway/rules_and_overrides.dart';

void main() {
  late Directory tempDir;
  late RulesAndOverrideEngine engine;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('rules_test_');
    engine = RulesAndOverrideEngine(storageDir: tempDir);
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('RulesAndOverrideEngine', () {
    test('正确添加覆写规则并按优先级降序排列', () {
      engine.addRule(
        const OverrideRule(
          id: 'r1',
          name: '低优先级覆写',
          yamlSnippet: 'dns:\n  enable: true',
          priority: 50,
        ),
      );
      engine.addRule(
        const OverrideRule(
          id: 'r2',
          name: '高优先级覆写',
          yamlSnippet: 'tun:\n  enable: true',
          priority: 100,
        ),
      );

      expect(engine.rules.length, equals(2));
      expect(engine.rules.first.id, equals('r2'));
      expect(engine.rules.last.id, equals('r1'));
    });

    test('覆写规则合成与生效逻辑', () {
      engine.addRule(
        const OverrideRule(
          id: 'r1',
          name: '启用TUN',
          yamlSnippet: 'tun:\n  enable: true',
          enabled: true,
        ),
      );
      engine.addRule(
        const OverrideRule(
          id: 'r2',
          name: '未启用覆写',
          yamlSnippet: 'experimental:\n  quic: true',
          enabled: false,
        ),
      );

      const base = 'port: 7890';
      final output = engine.applyOverrides(base);
      expect(output, contains('tun:\n  enable: true'));
      expect(output, isNot(contains('quic: true')));
    });
  });
}
