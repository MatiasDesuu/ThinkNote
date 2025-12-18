import 'package:flutter/material.dart';
import 'Settings/editor_settings_panel.dart';
import 'themes/eink_theme.dart';

class ThemeManager {
  static const String _colorKey = 'theme_color';
  static const String _brightnessKey = 'theme_brightness';
  static const String _colorModeKey = 'color_mode_enabled';
  static const String _customAdjustmentsKey = 'custom_adjustments_enabled';
  static const String _saturationKey = 'color_saturation';
  static const String _brightnessValueKey = 'color_brightness_value';
  static const String _monochromeKey = 'monochrome_enabled';
  static const String _catppuccinEnabledKey = 'catppuccin_enabled';
  static const String _catppuccinFlavorKey = 'catppuccin_flavor';
  static const String _catppuccinAccentKey = 'catppuccin_accent';
  static const String _einkEnabledKey = 'eink_enabled';

  // Catppuccin flavors and their colors
  static const Map<String, Map<String, Color>> catppuccinColors = {
    'latte': {
      'rosewater': Color(0xFFDC8A78),
      'flamingo': Color(0xFFDD7878),
      'pink': Color(0xFFEA76CB),
      'mauve': Color(0xFF8839EF),
      'red': Color(0xFFD20F39),
      'maroon': Color(0xFFE64553),
      'peach': Color(0xFFFE640B),
      'yellow': Color(0xFFDF8E1D),
      'green': Color(0xFF40A02B),
      'teal': Color(0xFF179299),
      'sky': Color(0xFF04A5E5),
      'sapphire': Color(0xFF209FB5),
      'blue': Color(0xFF1E66F5),
      'lavender': Color(0xFF7287FD),
    },
    'frappe': {
      'rosewater': Color(0xFFF2D5CF),
      'flamingo': Color(0xFFEEBEBE),
      'pink': Color(0xFFF4B8E4),
      'mauve': Color(0xFFCA9EE6),
      'red': Color(0xFFE78284),
      'maroon': Color(0xFFEA999C),
      'peach': Color(0xFFEF9F76),
      'yellow': Color(0xFFE5C890),
      'green': Color(0xFFA6D189),
      'teal': Color(0xFF81C8BE),
      'sky': Color(0xFF99D1DB),
      'sapphire': Color(0xFF85C1DC),
      'blue': Color(0xFF8CAAEE),
      'lavender': Color(0xFFBABBF1),
    },
    'macchiato': {
      'rosewater': Color(0xFFF4DBD6),
      'flamingo': Color(0xFFF0C6C6),
      'pink': Color(0xFFF5BDE6),
      'mauve': Color(0xFFC6A0F6),
      'red': Color(0xFFED8796),
      'maroon': Color(0xFFEE99A0),
      'peach': Color(0xFFF5A97F),
      'yellow': Color(0xFFEED49F),
      'green': Color(0xFFA6DA95),
      'teal': Color(0xFF8BD5CA),
      'sky': Color(0xFF91D7E3),
      'sapphire': Color(0xFF7DC4E4),
      'blue': Color(0xFF8AADF4),
      'lavender': Color(0xFFB7BDF8),
    },
    'mocha': {
      'rosewater': Color(0xFFF5E0DC),
      'flamingo': Color(0xFFF2CDCD),
      'pink': Color(0xFFF5C2E7),
      'mauve': Color(0xFFCBA6F7),
      'red': Color(0xFFF38BA8),
      'maroon': Color(0xFFEBA0AC),
      'peach': Color(0xFFFAB387),
      'yellow': Color(0xFFF9E2AF),
      'green': Color(0xFFA6E3A1),
      'teal': Color(0xFF94E2D5),
      'sky': Color(0xFF89DCEB),
      'sapphire': Color(0xFF74C7EC),
      'blue': Color(0xFF89B4FA),
      'lavender': Color(0xFFB4BEFE),
    },
  };

