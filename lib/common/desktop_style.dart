import 'package:material_ui/material_ui.dart';

ThemeData buildDesktopTheme(ThemeData base) {
  final dark = base.brightness == Brightness.dark;
  final colors = base.colorScheme;
  final pureBlack = colors.surface == Colors.black;
  final scheme = dark
      ? colors.copyWith(
          surface: pureBlack ? Colors.black : const Color(0xFF0B0B12),
          surfaceContainerLowest: pureBlack
              ? Colors.black
              : const Color(0xFF08080D),
          surfaceContainerLow: const Color(0xFF12121B),
          surfaceContainer: const Color(0xFF161620),
          surfaceContainerHigh: const Color(0xFF1C1C28),
          surfaceContainerHighest: const Color(0xFF252533),
          onSurface: const Color(0xFFEDEAF5),
          onSurfaceVariant: const Color(0xFFA6A2B8),
          outline: const Color(0xFF6B6879),
          outlineVariant: const Color(0xFF2A2937),
        )
      : colors;
  return base.copyWith(
    colorScheme: scheme,
    scaffoldBackgroundColor: scheme.surface,
    visualDensity: VisualDensity.compact,
    appBarTheme: base.appBarTheme.copyWith(
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
      titleTextStyle: base.textTheme.titleLarge?.copyWith(
        color: scheme.onSurface,
        fontSize: 22,
        fontWeight: FontWeight.w700,
      ),
    ),
    listTileTheme: base.listTileTheme.copyWith(
      titleTextStyle: base.textTheme.bodyMedium?.copyWith(
        color: scheme.onSurface,
        fontWeight: FontWeight.w500,
      ),
      subtitleTextStyle: base.textTheme.bodySmall?.copyWith(
        color: scheme.onSurfaceVariant,
      ),
    ),
    dividerColor: scheme.outlineVariant.withValues(alpha: 0.5),
  );
}

LinearGradient desktopAccentGradient(BuildContext context) {
  final colors = Theme.of(context).colorScheme;
  return LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color.lerp(colors.primary, const Color(0xFF38BDF8), 0.7)!,
      colors.primary,
      Color.lerp(colors.primary, const Color(0xFFC084FC), 0.7)!,
    ],
  );
}
