import 'package:flutter/material.dart';

class EInkTheme {
  static const Color pureBlack = Color(0xFF000000);
  static const Color pureWhite = Color(0xFFFFFFFF);

  static ColorScheme buildEInkColorScheme({required bool isLightMode}) {
    final backgroundColor = isLightMode ? pureWhite : pureBlack;
    final foregroundColor = isLightMode ? pureBlack : pureWhite;

    return ColorScheme(
      brightness: isLightMode ? Brightness.light : Brightness.dark,

      primary: foregroundColor,
      onPrimary: backgroundColor,
      primaryContainer: foregroundColor,
      onPrimaryContainer: backgroundColor,

      secondary: foregroundColor,
      onSecondary: backgroundColor,
      secondaryContainer: foregroundColor,
      onSecondaryContainer: backgroundColor,

      tertiary: foregroundColor,
      onTertiary: backgroundColor,
      tertiaryContainer: foregroundColor,
      onTertiaryContainer: backgroundColor,

      surface: backgroundColor,
      onSurface: foregroundColor,
      onSurfaceVariant: foregroundColor,

      surfaceContainerLowest: backgroundColor,
      surfaceContainerLow: backgroundColor,
      surfaceContainer: backgroundColor,
      surfaceContainerHigh: backgroundColor,
      surfaceContainerHighest: backgroundColor,

      error: foregroundColor,
      onError: backgroundColor,
      errorContainer: foregroundColor,
      onErrorContainer: backgroundColor,

      outline: foregroundColor,
      outlineVariant: foregroundColor,

      inverseSurface: foregroundColor,
      onInverseSurface: backgroundColor,
      inversePrimary: backgroundColor,

      shadow: foregroundColor,
      scrim: foregroundColor,
    );
  }

  static ThemeData buildEInkTheme({required bool isLightMode}) {
    final colorScheme = buildEInkColorScheme(isLightMode: isLightMode);
    final backgroundColor = isLightMode ? pureWhite : pureBlack;
    final foregroundColor = isLightMode ? pureBlack : pureWhite;

    return ThemeData(
      brightness: isLightMode ? Brightness.light : Brightness.dark,
      useMaterial3: true,
      colorScheme: colorScheme,

      appBarTheme: AppBarTheme(
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        backgroundColor: backgroundColor,
        foregroundColor: foregroundColor,
        elevation: 0,
        iconTheme: IconThemeData(color: foregroundColor),
      ),

      cardTheme: CardThemeData(
        color: backgroundColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: foregroundColor, width: 1),
        ),
      ),

      dividerTheme: DividerThemeData(color: foregroundColor, thickness: 1),

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

      iconTheme: IconThemeData(color: foregroundColor),
      primaryIconTheme: IconThemeData(color: foregroundColor),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: foregroundColor,
          foregroundColor: backgroundColor,
          elevation: 0,
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: foregroundColor),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: foregroundColor,
          side: BorderSide(color: foregroundColor),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        labelStyle: TextStyle(color: foregroundColor),
        hintStyle: TextStyle(color: foregroundColor),
      ),

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

      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return foregroundColor;
          }
          return backgroundColor;
        }),
      ),

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

      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: backgroundColor,
        selectedItemColor: backgroundColor,
        unselectedItemColor: foregroundColor,
      ),

      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: backgroundColor,
        selectedIconTheme: IconThemeData(color: backgroundColor),
        unselectedIconTheme: IconThemeData(color: foregroundColor),
        selectedLabelTextStyle: TextStyle(color: foregroundColor),
        unselectedLabelTextStyle: TextStyle(color: foregroundColor),
        indicatorColor: foregroundColor,
      ),

      scaffoldBackgroundColor: backgroundColor,
    );
  }

  static bool isPureColor(Color color) {
    return color == pureBlack || color == pureWhite;
  }

  static String getDescription(bool isLightMode) {
    if (isLightMode) {
      return 'Pure white background with black elements for e-ink displays';
    } else {
      return 'Pure black background with white elements for e-ink displays';
    }
  }
}