  // Catppuccin base colors for each flavor
  static const Map<String, Map<String, Color>> catppuccinBaseColors = {
    'latte': {
      'base': Color(0xFFEFF1F5),
      'mantle': Color(0xFFE6E9EF),
      'crust': Color(0xFFDCE0E8),
      'text': Color(0xFF4C4F69),
      'subtext0': Color(0xFF6C6F85),
      'subtext1': Color(0xFF8C8FA1),
      'overlay0': Color(0xFF9CA0B0),
      'overlay1': Color(0xFF8C8FA1),
      'overlay2': Color(0xFF7C7F93),
      'surface0': Color(0xFFCCD0DA),
      'surface1': Color(0xFFBCC0CC),
      'surface2': Color(0xFFACB0BE),
    },
    'frappe': {
      'base': Color(0xFF303446),
      'mantle': Color(0xFF292C3C),
      'crust': Color(0xFF232634),
      'text': Color(0xFFC6D0F5),
      'subtext0': Color(0xFFA5ADCE),
      'subtext1': Color(0xFF949CBB),
      'overlay0': Color(0xFF737994),
      'overlay1': Color(0xFF626880),
      'overlay2': Color(0xFF51576D),
      'surface0': Color(0xFF414559),
      'surface1': Color(0xFF51576D),
      'surface2': Color(0xFF626880),
    },
    'macchiato': {
      'base': Color(0xFF24273A),
      'mantle': Color(0xFF1E2030),
      'crust': Color(0xFF181926),
      'text': Color(0xFFCAD3F5),
      'subtext0': Color(0xFFB8C0E0),
      'subtext1': Color(0xFFA5ADCB),
      'overlay0': Color(0xFF6E738D),
      'overlay1': Color(0xFF5B6078),
      'overlay2': Color(0xFF494D64),
      'surface0': Color(0xFF363A4F),
      'surface1': Color(0xFF494D64),
      'surface2': Color(0xFF5B6078),
    },
    'mocha': {
      'base': Color(0xFF1E1E2E),
      'mantle': Color(0xFF181825),
      'crust': Color(0xFF11111B),
      'text': Color(0xFFCDD6F4),
      'subtext0': Color(0xFFBAC2DE),
      'subtext1': Color(0xFFA6ADC8),
      'overlay0': Color(0xFF6C7086),
      'overlay1': Color(0xFF585B70),
      'overlay2': Color(0xFF45475A),
      'surface0': Color(0xFF313244),
      'surface1': Color(0xFF45475A),
      'surface2': Color(0xFF585B70),
    },
  };

  static Future<Color> getThemeColor() async {
    final colorValue = await PlatformSettings.get(_colorKey, 0xFF2E7D32);
    return Color(colorValue);
  }

  static Future<Brightness> getThemeBrightness() async {
    final isLight = await PlatformSettings.get(_brightnessKey, false);
    return isLight ? Brightness.light : Brightness.dark;
  }

  static Future<bool> getColorModeEnabled() async {
    return await PlatformSettings.get(_colorModeKey, true);
  }

  static Future<bool> getCustomAdjustmentsEnabled() async {
    return await PlatformSettings.get(_customAdjustmentsKey, false);
  }

  static Future<bool> getMonochromeEnabled() async {
    return await PlatformSettings.get(_monochromeKey, false);
  }

  static Future<bool> getCatppuccinEnabled() async {
    return await PlatformSettings.get(_catppuccinEnabledKey, false);
  }

  static Future<String> getCatppuccinFlavor() async {
    return await PlatformSettings.get(_catppuccinFlavorKey, 'mocha');
  }

  static Future<String> getCatppuccinAccent() async {
    return await PlatformSettings.get(_catppuccinAccentKey, 'mauve');
  }

  static Future<bool> getEInkEnabled() async {
    return await PlatformSettings.get(_einkEnabledKey, false);
  }

  static Future<double> getSaturation() async {
    return await PlatformSettings.get(_saturationKey, 1.0);
  }

  static Future<double> getBrightnessValue() async {
    return await PlatformSettings.get(_brightnessValueKey, 1.0);
  }

