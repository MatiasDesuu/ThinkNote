// editor_settings_panel.dart
// ignore_for_file: library_private_types_in_public_api, use_build_context_synchronously

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import '../widgets/custom_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:launch_at_startup/launch_at_startup.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'personalization_settings_panel.dart' show materialYouColors;

// Cache para las configuraciones del editor
class EditorSettingsCache {
  static EditorSettingsCache? _instance;
  static EditorSettingsCache get instance =>
      _instance ??= EditorSettingsCache._();

  EditorSettingsCache._();

  double? _fontSize;
  double? _lineSpacing;
  Color? _fontColor;
  bool? _useThemeFontColor;
  bool _isInitialized = false;
  String? _fontFamily;
  bool? _isEditorCentered;
  bool? _isAutoSaveEnabled;
  bool? _startAtStartup;
  bool? _showNotebookIcons;
  bool? _showNoteIcons;
  bool? _hideTabsInImmersive;
  bool? _expandNotebooksOnSelection;
  bool? _expandNotebooksOnNoteOpen;
  bool? _expandNotebooksOnLinkOpen;
  double? _wordsPerSecond;
  bool? _showBottomBar;
  double? _splitViewUpdateDelay;

  double get fontSize => _fontSize ?? EditorSettings.defaultFontSize;
  double get lineSpacing => _lineSpacing ?? EditorSettings.defaultLineSpacing;
  Color get fontColor => _fontColor ?? EditorSettings.defaultFontColor;
  bool get useThemeFontColor =>
      _useThemeFontColor ?? EditorSettings.defaultUseThemeFontColor;
  bool get isInitialized => _isInitialized;
  String get fontFamily => _fontFamily ?? EditorSettings.defaultFontFamily;
  bool get isEditorCentered =>
      _isEditorCentered ?? EditorSettings.defaultEditorCentered;
  bool get isAutoSaveEnabled =>
      _isAutoSaveEnabled ?? EditorSettings.defaultAutoSaveEnabled;
  bool get startAtStartup =>
      _startAtStartup ?? EditorSettings.defaultStartAtStartup;
  bool get showNotebookIcons =>
      _showNotebookIcons ?? EditorSettings.defaultShowNotebookIcons;
  bool get showNoteIcons =>
      _showNoteIcons ?? EditorSettings.defaultShowNoteIcons;
  bool get hideTabsInImmersive =>
      _hideTabsInImmersive ?? EditorSettings.defaultHideTabsInImmersive;
  bool get expandNotebooksOnSelection =>
      _expandNotebooksOnSelection ??
      EditorSettings.defaultExpandNotebooksOnSelection;
  bool get expandNotebooksOnNoteOpen =>
      _expandNotebooksOnNoteOpen ??
      EditorSettings.defaultExpandNotebooksOnNoteOpen;
  bool get expandNotebooksOnLinkOpen =>
      _expandNotebooksOnLinkOpen ??
      EditorSettings.defaultExpandNotebooksOnLinkOpen;
  double get wordsPerSecond =>
      _wordsPerSecond ?? EditorSettings.defaultWordsPerSecond;
  bool get showBottomBar => _showBottomBar ?? EditorSettings.defaultShowBottomBar;
  double get splitViewUpdateDelay =>
      _splitViewUpdateDelay ?? EditorSettings.defaultSplitViewUpdateDelay;

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      final results = await Future.wait([
        EditorSettings.getFontSize(),
        EditorSettings.getLineSpacing(),
        EditorSettings.getUseThemeFontColor(),
        EditorSettings.getFontColor(),
        EditorSettings.getFontFamily(),
        EditorSettings.getEditorCentered(),
        EditorSettings.getAutoSaveEnabled(),
        EditorSettings.getStartAtStartup(),
        EditorSettings.getShowNotebookIcons(),
        EditorSettings.getShowNoteIcons(),
        EditorSettings.getHideTabsInImmersive(),
        EditorSettings.getExpandNotebooksOnSelection(),
        EditorSettings.getExpandNotebooksOnNoteOpen(),
        EditorSettings.getExpandNotebooksOnLinkOpen(),
        EditorSettings.getWordsPerSecond(),
        EditorSettings.getShowBottomBar(),
        EditorSettings.getSplitViewUpdateDelay(),
      ]);

