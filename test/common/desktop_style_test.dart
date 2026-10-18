import 'package:bfclash/common/desktop_style.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  test(
    'desktop dark surfaces follow the reference and retain custom accent',
    () {
      final original = ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFB923C),
          brightness: Brightness.dark,
        ),
      );
      final result = buildDesktopTheme(original);
      expect(result.colorScheme.surface, const Color(0xFF0B0B12));
      expect(result.colorScheme.surfaceContainerLow, const Color(0xFF12121B));
      expect(result.colorScheme.primary, original.colorScheme.primary);
      expect(result.colorScheme.error, original.colorScheme.error);
    },
  );

  test('desktop adaptation retains the pure-black preference', () {
    final original = ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.indigo,
        brightness: Brightness.dark,
      ).copyWith(surface: Colors.black),
    );
    final result = buildDesktopTheme(original);
    expect(result.colorScheme.surface, Colors.black);
    expect(result.colorScheme.surfaceContainerLowest, Colors.black);
  });

  test('light color scheme remains selected by the user', () {
    final original = ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
    );
    final result = buildDesktopTheme(original);
    expect(result.brightness, Brightness.light);
    expect(result.colorScheme, original.colorScheme);
  });
}