  static Future<void> saveTheme(
    Color color,
    Brightness brightness, {
    bool? colorModeEnabled,
    bool? customAdjustmentsEnabled,
    bool? monochromeEnabled,
    bool? catppuccinEnabled,
    String? catppuccinFlavor,
    String? catppuccinAccent,
    bool? einkEnabled,
    double? saturation,
    double? brightnessValue,
  }) async {
    await PlatformSettings.set(_colorKey, color.toARGB32());
    await PlatformSettings.set(_brightnessKey, brightness == Brightness.light);

    if (colorModeEnabled != null) {
      await PlatformSettings.set(_colorModeKey, colorModeEnabled);
    }
    if (customAdjustmentsEnabled != null) {
      await PlatformSettings.set(
        _customAdjustmentsKey,
        customAdjustmentsEnabled,
      );
    }
    if (monochromeEnabled != null) {
      await PlatformSettings.set(_monochromeKey, monochromeEnabled);
    }
    if (catppuccinEnabled != null) {
      await PlatformSettings.set(_catppuccinEnabledKey, catppuccinEnabled);
    }
    if (catppuccinFlavor != null) {
      await PlatformSettings.set(_catppuccinFlavorKey, catppuccinFlavor);
    }
    if (catppuccinAccent != null) {
      await PlatformSettings.set(_catppuccinAccentKey, catppuccinAccent);
    }
    if (einkEnabled != null) {
      await PlatformSettings.set(_einkEnabledKey, einkEnabled);
    }
    if (saturation != null) {
      await PlatformSettings.set(_saturationKey, saturation);
    }
    if (brightnessValue != null) {
      await PlatformSettings.set(_brightnessValueKey, brightnessValue);
    }

    themeNotifier.refreshTheme();
  }

  static ThemeData buildTheme({
    required Color color,
    required Brightness brightness,
    required bool colorMode,
    required bool customAdjustmentsEnabled,
    required double saturation,
    required double brightnessValue,
    required bool monochromeEnabled,
    required bool catppuccinEnabled,
    required String catppuccinFlavor,
    required String catppuccinAccent,
    required bool einkEnabled,
  }) {
    // If e-ink mode is enabled, use the e-ink theme
    if (einkEnabled) {
      return EInkTheme.buildEInkTheme(
        isLightMode: brightness == Brightness.light,
      );
    }

    Color adjustedColor = color;

    if (customAdjustmentsEnabled) {
      HSVColor hsvColor = HSVColor.fromColor(adjustedColor);
      hsvColor = hsvColor.withSaturation(
        (hsvColor.saturation * saturation).clamp(0.0, 1.0),
      );
      hsvColor = hsvColor.withValue(
        (hsvColor.value * brightnessValue).clamp(0.0, 1.0),
      );
      adjustedColor = hsvColor.toColor();
    }

    final colorScheme = _buildColorScheme(
      color: adjustedColor,
      brightness: brightness,
      colorMode: colorMode,
      monochromeEnabled: monochromeEnabled,
      catppuccinEnabled: catppuccinEnabled,
      catppuccinFlavor: catppuccinFlavor,
      catppuccinAccent: catppuccinAccent,
    );

    return ThemeData(
      brightness: brightness,
      useMaterial3: true,
      colorScheme: colorScheme,
      appBarTheme: AppBarTheme(
        scrolledUnderElevation: 2,
        surfaceTintColor: Colors.transparent,
        backgroundColor:
            brightness == Brightness.light
                ? const Color.fromRGBO(19, 19, 19, 1)
                : const Color(0xFF252525),
      ),
    );
  }

  static ColorScheme _buildColorScheme({
    required Color color,
    required Brightness brightness,
    required bool colorMode,
    required bool monochromeEnabled,
    required bool catppuccinEnabled,
    required String catppuccinFlavor,
    required String catppuccinAccent,
  }) {
    if (catppuccinEnabled) {
      return _buildCatppuccinColorScheme(
        brightness,
        catppuccinFlavor,
        catppuccinAccent,
      );
    } else if (!colorMode && monochromeEnabled) {
      if (brightness == Brightness.light) {
        return _buildMonochromeLight();
      } else {
        return _buildMonochromeDark();
      }
    } else if (!colorMode) {
      return _defaultColorScheme(color, brightness);
    } else {
      return _buildFullColorScheme(color, brightness);
    }
  }