      _fontSize = results[0] as double;
      _lineSpacing = results[1] as double;
      _useThemeFontColor = results[2] as bool;
      _fontColor = results[3] as Color;
      _fontFamily = results[4] as String;
      _isEditorCentered = results[5] as bool;
      _isAutoSaveEnabled = results[6] as bool;
      _startAtStartup = results[7] as bool;
      _showNotebookIcons = results[8] as bool;
      _showNoteIcons = results[9] as bool;
      _hideTabsInImmersive = results[10] as bool;
      _expandNotebooksOnSelection = results[11] as bool;
      _expandNotebooksOnNoteOpen = results[12] as bool;
      _expandNotebooksOnLinkOpen = results[13] as bool;
      _wordsPerSecond = results[14] as double;
      _showBottomBar = results[15] as bool;
      _splitViewUpdateDelay = results[16] as double;
      _isInitialized = true;
    } catch (e) {
      print('Error initializing editor settings cache: $e');
      // Usar valores por defecto si hay error
      _fontSize = EditorSettings.defaultFontSize;
      _lineSpacing = EditorSettings.defaultLineSpacing;
      _fontColor = EditorSettings.defaultFontColor;
      _useThemeFontColor = EditorSettings.defaultUseThemeFontColor;
      _fontFamily = EditorSettings.defaultFontFamily;
      _isEditorCentered = EditorSettings.defaultEditorCentered;
      _isAutoSaveEnabled = EditorSettings.defaultAutoSaveEnabled;
      _startAtStartup = EditorSettings.defaultStartAtStartup;
      _showNotebookIcons = EditorSettings.defaultShowNotebookIcons;
      _showNoteIcons = EditorSettings.defaultShowNoteIcons;
      _hideTabsInImmersive = EditorSettings.defaultHideTabsInImmersive;
      _expandNotebooksOnSelection =
          EditorSettings.defaultExpandNotebooksOnSelection;
      _expandNotebooksOnNoteOpen =
          EditorSettings.defaultExpandNotebooksOnNoteOpen;
      _wordsPerSecond = EditorSettings.defaultWordsPerSecond;
      _showBottomBar = EditorSettings.defaultShowBottomBar;
      _splitViewUpdateDelay = EditorSettings.defaultSplitViewUpdateDelay;
      _isInitialized = true;
    }
  }

  void updateFontSize(double size) {
    _fontSize = size;
  }

  void updateLineSpacing(double spacing) {
    _lineSpacing = spacing;
  }

  void updateFontColor(Color? color) {
    _fontColor = color;
    _useThemeFontColor = color == null;
  }

  void updateUseThemeFontColor(bool useTheme) {
    _useThemeFontColor = useTheme;
    if (useTheme) {
      _fontColor = null;
    }
  }

  void updateFontFamily(String fontFamily) {
    _fontFamily = fontFamily;
  }

  void updateEditorCentered(bool isCentered) {
    _isEditorCentered = isCentered;
  }

  void updateAutoSaveEnabled(bool isEnabled) {
    _isAutoSaveEnabled = isEnabled;
  }

  void updateStartAtStartup(bool enabled) {
    _startAtStartup = enabled;
  }

  void updateShowNotebookIcons(bool show) {
    _showNotebookIcons = show;
  }

  void updateShowNoteIcons(bool show) {
    _showNoteIcons = show;
  }

  void updateHideTabsInImmersive(bool hide) {
    _hideTabsInImmersive = hide;
  }

  void updateExpandNotebooksOnSelection(bool expand) {
    _expandNotebooksOnSelection = expand;
  }

  void updateExpandNotebooksOnNoteOpen(bool expand) {
    _expandNotebooksOnNoteOpen = expand;
  }

  void updateExpandNotebooksOnLinkOpen(bool expand) {
    _expandNotebooksOnLinkOpen = expand;
  }

  void updateWordsPerSecond(double wps) {
    _wordsPerSecond = wps;
  }

  void updateShowBottomBar(bool show) {
    _showBottomBar = show;
  }

  void updateSplitViewUpdateDelay(double delay) {
    _splitViewUpdateDelay = delay;
  }
}

// Eventos de configuración
class EditorSettingsEvents {
  static final _fontSizeController = StreamController<double>.broadcast();
  static final _lineSpacingController = StreamController<double>.broadcast();
  static final _fontColorController = StreamController<Color?>.broadcast();
  static final _fontFamilyController = StreamController<String>.broadcast();
  static final _editorCenteredController = StreamController<bool>.broadcast();
  static final _autoSaveEnabledController = StreamController<bool>.broadcast();
  static final _startAtStartupController = StreamController<bool>.broadcast();
  static final _showNotebookIconsController =
      StreamController<bool>.broadcast();
  static final _showNoteIconsController = StreamController<bool>.broadcast();
  static final _hideTabsInImmersiveController =
      StreamController<bool>.broadcast();
  static final _expandNotebooksOnSelectionController =
      StreamController<bool>.broadcast();
  static final _expandNotebooksOnNoteOpenController =
      StreamController<bool>.broadcast();
  static final _expandNotebooksOnLinkOpenController =
      StreamController<bool>.broadcast();
  static final _wordsPerSecondController = StreamController<double>.broadcast();
  static final _showBottomBarController = StreamController<bool>.broadcast();
  static final _splitViewUpdateDelayController =
      StreamController<double>.broadcast();

  static Stream<double> get fontSizeStream => _fontSizeController.stream;
  static Stream<double> get lineSpacingStream => _lineSpacingController.stream;
  static Stream<Color?> get fontColorStream => _fontColorController.stream;
  static Stream<String> get fontFamilyStream => _fontFamilyController.stream;
  static Stream<bool> get editorCenteredStream =>
      _editorCenteredController.stream;
  static Stream<bool> get autoSaveEnabledStream =>
      _autoSaveEnabledController.stream;
  static Stream<bool> get startAtStartupStream =>
      _startAtStartupController.stream;
  static Stream<bool> get showNotebookIconsStream =>
      _showNotebookIconsController.stream;
  static Stream<bool> get showNoteIconsStream =>
      _showNoteIconsController.stream;
  static Stream<bool> get hideTabsInImmersiveStream =>
      _hideTabsInImmersiveController.stream;
  static Stream<bool> get expandNotebooksOnSelectionStream =>
      _expandNotebooksOnSelectionController.stream;
  static Stream<bool> get expandNotebooksOnNoteOpenStream =>
      _expandNotebooksOnNoteOpenController.stream;
  static Stream<bool> get expandNotebooksOnLinkOpenStream =>
      _expandNotebooksOnLinkOpenController.stream;
  static Stream<double> get wordsPerSecondStream =>
      _wordsPerSecondController.stream;
  static Stream<bool> get showBottomBarStream =>
      _showBottomBarController.stream;
  static Stream<double> get splitViewUpdateDelayStream =>
      _splitViewUpdateDelayController.stream;

  static void notifyFontSizeChanged(double size) {
    _fontSizeController.add(size);
  }

  static void notifyLineSpacingChanged(double spacing) {
    _lineSpacingController.add(spacing);
  }

  static void notifyFontColorChanged(Color? color) {
    _fontColorController.add(color);
  }

  static void notifyFontFamilyChanged(String fontFamily) {
    _fontFamilyController.add(fontFamily);
  }

