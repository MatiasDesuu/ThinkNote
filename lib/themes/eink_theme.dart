// eink_theme.dart
// E-ink theme for devices with e-ink displays
// Pure black and white theme without any gray tones or transparencies

import 'package:flutter/material.dart';

class EInkTheme {
  // Pure colors for e-ink displays
  static const Color pureBlack = Color(0xFF000000);
  static const Color pureWhite = Color(0xFFFFFFFF);

  /// Builds a pure black and white ColorScheme for e-ink displays
  /// 
  /// When [isLightMode] is true:
  ///   - Backgrounds are white
  ///   - Text and prominent elements are black
  /// 
  /// When [isLightMode] is false:
  ///   - Backgrounds are black
  ///   - Text and prominent elements are white
  static ColorScheme buildEInkColorScheme({required bool isLightMode}) {
    // Define colors based on light/dark mode
    final backgroundColor = isLightMode ? pureWhite : pureBlack;
    final foregroundColor = isLightMode ? pureBlack : pureWhite;

    return ColorScheme(
      brightness: isLightMode ? Brightness.light : Brightness.dark,
      
      // Primary colors - Use foreground for prominent elements
      primary: foregroundColor,
      onPrimary: backgroundColor,
      primaryContainer: foregroundColor,
      onPrimaryContainer: backgroundColor,

      // Secondary colors - Same as primary for consistency
      secondary: foregroundColor,
      onSecondary: backgroundColor,
      secondaryContainer: foregroundColor,
      onSecondaryContainer: backgroundColor,

      // Tertiary colors - Same as primary for consistency
      tertiary: foregroundColor,
      onTertiary: backgroundColor,
      tertiaryContainer: foregroundColor,
      onTertiaryContainer: backgroundColor,

      // Surface colors - All backgrounds are pure background color
      surface: backgroundColor,
      onSurface: foregroundColor,
      onSurfaceVariant: foregroundColor,

      // Surface containers - All variations use the same background
      surfaceContainerLowest: backgroundColor,
      surfaceContainerLow: backgroundColor,
      surfaceContainer: backgroundColor,
      surfaceContainerHigh: backgroundColor,
      surfaceContainerHighest: backgroundColor,

      // Error colors - Use foreground color for visibility
      error: foregroundColor,
      onError: backgroundColor,
      errorContainer: foregroundColor,
      onErrorContainer: backgroundColor,

      // Outline colors - Use foreground for borders
      outline: foregroundColor,
      outlineVariant: foregroundColor,

      // Inverse colors - Swap background and foreground
      inverseSurface: foregroundColor,
      onInverseSurface: backgroundColor,
      inversePrimary: backgroundColor,

      // Shadow and scrim - Use foreground color
      shadow: foregroundColor,
      scrim: foregroundColor,
    );
  }

  /// Builds a complete ThemeData for e-ink displays
  static ThemeData buildEInkTheme({required bool isLightMode}) {
    final colorScheme = buildEInkColorScheme(isLightMode: isLightMode);
    final backgroundColor = isLightMode ? pureWhite : pureBlack;
    final foregroundColor = isLightMode ? pureBlack : pureWhite;

    return ThemeData(
      brightness: isLightMode ? Brightness.light : Brightness.dark,
      useMaterial3: true,
      colorScheme: colorScheme,
      
      // AppBar with pure colors
      appBarTheme: AppBarTheme(
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        backgroundColor: backgroundColor,
        foregroundColor: foregroundColor,
        elevation: 0,
        iconTheme: IconThemeData(color: foregroundColor),
      ),

      // Card theme with pure colors
      cardTheme: CardTheme(
        color: backgroundColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: foregroundColor, width: 1),
        ),
      ),

      // Divider with pure colors
      dividerTheme: DividerThemeData(
        color: foregroundColor,
        thickness: 1,
      ),

      // Text theme with pure colors
      textTheme: TextTheme(
        bodyLarge: TextStyle(color: foregroundColor),
        bodyMedium: TextStyle(color: foregroundColor),
        bodySmall: TextStyle(color: foregroundColor),
        displayLarge: TextStyle(color: foregroundColor),
        displayMedium: TextStyle(color: foregroundColor),
        displaySmall: TextStyle(color: foregroundColor),
        headlineLarge: TextStyle(color: foregroundColor),
        headlineMedium: TextStyle(color: foregroundColor),
        headlineSmall: TextStyle(color: foregroundColor),
        titleLarge: TextStyle(color: foregroundColor),
        titleMedium: TextStyle(color: foregroundColor),
        titleSmall: TextStyle(color: foregroundColor),
        labelLarge: TextStyle(color: foregroundColor),
        labelMedium: TextStyle(color: foregroundColor),
        labelSmall: TextStyle(color: foregroundColor),
      ),

      // Icon theme with pure colors
      iconTheme: IconThemeData(color: foregroundColor),
      primaryIconTheme: IconThemeData(color: foregroundColor),

      // Button themes with pure colors
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: foregroundColor,
          foregroundColor: backgroundColor,
          elevation: 0,
        ),
      ),
      
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: foregroundColor,
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: foregroundColor,
          side: BorderSide(color: foregroundColor),
        ),
      ),

      // Input decoration theme
      inputDecorationTheme: InputDecorationTheme(
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        labelStyle: TextStyle(color: foregroundColor),
        hintStyle: TextStyle(color: foregroundColor),
      ),

      // Switch theme
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.all(backgroundColor),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return foregroundColor;
          }
          return foregroundColor;
        }),
        trackOutlineColor: WidgetStateProperty.all(foregroundColor),
      ),

      // Checkbox theme
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return foregroundColor;
          }
          return backgroundColor;
        }),
        checkColor: WidgetStateProperty.all(backgroundColor),
        side: BorderSide(color: foregroundColor, width: 2),
      ),

      // Radio theme
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return foregroundColor;
          }
          return backgroundColor;
        }),
      ),

      // Navigation bar theme (Material 3)
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: backgroundColor,
        indicatorColor: foregroundColor,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: backgroundColor);
          }
          return IconThemeData(color: foregroundColor);
        }),
        labelTextStyle: WidgetStateProperty.all(
          TextStyle(color: foregroundColor, fontSize: 12),
        ),
      ),

      // Bottom navigation bar theme (Material 2 legacy)
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: backgroundColor,
        selectedItemColor: backgroundColor,
        unselectedItemColor: foregroundColor,
      ),

      // Navigation rail theme
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: backgroundColor,
        selectedIconTheme: IconThemeData(color: backgroundColor),
        unselectedIconTheme: IconThemeData(color: foregroundColor),
        selectedLabelTextStyle: TextStyle(color: foregroundColor),
        unselectedLabelTextStyle: TextStyle(color: foregroundColor),
        indicatorColor: foregroundColor,
      ),

      // Scaffold background
      scaffoldBackgroundColor: backgroundColor,
    );
  }

  /// Helper method to check if a color is pure black or white
  static bool isPureColor(Color color) {
    return color == pureBlack || color == pureWhite;
  }

  /// Helper method to get description based on mode
  static String getDescription(bool isLightMode) {
    if (isLightMode) {
      return 'Pure white background with black elements for e-ink displays';
    } else {
      return 'Pure black background with white elements for e-ink displays';
    }
  }
}
