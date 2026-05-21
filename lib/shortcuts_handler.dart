import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'widgets/Editor/format_handler.dart';

class CreateScriptBlockIntent extends Intent {
  const CreateScriptBlockIntent();
}

class FindInEditorIntent extends Intent {
  const FindInEditorIntent();
}

class ApplyEditorFormatIntent extends Intent {
  final FormatType formatType;

  const ApplyEditorFormatIntent(this.formatType);
}

class InsertEditorLinkIntent extends Intent {
  const InsertEditorLinkIntent();
}

class GlobalSearchIntent extends Intent {
  const GlobalSearchIntent();
}

class ShortcutsHandler {
  static bool get isMacOS => defaultTargetPlatform == TargetPlatform.macOS;

  static String get primaryModifierLabel => isMacOS ? 'Cmd' : 'Ctrl';

  static bool get isPrimaryModifierPressed =>
      isMacOS
          ? HardwareKeyboard.instance.isMetaPressed
          : HardwareKeyboard.instance.isControlPressed;

  static SingleActivator primaryActivator(
    LogicalKeyboardKey key, {
    bool shift = false,
    bool alt = false,
  }) {
    return SingleActivator(
      key,
      control: !isMacOS,
      meta: isMacOS,
      shift: shift,
      alt: alt,
    );
  }

  static String describePrimaryShortcut(
    LogicalKeyboardKey key, {
    bool shift = false,
    bool alt = false,
  }) {
    final parts = <String>[primaryModifierLabel];

    if (shift) {
      parts.add('Shift');
    }

    if (alt) {
      parts.add('Alt');
    }

    parts.add(_describeKey(key));
    return parts.join('+');
  }

  static String? editorFormatShortcutLabel(FormatType formatType) {
    switch (formatType) {
      case FormatType.bold:
        return describePrimaryShortcut(LogicalKeyboardKey.keyB);
      case FormatType.italic:
        return describePrimaryShortcut(LogicalKeyboardKey.keyI);
      case FormatType.strikethrough:
        return describePrimaryShortcut(LogicalKeyboardKey.keyG);
      case FormatType.code:
        return describePrimaryShortcut(LogicalKeyboardKey.keyK, shift: true);
      case FormatType.heading1:
        return describePrimaryShortcut(LogicalKeyboardKey.digit1, alt: true);
      case FormatType.heading2:
        return describePrimaryShortcut(LogicalKeyboardKey.digit2, alt: true);
      case FormatType.heading3:
        return describePrimaryShortcut(LogicalKeyboardKey.digit3, alt: true);
      case FormatType.heading4:
        return describePrimaryShortcut(LogicalKeyboardKey.digit4, alt: true);
      case FormatType.heading5:
        return describePrimaryShortcut(LogicalKeyboardKey.digit5, alt: true);
      case FormatType.numbered:
        return describePrimaryShortcut(
          LogicalKeyboardKey.digit7,
          shift: true,
        );
      case FormatType.bullet:
        return describePrimaryShortcut(LogicalKeyboardKey.digit8, shift: true);
      case FormatType.checkboxUnchecked:
        return describePrimaryShortcut(
          LogicalKeyboardKey.digit9,
          shift: true,
        );
      case FormatType.convertToScript:
        return describePrimaryShortcut(
          LogicalKeyboardKey.keyD,
          shift: true,
        );
      case FormatType.taggedCode:
        return describePrimaryShortcut(LogicalKeyboardKey.keyC, shift: true);
      case FormatType.noteLink:
        return describePrimaryShortcut(LogicalKeyboardKey.keyN, alt: true);
      case FormatType.notebookLink:
        return describePrimaryShortcut(LogicalKeyboardKey.keyO, alt: true);
      case FormatType.link:
        return describePrimaryShortcut(LogicalKeyboardKey.keyK);
      case FormatType.horizontalRule:
        return describePrimaryShortcut(LogicalKeyboardKey.keyH, shift: true);
      case FormatType.url:
        return describePrimaryShortcut(LogicalKeyboardKey.keyF, alt: true);
      default:
        return null;
    }
  }