  static void notifyEditorCenteredChanged(bool isCentered) {
    _editorCenteredController.add(isCentered);
  }

  static void notifyAutoSaveEnabledChanged(bool isEnabled) {
    _autoSaveEnabledController.add(isEnabled);
  }

  static void notifyStartAtStartupChanged(bool enabled) {
    _startAtStartupController.add(enabled);
  }

  static void notifyShowNotebookIconsChanged(bool show) {
    _showNotebookIconsController.add(show);
  }

  static void notifyShowNoteIconsChanged(bool show) {
    _showNoteIconsController.add(show);
  }

  static void notifyHideTabsInImmersiveChanged(bool hide) {
    _hideTabsInImmersiveController.add(hide);
  }

  static void notifyExpandNotebooksOnSelectionChanged(bool expand) {
    _expandNotebooksOnSelectionController.add(expand);
  }

  static void notifyExpandNotebooksOnNoteOpenChanged(bool expand) {
    _expandNotebooksOnNoteOpenController.add(expand);
  }

  static void notifyExpandNotebooksOnLinkOpenChanged(bool expand) {
    _expandNotebooksOnLinkOpenController.add(expand);
  }

  static void notifyWordsPerSecondChanged(double wps) {
    _wordsPerSecondController.add(wps);
  }

  static void notifyShowBottomBarChanged(bool show) {
    _showBottomBarController.add(show);
  }

  static void notifySplitViewUpdateDelayChanged(double delay) {
    _splitViewUpdateDelayController.add(delay);
  }

  static void dispose() {
    _fontSizeController.close();
    _lineSpacingController.close();
    _fontColorController.close();
    _fontFamilyController.close();
    _editorCenteredController.close();
    _autoSaveEnabledController.close();
    _startAtStartupController.close();
    _showNotebookIconsController.close();
    _showNoteIconsController.close();
    _hideTabsInImmersiveController.close();
    _expandNotebooksOnSelectionController.close();
    _expandNotebooksOnNoteOpenController.close();
    _expandNotebooksOnLinkOpenController.close();
    _wordsPerSecondController.close();
    _splitViewUpdateDelayController.close();
  }
}

class EditorSettings {
  static const String _autoSaveKey = 'auto_save_enabled';
  static const String _editorCenteredKey = 'editor_centered';
  static const String _startupKey = 'start_at_startup';
  static const String _fontSizeKey = 'editor_font_size';
  static const String _lineSpacingKey = 'editor_line_spacing';
  static const String _fontColorKey = 'editor_font_color';
  static const String _useThemeFontColorKey = 'editor_use_theme_font_color';
  static const String _fontFamilyKey = 'editor_font_family';
  static const String _showNotebookIconsKey = 'show_notebook_icons';
  static const String _showNoteIconsKey = 'show_note_icons';
  static const String _hideTabsInImmersiveKey = 'hide_tabs_in_immersive';
  static const String _expandNotebooksOnSelectionKey =
      'expand_notebooks_on_selection';
  static const String _expandNotebooksOnNoteOpenKey =
      'expand_notebooks_on_note_open';
  static const String _expandNotebooksOnLinkOpenKey =
      'expand_notebooks_on_link_open';
  static const String _wordsPerSecondKey = 'words_per_second';
  static const String _showBottomBarKey = 'show_editor_bottom_bar';
  static const String _splitViewUpdateDelayKey = 'split_view_update_delay';
  static const double defaultLineSpacing = 1.0;

  // Default values
  static const double defaultFontSize = 16.0;
  static const String defaultFontFamily = 'Roboto';
  static const Color defaultFontColor = Color(0xFF000000);
  static const bool defaultUseThemeFontColor = true;
  static const bool defaultEditorCentered = false;
  static const bool defaultAutoSaveEnabled = true;
  static const bool defaultStartAtStartup = false;
  static const bool defaultShowNotebookIcons = true;
  static const bool defaultShowNoteIcons = true;
  static const bool defaultHideTabsInImmersive = false;
  static const bool defaultExpandNotebooksOnSelection = true;
  static const bool defaultExpandNotebooksOnNoteOpen = true;
  static const bool defaultExpandNotebooksOnLinkOpen = true;
  static const double defaultWordsPerSecond = 5.0;
  static const bool defaultShowBottomBar = true;
  static const double defaultSplitViewUpdateDelay = 500.0;

  // Fuentes disponibles
  static const List<String> availableFonts = [
    'Roboto',
    'Inter',
    'Open Sans',
    'Lato',
    'Poppins',
    'Source Sans Pro',
    'Ubuntu',
    'Noto Sans',
    'Montserrat',
    'Raleway',
    'Work Sans',
    'Nunito',
    'Quicksand',
    'Comfortaa',
    'Josefin Sans',
    'Barlow',
    'IBM Plex Sans',
    'Fira Sans',
    'PT Sans',
    'Merriweather',
  ];

  // Usar los mismos colores que materialYouColors, pero agregando blanco y negro al principio
  static List<Color> get predefinedTextColors => [
    const Color(0xFFFFFFFF), // Blanco
    const Color(0xFF000000), // Negro
    ...materialYouColors,
  ];

  // Get autosave setting
  static Future<bool> getAutoSaveEnabled() async {
    return await PlatformSettings.get(_autoSaveKey, true);
  }

  // Save autosave setting
  static Future<void> setAutoSaveEnabled(bool value) async {
    await PlatformSettings.set(_autoSaveKey, value);
    EditorSettingsCache.instance.updateAutoSaveEnabled(value);
    EditorSettingsEvents.notifyAutoSaveEnabledChanged(value);
  }

  // Get if editor is centered
  static Future<bool> getEditorCentered() async {
    return await PlatformSettings.get(
      _editorCenteredKey,
      defaultEditorCentered,
    );
  }