  static ColorScheme _buildCatppuccinColorScheme(
    Brightness brightness,
    String flavor,
    String accent,
  ) {
    final colors = catppuccinColors[flavor]!;
    final baseColors = catppuccinBaseColors[flavor]!;

    // Use base colors from the specific flavor
    final base = baseColors['base']!;
    final mantle = baseColors['mantle']!;
    final crust = baseColors['crust']!;
    final text = baseColors['text']!;
    final subtext0 = baseColors['subtext0']!;
    final overlay0 = baseColors['overlay0']!;
    final overlay1 = baseColors['overlay1']!;
    final surface0 = baseColors['surface0']!;

    // Get the selected accent color
    final accentColor = colors[accent]!;

    // Create complementary colors based on the accent
    final complementaryColors = _getComplementaryColors(accentColor, colors);

    // Generate subtle divider colors based on Catppuccin palette
    final subtleDividerColor = _getSubtleDividerColor(
      base,
      overlay0,
      brightness,
    );

    return ColorScheme(
      brightness: brightness,
      // Primary colors using selected accent color
      primary: accentColor,
      onPrimary: _getContrastColor(accentColor),
      primaryContainer: accentColor.withAlpha(76),
      onPrimaryContainer: _getContrastColor(accentColor),

      // Secondary colors using complementary colors
      secondary: complementaryColors['secondary']!,
      onSecondary: _getContrastColor(complementaryColors['secondary']!),
      secondaryContainer: complementaryColors['secondary']!.withAlpha(76),
      onSecondaryContainer: _getContrastColor(
        complementaryColors['secondary']!,
      ),

      // Tertiary colors using different accent
      tertiary: complementaryColors['tertiary']!,
      onTertiary: _getContrastColor(complementaryColors['tertiary']!),
      tertiaryContainer: complementaryColors['tertiary']!.withAlpha(255),
      onTertiaryContainer: _getContrastColor(complementaryColors['tertiary']!),

      // Surface colors using Catppuccin base colors
      surface: base,
      onSurface: text,
      onSurfaceVariant: subtext0,

      // Surface containers - Using more subtle colors from Catppuccin palette
      surfaceContainerLowest: crust,
      surfaceContainerLow: mantle,
      surfaceContainer: base,
      surfaceContainerHigh: surface0,
      surfaceContainerHighest: _getCatppuccinSurfaceContainerHighest(
        base,
        overlay0,
        brightness,
      ),

      // Error colors
      error: colors['red']!,
      onError: _getContrastColor(colors['red']!),
      errorContainer: colors['red']!.withAlpha(255),
      onErrorContainer: _getContrastColor(colors['red']!),

      // Outline colors - Using subtle divider colors
      outline: subtleDividerColor,
      outlineVariant: overlay1,

      // Inverse colors
      inverseSurface: text,
      onInverseSurface: base,
      inversePrimary: accentColor,

      // Shadow colors
      shadow: Colors.black,
      scrim: Colors.black,
    );
  }

  // Helper method to generate subtle divider colors based on Catppuccin palette
  static Color _getSubtleDividerColor(
    Color base,
    Color overlay0,
    Brightness brightness,
  ) {
    // For light themes, use a very subtle color
    if (brightness == Brightness.light) {
      return overlay0.withAlpha(40);
    }
    // For dark themes, use a slightly more visible but still subtle color
    return overlay0.withAlpha(60);
  }