  static Map<ShortcutActivator, Intent> getEditorFormatShortcuts() {
    return {
      primaryActivator(LogicalKeyboardKey.keyB):
          const ApplyEditorFormatIntent(FormatType.bold),
      primaryActivator(LogicalKeyboardKey.keyI):
          const ApplyEditorFormatIntent(FormatType.italic),
        primaryActivator(LogicalKeyboardKey.keyG):
          const ApplyEditorFormatIntent(FormatType.strikethrough),
      primaryActivator(LogicalKeyboardKey.keyK, shift: true):
          const ApplyEditorFormatIntent(FormatType.code),
      primaryActivator(LogicalKeyboardKey.digit1, alt: true):
          const ApplyEditorFormatIntent(FormatType.heading1),
      primaryActivator(LogicalKeyboardKey.digit2, alt: true):
          const ApplyEditorFormatIntent(FormatType.heading2),
      primaryActivator(LogicalKeyboardKey.digit3, alt: true):
          const ApplyEditorFormatIntent(FormatType.heading3),
      primaryActivator(LogicalKeyboardKey.digit4, alt: true):
          const ApplyEditorFormatIntent(FormatType.heading4),
      primaryActivator(LogicalKeyboardKey.digit5, alt: true):
          const ApplyEditorFormatIntent(FormatType.heading5),
        primaryActivator(LogicalKeyboardKey.digit7, shift: true):
          const ApplyEditorFormatIntent(FormatType.numbered),
      primaryActivator(LogicalKeyboardKey.digit8, shift: true):
          const ApplyEditorFormatIntent(FormatType.bullet),
      primaryActivator(LogicalKeyboardKey.digit9, shift: true):
          const ApplyEditorFormatIntent(FormatType.checkboxUnchecked),
        primaryActivator(LogicalKeyboardKey.keyC, shift: true):
          const ApplyEditorFormatIntent(FormatType.taggedCode),
        primaryActivator(LogicalKeyboardKey.keyN, alt: true):
          const ApplyEditorFormatIntent(FormatType.noteLink),
        primaryActivator(LogicalKeyboardKey.keyO, alt: true):
          const ApplyEditorFormatIntent(FormatType.notebookLink),
        primaryActivator(LogicalKeyboardKey.keyK):
            const InsertEditorLinkIntent(),
        primaryActivator(LogicalKeyboardKey.keyH, shift: true):
          const ApplyEditorFormatIntent(FormatType.horizontalRule),
        // File/folder links map to url format; folder link uses Ctrl+Alt+Shift+F
        primaryActivator(LogicalKeyboardKey.keyF, alt: true):
          const ApplyEditorFormatIntent(FormatType.url),
        primaryActivator(LogicalKeyboardKey.keyF, alt: true, shift: true):
          const ApplyEditorFormatIntent(FormatType.url),
    };
  }

