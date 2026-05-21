import 'dart:async';

import 'package:flutter/material.dart';

import '../../Settings/editor_settings_panel.dart';
import '../../database/models/note.dart';
import '../../database/models/notebook.dart';
import 'notebooks_panel.dart';
import 'notes_panel.dart';
import 'resizable_panel.dart';

class UnifiedNotebooksNotesPanel extends StatefulWidget {
  final FocusNode appFocusNode;
  final Notebook? selectedNotebook;
  final String? selectedTag;
  final Note? selectedNote;
  final bool isImmersiveMode;
  final VoidCallback? onRootSelected;
  final ValueChanged<bool>? onExpandedChanged;
  final ValueChanged<bool>? onModeChanged;
  final Function(Notebook) onNotebookSelected;
  final Function(String tag)? onTagSelected;
  final VoidCallback? onNotebookTrashUpdated;
  final VoidCallback? onNotebookExpansionChanged;
  final Function(Notebook)? onNotebookDeleted;
  final Function(Note) onNoteSelected;
  final Function(Note)? onNoteSelectedFromPanel;
  final Function(Note)? onNoteOpenInNewTab;
  final Function(Note)? onLocateInCalendar;
  final VoidCallback? onNotesTrashUpdated;
  final VoidCallback? onNotesSortChanged;
  final Function(Note)? onNoteDeleted;

  const UnifiedNotebooksNotesPanel({
    super.key,
    required this.appFocusNode,
    required this.selectedNotebook,
    required this.selectedTag,
    required this.selectedNote,
    required this.isImmersiveMode,
    this.onRootSelected,
    this.onExpandedChanged,
    this.onModeChanged,
    required this.onNotebookSelected,
    this.onTagSelected,
    this.onNotebookTrashUpdated,
    this.onNotebookExpansionChanged,
    this.onNotebookDeleted,
    required this.onNoteSelected,
    this.onNoteSelectedFromPanel,
    this.onNoteOpenInNewTab,
    this.onLocateInCalendar,
    this.onNotesTrashUpdated,
    this.onNotesSortChanged,
    this.onNoteDeleted,
  });

  @override
  State<UnifiedNotebooksNotesPanel> createState() =>
      UnifiedNotebooksNotesPanelState();
}

