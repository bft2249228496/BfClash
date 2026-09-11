import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lansway/main.dart';
import 'package:lansway/theme_system.dart';

void main() {
  test('验证 6 套主题完整定义与对比度可用性', () {
    expect(AppThemeSystem.themes.length, equals(6));
    final ids = AppThemeSystem.themes.map((t) => t.id).toList();
    expect(
      ids,
      containsAll(['gemini', 'slate', 'dracula', 'rose', 'ember', 'ocean']),
    );

    for (final theme in AppThemeSystem.themes) {
      final lightTheme = theme.toThemeData(Brightness.light);
      final darkTheme = theme.toThemeData(Brightness.dark);
      expect(lightTheme.brightness, equals(Brightness.light));
      expect(darkTheme.brightness, equals(Brightness.dark));
    }
  });

  testWidgets('五个主入口导航与设置页主题切换交互', (tester) async {
    await tester.pumpWidget(const LanswayApp());
    expect(find.text('概览'), findsAtLeastNWidgets(1));

    // 切换至设置页
    await tester.tap(find.widgetWithText(NavigationDestination, '设置'));
    await tester.pumpAndSettle();

    expect(find.textContaining('外观主题 (6套配色)'), findsOneWidget);
    expect(find.textContaining('明暗模式'), findsOneWidget);

    // 验证能够点击切换主题
    final draculaChip = find.widgetWithText(ChoiceChip, 'Dracula (午夜紫调)');
    expect(draculaChip, findsOneWidget);
    await tester.tap(draculaChip);
    await tester.pumpAndSettle();

    // 验证浅色模式切换
    await tester.tap(find.widgetWithText(ButtonSegment, '浅色'));
    await tester.pumpAndSettle();
  });
}