  // Save if editor is centered
  static Future<void> setEditorCentered(bool value) async {
    await PlatformSettings.set(_editorCenteredKey, value);
    EditorSettingsCache.instance.updateEditorCentered(value);
    EditorSettingsEvents.notifyEditorCenteredChanged(value);
  }

  static Future<double> getFontSize() async {
    return await PlatformSettings.get(_fontSizeKey, defaultFontSize);
  }

  static Future<void> setFontSize(double value) async {
    await PlatformSettings.set(_fontSizeKey, value);
    EditorSettingsCache.instance.updateFontSize(value);
    EditorSettingsEvents.notifyFontSizeChanged(value);
  }

  static Future<double> getLineSpacing() async {
    return await PlatformSettings.get(_lineSpacingKey, defaultLineSpacing);
  }

  static Future<void> setLineSpacing(double value) async {
    await PlatformSettings.set(_lineSpacingKey, value);
    EditorSettingsCache.instance.updateLineSpacing(value);
    EditorSettingsEvents.notifyLineSpacingChanged(value);
  }

  static Future<bool> getUseThemeFontColor() async {
    return await PlatformSettings.get(
      _useThemeFontColorKey,
      defaultUseThemeFontColor,
    );
  }

  static Future<void> setUseThemeFontColor(bool value) async {
    await PlatformSettings.set(_useThemeFontColorKey, value);
    EditorSettingsCache.instance.updateUseThemeFontColor(value);
    EditorSettingsEvents.notifyFontColorChanged(null);
  }

  static Future<Color> getFontColor() async {
    final useTheme = await getUseThemeFontColor();
    if (useTheme) {
      return defaultFontColor; // Will be overridden by theme
    }
    final colorValue = await PlatformSettings.get(
      _fontColorKey,
      defaultFontColor.toARGB32(),
    );
    return Color(colorValue);
  }

  static Future<void> setFontColor(Color color) async {
    await PlatformSettings.set(_fontColorKey, color.toARGB32());
    await setUseThemeFontColor(false);
    EditorSettingsCache.instance.updateFontColor(color);
    EditorSettingsEvents.notifyFontColorChanged(color);
  }

  static Future<String> getFontFamily() async {
    return await PlatformSettings.get(_fontFamilyKey, defaultFontFamily);
  }

  static Future<void> setFontFamily(String fontFamily) async {
    await PlatformSettings.set(_fontFamilyKey, fontFamily);
    EditorSettingsCache.instance.updateFontFamily(fontFamily);
    EditorSettingsEvents.notifyFontFamilyChanged(fontFamily);
  }

  // Get startup setting
  static Future<bool> getStartAtStartup() async {
    return await PlatformSettings.get(_startupKey, defaultStartAtStartup);
  }

  // Save startup setting
  static Future<void> setStartAtStartup(bool value) async {
    await PlatformSettings.set(_startupKey, value);
    EditorSettingsCache.instance.updateStartAtStartup(value);
    EditorSettingsEvents.notifyStartAtStartupChanged(value);
    if (Platform.isWindows) {
      final packageInfo = await PackageInfo.fromPlatform();
      launchAtStartup.setup(
        appName: packageInfo.appName,
        appPath: Platform.resolvedExecutable,
      );

      if (value) {
        await launchAtStartup.enable();
      } else {
        await launchAtStartup.disable();
      }
    }
  }

  // Get show notebook icons setting
  static Future<bool> getShowNotebookIcons() async {
    return await PlatformSettings.get(
      _showNotebookIconsKey,
      defaultShowNotebookIcons,
    );
  }

  // Save show notebook icons setting
  static Future<void> setShowNotebookIcons(bool value) async {
    await PlatformSettings.set(_showNotebookIconsKey, value);
    EditorSettingsCache.instance.updateShowNotebookIcons(value);
    EditorSettingsEvents.notifyShowNotebookIconsChanged(value);
  }

  // Get show note icons setting
  static Future<bool> getShowNoteIcons() async {
    return await PlatformSettings.get(_showNoteIconsKey, defaultShowNoteIcons);
  }

  // Save show note icons setting
  static Future<void> setShowNoteIcons(bool value) async {
    await PlatformSettings.set(_showNoteIconsKey, value);
    EditorSettingsCache.instance.updateShowNoteIcons(value);
    EditorSettingsEvents.notifyShowNoteIconsChanged(value);
  }

  // Get hide tabs in immersive setting
  static Future<bool> getHideTabsInImmersive() async {
    return await PlatformSettings.get(
      _hideTabsInImmersiveKey,
      defaultHideTabsInImmersive,
    );
  }

  // Save hide tabs in immersive setting
  static Future<void> setHideTabsInImmersive(bool value) async {
    await PlatformSettings.set(_hideTabsInImmersiveKey, value);
    EditorSettingsCache.instance.updateHideTabsInImmersive(value);
    EditorSettingsEvents.notifyHideTabsInImmersiveChanged(value);
  }

  // Get expand notebooks on selection setting
  static Future<bool> getExpandNotebooksOnSelection() async {
    return await PlatformSettings.get(
      _expandNotebooksOnSelectionKey,
      defaultExpandNotebooksOnSelection,
    );
  }

  // Save expand notebooks on selection setting
  static Future<void> setExpandNotebooksOnSelection(bool value) async {
    await PlatformSettings.set(_expandNotebooksOnSelectionKey, value);
    EditorSettingsCache.instance.updateExpandNotebooksOnSelection(value);
    EditorSettingsEvents.notifyExpandNotebooksOnSelectionChanged(value);
  }

  // Get expand notebooks on note open setting
  static Future<bool> getExpandNotebooksOnNoteOpen() async {
    return await PlatformSettings.get(
      _expandNotebooksOnNoteOpenKey,
      defaultExpandNotebooksOnNoteOpen,
    );
  }

