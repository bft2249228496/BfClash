import 'package:material_ui/material_ui.dart';

const bfclashPartyColor = 0xFF6366F1;
const bfclashGeminiColor = 0xFF818CF8;
const bfclashSlateColor = 0xFF94A3B8;
const bfclashDraculaColor = 0xFFC084FC;
const bfclashSakuraColor = 0xFFFB7185;
const bfclashSunsetColor = 0xFFFB923C;
const bfclashOceanColor = 0xFF38BDF8;

class BfClashThemePreset {
  const BfClashThemePreset({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.selectionValue,
    required this.primaryDark,
    required this.backgroundDark,
    required this.cardDark,
    required this.borderDark,
    required this.primaryLight,
    required this.backgroundLight,
    required this.cardLight,
    required this.borderLight,
  });

  final String id;
  final String name;
  final String subtitle;
  final int selectionValue;
  final Color primaryDark;
  final Color backgroundDark;
  final Color cardDark;
  final Color borderDark;
  final Color primaryLight;
  final Color backgroundLight;
  final Color cardLight;
  final Color borderLight;

  Color get selectionColor => Color(selectionValue);
  Color primary(Brightness brightness) =>
      brightness == Brightness.dark ? primaryDark : primaryLight;
  Color background(Brightness brightness) =>
      brightness == Brightness.dark ? backgroundDark : backgroundLight;
  Color card(Brightness brightness) =>
      brightness == Brightness.dark ? cardDark : cardLight;
  Color border(Brightness brightness) =>
      brightness == Brightness.dark ? borderDark : borderLight;
}

const bfclashThemePresets = <BfClashThemePreset>[
  BfClashThemePreset(
    id: 'party',
    name: 'Party',
    subtitle: '黑曜派对',
    selectionValue: bfclashPartyColor,
    primaryDark: Color(0xFF818CF8),
    backgroundDark: Color(0xFF0B0C10),
    cardDark: Color(0xFF151620),
    borderDark: Color(0xFF282B3C),
    primaryLight: Color(0xFF4F46E5),
    backgroundLight: Color(0xFFF8FAFC),
    cardLight: Color(0xFFFFFFFF),
    borderLight: Color(0xFFE2E8F0),
  ),
  BfClashThemePreset(
    id: 'gemini',
    name: 'Gemini',
    subtitle: '星夜蓝紫',
    selectionValue: bfclashGeminiColor,
    primaryDark: Color(0xFF818CF8),
    backgroundDark: Color(0xFF0B0F19),
    cardDark: Color(0xFF111827),
    borderDark: Color(0xFF1F293D),
    primaryLight: Color(0xFF4F46E5),
    backgroundLight: Color(0xFFF8FAFC),
    cardLight: Color(0xFFFFFFFF),
    borderLight: Color(0xFFE2E8F0),
  ),
  BfClashThemePreset(
    id: 'slate',
    name: 'Slate',
    subtitle: '极客石墨',
    selectionValue: bfclashSlateColor,
    primaryDark: Color(0xFFCBD5E1),
    backgroundDark: Color(0xFF0F172A),
    cardDark: Color(0xFF1E293B),
    borderDark: Color(0xFF334155),
    primaryLight: Color(0xFF475569),
    backgroundLight: Color(0xFFF8FAFC),
    cardLight: Color(0xFFFFFFFF),
    borderLight: Color(0xFFE2E8F0),
  ),
  BfClashThemePreset(
    id: 'dracula',
    name: 'Dracula',
    subtitle: '霓虹暗紫',
    selectionValue: bfclashDraculaColor,
    primaryDark: Color(0xFFC084FC),
    backgroundDark: Color(0xFF140D24),
    cardDark: Color(0xFF22173B),
    borderDark: Color(0xFF3B2766),
    primaryLight: Color(0xFF9333EA),
    backgroundLight: Color(0xFFFAF5FF),
    cardLight: Color(0xFFFFFFFF),
    borderLight: Color(0xFFF3E8FF),
  ),
  BfClashThemePreset(
    id: 'sakura',
    name: 'Sakura',
    subtitle: '柔和樱霞',
    selectionValue: bfclashSakuraColor,
    primaryDark: Color(0xFFFB7185),
    backgroundDark: Color(0xFF1F0C16),
    cardDark: Color(0xFF2F1322),
    borderDark: Color(0xFF4C1D37),
    primaryLight: Color(0xFFE11D48),
    backgroundLight: Color(0xFFFFF1F2),
    cardLight: Color(0xFFFFFFFF),
    borderLight: Color(0xFFFFE4E6),
  ),
  BfClashThemePreset(
    id: 'sunset',
    name: 'Sunset',
    subtitle: '落日暖橘',
    selectionValue: bfclashSunsetColor,
    primaryDark: Color(0xFFFB923C),
    backgroundDark: Color(0xFF1C1209),
    cardDark: Color(0xFF2D1A0B),
    borderDark: Color(0xFF49280E),
    primaryLight: Color(0xFFEA580C),
    backgroundLight: Color(0xFFFFF7ED),
    cardLight: Color(0xFFFFFFFF),
    borderLight: Color(0xFFFFEDD5),
  ),
  BfClashThemePreset(
    id: 'ocean',
    name: 'Ocean',
    subtitle: '清透海盐',
    selectionValue: bfclashOceanColor,
    primaryDark: Color(0xFF38BDF8),
    backgroundDark: Color(0xFF061626),
    cardDark: Color(0xFF0C243C),
    borderDark: Color(0xFF163B60),
    primaryLight: Color(0xFF0284C7),
    backgroundLight: Color(0xFFF0F9FF),
    cardLight: Color(0xFFFFFFFF),
    borderLight: Color(0xFFE0F2FE),
  ),
];

BfClashThemePreset? bfclashThemePresetFor(Color color) {
  for (final preset in bfclashThemePresets) {
    if (preset.selectionValue == color.toARGB32()) return preset;
  }
  return null;
}

ColorScheme buildBfClashColorScheme({
  required Color color,
  required Brightness brightness,
  required DynamicSchemeVariant variant,
}) {
  final preset = bfclashThemePresetFor(color);
  if (preset == null) {
    return ColorScheme.fromSeed(
      seedColor: color,
      brightness: brightness,
      dynamicSchemeVariant: variant,
    );
  }
  final background = preset.background(brightness);
  final card = preset.card(brightness);
  final border = preset.border(brightness);
  final isParty = preset.id == 'party' && brightness == Brightness.dark;
  return ColorScheme.fromSeed(
    seedColor: preset.primary(brightness),
    brightness: brightness,
    dynamicSchemeVariant: variant,
  ).copyWith(
    primary: preset.primary(brightness),
    surface: background,
    surfaceContainerLowest: background,
    surfaceContainerLow: card,
    surfaceContainer: isParty
        ? const Color(0xFF191B28)
        : Color.lerp(background, card, 0.72),
    surfaceContainerHigh: isParty
        ? const Color(0xFF202334)
        : Color.lerp(card, border, 0.22),
    surfaceContainerHighest: isParty ? const Color(0xFF2D3148) : border,
    outline: border,
    outlineVariant: isParty
        ? const Color(0xFF383C56)
        : border.withValues(alpha: 0.72),
    secondaryContainer: isParty ? const Color(0xFF272147) : null,
    onSecondaryContainer: isParty ? const Color(0xFFA5B4FC) : null,
  );
}
