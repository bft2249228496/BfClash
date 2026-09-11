import 'package:flutter/material.dart';

class ThemeConfig {
  final String id;
  final String name;
  final String subtitle;
  final Color primaryDark;
  final Color backgroundDark;
  final Color cardDark;
  final Color primaryLight;
  final Color backgroundLight;
  final Color cardLight;

  const ThemeConfig({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.primaryDark,
    required this.backgroundDark,
    required this.cardDark,
    required this.primaryLight,
    required this.backgroundLight,
    required this.cardLight,
  });

  ThemeData toThemeData(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final primary = isDark ? primaryDark : primaryLight;
    final bg = isDark ? backgroundDark : backgroundLight;
    final card = isDark ? cardDark : cardLight;

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorSchemeSeed: primary,
      scaffoldBackgroundColor: bg,
      cardTheme: CardThemeData(
        color: card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: isDark ? const Color(0xff2d303a) : const Color(0xffe4e7f0),
            width: 1,
          ),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: bg,
        scrolledUnderElevation: 0,
        elevation: 0,
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
      primaryDark: Color(0xffa7baf2),
      backgroundDark: Color(0xff18191e),
      cardDark: Color(0xff202127),
      primaryLight: Color(0xff5b70b8),
      backgroundLight: Color(0xfff4f5fa),
      cardLight: Color(0xffffffff),
    ),
    ThemeConfig(
      id: 'slate',
      name: 'Slate',
      subtitle: '雾灰留白',
      primaryDark: Color(0xffb6c5dc),
      backgroundDark: Color(0xff191b1e),
      cardDark: Color(0xff222529),
      primaryLight: Color(0xff566d8d),
      backgroundLight: Color(0xfff5f6f8),
      cardLight: Color(0xffffffff),
    ),
    ThemeConfig(
      id: 'dracula',
      name: 'Dracula',
      subtitle: '午夜紫调',
      primaryDark: Color(0xffbd9ce9),
      backgroundDark: Color(0xff1e1d28),
      cardDark: Color(0xff292734),
      primaryLight: Color(0xff8a60b7),
      backgroundLight: Color(0xfff7f4fa),
      cardLight: Color(0xffffffff),
    ),
    ThemeConfig(
      id: 'rose',
      name: '樱霞',
      subtitle: '柔和玫瑰',
      primaryDark: Color(0xffe3a9c5),
      backgroundDark: Color(0xff211c20),
      cardDark: Color(0xff2c242a),
      primaryLight: Color(0xffb35c85),
      backgroundLight: Color(0xfffaf4f7),
      cardLight: Color(0xffffffff),
    ),
    ThemeConfig(
      id: 'ember',
      name: '日落',
      subtitle: '暖橘余晖',
      primaryDark: Color(0xffe8b18e),
      backgroundDark: Color(0xff211d1b),
      cardDark: Color(0xff2b2522),
      primaryLight: Color(0xffab6940),
      backgroundLight: Color(0xfffaf6f2),
      cardLight: Color(0xffffffff),
    ),
    ThemeConfig(
      id: 'ocean',
      name: '海盐',
      subtitle: '清透海蓝',
      primaryDark: Color(0xff94c5e8),
      backgroundDark: Color(0xff171e24),
      cardDark: Color(0xff202932),
      primaryLight: Color(0xff357ea7),
      backgroundLight: Color(0xfff2f7fa),
      cardLight: Color(0xffffffff),
    ),
  ];

  static ThemeConfig getTheme(String id) {
    return themes.firstWhere((t) => t.id == id, orElse: () => themes.first);
  }
}
