import 'package:material_ui/material_ui.dart';

const bfclashPartyColor = 0xFF6366F1;
const bfclashGeminiColor = 0xFF818CF8;
const bfclashSlateColor = 0xFF94A3B8;
const bfclashDraculaColor = 0xFFC084FC;
const bfclashSakuraColor = 0xFFFB7185;
const bfclashSunsetColor = 0xFFFB923C;
const bfclashOceanColor = 0xFF38BDF8;
const bfclashObsidianColor = 0xFF818CF8;
const bfclashEmberColor = 0xFFF59E0B;
const bfclashNeonColor = 0xFF06B6D4;

/// 深色模式下带主色倾向的层级容器色。
///
/// 不配置时回退到 [background] / [card] / [border] 的插值，
/// 也就是纯中性层级，不额外染色。
class BfClashThemeTint {
  const BfClashThemeTint({
    required this.container,
    required this.containerHigh,
    required this.containerHighest,
    required this.outlineVariant,
    required this.secondaryContainer,
  });

  final Color container;
  final Color containerHigh;
  final Color containerHighest;
  final Color outlineVariant;
  final Color secondaryContainer;
}

/// 靛蓝极光层级，供 Party / Gemini / Obsidian 深色模式使用。
const bfclashIndigoTint = BfClashThemeTint(
  container: Color(0xFF191B28),
  containerHigh: Color(0xFF202334),
  containerHighest: Color(0xFF2D3148),
  outlineVariant: Color(0xFF383C56),
  secondaryContainer: Color(0xFF272147),
);

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
    this.darkTint,
    this.textPrimaryDark = const Color(0xFFEDE9FE),
    this.textSecondaryDark = const Color(0xFFA5B4FC),
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

  /// 深色模式层级容器色；null 表示使用中性插值层级。
  final BfClashThemeTint? darkTint;

  /// 深色模式主文字色，默认沿用原有的冰月白。
  final Color textPrimaryDark;

  /// 深色模式次级文字色，默认沿用原有的雾感紫蓝灰。
  final Color textSecondaryDark;

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
    darkTint: bfclashIndigoTint,
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
    darkTint: bfclashIndigoTint,
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
  BfClashThemePreset(
    id: 'obsidian',
    name: 'Obsidian',
    subtitle: '极光黑曜',
    selectionValue: bfclashObsidianColor,
    darkTint: bfclashIndigoTint,
    primaryDark: Color(0xFF818CF8),
    backgroundDark: Color(0xFF08080D),
    cardDark: Color(0xFF12121B),
    borderDark: Color(0xFF282B3C),
    primaryLight: Color(0xFF4F46E5),
    backgroundLight: Color(0xFFF5F3FF),
    cardLight: Color(0xFFFFFFFF),
    borderLight: Color(0xFFE0E7FF),
  ),
  BfClashThemePreset(
    id: 'ember',
    name: 'Ember',
    subtitle: '琥珀余烬',
    selectionValue: bfclashEmberColor,
    darkTint: BfClashThemeTint(
      container: Color(0xFF241708),
      containerHigh: Color(0xFF2C1C0B),
      containerHighest: Color(0xFF3A2611),
      outlineVariant: Color(0xFF4A3118),
      secondaryContainer: Color(0xFF3B2609),
    ),
    textPrimaryDark: Color(0xFFFDF0DC),
    textSecondaryDark: Color(0xFFC9A882),
    primaryDark: Color(0xFFF59E0B),
    backgroundDark: Color(0xFF120A05),
    cardDark: Color(0xFF1C1108),
    borderDark: Color(0xFF3A2612),
    primaryLight: Color(0xFFB45309),
    backgroundLight: Color(0xFFFFFBED),
    cardLight: Color(0xFFFFFFFF),
    borderLight: Color(0xFFFEF3C7),
  ),
  BfClashThemePreset(
    id: 'neon',
    name: 'Neon',
    subtitle: '霓虹赛博',
    selectionValue: bfclashNeonColor,
    darkTint: BfClashThemeTint(
      container: Color(0xFF0B1720),
      containerHigh: Color(0xFF10202C),
      containerHighest: Color(0xFF162C3C),
      outlineVariant: Color(0xFF1E3A4E),
      secondaryContainer: Color(0xFF0A2A38),
    ),
    textPrimaryDark: Color(0xFFE0F7FB),
    textSecondaryDark: Color(0xFF8FCBD6),
    primaryDark: Color(0xFF06B6D4),
    backgroundDark: Color(0xFF070B0F),
    cardDark: Color(0xFF0D1420),
    borderDark: Color(0xFF1A2840),
    primaryLight: Color(0xFF0891B2),
    backgroundLight: Color(0xFFECFEFF),
    cardLight: Color(0xFFFFFFFF),
    borderLight: Color(0xFFCFFAFE),
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
  final tint = brightness == Brightness.dark ? preset.darkTint : null;
  return ColorScheme.fromSeed(
    seedColor: preset.primary(brightness),
    brightness: brightness,
    dynamicSchemeVariant: variant,
  ).copyWith(
    primary: preset.primary(brightness),
    surface: background,
    surfaceContainerLowest: background,
    surfaceContainerLow: card,
    surfaceContainer: tint?.container ?? Color.lerp(background, card, 0.72),
    surfaceContainerHigh: tint?.containerHigh ?? Color.lerp(card, border, 0.22),
    surfaceContainerHighest: tint?.containerHighest ?? border,
    outline: border,
    outlineVariant: tint?.outlineVariant ?? border.withValues(alpha: 0.72),
    onSurface: tint != null ? preset.textPrimaryDark : null,
    onSurfaceVariant: tint != null ? preset.textSecondaryDark : null,
    secondaryContainer: tint?.secondaryContainer,
    onSecondaryContainer: tint != null ? preset.textSecondaryDark : null,
  );
}

