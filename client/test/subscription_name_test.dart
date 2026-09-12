import 'package:flutter_test/flutter_test.dart';
import 'package:lansway/subscription_manager.dart';

void main() {
  group('SubscriptionManager URL 文件名/名称解析', () {
    test('从 URL path 提取文件名并去除后缀', () {
      expect(
        SubscriptionManager.extractSubscriptionName(
          'https://gist.githubusercontent.com/user/raw/123/my-special-sub.yaml',
        ),
        equals('my-special-sub'),
      );
      expect(
        SubscriptionManager.extractSubscriptionName(
          'https://example.com/nodes/hk-vip.yml',
        ),
        equals('hk-vip'),
      );
    });

    test('从 URL query 参数提取 name/filename', () {
      expect(
        SubscriptionManager.extractSubscriptionName(
          'https://example.com/api/v1/client/subscribe?token=abc&name=TokyoFast',
        ),
        equals('TokyoFast'),
      );
      expect(
        SubscriptionManager.extractSubscriptionName(
          'https://example.com/sub?token=abc&filename=HongKongNodes.yaml',
        ),
        equals('HongKongNodes.yaml'),
      );
    });

    test('无法获取明确文件名时回退到域名', () {
      expect(
        SubscriptionManager.extractSubscriptionName(
          'https://sub.domain.com/sub?token=123',
        ),
        equals('sub.domain.com'),
      );
    });
  });
}
