// shortcuts_handler.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// Intent for creating script block with Ctrl+Shift+D
class CreateScriptBlockIntent extends Intent {
  const CreateScriptBlockIntent();
}

// Intent for finding text in editor with Ctrl+F
class FindInEditorIntent extends Intent {
  const FindInEditorIntent();
}

// Intent for global search with Ctrl+Shift+S
class GlobalSearchIntent extends Intent {
  const GlobalSearchIntent();
}

class ShortcutsHandler {
  // Global application shortcuts
  static Map<ShortcutActivator, VoidCallback> getAppShortcuts({
    required VoidCallback onCloseDialog,
    required VoidCallback onToggleSidebar,
    required VoidCallback onToggleEditorCentered,
    required VoidCallback onCreateNote,
    required VoidCallback onCreateNotebook,
    required VoidCallback onCreateTodo,
    required VoidCallback onSaveNote,
    required VoidCallback onToggleNotesPanel,
    required VoidCallback onForceSync,
    required VoidCallback onSearch,
    required VoidCallback onToggleImmersiveMode,
    required VoidCallback onGlobalSearch,
    required VoidCallback onCloseTab,
    required VoidCallback onNewTab,
    required VoidCallback onToggleReadMode,
  }) {
    return {
      const SingleActivator(LogicalKeyboardKey.escape): onCloseDialog,
      SingleActivator(LogicalKeyboardKey.f2, includeRepeats: false):
          onToggleSidebar,
      const SingleActivator(LogicalKeyboardKey.f3): onToggleNotesPanel,
      const SingleActivator(LogicalKeyboardKey.f1): onToggleEditorCentered,
      const SingleActivator(LogicalKeyboardKey.keyN, control: true):
          onCreateNote,
      const SingleActivator(
            LogicalKeyboardKey.keyN,
            control: true,
            shift: true,
          ):
          onCreateNotebook,
      const SingleActivator(LogicalKeyboardKey.keyT, control: true): onNewTab,
      const SingleActivator(LogicalKeyboardKey.keyD, control: true):
          onCreateTodo,
      const SingleActivator(LogicalKeyboardKey.keyS, control: true): onSaveNote,
      const SingleActivator(LogicalKeyboardKey.keyF, control: true): onSearch,
      const SingleActivator(LogicalKeyboardKey.f4): onToggleImmersiveMode,
      const SingleActivator(LogicalKeyboardKey.f5): onForceSync,
      const SingleActivator(
            LogicalKeyboardKey.keyF,
            control: true,
            shift: true,
          ):
          onGlobalSearch,
      const SingleActivator(LogicalKeyboardKey.keyW, control: true): onCloseTab,
      const SingleActivator(LogicalKeyboardKey.keyP, control: true): onToggleReadMode,
    };
  }

  /// Checks if a keyboard event matches a global shortcut and handles it.
  /// Returns true if the event was handled (to stop propagation).
  static bool handleGlobalKeyEvent(
    KeyEvent event, {
    required VoidCallback onCloseDialog,
    required VoidCallback onToggleSidebar,
    required VoidCallback onToggleEditorCentered,
    required VoidCallback onCreateNote,
    required VoidCallback onCreateNotebook,
    required VoidCallback onCreateTodo,
    required VoidCallback onSaveNote,
    required VoidCallback onToggleNotesPanel,
    required VoidCallback onForceSync,
    required VoidCallback onSearch,
    required VoidCallback onToggleImmersiveMode,
    required VoidCallback onGlobalSearch,
    required VoidCallback onCloseTab,
    required VoidCallback onNewTab,
    required VoidCallback onToggleReadMode,
  }) {
    // Only handle key down events
    if (event is! KeyDownEvent) return false;

    final bool isControlPressed = HardwareKeyboard.instance.isControlPressed;
    final bool isShiftPressed = HardwareKeyboard.instance.isShiftPressed;
    final LogicalKeyboardKey key = event.logicalKey;

    // Ctrl+Shift combinations (check first as they're more specific)
    if (isControlPressed && isShiftPressed) {
      if (key == LogicalKeyboardKey.keyN) {
        onCreateNotebook();
        return true;
      }
      if (key == LogicalKeyboardKey.keyF) {
        onGlobalSearch();
        return true;
      }
    }

    // Ctrl combinations (without Shift)
    if (isControlPressed && !isShiftPressed) {
      if (key == LogicalKeyboardKey.keyN) {
        onCreateNote();
        return true;
      }
      if (key == LogicalKeyboardKey.keyD) {
        onCreateTodo();
        return true;
      }
      if (key == LogicalKeyboardKey.keyT) {
        onNewTab();
        return true;
      }
      // Ctrl+S is NOT handled globally - it's handled by the editor's
      // Shortcuts widget to preserve focus and cursor position (like Obsidian/Joplin)
      if (key == LogicalKeyboardKey.keyW) {
        onCloseTab();
        return true;
      }
      if (key == LogicalKeyboardKey.keyP) {
        onToggleReadMode();
        return true;
      }
    }

    // Function keys (no modifiers needed)
    if (!isControlPressed && !isShiftPressed) {
      if (key == LogicalKeyboardKey.escape) {
        onCloseDialog();
        return true;
      }
      if (key == LogicalKeyboardKey.f1) {
        onToggleEditorCentered();
        return true;
      }
      if (key == LogicalKeyboardKey.f2) {
        onToggleSidebar();
        return true;
      }
      if (key == LogicalKeyboardKey.f3) {
        onToggleNotesPanel();
        return true;
      }
      if (key == LogicalKeyboardKey.f4) {
        onToggleImmersiveMode();
        return true;
      }
      if (key == LogicalKeyboardKey.f5) {
        onForceSync();
        return true;
      }
    }

    return false;
  }