  // Save expand notebooks on note open setting
  static Future<void> setExpandNotebooksOnNoteOpen(bool value) async {
    await PlatformSettings.set(_expandNotebooksOnNoteOpenKey, value);
    EditorSettingsCache.instance.updateExpandNotebooksOnNoteOpen(value);
    EditorSettingsEvents.notifyExpandNotebooksOnNoteOpenChanged(value);
  }

  // Get expand notebooks on link open setting
  static Future<bool> getExpandNotebooksOnLinkOpen() async {
    return await PlatformSettings.get(
      _expandNotebooksOnLinkOpenKey,
      defaultExpandNotebooksOnLinkOpen,
    );
  }

  // Save expand notebooks on link open setting
  static Future<void> setExpandNotebooksOnLinkOpen(bool value) async {
    await PlatformSettings.set(_expandNotebooksOnLinkOpenKey, value);
    EditorSettingsCache.instance.updateExpandNotebooksOnLinkOpen(value);
    EditorSettingsEvents.notifyExpandNotebooksOnLinkOpenChanged(value);
  }

  // Get words per second setting
  static Future<double> getWordsPerSecond() async {
    return await PlatformSettings.get(_wordsPerSecondKey, defaultWordsPerSecond);
  }

  // Save words per second setting
  static Future<void> setWordsPerSecond(double value) async {
    await PlatformSettings.set(_wordsPerSecondKey, value);
    EditorSettingsCache.instance.updateWordsPerSecond(value);
    EditorSettingsEvents.notifyWordsPerSecondChanged(value);
  }

  // Get show bottom bar setting
  static Future<bool> getShowBottomBar() async {
    return await PlatformSettings.get(_showBottomBarKey, defaultShowBottomBar);
  }

  // Save show bottom bar setting
  static Future<void> setShowBottomBar(bool value) async {
    await PlatformSettings.set(_showBottomBarKey, value);
    EditorSettingsCache.instance.updateShowBottomBar(value);
    EditorSettingsEvents.notifyShowBottomBarChanged(value);
  }

  // Get split view update delay setting
  static Future<double> getSplitViewUpdateDelay() async {
    return await PlatformSettings.get(
      _splitViewUpdateDelayKey,
      defaultSplitViewUpdateDelay,
    );
  }

  // Save split view update delay setting
  static Future<void> setSplitViewUpdateDelay(double value) async {
    await PlatformSettings.set(_splitViewUpdateDelayKey, value);
    EditorSettingsCache.instance.updateSplitViewUpdateDelay(value);
    EditorSettingsEvents.notifySplitViewUpdateDelayChanged(value);
  }

  // Método para precargar todas las configuraciones del editor
  static Future<void> preloadSettings() async {
    await EditorSettingsCache.instance.initialize();
  }
}

class EditorSettingsPanel extends StatefulWidget {
  const EditorSettingsPanel({super.key});

  @override
  _EditorSettingsPanelState createState() => _EditorSettingsPanelState();
}