  static String _describeKey(LogicalKeyboardKey key) {
    final label = key.keyLabel;

    if (label.isNotEmpty) {
      return label.toUpperCase();
    }

    final debugName = key.debugName;
    if (debugName != null && debugName.isNotEmpty) {
      return debugName.toUpperCase();
    }

    return key.toString();
  }

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
    required VoidCallback onToggleSplitView,
    required VoidCallback onToggleCalendarPanel,
    required VoidCallback onToggleFavoritesPanel,
    required VoidCallback onToggleTrashPanel,
    required VoidCallback onToggleTemplatesPanel,
  }) {
    return {
      const SingleActivator(LogicalKeyboardKey.escape): onCloseDialog,
      SingleActivator(LogicalKeyboardKey.f2, includeRepeats: false):
          onToggleSidebar,
      const SingleActivator(LogicalKeyboardKey.f3): onToggleNotesPanel,
      const SingleActivator(LogicalKeyboardKey.f1): onToggleEditorCentered,
        primaryActivator(LogicalKeyboardKey.keyN): onCreateNote,
        primaryActivator(LogicalKeyboardKey.keyN, shift: true): onCreateNotebook,
        primaryActivator(LogicalKeyboardKey.keyT): onNewTab,
        primaryActivator(LogicalKeyboardKey.keyD): onCreateTodo,
        primaryActivator(LogicalKeyboardKey.keyT, shift: true):
          onToggleTemplatesPanel,
        primaryActivator(LogicalKeyboardKey.keyS): onSaveNote,
        primaryActivator(LogicalKeyboardKey.keyF): onSearch,
      const SingleActivator(LogicalKeyboardKey.f4): onToggleImmersiveMode,
      const SingleActivator(LogicalKeyboardKey.f5): onForceSync,
      const SingleActivator(LogicalKeyboardKey.f6): onToggleCalendarPanel,
      const SingleActivator(LogicalKeyboardKey.f7): onToggleFavoritesPanel,
      const SingleActivator(LogicalKeyboardKey.f8): onToggleTrashPanel,
      const SingleActivator(LogicalKeyboardKey.f9): onGlobalSearch,
      primaryActivator(LogicalKeyboardKey.keyF, shift: true): onGlobalSearch,
      primaryActivator(LogicalKeyboardKey.keyW): onCloseTab,
      primaryActivator(LogicalKeyboardKey.keyP): onToggleReadMode,
      primaryActivator(LogicalKeyboardKey.keyP, shift: true): onToggleSplitView,
    };
  }

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
    required VoidCallback onToggleSplitView,
    required VoidCallback onToggleCalendarPanel,
    required VoidCallback onToggleFavoritesPanel,
    required VoidCallback onToggleTrashPanel,
    required VoidCallback onToggleTemplatesPanel,
  }) {
    if (event is! KeyDownEvent) return false;

    final bool isPrimaryModifierPressed =
      ShortcutsHandler.isPrimaryModifierPressed;
    final bool isShiftPressed = HardwareKeyboard.instance.isShiftPressed;
    final bool isAltPressed = HardwareKeyboard.instance.isAltPressed;
    final LogicalKeyboardKey key = event.logicalKey;

    if (isPrimaryModifierPressed && isShiftPressed && !isAltPressed) {
      if (key == LogicalKeyboardKey.keyN) {
        onCreateNotebook();
        return true;
      }
      if (key == LogicalKeyboardKey.keyF) {
        onGlobalSearch();
        return true;
      }
      if (key == LogicalKeyboardKey.keyP) {
        onToggleSplitView();
        return true;
      }
      if (key == LogicalKeyboardKey.keyT) {
        onToggleTemplatesPanel();
        return true;
      }
    }

    if (isPrimaryModifierPressed && !isShiftPressed && !isAltPressed) {
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

      if (key == LogicalKeyboardKey.keyW) {
        onCloseTab();
        return true;
      }
      if (key == LogicalKeyboardKey.keyP) {
        onToggleReadMode();
        return true;
      }
    }

    if (!isPrimaryModifierPressed && !isShiftPressed && !isAltPressed) {
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
      if (key == LogicalKeyboardKey.f6) {
        onToggleCalendarPanel();
        return true;
      }
      if (key == LogicalKeyboardKey.f7) {
        onToggleFavoritesPanel();
        return true;
      }
      if (key == LogicalKeyboardKey.f8) {
        onToggleTrashPanel();
        return true;
      }
      if (key == LogicalKeyboardKey.f9) {
        onGlobalSearch();
        return true;
      }
    }

    return false;
  }

  static Map<ShortcutActivator, Intent> getEditorShortcuts({
    required VoidCallback onCreateScriptBlock,
    required VoidCallback onFindInEditor,
  }) {
    return {
      primaryActivator(LogicalKeyboardKey.keyD, shift: true):
          const CreateScriptBlockIntent(),
      primaryActivator(LogicalKeyboardKey.keyF): const FindInEditorIntent(),
    };
  }

  static Map<ShortcutActivator, VoidCallback> getDialogShortcuts({
    required VoidCallback onConfirm,
    required VoidCallback onCancel,
  }) {
    return {
      const SingleActivator(LogicalKeyboardKey.enter): onConfirm,
      const SingleActivator(LogicalKeyboardKey.numpadEnter): onConfirm,
      const SingleActivator(LogicalKeyboardKey.escape): onCancel,
    };
  }

  static Map<ShortcutActivator, VoidCallback> getInputDialogShortcuts({
    required VoidCallback onSubmit,
    VoidCallback? onCancel,
  }) {
    final Map<ShortcutActivator, VoidCallback> shortcuts = {
      const SingleActivator(LogicalKeyboardKey.enter): onSubmit,
      const SingleActivator(LogicalKeyboardKey.numpadEnter): onSubmit,
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
  final VoidCallback onToggleSplitView;
  final VoidCallback onToggleCalendarPanel;
  final VoidCallback onToggleFavoritesPanel;
  final VoidCallback onToggleTrashPanel;
  final VoidCallback onToggleTemplatesPanel;

  final bool Function()? isEnabled;

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
    required this.onToggleSplitView,
    required this.onToggleCalendarPanel,
    required this.onToggleFavoritesPanel,
    required this.onToggleTrashPanel,
    required this.onToggleTemplatesPanel,
    this.isEnabled,
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
    final modalRoute = ModalRoute.of(context);
    final isMainRouteActive = modalRoute?.isCurrent ?? false;

    final shouldHandle = widget.isEnabled?.call() ?? isMainRouteActive;

    if (!shouldHandle) {
      return false;
    }

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
      onToggleSplitView: widget.onToggleSplitView,
      onToggleCalendarPanel: widget.onToggleCalendarPanel,
      onToggleFavoritesPanel: widget.onToggleFavoritesPanel,
      onToggleTrashPanel: widget.onToggleTrashPanel,
      onToggleTemplatesPanel: widget.onToggleTemplatesPanel,
    );
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
