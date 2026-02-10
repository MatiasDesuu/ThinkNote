import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ImmersiveModeService extends ChangeNotifier {
  static final ImmersiveModeService _instance =
      ImmersiveModeService._internal();
  factory ImmersiveModeService() => _instance;
  ImmersiveModeService._internal();

  bool _isImmersiveMode = false;
  bool _isInitialized = false;

  bool? _wasIconSidebarExpanded;
  bool? _wasNotebooksPanelExpanded;
  bool? _wasNotesPanelExpanded;
  bool? _wasCalendarPanelExpanded;

  bool get isImmersiveMode => _isImmersiveMode;

  Future<void> initialize() async {
    if (_isInitialized) return;

    _isImmersiveMode = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('immersive_mode_enabled', false);
    _isInitialized = true;
    notifyListeners();
  }

  void savePanelStates({
    required bool iconSidebarExpanded,
    required bool notebooksPanelExpanded,
    required bool notesPanelExpanded,
    required bool calendarPanelExpanded,
  }) {
    _wasIconSidebarExpanded = iconSidebarExpanded;
    _wasNotebooksPanelExpanded = notebooksPanelExpanded;
    _wasNotesPanelExpanded = notesPanelExpanded;
    _wasCalendarPanelExpanded = calendarPanelExpanded;
  }

  Map<String, bool?> getSavedPanelStates() {
    return {
      'iconSidebar': _wasIconSidebarExpanded,
      'notebooks': _wasNotebooksPanelExpanded,
      'notes': _wasNotesPanelExpanded,
      'calendar': _wasCalendarPanelExpanded,
    };
  }

  Future<void> enterImmersiveMode() async {
    if (_isImmersiveMode) return;

    _isImmersiveMode = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('immersive_mode_enabled', _isImmersiveMode);
    notifyListeners();
  }

  Future<void> exitImmersiveMode() async {
    if (!_isImmersiveMode) return;

    _isImmersiveMode = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('immersive_mode_enabled', _isImmersiveMode);
    notifyListeners();
  }

  Future<void> toggleImmersiveMode() async {
    if (_isImmersiveMode) {
      await exitImmersiveMode();
    } else {
      await enterImmersiveMode();
    }
  }

  Future<void> setImmersiveMode(bool enabled) async {
    if (_isImmersiveMode == enabled) return;

    _isImmersiveMode = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('immersive_mode_enabled', _isImmersiveMode);
    notifyListeners();
  }
}
