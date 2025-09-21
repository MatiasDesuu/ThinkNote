import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeManager {
  static const String _darkModeKey = 'mobile_dark_mode';
  static const String _colorModeKey = 'mobile_color_mode';
  static const String _monochromeKey = 'mobile_monochrome';

  static Future<bool> getThemeBrightness() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_darkModeKey) ?? false;
  }

  static Future<bool> getColorModeEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_colorModeKey) ?? true;
  }

  static Future<bool> getMonochromeEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_monochromeKey) ?? false;
  }

  static Future<void> saveTheme({
    required bool isDarkMode,
    bool? colorModeEnabled,
    bool? monochromeEnabled,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_darkModeKey, isDarkMode);
    if (colorModeEnabled != null) {
      await prefs.setBool(_colorModeKey, colorModeEnabled);
    }
    if (monochromeEnabled != null) {
      await prefs.setBool(_monochromeKey, monochromeEnabled);
    }
  }

  static ThemeData buildTheme({
    required ColorScheme? lightDynamic,
    required ColorScheme? darkDynamic,
    required bool isDarkMode,
    required bool colorModeEnabled,
    required bool monochromeEnabled,
  }) {
    // Crear esquemas de color predeterminados como respaldo
    final baseLight = ColorScheme.fromSeed(
      seedColor: Colors.deepPurple,
      brightness: Brightness.light,
    );

    final baseDark = ColorScheme.fromSeed(
      seedColor: Colors.deepPurple,
      brightness: Brightness.dark,
    );

    // Esquemas finales según modo y disponibilidad
    ColorScheme lightScheme;
    ColorScheme darkScheme;

    // Determinar qué esquemas de colores usar basados en disponibilidad de dynamic colors
    final lightColorScheme = lightDynamic ?? baseLight;
    final darkColorScheme = darkDynamic ?? baseDark;

    if (!colorModeEnabled && monochromeEnabled) {
      // Modo monocromático
      if (isDarkMode) {
        return _buildMonochromeDark();
      } else {
        return _buildMonochromeLight();
      }
    } else if (!colorModeEnabled) {
      // Modo simple sin monocromático
      lightScheme = _buildSimpleLight(lightColorScheme);
      darkScheme = _buildSimpleDark(darkColorScheme);
    } else {
      // Modo color completo usando Material You
      lightScheme = ColorScheme.fromSeed(
        seedColor: lightDynamic?.primary ?? Colors.deepPurple,
        brightness: Brightness.light,
      );
      darkScheme = ColorScheme.fromSeed(
        seedColor: darkDynamic?.primary ?? Colors.deepPurple,
        brightness: Brightness.dark,
      );
    }

    return ThemeData(
      colorScheme: isDarkMode ? darkScheme : lightScheme,
      useMaterial3: true,
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: (isDarkMode ? darkScheme : lightScheme).primary,
          foregroundColor: (isDarkMode ? darkScheme : lightScheme).onPrimary,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: <TargetPlatform, PageTransitionsBuilder>{
          TargetPlatform.android: ZoomPageTransitionsBuilder(),
        },
      ),
      appBarTheme: const AppBarTheme(
        scrolledUnderElevation: 2,
        surfaceTintColor: Colors.transparent,
      ),
      textSelectionTheme: TextSelectionThemeData(
        selectionColor: (isDarkMode ? darkScheme : lightScheme).primary
            .withAlpha(77),
        selectionHandleColor: (isDarkMode ? darkScheme : lightScheme).primary,
        cursorColor: (isDarkMode ? darkScheme : lightScheme).primary,
      ),
    );
  }

  static ThemeData _buildMonochromeLight() {
    final baseLight = _buildSimpleLight(ColorScheme.light());
    return ThemeData(
      useMaterial3: true,
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF222222),
          foregroundColor: const Color(0xFFFFFFFF),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      colorScheme: baseLight.copyWith(
        primary: const Color(0xFF222222),
        onPrimary: const Color(0xFFFFFFFF),
        secondary: const Color(0xFF858585),
        onSecondary: const Color(0xFFFFFFFF),
        tertiary: const Color(0xFF222222),
        onTertiary: const Color(0xFFFFFFFF),
        primaryContainer: const Color(0xFFEFEFEF),
        onPrimaryContainer: const Color(0xFF222222),
        secondaryContainer: const Color(0xFFF8F8F8),
        onSecondaryContainer: const Color(0xFF858585),
        tertiaryContainer: const Color(0xFFF5F5F5),
        onTertiaryContainer: const Color(0xFF222222),
        error: const Color(0xFFc9184a),
        onError: const Color(0xFFFFFFFF),
        errorContainer: const Color(0xFFB00020),
        onErrorContainer: const Color(0xFFFFFFFF),
        inverseSurface: const Color(0xFF222222),
        onInverseSurface: const Color(0xFFFFFFFF),
        inversePrimary: const Color(0xFFFFFFFF),
      ),
      appBarTheme: const AppBarTheme(
        scrolledUnderElevation: 2,
        surfaceTintColor: Colors.transparent,
        color: Color(0xFFFAFAFA),
      ),
      textSelectionTheme: const TextSelectionThemeData(
        selectionColor: Color(0x4D222222),
        selectionHandleColor: Color(0xFF222222),
        cursorColor: Color(0xFF222222),
      ),
    );
  }

  static ThemeData _buildMonochromeDark() {
    final baseDark = _buildSimpleDark(ColorScheme.dark());
    return ThemeData(
      useMaterial3: true,
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFDADADA),
          foregroundColor: const Color(0xFF1E1E1E),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      colorScheme: baseDark.copyWith(
        primary: const Color(0xFFDADADA),
        onPrimary: const Color(0xFF1E1E1E),
        secondary: const Color(0xFF949494),
        onSecondary: const Color(0xFF1E1E1E),
        tertiary: const Color(0xFFDADADA),
        onTertiary: const Color(0xFF1E1E1E),
        primaryContainer: const Color(0xFF252525),
        onPrimaryContainer: const Color(0xFFDADADA),
        secondaryContainer: const Color(0xFF1A1A1A),
        onSecondaryContainer: const Color(0xFF949494),
        tertiaryContainer: const Color(0xFF1E1E1E),
        onTertiaryContainer: const Color(0xFFDADADA),
        error: const Color(0xFFff8fa3),
        onError: const Color(0xFF1E1E1E),
        errorContainer: const Color(0xFFB00020),
        onErrorContainer: const Color(0xFFDADADA),
        inverseSurface: const Color(0xFFDADADA),
        onInverseSurface: const Color(0xFF1E1E1E),
        inversePrimary: const Color(0xFF1E1E1E),
      ),
      appBarTheme: const AppBarTheme(
        scrolledUnderElevation: 2,
        surfaceTintColor: Colors.transparent,
        color: Color(0xFF131313),
      ),
      textSelectionTheme: const TextSelectionThemeData(
        selectionColor: Color(0x4DDADADA),
        selectionHandleColor: Color(0xFFDADADA),
        cursorColor: Color(0xFFDADADA),
      ),
    );
  }

  static ColorScheme _buildSimpleLight(ColorScheme baseScheme) {
    return ColorScheme.fromSeed(
      seedColor: baseScheme.primary,
      brightness: Brightness.light,
    ).copyWith(
      surface: const Color(0xFFFAFAFA),
      surfaceContainerLowest: const Color(0xFFFCFCFC),
      surfaceContainerLow: const Color(0xFFF8F8F8),
      surfaceContainer: const Color(0xFFF5F5F5),
      surfaceContainerHigh: const Color(0xFFEFEFEF),
      surfaceContainerHighest: const Color(0xFFE9E9E9),
      primaryContainer: const Color(0xFFEFEFEF),
      onPrimaryContainer: const Color(0xFF1C1C1C),
      tertiary: const Color(0xFF2E7D32),
    );
  }

  static ColorScheme _buildSimpleDark(ColorScheme baseScheme) {
    return ColorScheme.fromSeed(
      seedColor: baseScheme.primary,
      brightness: Brightness.dark,
    ).copyWith(
      surface: const Color(0xFF131313),
      surfaceContainerLowest: const Color(0xFF121212),
      surfaceContainerLow: const Color(0xFF1A1A1A),
      surfaceContainer: const Color(0xFF1E1E1E),
      surfaceContainerHigh: const Color(0xFF252525),
      surfaceContainerHighest: const Color(0xFF2C2C2C),
      primaryContainer: const Color(0xFF252525),
      onPrimaryContainer: const Color(0xFFE5E5E5),
      tertiary: const Color(0xFF69F0AE),
    );
  }
}
