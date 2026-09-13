import 'package:fl_clash/common/common.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  test('restores the six BfClash theme presets', () {
    expect(bfclashThemePresets.map((preset) => preset.id), [
      'gemini',
      'slate',
      'dracula',
      'sakura',
      'sunset',
      'ocean',
    ]);
    expect(
      bfclashThemePresets.map((preset) => preset.selectionValue).toSet(),
      hasLength(bfclashThemePresets.length),
    );
  });

  test('Gemini preserves the original BfClash surfaces', () {
    final dark = buildBfClashColorScheme(
      color: const Color(bfclashGeminiColor),
      brightness: Brightness.dark,
      variant: DynamicSchemeVariant.content,
    );
    final light = buildBfClashColorScheme(
      color: const Color(bfclashGeminiColor),
      brightness: Brightness.light,
      variant: DynamicSchemeVariant.content,
    );
    expect(dark.surface, const Color(0xFF0B0F19));
    expect(dark.surfaceContainerLow, const Color(0xFF111827));
    expect(light.primary, const Color(0xFF4F46E5));
    expect(light.surface, const Color(0xFFF8FAFC));
  });

  test('custom colors still use Material color generation', () {
    final scheme = buildBfClashColorScheme(
      color: const Color(0xFF00FF00),
      brightness: Brightness.light,
      variant: DynamicSchemeVariant.content,
    );
    expect(scheme.brightness, Brightness.light);
    expect(bfclashThemePresetFor(const Color(0xFF00FF00)), isNull);
  });
}
