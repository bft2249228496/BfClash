import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lansway/main.dart';

void main() {
  testWidgets('未接入内核时不显示虚假的连接状态', (tester) async {
    await tester.pumpWidget(const LanswayApp());
    expect(find.text('已连接'), findsNothing);
    expect(find.textContaining('未连接'), findsAtLeastNWidgets(1));
    await tester.tap(find.widgetWithText(NavigationDestination, '配置'));
    await tester.pump();
    expect(find.textContaining('配置'), findsAtLeastNWidgets(1));
  });
}
