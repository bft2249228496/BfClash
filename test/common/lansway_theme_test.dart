import 'package:fl_clash/common/common.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  test('restores the six Lansway theme presets', () {
    expect(lanswayThemePresets.map((preset) => preset.id), [
      'gemini',
      'slate',
      'dracula',
      'sakura',
      'sunset',
      'ocean',
    ]);
    expect(
      lanswayThemePresets.map((preset) => preset.selectionValue).toSet(),
      hasLength(lanswayThemePresets.length),
    );
  });

  test('Gemini preserves the original Lansway surfaces', () {
    final dark = buildLanswayColorScheme(
      color: const Color(lanswayGeminiColor),
      brightness: Brightness.dark,
      variant: DynamicSchemeVariant.content,
    );
    final light = buildLanswayColorScheme(
      color: const Color(lanswayGeminiColor),
      brightness: Brightness.light,
      variant: DynamicSchemeVariant.content,
    );
    expect(dark.surface, const Color(0xFF0B0F19));
    expect(dark.surfaceContainerLow, const Color(0xFF111827));
    expect(light.primary, const Color(0xFF4F46E5));
    expect(light.surface, const Color(0xFFF8FAFC));
  });

  test('custom colors still use Material color generation', () {
    final scheme = buildLanswayColorScheme(
      color: const Color(0xFF00FF00),
      brightness: Brightness.light,
      variant: DynamicSchemeVariant.content,
    );
    expect(scheme.brightness, Brightness.light);
    expect(lanswayThemePresetFor(const Color(0xFF00FF00)), isNull);
  });
}
