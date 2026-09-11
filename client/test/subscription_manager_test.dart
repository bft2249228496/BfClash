import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lansway/subscription_manager.dart';

void main() {
  late Directory tempDir;
  late SubscriptionManager manager;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('sub_test_');
    manager = SubscriptionManager(storageDir: tempDir);
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('SubscriptionManager', () {
    test('拒绝非 HTTP/HTTPS 链接', () async {
      expect(
        () async => await manager.addSubscription(
          name: '非法链接',
          url: 'ftp://example.com/sub',
        ),
        throwsArgumentError,
      );
    });

    test('添加并持久化订阅', () async {
      final sub = await manager.addSubscription(
        name: '工作节点',
        url:
            'https://example.com/api/v1/client/subscribe?token=mock_test_token',
      );
      expect(sub.name, equals('工作节点'));
      expect(manager.subscriptions.length, equals(1));

      // 重新实例化并读取，验证持久化
      final newManager = SubscriptionManager(storageDir: tempDir);
      await newManager.load();
      expect(newManager.subscriptions.length, equals(1));
      expect(newManager.subscriptions.first.id, equals(sub.id));
    });

    test('删除订阅', () async {
      final sub = await manager.addSubscription(
        name: '临时订阅',
        url: 'https://example.com/sub',
      );
      expect(manager.subscriptions.length, equals(1));

      final ok = await manager.removeSubscription(sub.id);
      expect(ok, isTrue);
      expect(manager.subscriptions.isEmpty, isTrue);
    });

    test('解析 subscription-userinfo 头部', () {
      const header =
          'upload=1073741824; download=5368709120; total=107374182400; expire=1789123456';
      final parsed = SubscriptionManager.parseSubscriptionUserInfoHeader(
        header,
      );
      expect(parsed['upload'], equals(1073741824));
      expect(parsed['download'], equals(5368709120));
      expect(parsed['total'], equals(107374182400));
      expect(parsed['expire'], equals(1789123456));
    });
  });
}