  // Helper method to get complementary colors based on the selected accent
  static Map<String, Color> _getComplementaryColors(
    Color accentColor,
    Map<String, Color> colors,
  ) {
    // Define color relationships for better harmony
    final colorRelationships = {
      'rosewater': ['blue', 'teal'],
      'flamingo': ['sapphire', 'sky'],
      'pink': ['green', 'teal'],
      'mauve': ['yellow', 'peach'],
      'red': ['green', 'teal'],
      'maroon': ['green', 'sky'],
      'peach': ['blue', 'lavender'],
      'yellow': ['mauve', 'pink'],
      'green': ['pink', 'red'],
      'teal': ['rosewater', 'pink'],
      'sky': ['flamingo', 'peach'],
      'sapphire': ['flamingo', 'rosewater'],
      'blue': ['peach', 'yellow'],
      'lavender': ['peach', 'green'],
    };

    // Find which accent color we're using
    String? accentName;
    for (final entry in colors.entries) {
      if (entry.value.toARGB32() == accentColor.toARGB32()) {
        accentName = entry.key;
        break;
      }
    }

    // Get complementary colors based on relationships
    final relationships = colorRelationships[accentName] ?? ['blue', 'teal'];

    return {
      'secondary': colors[relationships[0]]!,
      'tertiary': colors[relationships[1]]!,
    };
  }

  // Helper method to get appropriate contrast color
  static Color _getContrastColor(Color color) {
    final luminance = color.computeLuminance();
    return luminance > 0.5 ? Colors.black : Colors.white;
  }

  static ColorScheme _buildFullColorScheme(Color color, Brightness brightness) {
    final bool isDark = brightness == Brightness.dark;
    final HSLColor hslColor = HSLColor.fromColor(color);

    // Función para ajustar la luminosidad manteniendo el tono y saturación
    Color adjustBrightness(double lightness) {
      return hslColor.withLightness(lightness).toColor();
    }

    // Función para ajustar la saturación manteniendo el tono
    Color adjustSaturation(double saturation, double lightness) {
      return hslColor
          .withSaturation(saturation)
          .withLightness(lightness)
          .toColor();
    }

    // En modo oscuro, empezamos más oscuro y vamos aumentando la luminosidad
    // En modo claro, empezamos más claro y vamos disminuyendo la luminosidad
    final surfaceLightness =
        isDark
            ? [
              0.08, // Más oscuro pero no tanto
              0.12, // Incremento sutil
              0.16, // Mayor diferencia
              0.22, // Aún más claro
              0.28, // El más claro
            ] // Modo oscuro: de más oscuro a más claro
            : [
              0.98, // Casi blanco
              0.96, // Muy sutil diferencia
              0.94, // Diferencia notable
              0.91, // Más oscuro
              0.88, // El más oscuro
            ]; // Modo claro: de más claro a más oscuro

    // La saturación se reduce para hacer los colores más suaves
    final surfaceSaturation =
        isDark
            ? [
              0.08,
              0.12,
              0.16,
              0.20,
              0.24,
            ] // Modo oscuro: saturación más sutil
            : [
              0.05,
              0.08,
              0.12,
              0.16,
              0.20,
            ]; // Modo claro: saturación más sutil

    return ColorScheme(
      brightness: brightness,
      // Colores principales - Mantienen el tono exacto
      primary: color,
      onPrimary: isDark ? Colors.black : Colors.white,
      primaryContainer: adjustBrightness(isDark ? 0.3 : 0.8),
      onPrimaryContainer: isDark ? Colors.white : Colors.black,

      // Colores secundarios - Variaciones del mismo tono
      secondary: adjustSaturation(0.6, isDark ? 0.6 : 0.4),
      onSecondary: isDark ? Colors.black : Colors.white,
      secondaryContainer: adjustSaturation(0.3, isDark ? 0.3 : 0.9),
      onSecondaryContainer: isDark ? Colors.white : Colors.black,

      // Colores terciarios - Más variaciones del mismo tono
      tertiary: adjustSaturation(0.8, isDark ? 0.7 : 0.3),
      onTertiary: isDark ? Colors.black : Colors.white,
      tertiaryContainer: adjustSaturation(0.4, isDark ? 0.4 : 0.8),
      onTertiaryContainer: isDark ? Colors.white : Colors.black,

      // Superficies - Versiones más saturadas del color para fondos
      surface: adjustSaturation(surfaceSaturation[0], surfaceLightness[0]),
      onSurface: isDark ? Colors.white : Colors.black,
      onSurfaceVariant:
          isDark ? Colors.white.withAlpha(229) : Colors.black.withAlpha(229),

      // Contenedores - Gradiente de superficies con más saturación
      surfaceContainerLowest: adjustSaturation(
        surfaceSaturation[0],
        surfaceLightness[0],
      ),
      surfaceContainerLow: adjustSaturation(
        surfaceSaturation[1],
        surfaceLightness[1],
      ),
      surfaceContainer: adjustSaturation(
        surfaceSaturation[2],
        surfaceLightness[2],
      ),
      surfaceContainerHigh: adjustSaturation(
        surfaceSaturation[3],
        surfaceLightness[3],
      ),
      surfaceContainerHighest: adjustSaturation(
        surfaceSaturation[4],
        surfaceLightness[4],
      ),
      error: isDark ? const Color(0xFFCF6679) : const Color(0xFFB00020),
      onError: isDark ? Colors.black : Colors.white,
      errorContainer:
          isDark ? const Color(0xFF8B0016) : const Color(0xFFFCD8DF),
      onErrorContainer: isDark ? Colors.white : Colors.black,

      // Colores de borde y estado
      outline: adjustSaturation(0.2, isDark ? 0.6 : 0.4),
      outlineVariant: adjustSaturation(0.15, isDark ? 0.3 : 0.8),

      // Colores inversos
      inverseSurface: adjustSaturation(0.3, isDark ? 0.9 : 0.1),
      onInverseSurface: isDark ? Colors.black : Colors.white,
      inversePrimary: adjustSaturation(0.7, isDark ? 0.4 : 0.6),

      // Sombras
      shadow: Colors.black,
      scrim: Colors.black,
    );
  }

