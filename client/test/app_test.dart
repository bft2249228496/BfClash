import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lansway/main.dart';

void main() {
  testWidgets('未接入内核时不显示虚假的连接状态', (tester) async {
    await tester.pumpWidget(const LanswayApp());
    expect(find.textContaining('代理服务尚未接入'), findsOneWidget);
    expect(find.text('已连接'), findsNothing);
    await tester.tap(find.widgetWithText(NavigationDestination, '订阅'));
    await tester.pumpAndSettle();
    expect(find.textContaining('订阅导入与配置持久化'), findsOneWidget);
  });
}
