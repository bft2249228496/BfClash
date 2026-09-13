import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';

class ThemeConfig {
  final String id;
  final String name;
  final String subtitle;
  final Color accent;
  final Color primaryDark;
  final Color backgroundDark;
  final Color cardDark;
  final Color borderDark;
  final Color primaryLight;
  final Color backgroundLight;
  final Color cardLight;
  final Color borderLight;

  const ThemeConfig({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.accent,
    required this.primaryDark,
    required this.backgroundDark,
    required this.cardDark,
    required this.borderDark,
    required this.primaryLight,
    required this.backgroundLight,
    required this.cardLight,
    required this.borderLight,
  });

  ThemeData toThemeData(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final primary = isDark ? primaryDark : primaryLight;
    final bg = isDark ? backgroundDark : backgroundLight;
    final card = isDark ? cardDark : cardLight;
    final border = isDark ? borderDark : borderLight;

    final colorScheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: brightness,
      surface: bg,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: bg,
      cardColor: card,
      cardTheme: CardThemeData(
        color: card,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: border, width: 1.2),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: bg,
        foregroundColor: isDark ? Colors.white : const Color(0xff1e293b),
        scrolledUnderElevation: 0,
        elevation: 0,
        centerTitle: false,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: card,
        indicatorColor: primary.withAlpha(isDark ? 65 : 45),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return TextStyle(color: primary, fontWeight: FontWeight.bold, fontSize: 12);
          }
          return TextStyle(color: isDark ? Colors.white70 : Colors.black54, fontSize: 12);
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: primary);
          }
          return IconThemeData(color: isDark ? Colors.white70 : Colors.black54);
        }),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: card,
        selectedColor: primary.withAlpha(isDark ? 70 : 45),
        side: BorderSide(color: border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        labelStyle: TextStyle(
          color: isDark ? Colors.white : Colors.black87,
          fontSize: 13,
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return primary.withAlpha(isDark ? 65 : 40);
            }
            return card;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return primary;
            }
            return isDark ? Colors.white70 : Colors.black87;
          }),
          side: WidgetStateProperty.all(BorderSide(color: border)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: isDark ? const Color(0xff0f172a) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    );
  }
}

class AppThemeSystem {
  static const List<ThemeConfig> themes = [
    ThemeConfig(
      id: 'gemini',
      name: 'Gemini',
      subtitle: '星夜蓝紫',
      accent: Color(0xff818cf8),
      primaryDark: Color(0xff818cf8),
      backgroundDark: Color(0xff0b0f19),
      cardDark: Color(0xff111827),
      borderDark: Color(0xff1f293d),
      primaryLight: Color(0xff4f46e5),
      backgroundLight: Color(0xfff8fafc),
      cardLight: Color(0xffffffff),
      borderLight: Color(0xffe2e8f0),
    ),
    ThemeConfig(
      id: 'slate',
      name: 'Slate',
      subtitle: '极客石墨',
      accent: Color(0xff94a3b8),
      primaryDark: Color(0xffcbd5e1),
      backgroundDark: Color(0xff0f172a),
      cardDark: Color(0xff1e293b),
      borderDark: Color(0xff334155),
      primaryLight: Color(0xff475569),
      backgroundLight: Color(0xfff8fafc),
      cardLight: Color(0xffffffff),
      borderLight: Color(0xffe2e8f0),
    ),
    ThemeConfig(
      id: 'dracula',
      name: 'Dracula',
      subtitle: '霓虹暗紫',
      accent: Color(0xffc084fc),
      primaryDark: Color(0xffc084fc),
      backgroundDark: Color(0xff140d24),
      cardDark: Color(0xff22173b),
      borderDark: Color(0xff3b2766),
      primaryLight: Color(0xff9333ea),
      backgroundLight: Color(0xfffaf5ff),
      cardLight: Color(0xffffffff),
      borderLight: Color(0xfff3e8ff),
    ),
    ThemeConfig(
      id: 'rose',
      name: '樱霞',
      subtitle: '柔和玫瑰',
      accent: Color(0xfffb7185),
      primaryDark: Color(0xfffb7185),
      backgroundDark: Color(0xff1f0c16),
      cardDark: Color(0xff2f1322),
      borderDark: Color(0xff4c1d37),
      primaryLight: Color(0xffe11d48),
      backgroundLight: Color(0xfffff1f2),
      cardLight: Color(0xffffffff),
      borderLight: Color(0xffffe4e6),
    ),
    ThemeConfig(
      id: 'ember',
      name: '日落',
      subtitle: '落日暖橘',
      accent: Color(0xfffb923c),
      primaryDark: Color(0xfffb923c),
      backgroundDark: Color(0xff1c1209),
      cardDark: Color(0xff2d1a0b),
      borderDark: Color(0xff49280e),
      primaryLight: Color(0xffea580c),
      backgroundLight: Color(0xfffff7ed),
      cardLight: Color(0xffffffff),
      borderLight: Color(0xffffedd5),
    ),
    ThemeConfig(
      id: 'ocean',
      name: '海盐',
      subtitle: '清透碧蓝',
      accent: Color(0xff38bdf8),
      primaryDark: Color(0xff38bdf8),
      backgroundDark: Color(0xff061626),
      cardDark: Color(0xff0c243c),
      borderDark: Color(0xff163b60),
      primaryLight: Color(0xff0284c7),
      backgroundLight: Color(0xfff0f9ff),
      cardLight: Color(0xffffffff),
      borderLight: Color(0xffe0f2fe),
    ),
  ];

  static ThemeConfig getTheme(String id) {
    return themes.firstWhere((t) => t.id == id, orElse: () => themes.first);
  }

  /// 本地持久化保存主题配置
  static Future<void> savePreferences(String themeId, ThemeMode mode) async {
    try {
      Directory baseDir = Directory.systemTemp;
    if (Platform.isAndroid) {
      try {
        final filesDir = Directory('${Directory.systemTemp.parent.path}/files');
        if (!filesDir.existsSync()) filesDir.createSync(recursive: true);
        baseDir = filesDir;
      } catch (_) {}
    }
    final file = File('${baseDir.path}/lansway_theme_pref.json');
      final data = {
        'themeId': themeId,
        'mode': mode.name,
      };
      await file.writeAsString(json.encode(data), flush: true);
    } catch (_) {}
  }

  /// 读取本地保存的主题配置
  static Future<Map<String, dynamic>?> loadPreferences() async {
    try {
      Directory baseDir = Directory.systemTemp;
    if (Platform.isAndroid) {
      try {
        final filesDir = Directory('${Directory.systemTemp.parent.path}/files');
        if (!filesDir.existsSync()) filesDir.createSync(recursive: true);
        baseDir = filesDir;
      } catch (_) {}
    }
    final file = File('${baseDir.path}/lansway_theme_pref.json');
      if (await file.exists()) {
        final content = await file.readAsString();
        return json.decode(content) as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
  }
}