  // Editor shortcuts
  static Map<ShortcutActivator, Intent> getEditorShortcuts({
    required VoidCallback onCreateScriptBlock,
    required VoidCallback onFindInEditor,
  }) {
    return {
      const SingleActivator(
            LogicalKeyboardKey.keyD,
            control: true,
            shift: true,
          ):
          const CreateScriptBlockIntent(),
      const SingleActivator(LogicalKeyboardKey.keyF, control: true):
          const FindInEditorIntent(),
    };
  }

  // Common shortcuts for dialogs
  static Map<ShortcutActivator, VoidCallback> getDialogShortcuts({
    required VoidCallback onConfirm,
    required VoidCallback onCancel,
  }) {
    return {
      const SingleActivator(LogicalKeyboardKey.enter): onConfirm,
      const SingleActivator(LogicalKeyboardKey.escape): onCancel,
    };
  }

  // Specific shortcuts for dialogs with text fields
  static Map<ShortcutActivator, VoidCallback> getInputDialogShortcuts({
    required VoidCallback onSubmit,
    VoidCallback? onCancel,
  }) {
    final Map<ShortcutActivator, VoidCallback> shortcuts = {
      const SingleActivator(LogicalKeyboardKey.enter): onSubmit,
    };

    if (onCancel != null) {
      shortcuts[const SingleActivator(LogicalKeyboardKey.escape)] = onCancel;
    }

    return shortcuts;
  }
}

class AppShortcuts extends StatelessWidget {
  final Widget child;
  final Map<ShortcutActivator, VoidCallback> shortcuts;

  const AppShortcuts({super.key, required this.child, required this.shortcuts});

  @override
  Widget build(BuildContext context) {
    return FocusScope(
      autofocus: true,
      canRequestFocus: true,
      child: CallbackShortcuts(bindings: shortcuts, child: child),
    );
  }
}

/// A widget that captures keyboard shortcuts globally, regardless of focus.
/// This ensures shortcuts like Ctrl+N, Ctrl+Shift+N, Ctrl+D, Ctrl+Shift+F
/// work from anywhere in the application.
class GlobalAppShortcuts extends StatefulWidget {
  final Widget child;
  final VoidCallback onCloseDialog;
  final VoidCallback onToggleSidebar;
  final VoidCallback onToggleEditorCentered;
  final VoidCallback onCreateNote;
  final VoidCallback onCreateNotebook;
  final VoidCallback onCreateTodo;
  final VoidCallback onSaveNote;
  final VoidCallback onToggleNotesPanel;
  final VoidCallback onForceSync;
  final VoidCallback onSearch;
  final VoidCallback onToggleImmersiveMode;
  final VoidCallback onGlobalSearch;
  final VoidCallback onCloseTab;
  final VoidCallback onNewTab;
  final VoidCallback onToggleReadMode;

  const GlobalAppShortcuts({
    super.key,
    required this.child,
    required this.onCloseDialog,
    required this.onToggleSidebar,
    required this.onToggleEditorCentered,
    required this.onCreateNote,
    required this.onCreateNotebook,
    required this.onCreateTodo,
    required this.onSaveNote,
    required this.onToggleNotesPanel,
    required this.onForceSync,
    required this.onSearch,
    required this.onToggleImmersiveMode,
    required this.onGlobalSearch,
    required this.onCloseTab,
    required this.onNewTab,
    required this.onToggleReadMode,
  });

  @override
  State<GlobalAppShortcuts> createState() => _GlobalAppShortcutsState();
}

class _GlobalAppShortcutsState extends State<GlobalAppShortcuts> {
  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_handleKeyEvent);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    super.dispose();
  }

  bool _handleKeyEvent(KeyEvent event) {
    return ShortcutsHandler.handleGlobalKeyEvent(
      event,
      onCloseDialog: widget.onCloseDialog,
      onToggleSidebar: widget.onToggleSidebar,
      onToggleEditorCentered: widget.onToggleEditorCentered,
      onCreateNote: widget.onCreateNote,
      onCreateNotebook: widget.onCreateNotebook,
      onCreateTodo: widget.onCreateTodo,
      onSaveNote: widget.onSaveNote,
      onToggleNotesPanel: widget.onToggleNotesPanel,
      onForceSync: widget.onForceSync,
      onSearch: widget.onSearch,
      onToggleImmersiveMode: widget.onToggleImmersiveMode,
      onGlobalSearch: widget.onGlobalSearch,
      onCloseTab: widget.onCloseTab,
      onNewTab: widget.onNewTab,
      onToggleReadMode: widget.onToggleReadMode,
    );
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
