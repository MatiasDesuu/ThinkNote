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