  // Monochrome scheme for light theme (black on white)
  static ColorScheme _buildMonochromeLight() {
    final baseScheme = _defaultColorScheme(
      const Color(0xFF000000),
      Brightness.light,
    );

    return baseScheme.copyWith(
      // Main accent colors
      primary: const Color(0xFF222222), // Active buttons
      onPrimary: const Color(0xFFFFFFFF),
      secondary: const Color(0xFF858585), // Disabled buttons
      onSecondary: const Color(0xFFFFFFFF),
      tertiary: const Color(0xFF222222),
      onTertiary: const Color(0xFFFFFFFF),

      // Containers and backgrounds
      primaryContainer: const Color(0xFFE0E0E0), // Button sidebar
      onPrimaryContainer: const Color(0xFF222222),
      secondaryContainer: const Color(0xFFF6F6F6), // Elements sidebar
      onSecondaryContainer: const Color(0xFF858585),
      tertiaryContainer: const Color(0xFFF6F6F6),
      onTertiaryContainer: const Color(0xFF222222),

      // Fixed colors
      primaryFixed: const Color(0xFF666666),
      primaryFixedDim: const Color(0xFF444444),

      // Surface colors
      surface: const Color(0xFFFFFFFF), // Editor background
      onSurface: const Color(0xFF222222),
      surfaceContainerLow: const Color(0xFFF6F6F6),
      surfaceContainerHigh: const Color(0xFFF6F6F6),
      surfaceContainerHighest: const Color(0xFFE0E0E0),

      // Error and outline colors
      error: const Color(0xFFc9184a),
      onError: const Color(0xFFFFFFFF),
      outline: const Color(0xFFB1B1B1),
      outlineVariant: const Color(0xFFE0E0E0),

      // State colors
      errorContainer: const Color(0xFFB00020),
      onErrorContainer: const Color(0xFFFFFFFF),
      inverseSurface: const Color(0xFF222222),
      onInverseSurface: const Color(0xFFFFFFFF),
      inversePrimary: const Color(0xFFFFFFFF),
      shadow: const Color(0xFF000000),
      scrim: const Color(0xFF000000),
    );
  }