class _EditorSettingsPanelState extends State<EditorSettingsPanel> {
  double _fontSize = 16.0;
  double _lineSpacing = 1.0;
  Color _fontColor = const Color(0xFF000000);
  bool _useThemeFontColor = true;
  String _fontFamily = 'Roboto';
  bool _isEditorCentered = false;
  bool _isAutoSaveEnabled = true;
  bool _startAtStartup = false;
  bool _showNotebookIcons = true;
  bool _showNoteIcons = true;
  bool _hideTabsInImmersive = false;
  bool _expandNotebooksOnSelection = true;
  bool _expandNotebooksOnNoteOpen = true;
  bool _expandNotebooksOnLinkOpen = true;
  double _wordsPerSecond = 5.0;
  double _splitViewUpdateDelay = 500.0;
  bool _showBottomBar = true;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final fontSize = await EditorSettings.getFontSize();
    final lineSpacing = await EditorSettings.getLineSpacing();
    final useThemeFontColor = await EditorSettings.getUseThemeFontColor();
    final fontColor = await EditorSettings.getFontColor();
    final fontFamily = await EditorSettings.getFontFamily();
    final isEditorCentered = await EditorSettings.getEditorCentered();
    final isAutoSaveEnabled = await EditorSettings.getAutoSaveEnabled();
    final startAtStartup = await EditorSettings.getStartAtStartup();
    final showNotebookIcons = await EditorSettings.getShowNotebookIcons();
    final showNoteIcons = await EditorSettings.getShowNoteIcons();
    final hideTabsInImmersive = await EditorSettings.getHideTabsInImmersive();
    final expandNotebooksOnSelection =
        await EditorSettings.getExpandNotebooksOnSelection();
    final expandNotebooksOnNoteOpen =
        await EditorSettings.getExpandNotebooksOnNoteOpen();
    final expandNotebooksOnLinkOpen =
        await EditorSettings.getExpandNotebooksOnLinkOpen();
    final wordsPerSecond = await EditorSettings.getWordsPerSecond();
    final splitViewUpdateDelay = await EditorSettings.getSplitViewUpdateDelay();
    final showBottomBar = await EditorSettings.getShowBottomBar();
    setState(() {
      _fontSize = fontSize;
      _lineSpacing = lineSpacing;
      _useThemeFontColor = useThemeFontColor;
      _fontColor = fontColor;
      _fontFamily = fontFamily;
      _isEditorCentered = isEditorCentered;
      _isAutoSaveEnabled = isAutoSaveEnabled;
      _startAtStartup = startAtStartup;
      _showNotebookIcons = showNotebookIcons;
      _showNoteIcons = showNoteIcons;
      _hideTabsInImmersive = hideTabsInImmersive;
      _expandNotebooksOnSelection = expandNotebooksOnSelection;
      _expandNotebooksOnNoteOpen = expandNotebooksOnNoteOpen;
      _expandNotebooksOnLinkOpen = expandNotebooksOnLinkOpen;
      _wordsPerSecond = wordsPerSecond;
      _splitViewUpdateDelay = splitViewUpdateDelay;
      _showBottomBar = showBottomBar;
      _isLoading = false;
    });
  }

  Future<void> _updateLineSpacing(double newValue) async {
    setState(() => _lineSpacing = newValue);
    await EditorSettings.setLineSpacing(newValue);
    EditorSettingsEvents.notifyLineSpacingChanged(newValue);
  }

  Future<void> _updateFontSize(double newSize) async {
    setState(() => _fontSize = newSize);
    await EditorSettings.setFontSize(newSize);
    EditorSettingsEvents.notifyFontSizeChanged(newSize);
  }

  Future<void> _updateFontColor(Color color) async {
    setState(() {
      _fontColor = color;
      _useThemeFontColor = false;
    });
    await EditorSettings.setFontColor(color);
    EditorSettingsEvents.notifyFontColorChanged(color);
  }

  Future<void> _toggleUseThemeFontColor(bool value) async {
    setState(() => _useThemeFontColor = value);
    await EditorSettings.setUseThemeFontColor(value);
    EditorSettingsEvents.notifyFontColorChanged(null);
  }

  Future<void> _updateFontFamily(String fontFamily) async {
    setState(() => _fontFamily = fontFamily);
    await EditorSettings.setFontFamily(fontFamily);
    EditorSettingsEvents.notifyFontFamilyChanged(fontFamily);
  }

  Future<void> _updateEditorCentered(bool isCentered) async {
    setState(() => _isEditorCentered = isCentered);
    await EditorSettings.setEditorCentered(isCentered);
    EditorSettingsEvents.notifyEditorCenteredChanged(isCentered);
  }

  Future<void> _updateAutoSaveEnabled(bool isEnabled) async {
    setState(() => _isAutoSaveEnabled = isEnabled);
    await EditorSettings.setAutoSaveEnabled(isEnabled);
    EditorSettingsEvents.notifyAutoSaveEnabledChanged(isEnabled);
  }

  Future<void> _updateStartAtStartup(bool value) async {
    setState(() => _startAtStartup = value);
    await EditorSettings.setStartAtStartup(value);
  }

  Future<void> _updateShowNotebookIcons(bool value) async {
    setState(() => _showNotebookIcons = value);
    await EditorSettings.setShowNotebookIcons(value);
    EditorSettingsEvents.notifyShowNotebookIconsChanged(value);
  }

  Future<void> _updateShowNoteIcons(bool value) async {
    setState(() => _showNoteIcons = value);
    await EditorSettings.setShowNoteIcons(value);
    EditorSettingsEvents.notifyShowNoteIconsChanged(value);
  }

  Future<void> _updateHideTabsInImmersive(bool value) async {
    setState(() => _hideTabsInImmersive = value);
    await EditorSettings.setHideTabsInImmersive(value);
    EditorSettingsEvents.notifyHideTabsInImmersiveChanged(value);
  }

  Future<void> _updateExpandNotebooksOnSelection(bool value) async {
    setState(() => _expandNotebooksOnSelection = value);
    await EditorSettings.setExpandNotebooksOnSelection(value);
    EditorSettingsEvents.notifyExpandNotebooksOnSelectionChanged(value);
  }

  Future<void> _updateExpandNotebooksOnNoteOpen(bool value) async {
    setState(() => _expandNotebooksOnNoteOpen = value);
    await EditorSettings.setExpandNotebooksOnNoteOpen(value);
    EditorSettingsEvents.notifyExpandNotebooksOnNoteOpenChanged(value);
  }

  Future<void> _updateExpandNotebooksOnLinkOpen(bool value) async {
    setState(() => _expandNotebooksOnLinkOpen = value);
    await EditorSettings.setExpandNotebooksOnLinkOpen(value);
    EditorSettingsEvents.notifyExpandNotebooksOnLinkOpenChanged(value);
  }

  Future<void> _updateWordsPerSecond(double value) async {
    setState(() => _wordsPerSecond = value);
    await EditorSettings.setWordsPerSecond(value);
    EditorSettingsEvents.notifyWordsPerSecondChanged(value);
  }

  Future<void> _updateSplitViewUpdateDelay(double value) async {
    setState(() => _splitViewUpdateDelay = value);
    await EditorSettings.setSplitViewUpdateDelay(value);
    EditorSettingsEvents.notifySplitViewUpdateDelayChanged(value);
  }

  Future<void> _updateShowBottomBar(bool value) async {
    setState(() => _showBottomBar = value);
    await EditorSettings.setShowBottomBar(value);
    EditorSettingsEvents.notifyShowBottomBarChanged(value);
  }

  void _showFontSelector() {
    showDialog(
      context: context,
      builder:
          (context) => _FontSelectorDialog(
            selectedFont: _fontFamily,
            onFontSelected: (fontFamily) {
              _updateFontFamily(fontFamily);
              Navigator.pop(context);
            },
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    final colorScheme = Theme.of(context).colorScheme;
    final textStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
      color: colorScheme.onSurface,
      fontWeight: FontWeight.normal,
      fontSize: 15,
    );

    return ListView(
      children: [
        const Text(
          'Editor Settings',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 20),

        // Behavior Section (mover arriba)
        Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.settings_rounded, color: colorScheme.primary),
                    const SizedBox(width: 8),
                    const Text(
                      'Behavior',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Configure how the editor behaves',
                  style: TextStyle(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 16),

                // Editor Centered
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Default center editor', style: textStyle),
                          const SizedBox(height: 4),
                          Text(
                            'Set the default centering behavior for new notes',
                            style: TextStyle(
                              color: colorScheme.onSurfaceVariant,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: _isEditorCentered,
                      onChanged: _updateEditorCentered,
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // Show Editor Bottom Bar
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Show editor toolbar', style: textStyle),
                          const SizedBox(height: 4),
                          Text(
                            'Display the formatting toolbar in the editor',
                            style: TextStyle(
                              color: colorScheme.onSurfaceVariant,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: _showBottomBar,
                      onChanged: _updateShowBottomBar,
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // Auto Save
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Auto save', style: textStyle),
                          const SizedBox(height: 4),
                          Text(
                            'Automatically save changes while typing',
                            style: TextStyle(
                              color: colorScheme.onSurfaceVariant,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: _isAutoSaveEnabled,
                      onChanged: _updateAutoSaveEnabled,
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // Start at Startup (Windows only)
                if (Platform.isWindows)
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Start at startup', style: textStyle),
                            const SizedBox(height: 4),
                            Text(
                              'Launch the app automatically when Windows starts',
                              style: TextStyle(
                                color: colorScheme.onSurfaceVariant,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: _startAtStartup,
                        onChanged: _updateStartAtStartup,
                      ),
                    ],
                  ),

                const SizedBox(height: 20),

                // Show Notebook Icons
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Show notebook icons', style: textStyle),
                          const SizedBox(height: 4),
                          Text(
                            'Display icons next to notebook names in the sidebar',
                            style: TextStyle(
                              color: colorScheme.onSurfaceVariant,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: _showNotebookIcons,
                      onChanged: _updateShowNotebookIcons,
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // Show Note Icons
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Show note icons', style: textStyle),
                          const SizedBox(height: 4),
                          Text(
                            'Display icons next to note names in the notes panel',
                            style: TextStyle(
                              color: colorScheme.onSurfaceVariant,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: _showNoteIcons,
                      onChanged: _updateShowNoteIcons,
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // Hide Tabs in Immersive Mode
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Hide tabs in immersive mode', style: textStyle),
                          const SizedBox(height: 4),
                          Text(
                            'Hide the tab bar when entering immersive mode for distraction-free editing',
                            style: TextStyle(
                              color: colorScheme.onSurfaceVariant,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: _hideTabsInImmersive,
                      onChanged: _updateHideTabsInImmersive,
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // Expand Notebooks on Selection
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Auto-expand notebooks when selecting favorites',
                            style: textStyle,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Automatically expand parent folders when selecting notebooks from calendar favorites',
                            style: TextStyle(
                              color: colorScheme.onSurfaceVariant,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: _expandNotebooksOnSelection,
                      onChanged: _updateExpandNotebooksOnSelection,
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // Expand Notebooks on Note Open
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Auto-expand notebooks when opening notes',
                            style: textStyle,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Automatically expand parent folders when opening notes',
                            style: TextStyle(
                              color: colorScheme.onSurfaceVariant,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: _expandNotebooksOnNoteOpen,
                      onChanged: _updateExpandNotebooksOnNoteOpen,
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // Expand Notebooks on Link Open
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Auto-expand notebooks when opening links',
                            style: textStyle,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Automatically expand parent folders when opening notebook links',
                            style: TextStyle(
                              color: colorScheme.onSurfaceVariant,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: _expandNotebooksOnLinkOpen,
                      onChanged: _updateExpandNotebooksOnLinkOpen,
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // Words Per Second for Script Mode
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Script mode words per second', style: textStyle),
                    const SizedBox(height: 4),
                    Text(
                      'Adjust the reading speed for script mode duration estimation',
                      style: TextStyle(
                        color: colorScheme.onSurfaceVariant,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(
                          '${_wordsPerSecond.toStringAsFixed(1)} WPS',
                          style: TextStyle(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Expanded(
                          child: Slider(
                            value: _wordsPerSecond,
                            min: 1.0,
                            max: 10.0,
                            divisions: 90,
                            onChanged: _updateWordsPerSecond,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // Preview Update Delay
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Preview update delay', style: textStyle),
                    const SizedBox(height: 4),
                    Text(
                      'Adjust how fast the split view preview updates while typing',
                      style: TextStyle(
                        color: colorScheme.onSurfaceVariant,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(
                          '${(_splitViewUpdateDelay / 1000).toStringAsFixed(2)} s',
                          style: TextStyle(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Expanded(
                          child: Slider(
                            value: _splitViewUpdateDelay,
                            min: 0,
                            max: 2000,
                            divisions: 40,
                            label: '${(_splitViewUpdateDelay / 1000).toStringAsFixed(2)} s',
                            onChanged: _updateSplitViewUpdateDelay,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Typography Section
        Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.text_fields_rounded, color: colorScheme.primary),
                    const SizedBox(width: 8),
                    const Text(
                      'Typography',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Customize the appearance of your text',
                  style: TextStyle(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 16),

                // Font Size
                Text(
                  'Font size:',
                  style: textStyle?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Slider(
                        value: _fontSize,
                        min: 12,
                        max: 32,
                        divisions: 20,
                        label: _fontSize.round().toString(),
                        onChanged: _updateFontSize,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: colorScheme.outline.withAlpha(51),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        '${_fontSize.round()} pt',
                        style: textStyle?.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // Line Spacing
                Text(
                  'Line spacing:',
                  style: textStyle?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Slider(
                        value: _lineSpacing,
                        min: 0.8,
                        max: 2.0,
                        divisions: 12,
                        label: _lineSpacing.toStringAsFixed(1),
                        onChanged: _updateLineSpacing,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: colorScheme.outline.withAlpha(51),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        'x${_lineSpacing.toStringAsFixed(1)}',
                        style: textStyle?.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // Text Color
                Text(
                  'Text color:',
                  style: textStyle?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),

                // Use theme color toggle
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Use theme color', style: textStyle),
                          const SizedBox(height: 4),
                          Text(
                            'Use the default theme color for text',
                            style: TextStyle(
                              color: colorScheme.onSurfaceVariant,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: _useThemeFontColor,
                      onChanged: _toggleUseThemeFontColor,
                    ),
                  ],
                ),

                // Color selection (only visible when not using theme color)
                if (!_useThemeFontColor) ...[
                  const SizedBox(height: 16),
                  Text(
                    'Select custom color:',
                    style: textStyle?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  _buildColorGrid(),
                ],

                const SizedBox(height: 20),

                // Font Family
                Text(
                  'Font family:',
                  style: textStyle?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(16),
                    child: InkWell(
                      onTap: _showFontSelector,
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHighest.withAlpha(
                            127,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: colorScheme.outline,
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.text_fields_rounded,
                              color: colorScheme.primary,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _fontFamily,
                                style: TextStyle(
                                  fontFamily: _fontFamily,
                                  fontSize: 16,
                                  color: colorScheme.onSurface,
                                ),
                              ),
                            ),
                            Icon(
                              Icons.arrow_drop_down_rounded,
                              color: colorScheme.onSurface,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Preview Section
        Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.preview_rounded, color: colorScheme.primary),
                    const SizedBox(width: 8),
                    const Text(
                      'Preview',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'See how your text will look with current settings',
                  style: TextStyle(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerLow,
                    border: Border.all(
                      color: colorScheme.outline.withAlpha(77),
                      width: 1,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Lorem ipsum dolor sit amet, consectetur adipiscing elit. Donec suscipit arcu id sem sodales, vel eleifend nunc tincidunt. Nulla faucibus et nulla ut convallis. Vivamus viverra magna venenatis tempor pellentesque. Aliquam erat volutpat. Suspendisse semper gravida sapien id suscipit. Donec non vestibulum lacus. In id lorem ac nisi faucibus dapibus vitae sit amet odio. Sed euismod venenatis libero at blandit. Aenean dictum ante ut viverra ullamcorper. Morbi quis tortor in purus mollis interdum. Sed ullamcorper ex velit, vitae fringilla ligula pellentesque eu. Integer tincidunt faucibus nisl eget condimentum. Curabitur posuere aliquam mollis.\n',
                    style: TextStyle(
                      fontSize: _fontSize,
                      height: _lineSpacing,
                      fontFamily: _fontFamily,
                      color:
                          _useThemeFontColor
                              ? colorScheme.onSurface
                              : _fontColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildColorGrid() {
    final colorScheme = Theme.of(context).colorScheme;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children:
          EditorSettings.predefinedTextColors.map((color) {
            final isSelected =
                !_useThemeFontColor &&
                _fontColor.toARGB32() == color.toARGB32();
            return GestureDetector(
              onTap: () => _updateFontColor(color),
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color:
                        isSelected
                            ? colorScheme.primary
                            : color.computeLuminance() > 0.8
                            ? Colors.grey.withAlpha(127)
                            : Colors.transparent,
                    width: isSelected ? 3 : 1,
                  ),
                ),
                child:
                    isSelected
                        ? Icon(
                          Icons.check_rounded,
                          color:
                              color.computeLuminance() > 0.5
                                  ? Colors.black
                                  : Colors.white,
                          size: 16,
                        )
                        : null,
              ),
            );
          }).toList(),
    );
  }
}

class PlatformSettings {
  static String _getPlatformKey(String key) {
    final platform =
        Platform.isWindows
            ? 'windows'
            : Platform.isLinux
            ? 'linux'
            : Platform.isMacOS
            ? 'macos'
            : 'unknown';
    return '${platform}_$key';
  }

  static Future<T> get<T>(String key, T defaultValue) async {
    final prefs = await SharedPreferences.getInstance();
    final platformKey = _getPlatformKey(key);

    if (T == bool) {
      return prefs.getBool(platformKey) as T? ?? defaultValue;
    } else if (T == int) {
      return prefs.getInt(platformKey) as T? ?? defaultValue;
    } else if (T == double) {
      return prefs.getDouble(platformKey) as T? ?? defaultValue;
    } else if (T == String) {
      return prefs.getString(platformKey) as T? ?? defaultValue;
    }
    return defaultValue;
  }

  static Future<void> set<T>(String key, T value) async {
    final prefs = await SharedPreferences.getInstance();
    final platformKey = _getPlatformKey(key);

    if (value is bool) {
      await prefs.setBool(platformKey, value);
    } else if (value is int) {
      await prefs.setInt(platformKey, value);
    } else if (value is double) {
      await prefs.setDouble(platformKey, value);
    } else if (value is String) {
      await prefs.setString(platformKey, value);
    }
  }
}

class _FontSelectorDialog extends StatelessWidget {
  final String selectedFont;
  final Function(String) onFontSelected;

  const _FontSelectorDialog({
    required this.selectedFont,
    required this.onFontSelected,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return CustomDialog(
      title: 'Select Font',
      icon: Icons.text_fields_rounded,
      width: 500,
      height: 400,
      child: Expanded(
        child: ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: EditorSettings.availableFonts.length,
          itemBuilder: (context, index) {
            final font = EditorSettings.availableFonts[index];
            final isSelected = font == selectedFont;
            return Card(
              elevation: 0,
              margin: const EdgeInsets.only(bottom: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(
                  color: colorScheme.outlineVariant.withAlpha(127),
                  width: 0.5,
                ),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => onFontSelected(font),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    height: 56,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Icon(
                          isSelected
                              ? Icons.check_circle_rounded
                              : Icons.circle_outlined,
                          color:
                              isSelected
                                  ? colorScheme.primary
                                  : colorScheme.onSurfaceVariant,
                          size: 20,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            font,
                            style: TextStyle(
                              fontFamily: font,
                              fontSize: 16,
                              color: colorScheme.onSurface,
                            ),
                          ),
                        ),
                        if (isSelected)
                          Icon(
                            Icons.check_rounded,
                            color: colorScheme.primary,
                            size: 20,
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