TextTheme buildBfClashTextTheme({
  required Color color,
  required Brightness brightness,
  required TextTheme base,
}) {
  if (brightness != Brightness.dark) return base;

  // 暗黑模式全局彻底消除生硬惨白：文字色跟随当前预设，
  // 默认沿用冰月白 + 雾感紫蓝灰。
  final preset = bfclashThemePresetFor(color);
  final primaryTextColor = preset?.textPrimaryDark ?? const Color(0xFFEDE9FE);
  final secondaryTextColor =
      preset?.textSecondaryDark ?? const Color(0xFFA5B4FC);

  return base.copyWith(
    displayLarge: base.displayLarge?.copyWith(color: primaryTextColor),
    displayMedium: base.displayMedium?.copyWith(color: primaryTextColor),
    displaySmall: base.displaySmall?.copyWith(color: primaryTextColor),
    headlineLarge: base.headlineLarge?.copyWith(color: primaryTextColor),
    headlineMedium: base.headlineMedium?.copyWith(color: primaryTextColor),
    headlineSmall: base.headlineSmall?.copyWith(color: primaryTextColor),
    titleLarge: base.titleLarge?.copyWith(color: primaryTextColor),
    titleMedium: base.titleMedium?.copyWith(color: primaryTextColor),
    titleSmall: base.titleSmall?.copyWith(color: secondaryTextColor),
    bodyLarge: base.bodyLarge?.copyWith(color: primaryTextColor),
    bodyMedium: base.bodyMedium?.copyWith(color: primaryTextColor),
    bodySmall: base.bodySmall?.copyWith(color: secondaryTextColor),
    labelLarge: base.labelLarge?.copyWith(color: primaryTextColor),
    labelMedium: base.labelMedium?.copyWith(color: secondaryTextColor),
    labelSmall: base.labelSmall?.copyWith(color: secondaryTextColor),
  );
}