  // Monochrome scheme for dark theme (white on black)
  static ColorScheme _buildMonochromeDark() {
    // Start from base scheme for themes without Color Mode
    final baseScheme = _defaultColorScheme(
      const Color(0xFFFFFFFF),
      Brightness.dark,
    );

    // Modify only accent colors, keeping backgrounds the same
    return baseScheme.copyWith(
      // Main accent colors
      primary: const Color(0xFFDADADA), // Primary color buttons
      onPrimary: const Color(0xFF1E1E1E),
      secondary: const Color(0xFF949494), // Inactive buttons
      onSecondary: const Color(0xFF1E1E1E),
      tertiary: const Color(0xFFDADADA),
      onTertiary: const Color(0xFF1E1E1E),

      // Containers and backgrounds
      primaryContainer: const Color(0xFF363636), // Button and element hover
      onPrimaryContainer: const Color(0xFFDADADA),
      secondaryContainer: const Color(0xFF262626),
      onSecondaryContainer: const Color(0xFF949494),
      tertiaryContainer: const Color(0xFF363636),
      onTertiaryContainer: const Color(0xFFDADADA),

      // Fixed colors
      primaryFixed: const Color(0xFFAAAAAA),
      primaryFixedDim: const Color(0xFF888888),

      // Surface colors
      surface: const Color(0xFF2D2D2D),
      onSurface: const Color(0xFFDADADA),
      surfaceContainerLow: const Color(0xFF262626),
      surfaceContainerHigh: const Color(0xFF363636),
      surfaceContainerHighest: const Color(0xFF363636),

      // Error and outline colors
      error: const Color(0xFFff8fa3),
      onError: const Color(0xFF1E1E1E),
      outline: const Color(0xFFA2A2A2),
      outlineVariant: const Color(0xFF262626),

      // State colors
      errorContainer: const Color(0xFFB00020),
      onErrorContainer: const Color(0xFFDADADA),
      inverseSurface: const Color(0xFFDADADA),
      onInverseSurface: const Color(0xFF1E1E1E),
      inversePrimary: const Color(0xFF1E1E1E),
      shadow: const Color(0xFF000000),
      scrim: const Color(0xFF000000),
    );
  }

  // Helper method to generate default color scheme
  static ColorScheme _defaultColorScheme(Color color, Brightness brightness) {
    final bool isDark = brightness == Brightness.dark;
    return ColorScheme.fromSeed(
      seedColor: color,
      brightness: brightness,
    ).copyWith(
      primary: color,
      onPrimary: isDark ? Colors.black : Colors.white,
      primaryContainer: color,
      onPrimaryContainer: isDark ? Colors.black : Colors.white,
      surface:
          brightness == Brightness.light
              ? const Color(0xFFFFFFFF) // Editor background
              : const Color(0xFF2D2D2D),
      surfaceContainerLowest:
          brightness == Brightness.light
              ? const Color(0xFFFFFFFF)
              : const Color(0xFF121212),
      surfaceContainerLow:
          brightness == Brightness.light
              ? const Color(0xFFF6F6F6) // Button and elements sidebar
              : const Color(0xFF262626),
      surfaceContainer:
          brightness == Brightness.light
              ? const Color(0xFFF6F6F6)
              : const Color(0xFF1E1E1E),
      surfaceContainerHigh:
          brightness == Brightness.light
              ? const Color(0xFFF6F6F6)
              : const Color(0xFF303030),
      surfaceContainerHighest:
          brightness == Brightness.light
              ? const Color(0xFFe0e0e0) // Sidebar divider
              : const Color(0xFF363636),
      tertiary:
          brightness == Brightness.light
              ? const Color(0xFF222222)
              : const Color(0xFF69F0AE),
      onSurface:
          brightness == Brightness.light
              ? const Color(0xFF222222)
              : const Color(0xFFE5E5E5),
      outline:
          brightness == Brightness.light
              ? const Color(0xFFB1B1B1)
              : const Color(0xFFA2A2A2),
    );
  }

  static Color _getCatppuccinSurfaceContainerHighest(
    Color base,
    Color overlay0,
    Brightness brightness,
  ) {
    // For light themes, use a very subtle color
    if (brightness == Brightness.light) {
      return overlay0.withAlpha(40);
    }
    // For dark themes, use a slightly more visible but still subtle color
    return overlay0.withAlpha(60);
  }
}

class ThemeNotifier extends ChangeNotifier {
  void refreshTheme() {
    notifyListeners();
  }
}

final themeNotifier = ThemeNotifier();
