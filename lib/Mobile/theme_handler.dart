import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../themes/eink_theme.dart';

class ThemeManager {
  static const String _darkModeKey = 'mobile_dark_mode';
  static const String _colorModeKey = 'mobile_color_mode';
  static const String _monochromeKey = 'mobile_monochrome';
  static const String _einkKey = 'mobile_eink';
  static const String _amoledKey = 'mobile_amoled';

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

  static Future<bool> getEInkEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_einkKey) ?? false;
  }

  static Future<bool> getAmoledEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_amoledKey) ?? false;
  }

  static Future<void> saveTheme({
    required bool isDarkMode,
    bool? colorModeEnabled,
    bool? monochromeEnabled,
    bool? einkEnabled,
    bool? amoledEnabled,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_darkModeKey, isDarkMode);
    if (colorModeEnabled != null) await prefs.setBool(_colorModeKey, colorModeEnabled);
    if (monochromeEnabled != null) await prefs.setBool(_monochromeKey, monochromeEnabled);
    if (einkEnabled != null) await prefs.setBool(_einkKey, einkEnabled);
    if (amoledEnabled != null) await prefs.setBool(_amoledKey, amoledEnabled);
  }

  static ThemeData buildTheme({
    required ColorScheme? lightDynamic,
    required ColorScheme? darkDynamic,
    required bool isDarkMode,
    required bool colorModeEnabled,
    required bool monochromeEnabled,
    required bool einkEnabled,
    bool amoledEnabled = false,
    String fontFamily = 'Roboto',
  }) {
    if (einkEnabled) {
      return EInkTheme.buildEInkTheme(
        isLightMode: !isDarkMode,
        fontFamily: fontFamily,
      );
    }

    final baseLight = ColorScheme.fromSeed(
      seedColor: Colors.deepPurple,
      brightness: Brightness.light,
    );

    final baseDark = ColorScheme.fromSeed(
      seedColor: Colors.deepPurple,
      brightness: Brightness.dark,
    );

    ColorScheme lightScheme;
    ColorScheme darkScheme;

    final lightColorScheme = lightDynamic ?? baseLight;
    final darkColorScheme = darkDynamic ?? baseDark;

    if (!colorModeEnabled && monochromeEnabled) {
      if (isDarkMode) {
        return _buildMonochromeDark(amoledEnabled: amoledEnabled);
      } else {
        return _buildMonochromeLight();
      }
    } else if (!colorModeEnabled) {
      lightScheme = _buildSimpleLight(lightColorScheme);
      darkScheme = _buildSimpleDark(darkColorScheme, amoledEnabled: amoledEnabled);
    } else {
      lightScheme = ColorScheme.fromSeed(
        seedColor: lightDynamic?.primary ?? Colors.deepPurple,
        brightness: Brightness.light,
      );
      darkScheme = ColorScheme.fromSeed(
        seedColor: darkDynamic?.primary ?? Colors.deepPurple,
        brightness: Brightness.dark,
      );
      if (amoledEnabled) {
        darkScheme = _applyAmoledSurfaces(darkScheme);
      }
    }

    final activeScheme = isDarkMode ? darkScheme : lightScheme;

    return ThemeData(
      colorScheme: activeScheme,
      useMaterial3: true,
      splashFactory: InkRipple.splashFactory,
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: activeScheme.primary,
          foregroundColor: activeScheme.onPrimary,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: <TargetPlatform, PageTransitionsBuilder>{
          TargetPlatform.android: ZoomPageTransitionsBuilder(),
        },
      ),
      appBarTheme: AppBarTheme(
        scrolledUnderElevation: amoledEnabled && isDarkMode ? 0 : 2,
        surfaceTintColor: Colors.transparent,
        backgroundColor: amoledEnabled && isDarkMode ? const Color(0xFF000000) : null,
        shadowColor: amoledEnabled && isDarkMode ? const Color(0xFF1A1A1A) : null,
      ),
      navigationBarTheme: amoledEnabled && isDarkMode
          ? _amoledNavigationBarTheme(activeScheme)
          : null,
      textSelectionTheme: TextSelectionThemeData(
        selectionColor: activeScheme.primary.withAlpha(77),
        selectionHandleColor: activeScheme.primary,
        cursorColor: activeScheme.primary,
      ),
    );
  }

  // ─── AMOLED helpers ────────────────────────────────────────────────────────

  /// Reemplaza las superficies con grises neutros escalonados sobre negro puro.
  /// Pasos de ~7–9 puntos para que cada nivel sea perceptiblemente más claro.
  static ColorScheme _applyAmoledSurfaces(ColorScheme scheme) {
    final p = scheme.primary;
    // primaryContainer con tinte sutil del acento (perceptible pero sin brillar)
    final tintedContainer = Color.lerp(const Color(0xFF111111), p, 0.10)!;

    return scheme.copyWith(
      surface:                   const Color(0xFF000000),
      surfaceContainerLowest:    const Color(0xFF000000),
      surfaceContainerLow:       const Color(0xFF0D0D0D),
      surfaceContainer:          const Color(0xFF141414),
      surfaceContainerHigh:      const Color(0xFF1C1C1C),
      surfaceContainerHighest:   const Color(0xFF242424),
      primaryContainer:          tintedContainer,
      onPrimaryContainer:        const Color(0xFFE8E8E8),
      secondaryContainer:        const Color(0xFF0F0F0F),
      onSecondaryContainer:      scheme.secondary,
      tertiary:                  const Color(0xFF69F0AE),
    );
  }

  static NavigationBarThemeData _amoledNavigationBarTheme(ColorScheme scheme) {
    return NavigationBarThemeData(
      // Ligeramente por encima del fondo para separarse sin flotar
      backgroundColor: const Color(0xFF0D0D0D),
      elevation: 0,
      shadowColor: Colors.transparent,
      indicatorColor: scheme.primary.withAlpha(40),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return IconThemeData(color: scheme.primary);
        }
        return const IconThemeData(color: Color(0xFF8A8A8A));
      }),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return TextStyle(
            color: scheme.primary,
            fontWeight: FontWeight.w600,
            fontSize: 12,
          );
        }
        return const TextStyle(color: Color(0xFF8A8A8A), fontSize: 12);
      }),
    );
  }

  // ─── Monochrome ────────────────────────────────────────────────────────────

  static ThemeData _buildMonochromeLight() {
    final baseLight = _buildSimpleLight(const ColorScheme.light());
    return ThemeData(
      useMaterial3: true,
      splashFactory: InkRipple.splashFactory,
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
        backgroundColor: Color(0xFFFAFAFA),
      ),
      textSelectionTheme: const TextSelectionThemeData(
        selectionColor: Color(0x4D222222),
        selectionHandleColor: Color(0xFF222222),
        cursorColor: Color(0xFF222222),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: const Color(0xFFF5F5F5),
        indicatorColor: const Color(0xFF222222),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: Color(0xFFFFFFFF));
          }
          return const IconThemeData(color: Color(0xFF222222));
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
              color: Color(0xFF222222),
              fontWeight: FontWeight.bold,
              fontSize: 12,
            );
          }
          return const TextStyle(color: Color(0xFF222222), fontSize: 12);
        }),
      ),
    );
  }

  static ThemeData _buildMonochromeDark({bool amoledEnabled = false}) {
    final baseDark = _buildSimpleDark(const ColorScheme.dark(), amoledEnabled: amoledEnabled);
    return ThemeData(
      useMaterial3: true,
      splashFactory: InkRipple.splashFactory,
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
        primaryContainer: amoledEnabled ? const Color(0xFF111111) : const Color(0xFF252525),
        onPrimaryContainer: const Color(0xFFDADADA),
        secondaryContainer: amoledEnabled ? const Color(0xFF0A0A0A) : const Color(0xFF1A1A1A),
        onSecondaryContainer: const Color(0xFF949494),
        tertiaryContainer: amoledEnabled ? const Color(0xFF0A0A0A) : const Color(0xFF1E1E1E),
        onTertiaryContainer: const Color(0xFFDADADA),
        error: const Color(0xFFff8fa3),
        onError: const Color(0xFF1E1E1E),
        errorContainer: const Color(0xFFB00020),
        onErrorContainer: const Color(0xFFDADADA),
        inverseSurface: const Color(0xFFDADADA),
        onInverseSurface: const Color(0xFF1E1E1E),
        inversePrimary: const Color(0xFF1E1E1E),
        // Superficies escalonadas en modo monochrome AMOLED
        surface:                 amoledEnabled ? const Color(0xFF000000) : const Color(0xFF131313),
        surfaceContainerLowest:  amoledEnabled ? const Color(0xFF000000) : const Color(0xFF121212),
        surfaceContainerLow:     amoledEnabled ? const Color(0xFF0D0D0D) : const Color(0xFF1A1A1A),
        surfaceContainer:        amoledEnabled ? const Color(0xFF141414) : const Color(0xFF1E1E1E),
        surfaceContainerHigh:    amoledEnabled ? const Color(0xFF1C1C1C) : const Color(0xFF252525),
        surfaceContainerHighest: amoledEnabled ? const Color(0xFF242424) : const Color(0xFF2C2C2C),
      ),
      appBarTheme: AppBarTheme(
        scrolledUnderElevation: amoledEnabled ? 0 : 2,
        surfaceTintColor: Colors.transparent,
        backgroundColor: amoledEnabled ? const Color(0xFF000000) : const Color(0xFF131313),
      ),
      textSelectionTheme: const TextSelectionThemeData(
        selectionColor: Color(0x4DDADADA),
        selectionHandleColor: Color(0xFFDADADA),
        cursorColor: Color(0xFFDADADA),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: amoledEnabled ? const Color(0xFF0D0D0D) : const Color(0xFF1E1E1E),
        elevation: 0,
        // Indicador siempre blanco/claro para que el icono oscuro encima se vea bien
        indicatorColor: const Color(0xFFDADADA),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            // Icono oscuro sobre indicador claro = buen contraste siempre
            return const IconThemeData(color: Color(0xFF1A1A1A));
          }
          return const IconThemeData(color: Color(0xFF8A8A8A));
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
              color: Color(0xFFDADADA),
              fontWeight: FontWeight.w600,
              fontSize: 12,
            );
          }
          return const TextStyle(color: Color(0xFF8A8A8A), fontSize: 12);
        }),
      ),
    );
  }

  // ─── Simple light / dark ───────────────────────────────────────────────────

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

  static ColorScheme _buildSimpleDark(ColorScheme baseScheme, {bool amoledEnabled = false}) {
    if (amoledEnabled) {
      return _applyAmoledSurfaces(
        ColorScheme.fromSeed(
          seedColor: baseScheme.primary,
          brightness: Brightness.dark,
        ),
      );
    }

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