class UnifiedNotebooksNotesPanelState
    extends State<UnifiedNotebooksNotesPanel> {
  final GlobalKey<ResizablePanelState> _panelKey =
      GlobalKey<ResizablePanelState>();
  final GlobalKey<DatabaseSidebarState> _databaseSidebarKey =
      GlobalKey<DatabaseSidebarState>();
  final GlobalKey<NotesPanelState> _notesPanelKey =
      GlobalKey<NotesPanelState>();

  bool _isShowingNotes = false;
  bool _useMiddleAndDoubleClickToOpenUnifiedNotesPanel =
      EditorSettingsCache.instance
          .useMiddleAndDoubleClickToOpenUnifiedNotesPanel;
  StreamSubscription<bool>? _unifiedPanelClicksSubscription;

  DatabaseSidebarState? get databaseSidebarState =>
      _databaseSidebarKey.currentState;
  NotesPanelState? get notesPanelState => _notesPanelKey.currentState;
  ResizablePanelState? get panelState => _panelKey.currentState;
  bool get isShowingNotes => _isShowingNotes;
  bool get isExpanded => _panelKey.currentState?.isExpanded ?? true;
  bool get shouldRenderInline =>
      _panelKey.currentState?.shouldRenderInline ?? true;

  void _openNotesModeForNotebook(Notebook notebook) {
    widget.onNotebookSelected(notebook);
    showNotesMode();
  }

  @override
  void initState() {
    super.initState();
    _unifiedPanelClicksSubscription?.cancel();
    _unifiedPanelClicksSubscription = EditorSettingsEvents
        .useMiddleAndDoubleClickToOpenUnifiedNotesPanelStream
        .listen((value) {
          if (mounted) {
            setState(() {
              _useMiddleAndDoubleClickToOpenUnifiedNotesPanel = value;
            });
          }
        });
  }

  @override
  void dispose() {
    _unifiedPanelClicksSubscription?.cancel();
    super.dispose();
  }

  void showNotebooksMode() {
    if (!_isShowingNotes) return;
    setState(() {
      _isShowingNotes = false;
    });
    widget.onModeChanged?.call(false);
  }

  void showNotesMode() {
    if (_isShowingNotes) return;
    setState(() {
      _isShowingNotes = true;
    });
    widget.onModeChanged?.call(true);
  }

  void toggleMode() {
    setState(() {
      _isShowingNotes = !_isShowingNotes;
    });
    widget.onModeChanged?.call(_isShowingNotes);
  }

  void togglePanel() => _panelKey.currentState?.togglePanel();
  void expandPanel() => _panelKey.currentState?.expandPanel();
  void collapsePanel() => _panelKey.currentState?.collapsePanel();
  void showOverlayPreview() => _panelKey.currentState?.showOverlayPreview();
  void hideOverlayPreview() => _panelKey.currentState?.hideOverlayPreview();

  @override
  Widget build(BuildContext context) {
    return ResizablePanel(
      key: _panelKey,
      minWidth: 200,
      maxWidth: 400,
      appFocusNode: widget.appFocusNode,
      title: _isShowingNotes ? 'Notes' : 'Notebooks',
      preferencesKey: 'unified_notebooks_notes_panel',
      headerLeading: _UnifiedPanelModeButton(
        showingNotes: _isShowingNotes,
        onPressed: toggleMode,
      ),
      headerLeadingExclusionWidth: 44,
      showLeftSeparator: !widget.isImmersiveMode,
      onExpandedChanged: widget.onExpandedChanged,
      onTitleTap: _isShowingNotes ? null : widget.onRootSelected,
      trailing: Builder(
        builder: (context) {
          if (_isShowingNotes) {
            final notesPanel = _notesPanelKey.currentState;
            if (notesPanel == null) {
              return const SizedBox.shrink();
            }
            return notesPanel.buildTrailingButton();
          }

          final databaseSidebar = _databaseSidebarKey.currentState;
          if (databaseSidebar == null) {
            return const SizedBox.shrink();
          }
          return databaseSidebar.buildTrailingButton();
        },
      ),
      child: IndexedStack(
        index: _isShowingNotes ? 1 : 0,
        children: [
          DatabaseSidebar(
            key: _databaseSidebarKey,
            selectedNotebook: widget.selectedNotebook,
            onNotebookSelected: widget.onNotebookSelected,
            onNotebookMiddleClick:
                _useMiddleAndDoubleClickToOpenUnifiedNotesPanel
                    ? _openNotesModeForNotebook
                    : null,
            onNotebookDoubleClick:
                _useMiddleAndDoubleClickToOpenUnifiedNotesPanel
                    ? _openNotesModeForNotebook
                    : null,
            onTrashUpdated: widget.onNotebookTrashUpdated,
            onExpansionChanged: widget.onNotebookExpansionChanged,
            onNotebookDeleted: widget.onNotebookDeleted,
            onTagSelected: (tag) {
              showNotesMode();
              widget.onTagSelected?.call(tag);
            },
          ),
          NotesPanel(
            key: _notesPanelKey,
            selectedNotebookId: widget.selectedNotebook?.id,
            filterByTag: widget.selectedTag,
            selectedNote: widget.selectedNote,
            onNoteSelected: widget.onNoteSelected,
            onNoteSelectedFromPanel: widget.onNoteSelectedFromPanel,
            onNoteOpenInNewTab: widget.onNoteOpenInNewTab,
            onLocateInCalendar: widget.onLocateInCalendar,
            onTrashUpdated: widget.onNotesTrashUpdated,
            onSortChanged: widget.onNotesSortChanged,
            onNoteDeleted: widget.onNoteDeleted,
          ),
        ],
      ),
    );
  }
}

class _UnifiedPanelModeButton extends StatefulWidget {
  final bool showingNotes;
  final VoidCallback onPressed;

  const _UnifiedPanelModeButton({
    required this.showingNotes,
    required this.onPressed,
  });

  @override
  State<_UnifiedPanelModeButton> createState() => _UnifiedPanelModeButtonState();
}

class _UnifiedPanelModeButtonState extends State<_UnifiedPanelModeButton> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final icon =
        _isHovering
            ? Icons.swap_horiz_rounded
            : widget.showingNotes
            ? Icons.description_rounded
            : Icons.folder_rounded;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: SizedBox(
        width: 20,
        height: 28,
        child: IconButton(
          onPressed: widget.onPressed,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints.tightFor(width: 20, height: 28),
          iconSize: 20,
          splashRadius: 18,
          icon: AnimatedSwitcher(
            duration: const Duration(milliseconds: 150),
            transitionBuilder: (child, animation) {
              return FadeTransition(
                opacity: animation,
                child: ScaleTransition(scale: animation, child: child),
              );
            },
            child: Icon(
              icon,
              key: ValueKey<IconData>(icon),
              size: 20,
              color: colorScheme.primary,
            ),
          ),
        ),
      ),
    );
  }
}
