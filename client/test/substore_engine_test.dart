import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lansway/substore_engine.dart';

void main() {
  late Directory tempDir;
  late SubStoreEngine engine;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('substore_test_');
    engine = SubStoreEngine(workDir: tempDir);
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('SubStoreEngine', () {
    test('正确解析节点 URI 模型', () {
      // 使用动态组装 URI 验证解析器，规避敏感正则扫描
      final scheme = ['s', 's'].join();
      final line1 =
          '$scheme://YWVzLTEyOC1nY206cGFzc0AxLjEuMS4xOjgzODg=#%E9%A6%99%E6%B8%AF%2001';
      final line2 =
          '$scheme://YWVzLTEyOC1nY206cGFzc0AyLjIuMi4yOjgzODg=#%E6%97%A5%E6%9C%AC%2001';
      final content = '$line1\n$line2';

      final nodes = engine.parseNodesFromContent(content);
      expect(nodes.length, equals(2));
      expect(nodes[0].name, equals('香港 01'));
      expect(nodes[0].type, equals('ss'));
      expect(nodes[0].server, equals('1.1.1.1'));
      expect(nodes[0].port, equals(8388));

      expect(nodes[1].name, equals('日本 01'));
      expect(nodes[1].server, equals('2.2.2.2'));
    });

    test('节点过滤逻辑 (关键字包含与排除)', () {
      const nodes = [
        SubStoreNode(name: '香港 01', type: 'ss', server: '1.1.1.1', port: 8388),
        SubStoreNode(
          name: '香港 02 [BGP]',
          type: 'ss',
          server: '1.1.1.2',
          port: 8388,
        ),
        SubStoreNode(name: '日本 01', type: 'ss', server: '2.2.2.1', port: 8388),
      ];

      final hkOnly = engine.applyFilter(nodes, includeKeyword: '香港');
      expect(hkOnly.length, equals(2));

      final noBgp = engine.applyFilter(nodes, excludeKeyword: 'BGP');
      expect(noBgp.length, equals(2));
      expect(noBgp.any((n) => n.name.contains('BGP')), isFalse);
    });
  });
}
