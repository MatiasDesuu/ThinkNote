import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../database/models/note.dart';
import '../../database/repositories/note_repository.dart';
import '../../database/database_helper.dart';
import '../../Settings/editor_settings_panel.dart';
import '../custom_snackbar.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import '../context_menu.dart';
import '../../services/tags_service.dart';

enum SortMode { order, date, completion }

class NotesPanel extends StatefulWidget {
  final int? selectedNotebookId;
  final Note? selectedNote;
  final Function(Note) onNoteSelected;
  final Function(Note)? onNoteOpenInNewTab;
  final Function(Note)? onNoteSelectedFromPanel;
  final VoidCallback? onTrashUpdated;
  final VoidCallback? onTogglePanel;
  final VoidCallback? onSortChanged;
  final Function(Note)? onNoteDeleted;
  final String? filterByTag;

  const NotesPanel({
    super.key,
    this.selectedNotebookId,
    this.selectedNote,
    required this.onNoteSelected,
    this.onNoteOpenInNewTab,
    this.onNoteSelectedFromPanel,
    this.onTrashUpdated,
    this.onTogglePanel,
    this.onSortChanged,
    this.onNoteDeleted,
    this.filterByTag,
  });

  @override
  State<NotesPanel> createState() => NotesPanelState();
}

class NotesPanelState extends State<NotesPanel> {
  late final NoteRepository _noteRepository;
  List<Note> _notes = [];
  bool _isLoading = true;
  String? _errorMessage;
  bool _isExpanded = true;
  SortMode _sortMode = SortMode.order;
  bool _completionSubSortByDate = false;
  String get _sortPreferenceKey =>
      'notes_sort_mode_${widget.selectedNotebookId ?? 0}';
  String get _completionSubSortPreferenceKey =>
      'notes_completion_sub_sort_by_date_${widget.selectedNotebookId ?? 0}';
  bool _showNoteIcons = true;
  StreamSubscription<bool>? _showNoteIconsSubscription;

  // Selection state - using a dedicated approach similar to Obsidian/Joplin
  final Set<int> _selectedNoteIds = {};
  bool get hasSelection => _selectedNoteIds.isNotEmpty;
  int get selectionCount => _selectedNoteIds.length;

  // Anchor note for shift-selection (the starting point of a range selection)
  int? _selectionAnchorId;
  // Last clicked note (for tracking the most recent selection action)
  int? _lastClickedNoteId;

  bool _isProcessingAction = false;

  final Map<int, bool> _pendingCompletionChanges = {};

  Timer? _completionDebounceTimer;

  bool _isReloading = false;

  bool _isContextMenuOpen = false;

  // Drag and drop state
  int? _dragTargetIndex;
  bool _dragTargetIsAbove = false;
  bool _isDragging = false;

  // Deferred selection state - for handling click vs drag on selected notes
  // When clicking a note that's already selected (without modifiers), we defer
  // the single-selection until we know it wasn't a drag operation
  int? _pendingDeselectionNoteId;

  // Element bounds tracking
  final Map<int, Rect> _elementBounds = {};

  // Visual position tracking
  double? _currentVisualLineY;

  bool get sortByDate => _sortMode == SortMode.date;
  bool get isExpanded => _isExpanded;

  IconData _getSortIcon() {
    switch (_sortMode) {
      case SortMode.order:
        return Icons.sort_by_alpha_rounded;
      case SortMode.date:
        return Icons.hourglass_bottom_rounded;
      case SortMode.completion:
        return Icons.check_circle_outline;
    }
  }

  Widget buildTrailingButton() {
    if (_sortMode == SortMode.completion) {
      return Row(
        key: ValueKey<bool>(_completionSubSortByDate),
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              transitionBuilder: (Widget child, Animation<double> animation) {
                return ScaleTransition(
                  scale: animation,
                  child: FadeTransition(opacity: animation, child: child),
                );
              },
              child: Icon(
                _completionSubSortByDate
                    ? Icons.access_time
                    : Icons.sort_by_alpha,
                size: 16,
                key: ValueKey<bool>(_completionSubSortByDate),
              ),
            ),
            onPressed: toggleCompletionSubSort,
          ),
          IconButton(
            icon: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              transitionBuilder: (Widget child, Animation<double> animation) {
                return ScaleTransition(
                  scale: animation,
                  child: FadeTransition(opacity: animation, child: child),
                );
              },
              child: Icon(
                _getSortIcon(),
                size: 16,
                key: ValueKey<SortMode>(_sortMode),
              ),
            ),
            onPressed: toggleSortOrder,
          ),
        ],
      );
    } else {
      return IconButton(
        icon: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          transitionBuilder: (Widget child, Animation<double> animation) {
            return ScaleTransition(
              scale: animation,
              child: FadeTransition(opacity: animation, child: child),
            );
          },
          child: Icon(
            _getSortIcon(),
            size: 16,
            key: ValueKey<SortMode>(_sortMode),
          ),
        ),
        onPressed: toggleSortOrder,
      );
    }
  }

  /// Handles note selection with Ctrl and Shift modifiers
  /// Implements a professional selection model similar to Obsidian/Joplin:
  /// - Click: Select single note, clear others
  /// - Ctrl+Click: Toggle note in selection (add/remove)
  /// - Shift+Click: Select range from anchor to clicked note
  void _handleNoteSelection(
    Note note,
    bool isCtrlPressed,
    bool isShiftPressed,
  ) {
    if (note.id == null) return;

    setState(() {
      if (isShiftPressed) {
        // Shift+Click: Range selection from anchor to current note
        _handleShiftSelection(note);
      } else if (isCtrlPressed) {
        // Ctrl+Click: Toggle individual note in selection
        _handleCtrlSelection(note);
      } else {
        // Normal click: Single selection, clear all others
        _handleSingleSelection(note);
      }
    });

    widget.onNoteSelected(note);
  }

  /// Handles Shift+Click range selection
  void _handleShiftSelection(Note note) {
    // If no anchor exists, use the currently selected note or the first selected note
    if (_selectionAnchorId == null) {
      if (widget.selectedNote != null) {
        _selectionAnchorId = widget.selectedNote!.id;
      } else if (_selectedNoteIds.isNotEmpty) {
        _selectionAnchorId = _selectedNoteIds.first;
      } else {
        // No anchor available, treat as single selection
        _handleSingleSelection(note);
        return;
      }
    }

    final anchorIndex = _notes.indexWhere((n) => n.id == _selectionAnchorId);
    final targetIndex = _notes.indexWhere((n) => n.id == note.id);

    // If anchor note no longer exists, use the first note as anchor
    if (anchorIndex == -1) {
      if (_notes.isNotEmpty) {
        _selectionAnchorId = _notes.first.id;
        _handleShiftSelection(note); // Retry with new anchor
      } else {
        _handleSingleSelection(note);
      }
      return;
    }

    if (targetIndex == -1) return;

    // Clear current selection and select the range
    _selectedNoteIds.clear();

    final start = anchorIndex <= targetIndex ? anchorIndex : targetIndex;
    final end = anchorIndex <= targetIndex ? targetIndex : anchorIndex;

    for (int i = start; i <= end; i++) {
      final noteId = _notes[i].id;
      if (noteId != null) {
        _selectedNoteIds.add(noteId);
      }
    }

    _lastClickedNoteId = note.id;
    // Keep anchor unchanged for consecutive shift-clicks
  }

  /// Handles Ctrl+Click toggle selection
  void _handleCtrlSelection(Note note) {
    // If starting multi-selection and nothing is selected yet,
    // include the currently visible/active note
    if (_selectedNoteIds.isEmpty && widget.selectedNote != null) {
      final currentNoteId = widget.selectedNote!.id;
      if (currentNoteId != null) {
        _selectedNoteIds.add(currentNoteId);
        _selectionAnchorId = currentNoteId;
      }
    }

    final noteId = note.id!;
    if (_selectedNoteIds.contains(noteId)) {
      _selectedNoteIds.remove(noteId);
      // If we removed the anchor, update it to another selected note
      if (_selectionAnchorId == noteId) {
        _selectionAnchorId =
            _selectedNoteIds.isNotEmpty ? _selectedNoteIds.first : null;
      }
    } else {
      _selectedNoteIds.add(noteId);
    }

    _lastClickedNoteId = note.id;
    // Update anchor to clicked note for future shift-selections
    _selectionAnchorId = note.id;
  }

  /// Handles normal single click selection
  void _handleSingleSelection(Note note) {
    _selectedNoteIds.clear();
    _lastClickedNoteId = note.id;
    _selectionAnchorId = note.id; // Set anchor for future shift-selections
  }

  /// Clears all selection state
  void _clearSelection() {
    setState(() {
      _selectedNoteIds.clear();
      _selectionAnchorId = null;
      _lastClickedNoteId = null;
    });
    _pendingCompletionChanges.clear();
  }

  /// Gets an immutable copy of currently selected note IDs
  /// This is important for async operations to prevent race conditions
  List<int> _getSelectedNoteIdsCopy() {
    return List<int>.unmodifiable(_selectedNoteIds.toList());
  }

  /// Converts selected notes to tasks or regular notes
  /// Uses immutable copy of selection to prevent race conditions
  Future<void> _convertSelectedNotes({required bool toTask}) async {
    if (_isProcessingAction) return;
    _isProcessingAction = true;

    // Capture selection state BEFORE any async operations
    final noteIdsToConvert = _getSelectedNoteIdsCopy();

    if (noteIdsToConvert.isEmpty) {
      _isProcessingAction = false;
      _isContextMenuOpen = false;
      return;
    }

    try {
      for (final noteId in noteIdsToConvert) {
        try {
          final note = await _noteRepository.getNote(noteId);
          if (note != null) {
            await _noteRepository.updateNote(
              note.copyWith(isTask: toTask, isCompleted: false),
            );
          }
        } catch (e) {
          print('Error converting note $noteId: $e');
        }
      }

      if (mounted) {
        _loadNotes();
      }
    } catch (e) {
      if (mounted) {
        CustomSnackbar.show(
          context: context,
          message: 'Error converting notes: ${e.toString()}',
          type: CustomSnackbarType.error,
        );
      }
    } finally {
      _isProcessingAction = false;
      _isContextMenuOpen = false;
    }
  }

  void _toggleNoteCompletion(int noteId) {
    final currentNoteIndex = _notes.indexWhere((n) => n.id == noteId);
    if (currentNoteIndex == -1) return;

    final currentNote = _notes[currentNoteIndex];

    bool currentState = currentNote.isCompleted;
    if (_pendingCompletionChanges.containsKey(noteId)) {
      currentState = _pendingCompletionChanges[noteId]!;
    }

    final newCompletedState = !currentState;

    _pendingCompletionChanges[noteId] = newCompletedState;

    setState(() {
      _notes[currentNoteIndex] = currentNote.copyWith(
        isCompleted: newCompletedState,
      );
    });

    _completionDebounceTimer?.cancel();

    _completionDebounceTimer = Timer(const Duration(milliseconds: 500), () {
      _processPendingCompletionChanges();
    });
  }

  Future<void> _processPendingCompletionChanges() async {
    if (_pendingCompletionChanges.isEmpty) return;

    final changesToProcess = Map<int, bool>.from(_pendingCompletionChanges);

    _pendingCompletionChanges.clear();

    try {
      await Future.wait(
        changesToProcess.entries.map((entry) async {
          final noteId = entry.key;
          final newState = entry.value;

          await _noteRepository.toggleNoteCompletion(noteId, newState);
        }),
      );
    } catch (e) {
      setState(() {
        for (final entry in changesToProcess.entries) {
          final noteId = entry.key;
          final newState = entry.value;

          final index = _notes.indexWhere((n) => n.id == noteId);
          if (index != -1) {
            _notes[index] = _notes[index].copyWith(isCompleted: !newState);
          }
        }
      });

      if (mounted) {
        CustomSnackbar.show(
          context: context,
          message: 'Error updating notes: ${e.toString()}',
          type: CustomSnackbarType.error,
        );
      }
    }
  }

  /// Deletes all selected notes safely
  /// Uses immutable copy of selection to prevent race conditions
  Future<void> _deleteSelectedNotes() async {
    if (_isProcessingAction) return;
    _isProcessingAction = true;

    // Capture selection state BEFORE any async operations
    final noteIdsToDelete = _getSelectedNoteIdsCopy();

    if (noteIdsToDelete.isEmpty) {
      _isProcessingAction = false;
      _isContextMenuOpen = false;
      return;
    }

    // Clear selection immediately for responsive UI
    _clearSelection();

    final List<Note> deletedNotes = [];

    try {
      // Process deletions sequentially to avoid race conditions
      for (final noteId in noteIdsToDelete) {
        try {
          final note = await _noteRepository.getNote(noteId);
          if (note != null) {
            await _noteRepository.deleteNote(noteId);
            deletedNotes.add(note);
          }
        } catch (e) {
          print('Error deleting note $noteId: $e');
        }
      }

      // Notify about deleted notes
      for (final note in deletedNotes) {
        widget.onNoteDeleted?.call(note);
      }

      if (mounted) {
        widget.onTrashUpdated?.call();
      }
    } catch (e) {
      if (mounted) {
        CustomSnackbar.show(
          context: context,
          message: 'Error deleting notes: ${e.toString()}',
          type: CustomSnackbarType.error,
        );
      }
    } finally {
      _isProcessingAction = false;
      _isContextMenuOpen = false;
    }
  }

  void _showMultiSelectionMenu(BuildContext context, Offset position) {
    if (_isContextMenuOpen) return;
    _isContextMenuOpen = true;

    ContextMenuOverlay.show(
      context: context,
      tapPosition: position,
      items: [
        if (_selectedNoteIds.length == 1)
          ContextMenuItem(
            icon: Icons.edit_rounded,
            label: 'Rename Note',
            onTap: () {
              _noteRepository
                  .getNote(_selectedNoteIds.first)
                  .then((note) {
                    if (note != null && mounted) {
                      _showRenameDialog(note);
                    }
                  })
                  .catchError((e) {
                    if (mounted) {
                      CustomSnackbar.show(
                        context: context,
                        message: 'Error loading note: ${e.toString()}',
                        type: CustomSnackbarType.error,
                      );
                    }
                  })
                  .whenComplete(() {
                    _isContextMenuOpen = false;
                  });
            },
          ),
        ContextMenuItem(
          icon: Icons.check_circle_outline_rounded,
          label: 'Convert Selected to Todo',
          onTap: () => _convertSelectedNotes(toTask: true),
        ),
        ContextMenuItem(
          icon: Icons.description_outlined,
          label: 'Convert Selected to Note',
          onTap: () => _convertSelectedNotes(toTask: false),
        ),
        ContextMenuItem(
          icon: Icons.delete_rounded,
          label: 'Move Selected to Trash',
          iconColor: Theme.of(context).colorScheme.error,
          onTap: _deleteSelectedNotes,
        ),
      ],
      onOutsideTap: () {
        _isContextMenuOpen = false;
      },
    );
  }

  @override
  void initState() {
    super.initState();
    _initializeRepository();
    _loadExpandedState();
    _loadIconSettings();
    _setupIconSettingsListener();
  }

  @override
  void dispose() {
    _showNoteIconsSubscription?.cancel();
    _completionDebounceTimer?.cancel();
    _isContextMenuOpen = false;
    _isProcessingAction = false;
    super.dispose();
  }

  Future<void> _loadIconSettings() async {
    final showIcons = await EditorSettings.getShowNoteIcons();
    if (mounted) {
      setState(() {
        _showNoteIcons = showIcons;
      });
    }
  }

  void _setupIconSettingsListener() {
    _showNoteIconsSubscription?.cancel();
    _showNoteIconsSubscription = EditorSettingsEvents.showNoteIconsStream
        .listen((show) {
          if (mounted) {
            setState(() {
              _showNoteIcons = show;
            });
          }
        });
  }

  void reloadSidebar() {
    if (mounted) {
      _loadNotes();
    }
  }

  /// Selects a specific note in the panel after a notebook change
  void selectNoteAfterNotebookChange(Note note) {
    if (mounted) {
      // Reload sidebar first to load notes from the new notebook
      _loadNotes().then((_) {
        // After loading, trigger the note selection
        if (mounted) {
          widget.onNoteSelected(note);
        }
      });
    }
  }

  Future<void> _loadExpandedState() async {
    if (!mounted) return;
    setState(() {
      _isExpanded = true;
    });
    await _saveExpandedState(true);
  }

  Future<void> _saveExpandedState(bool isExpanded) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notes_panel_expanded', isExpanded);
  }

  void togglePanel() {
    setState(() {
      _isExpanded = !_isExpanded;
    });
    _saveExpandedState(_isExpanded);
    widget.onTogglePanel?.call();
  }

  void collapsePanel() {
    if (!_isExpanded) return;

    setState(() {
      _isExpanded = false;
    });
    _saveExpandedState(_isExpanded);
    widget.onTogglePanel?.call();
  }

  void expandPanel() {
    if (_isExpanded) return;

    setState(() {
      _isExpanded = true;
    });
    _saveExpandedState(_isExpanded);
    widget.onTogglePanel?.call();
  }

  Future<void> _loadSortPreference() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    final sortModeString = prefs.getString(_sortPreferenceKey) ?? 'order';
    setState(() {
      _sortMode = SortMode.values.firstWhere(
        (mode) => mode.name == sortModeString,
        orElse: () => SortMode.order,
      );
    });
  }

  Future<void> _saveSortPreference() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sortPreferenceKey, _sortMode.name);
  }

  Future<void> _loadCompletionSubSortPreference() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _completionSubSortByDate =
          prefs.getBool(_completionSubSortPreferenceKey) ?? false;
    });
  }

  Future<void> _saveCompletionSubSortPreference() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(
      _completionSubSortPreferenceKey,
      _completionSubSortByDate,
    );
  }

  Future<void> toggleSortOrder() async {
    setState(() {
      final modes = SortMode.values;
      final currentIndex = modes.indexOf(_sortMode);
      _sortMode = modes[(currentIndex + 1) % modes.length];
    });
    await _saveSortPreference();
    await _loadNotes();
    widget.onSortChanged?.call();
  }

  Future<void> toggleCompletionSubSort() async {
    setState(() {
      _completionSubSortByDate = !_completionSubSortByDate;
    });
    await _saveCompletionSubSortPreference();
    await _loadNotes();
    widget.onSortChanged?.call();
  }

  Future<void> _initializeRepository() async {
    try {
      final dbHelper = DatabaseHelper();
      await dbHelper.database;
      _noteRepository = NoteRepository(dbHelper);
      await Future.wait([
        _loadSortPreference(),
        _loadCompletionSubSortPreference(),
      ]);
      await _loadNotes();
    } catch (e) {
      print('Error initializing repository: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Error initializing database';
        });
      }
    }
  }

  void updateNoteTitle(Note updatedNote) {
    if (!mounted) return;

    setState(() {
      final index = _notes.indexWhere((note) => note.id == updatedNote.id);
      if (index != -1) {
        _notes[index] = updatedNote;
      }
    });
  }

  Future<void> _loadPreferencesAndNotes() async {
    await Future.wait([
      _loadSortPreference(),
      _loadCompletionSubSortPreference(),
    ]);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onSortChanged?.call();
    });
    await _loadNotes();
  }

  Future<void> _loadNotes() async {
    if (!mounted || _isReloading) return;

    final currentSelection = Set<int>.from(_selectedNoteIds);

    _isReloading = true;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      List<Note> notes;

      // If filtering by tag, get all notes with that tag
      if (widget.filterByTag != null && widget.filterByTag!.isNotEmpty) {
        notes = await TagsService().getNotesByTag(widget.filterByTag!);
      } else {
        // Otherwise, get notes by notebook
        notes = await _noteRepository.getNotesByNotebookId(
          widget.selectedNotebookId ?? 0,
        );
      }

      if (!mounted) return;

      switch (_sortMode) {
        case SortMode.date:
          notes.sort((a, b) {
            if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
            return b.createdAt.compareTo(a.createdAt);
          });
          break;
        case SortMode.order:
          notes.sort((a, b) {
            if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
            return a.orderIndex.compareTo(b.orderIndex);
          });
          break;
        case SortMode.completion:
          notes.sort((a, b) {
            if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
            if (a.isCompleted == b.isCompleted) {
              if (_completionSubSortByDate) {
                return b.createdAt.compareTo(a.createdAt);
              } else {
                return a.title.compareTo(b.title);
              }
            } else {
              return a.isCompleted ? 1 : -1;
            }
          });
          break;
      }

      setState(() {
        _notes = notes;
        _isLoading = false;

        // Preserve selection state - only keep IDs that still exist
        _selectedNoteIds.clear();
        for (final noteId in currentSelection) {
          if (notes.any((note) => note.id == noteId)) {
            _selectedNoteIds.add(noteId);
          }
        }

        // Preserve anchor if it still exists
        if (_selectionAnchorId != null &&
            !notes.any((note) => note.id == _selectionAnchorId)) {
          _selectionAnchorId =
              _selectedNoteIds.isNotEmpty ? _selectedNoteIds.first : null;
        }

        // Preserve last clicked if it still exists
        if (_lastClickedNoteId != null &&
            !notes.any((note) => note.id == _lastClickedNoteId)) {
          _lastClickedNoteId = null;
        }
      });
      _isReloading = false;
    } catch (e) {
      print('Error loading notes: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Error loading notes: ${e.toString()}';
        });
      }
      _isReloading = false;
    }
  }

  void _showContextMenu(BuildContext context, Offset tapPosition, Note note) {
    if (_isContextMenuOpen) return;
    _isContextMenuOpen = true;

    final List<ContextMenuItem> menuItems = [
      ContextMenuItem(
        icon: Icons.edit_rounded,
        label: 'Rename Note',
        onTap: () => _showRenameDialog(note),
      ),
    ];

    // Add "Open in New Tab" option if callback is provided
    if (widget.onNoteOpenInNewTab != null) {
      menuItems.add(
        ContextMenuItem(
          icon: Icons.open_in_new_rounded,
          label: 'Open in New Tab',
          onTap: () {
            widget.onNoteOpenInNewTab!(note);
            _isContextMenuOpen = false;
          },
        ),
      );
    }

    // Add Pin/Unpin option
    menuItems.add(
      ContextMenuItem(
        icon: note.isPinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
        label: note.isPinned ? 'Unpin' : 'Pin to top',
        onTap: () {
          if (_isProcessingAction) return;
          _isProcessingAction = true;

          _noteRepository
              .updateNote(note.copyWith(isPinned: !note.isPinned))
              .then((_) {
                if (mounted) {
                  _loadNotes();
                }
              })
              .catchError((e) {
                if (mounted) {
                  CustomSnackbar.show(
                    context: context,
                    message: 'Error updating note: ${e.toString()}',
                    type: CustomSnackbarType.error,
                  );
                }
              })
              .whenComplete(() {
                _isProcessingAction = false;
                _isContextMenuOpen = false;
              });
        },
      ),
    );

    // Agregar opción de completar/descompletar solo si es un todo
    if (note.isTask) {
      menuItems.add(
        ContextMenuItem(
          icon:
              note.isCompleted
                  ? Icons.radio_button_unchecked_rounded
                  : Icons.check_circle_rounded,
          label: note.isCompleted ? 'Mark as incomplete' : 'Mark as complete',
          onTap: () {
            if (_isProcessingAction) return;
            _isProcessingAction = true;

            _noteRepository
                .updateNote(note.copyWith(isCompleted: !note.isCompleted))
                .then((_) {
                  if (mounted) {
                    _loadNotes();
                  }
                })
                .catchError((e) {
                  if (mounted) {
                    CustomSnackbar.show(
                      context: context,
                      message: 'Error updating todo: ${e.toString()}',
                      type: CustomSnackbarType.error,
                    );
                  }
                })
                .whenComplete(() {
                  _isProcessingAction = false;
                  _isContextMenuOpen = false;
                });
          },
        ),
      );
    }

    menuItems.addAll([
      ContextMenuItem(
        icon:
            note.isFavorite
                ? Icons.favorite_rounded
                : Icons.favorite_border_rounded,
        label: note.isFavorite ? 'Remove from Favorites' : 'Add to Favorites',
        onTap: () {
          if (_isProcessingAction) return;
          _isProcessingAction = true;

          _noteRepository
              .updateNote(note.copyWith(isFavorite: !note.isFavorite))
              .then((_) {
                if (mounted) {
                  _loadNotes();
                }
              })
              .catchError((e) {
                if (mounted) {
                  CustomSnackbar.show(
                    context: context,
                    message: 'Error updating note: ${e.toString()}',
                    type: CustomSnackbarType.error,
                  );
                }
              })
              .whenComplete(() {
                _isProcessingAction = false;
                _isContextMenuOpen = false;
              });
        },
      ),
      ContextMenuItem(
        icon:
            note.isTask
                ? Icons.description_outlined
                : Icons.check_circle_outline_rounded,
        label: note.isTask ? 'Convert to Note' : 'Convert to Todo',
        onTap: () {
          if (_isProcessingAction) return;
          _isProcessingAction = true;

          _noteRepository
              .updateNote(
                note.copyWith(isTask: !note.isTask, isCompleted: false),
              )
              .then((_) {
                if (mounted) {
                  _loadNotes();
                }
              })
              .catchError((e) {
                if (mounted) {
                  CustomSnackbar.show(
                    context: context,
                    message: 'Error updating note: ${e.toString()}',
                    type: CustomSnackbarType.error,
                  );
                }
              })
              .whenComplete(() {
                _isProcessingAction = false;
                _isContextMenuOpen = false;
              });
        },
      ),
      ContextMenuItem(
        icon: Icons.delete_rounded,
        label: 'Move to Trash',
        iconColor: Theme.of(context).colorScheme.error,
        onTap: () {
          if (_isProcessingAction) return;
          _isProcessingAction = true;

          _noteRepository
              .deleteNote(note.id!)
              .then((_) {
                if (mounted) {
                  widget.onNoteDeleted?.call(note);
                  _loadNotes();
                  widget.onTrashUpdated?.call();
                }
              })
              .catchError((e) {
                if (mounted) {
                  CustomSnackbar.show(
                    context: context,
                    message: 'Error deleting note: ${e.toString()}',
                    type: CustomSnackbarType.error,
                  );
                }
              })
              .whenComplete(() {
                _isProcessingAction = false;
                _isContextMenuOpen = false;
              });
        },
      ),
    ]);

    ContextMenuOverlay.show(
      context: context,
      tapPosition: tapPosition,
      items: menuItems,
      onOutsideTap: () {
        _isContextMenuOpen = false;
      },
    );
  }

  void _showRenameDialog(Note note) {
    _isContextMenuOpen = false;
    final TextEditingController controller = TextEditingController(
      text: note.title,
    );
    final colorScheme = Theme.of(context).colorScheme;

    showDialog(
      context: context,
      builder:
          (context) => Dialog(
            backgroundColor: Colors.transparent,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: 400,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      height: 56,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          Icon(
                            Icons.edit_rounded,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Rename Note',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const Spacer(),
                          IconButton(
                            icon: Icon(
                              Icons.close_rounded,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      child: Column(
                        children: [
                          TextFormField(
                            controller: controller,
                            autofocus: true,
                            decoration: InputDecoration(
                              labelText: 'Note title',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              filled: true,
                              fillColor: Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerHighest
                                  .withAlpha(76),
                              prefixIcon: const Icon(Icons.title_rounded),
                            ),
                            onFieldSubmitted:
                                (_) => _handleRename(note, controller.text),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      height: 56,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextButton(
                              onPressed: () => Navigator.pop(context),
                              style: TextButton.styleFrom(
                                backgroundColor:
                                    colorScheme.surfaceContainerHigh,
                                foregroundColor: colorScheme.onSurface,
                                minimumSize: const Size(0, 44),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: const Text(
                                'Cancel',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.normal,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed:
                                  () => _handleRename(note, controller.text),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: colorScheme.primary,
                                foregroundColor: colorScheme.onPrimary,
                                minimumSize: const Size(0, 44),
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: const Text(
                                'Rename',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
    );
  }

  Future<void> _handleRename(Note note, String newTitle) async {
    if (newTitle.trim().isEmpty) return;

    try {
      await _noteRepository.updateNote(note.copyWith(title: newTitle.trim()));

      if (mounted) {
        Navigator.pop(context);
        await _loadNotes();
      }
    } catch (e) {
      if (mounted) {
        CustomSnackbar.show(
          context: context,
          message: 'Error renaming: ${e.toString()}',
          type: CustomSnackbarType.error,
        );
      }
    }
  }

  Widget _buildNoteRow(Note note) {
    final isSelected = _selectedNoteIds.contains(note.id);
    // Don't show selection highlight when dragging a single note
    // Only show selection highlight for multi-selection (2+ notes)
    final showSelectionHighlight = isSelected && _selectedNoteIds.length > 1;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onSecondaryTapDown: (details) {
            if (isSelected) {
              _showMultiSelectionMenu(context, details.globalPosition);
            } else {
              _showContextMenu(context, details.globalPosition, note);
            }
          },
          borderRadius: BorderRadius.circular(4),
          hoverColor: Theme.of(context).colorScheme.surfaceContainerHigh,
          child: Container(
            color:
                showSelectionHighlight
                    ? Theme.of(context).colorScheme.surfaceContainerHigh
                    : widget.selectedNote?.id == note.id
                    ? Theme.of(context).colorScheme.surfaceContainerHigh
                    : Colors.transparent,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(
                  height: 24,
                  width: 24,
                  child:
                      _showNoteIcons
                          ? (note.isTask
                              ? GestureDetector(
                                onTap: () {
                                  _toggleNoteCompletion(note.id!);
                                },
                                child: Icon(
                                  note.isCompleted
                                      ? Icons.check_box_rounded
                                      : Icons.check_box_outline_blank_rounded,
                                  size: 20,
                                  color:
                                      note.isCompleted
                                          ? Theme.of(
                                            context,
                                          ).colorScheme.primary
                                          : Theme.of(
                                            context,
                                          ).colorScheme.onSurfaceVariant,
                                ),
                              )
                              : Container(
                                padding: const EdgeInsets.all(2),
                                child: Icon(
                                  Icons.description_outlined,
                                  size: 20,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ))
                          : null,
                ),
                if (_showNoteIcons) const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    note.title,
                    style: TextStyle(
                      fontWeight:
                          widget.selectedNote?.id == note.id
                              ? FontWeight.bold
                              : FontWeight.normal,
                      color:
                          showSelectionHighlight ||
                                  widget.selectedNote?.id == note.id
                              ? Theme.of(context).colorScheme.onSurface
                              : note.isTask && note.isCompleted
                              ? Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant.withAlpha(153)
                              : null,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (_showNoteIcons && note.isFavorite)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Icon(
                      Icons.favorite_rounded,
                      size: 16,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                if (_showNoteIcons && note.isPinned)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Icon(
                      Icons.push_pin_rounded,
                      size: 14,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Builds the drag feedback widget showing the note being dragged
  Widget _buildDragFeedback(Note primaryNote, List<Note> allNotes) {
    final colorScheme = Theme.of(context).colorScheme;
    final noteCount = allNotes.length;
    final title =
        noteCount == 1
            ? primaryNote.title
            : '${primaryNote.title} (+${noteCount - 1})';

    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(51),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.description_outlined,
              color: colorScheme.primary,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDraggableNote(Note note) {
    // Determine if this note is part of a multi-selection
    final isNoteInSelection = _selectedNoteIds.contains(note.id);
    // If dragging a selected note, include all selected notes
    // If dragging an unselected note, just drag that one note
    final notesToDrag =
        isNoteInSelection && hasSelection
            ? _notes.where((n) => _selectedNoteIds.contains(n.id)).toList()
            : [note];

    return Draggable<Map<String, dynamic>>(
      data: {
        'type': 'note',
        'note': note,
        'isMultiDrag': isNoteInSelection && _selectedNoteIds.length > 1,
        'selectedNotes': notesToDrag,
      },
      dragAnchorStrategy: pointerDragAnchorStrategy,
      onDragStarted: () {
        setState(() {
          _isDragging = true;
          // Cancel any pending deselection - user is dragging, not clicking
          _pendingDeselectionNoteId = null;

          // If dragging an unselected note, clear selection and select just this note
          if (!isNoteInSelection) {
            _selectedNoteIds.clear();
            _selectedNoteIds.add(note.id!);
            _selectionAnchorId = note.id;
            _lastClickedNoteId = note.id;
          }
        });
      },
      onDragEnd: (details) {
        setState(() {
          _isDragging = false;
          _dragTargetIndex = null;
          _currentVisualLineY = null;
          _elementBounds.clear(); // Clear bounds when drag ends
          _pendingDeselectionNoteId = null;
        });
      },
      feedback: Material(
        color: Colors.transparent,
        child: _buildDragFeedback(note, notesToDrag),
      ),
      child: GestureDetector(
        onTap: () {
          // Handle deferred single-selection for previously selected notes
          // This fires when it was a click, not a drag
          if (_pendingDeselectionNoteId == note.id) {
            setState(() {
              _pendingDeselectionNoteId = null;
            });
            _handleSingleSelection(note);
            widget.onNoteSelected(note);
          }
        },
        onSecondaryTapDown: (details) {
          if (_selectedNoteIds.contains(note.id)) {
            _showMultiSelectionMenu(context, details.globalPosition);
          } else {
            _showContextMenu(context, details.globalPosition, note);
          }
        },
        onTertiaryTapDown: (details) {
          // Middle mouse button - open in new tab
          if (widget.onNoteOpenInNewTab != null) {
            widget.onNoteOpenInNewTab!(note);
          }
        },
        child: Listener(
          onPointerDown: (event) {
            if (event.down && event.buttons == 1) {
              final isCtrlPressed = HardwareKeyboard.instance.isControlPressed;
              final isShiftPressed = HardwareKeyboard.instance.isShiftPressed;
              final isNoteAlreadySelected = _selectedNoteIds.contains(note.id);

              // If clicking on an already-selected note without modifiers,
              // defer the single-selection until we know it's not a drag
              if (isNoteAlreadySelected &&
                  !isCtrlPressed &&
                  !isShiftPressed &&
                  hasSelection) {
                // Mark this note for potential deselection on click completion
                _pendingDeselectionNoteId = note.id;
                // Still notify the panel about selection for visual feedback
                widget.onNoteSelectedFromPanel?.call(note);
              } else {
                // Normal selection behavior
                _pendingDeselectionNoteId = null;
                widget.onNoteSelectedFromPanel?.call(note);
                _handleNoteSelection(note, isCtrlPressed, isShiftPressed);
              }
            }
          },
          child: _buildNoteRow(note),
        ),
      ),
    );
  }

  void _updateDragTargetFromGlobalPosition(Offset globalPosition) {
    // Find which note element the cursor is over by checking stored bounds
    for (int i = 0; i < _notes.length; i++) {
      final bounds = _elementBounds[i];
      if (bounds != null && bounds.contains(globalPosition)) {
        // Calculate if cursor is in upper or lower half
        final localY = globalPosition.dy - bounds.top;
        final isAbove = localY < bounds.height / 2;

        // Calculate the visual line Y position
        final visualLineY = isAbove ? bounds.top : bounds.bottom;

        // Check if we're on the same visual line (within tolerance)
        bool sameVisualLine = false;
        if (_currentVisualLineY != null) {
          sameVisualLine = (visualLineY - _currentVisualLineY!).abs() < 5.0;
        }

        // Only update if we're not on the same visual line
        if (!sameVisualLine) {
          setState(() {
            _dragTargetIndex = i;
            _dragTargetIsAbove = isAbove;
            _currentVisualLineY = visualLineY;
          });
        } else {
          // Same visual line, just update internal state without setState
          _dragTargetIndex = i;
          _dragTargetIsAbove = isAbove;
          _currentVisualLineY = visualLineY;
        }
        return;
      }
    }

    // If not over any note, clear the target only if it was set
    if (_dragTargetIndex != null) {
      setState(() {
        _dragTargetIndex = null;
        _currentVisualLineY = null;
      });
    }
  }

  Widget _buildNoteWithDropZone(Note note, int index) {
    return DragTarget<Map<String, dynamic>>(
      onWillAcceptWithDetails: (details) {
        final data = details.data;
        if (data['type'] == 'note') {
          final draggedNote = data['note'] as Note;
          if (draggedNote.id != note.id) {
            return true;
          }
        }
        return false;
      },
      onLeave: (data) {
        // Hide indicator when leaving this element
        if (_dragTargetIndex == index) {
          setState(() {
            _dragTargetIndex = null;
            _currentVisualLineY = null;
          });
        }
      },
      onAcceptWithDetails: (details) async {
        final data = details.data;
        if (data['type'] == 'note') {
          final draggedNote = data['note'] as Note;
          final currentIndex = _notes.indexWhere((n) => n.id == draggedNote.id);
          if (currentIndex == -1) return;

          int targetIndex = index;

          // Use the stored drag target information
          if (_dragTargetIndex == index) {
            if (currentIndex < index) {
              targetIndex = _dragTargetIsAbove ? index : index + 1;
            } else {
              targetIndex = _dragTargetIsAbove ? index : index + 1;
            }
          } else {
            // Fallback to simple index-based logic
            if (currentIndex < index) {
              targetIndex = index;
            } else {
              targetIndex = index;
            }
          }

          // Ensure target index is within bounds
          targetIndex = targetIndex.clamp(0, _notes.length);

          await _moveNote(draggedNote, targetIndex);
        }

        setState(() {
          _dragTargetIndex = null;
          _currentVisualLineY = null;
        });
      },
      builder: (context, candidateData, rejectedData) {
        final isTarget = _dragTargetIndex == index && _isDragging;

        return LayoutBuilder(
          builder: (context, constraints) {
            // Store the bounds of this element for cursor detection
            WidgetsBinding.instance.addPostFrameCallback((_) {
              final RenderBox renderBox =
                  context.findRenderObject() as RenderBox;
              final position = renderBox.localToGlobal(Offset.zero);
              final size = renderBox.size;
              _elementBounds[index] = Rect.fromLTWH(
                position.dx,
                position.dy,
                size.width,
                size.height,
              );
            });

            return Column(
              children: [
                // Top indicator
                Container(
                  height: isTarget && _dragTargetIsAbove ? 4 : 0,
                  margin: EdgeInsets.symmetric(
                    horizontal: isTarget && _dragTargetIsAbove ? 8 : 0,
                  ),
                  decoration: BoxDecoration(
                    color:
                        isTarget && _dragTargetIsAbove
                            ? Theme.of(
                              context,
                            ).colorScheme.primary.withAlpha(60)
                            : Colors.transparent,
                    borderRadius:
                        isTarget && _dragTargetIsAbove
                            ? BorderRadius.circular(2)
                            : null,
                  ),
                ),
                // Note item
                _buildDraggableNote(note),
                // Bottom indicator
                Container(
                  height: isTarget && !_dragTargetIsAbove ? 4 : 0,
                  margin: EdgeInsets.symmetric(
                    horizontal: isTarget && !_dragTargetIsAbove ? 8 : 0,
                  ),
                  decoration: BoxDecoration(
                    color:
                        isTarget && !_dragTargetIsAbove
                            ? Theme.of(
                              context,
                            ).colorScheme.onPrimary.withAlpha(60)
                            : Colors.transparent,
                    borderRadius:
                        isTarget && !_dragTargetIsAbove
                            ? BorderRadius.circular(2)
                            : null,
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _moveNote(Note draggedNote, int targetIndex) async {
    if (targetIndex < 0 || targetIndex > _notes.length) return;

    if (_sortMode != SortMode.order) {
      if (mounted) {
        CustomSnackbar.show(
          context: context,
          message: 'Cannot reorder notes while sorting by date or completion',
          type: CustomSnackbarType.error,
        );
      }
      return;
    }

    final currentIndex = _notes.indexWhere((note) => note.id == draggedNote.id);
    if (currentIndex == -1) return;

    // Constrain reordering to pinned/unpinned sections
    final pinnedNotesCount = _notes.where((n) => n.isPinned).length;
    int adjustedTargetIndex = targetIndex;

    if (draggedNote.isPinned) {
      // Pinned notes can only move within the pinned section
      if (adjustedTargetIndex > pinnedNotesCount) {
        adjustedTargetIndex = pinnedNotesCount;
      }
    } else {
      // Unpinned notes can only move within the unpinned section
      if (adjustedTargetIndex < pinnedNotesCount) {
        adjustedTargetIndex = pinnedNotesCount;
      }
    }

    // Actualizar la UI inmediatamente para feedback visual
    setState(() {
      final finalTargetIndex =
          adjustedTargetIndex > currentIndex
              ? adjustedTargetIndex - 1
              : adjustedTargetIndex;
      final newNotes = List<Note>.from(_notes);
      newNotes.removeAt(currentIndex);
      newNotes.insert(finalTargetIndex, draggedNote);
      _notes = newNotes;
    });

    try {
      final repo = NoteRepository(DatabaseHelper());

      // Obtener todas las notas del notebook ordenadas
      final allNotes = await repo.getNotesByNotebookId(draggedNote.notebookId);
      // Ensure local sorting matches the constraint
      allNotes.sort((a, b) {
        if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
        return a.orderIndex.compareTo(b.orderIndex);
      });

      // Remover la nota que se está moviendo de la lista
      allNotes.removeWhere((note) => note.id == draggedNote.id);

      // Insertar la nota en la nueva posición restringida
      final finalTargetIndex =
          adjustedTargetIndex > currentIndex
              ? adjustedTargetIndex - 1
              : adjustedTargetIndex;
      allNotes.insert(finalTargetIndex, draggedNote);

      // Actualizar todos los orderIndex de forma optimizada
      final db = await DatabaseHelper().database;
      for (int i = 0; i < allNotes.length; i++) {
        db.execute('UPDATE notes SET order_index = ? WHERE id = ?', [
          i,
          allNotes[i].id,
        ]);
      }

      // Notificar cambios en la base de datos para sincronización
      DatabaseHelper.notifyDatabaseChanged();

      // Recargar las notas para asegurar sincronización
      if (mounted) {
        await _loadNotes();
      }
    } catch (e) {
      print('Error moving note: $e');
      // Revertir cambios en la UI si hay error
      if (mounted) {
        await _loadNotes();
        CustomSnackbar.show(
          context: context,
          message: 'Error reordering note',
          type: CustomSnackbarType.error,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isExpanded) {
      return const SizedBox.shrink();
    }

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _errorMessage!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _loadNotes, child: const Text('Retry')),
          ],
        ),
      );
    }

    if (_notes.isEmpty) {
      return const Center(child: Text('Empty'));
    }

    // Calculate bounds for all elements after the frame is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_isDragging) {
        for (int i = 0; i < _notes.length; i++) {
          // We'll calculate bounds in a different way
        }
      }
    });

    return Listener(
      onPointerMove:
          _isDragging
              ? (event) {
                // Global listener to track cursor position during drag
                _updateDragTargetFromGlobalPosition(event.position);
              }
              : null,
      child: ListView.builder(
        itemCount: _notes.length + 2, // +2 for start and end drop zones
        itemBuilder: (context, index) {
          if (index == 0) {
            // Start drop zone
            return DragTarget<Map<String, dynamic>>(
              onWillAcceptWithDetails: (details) {
                final data = details.data;
                if (data['type'] == 'note') {
                  return true;
                }
                return false;
              },
              onAcceptWithDetails: (details) async {
                final data = details.data;
                if (data['type'] == 'note') {
                  final draggedNote = data['note'] as Note;
                  await _moveNote(draggedNote, 0);
                }
              },
              builder: (context, candidateData, rejectedData) {
                return Container(
                  height: candidateData.isNotEmpty ? 4 : 0,
                  margin: EdgeInsets.symmetric(
                    horizontal: candidateData.isNotEmpty ? 8 : 0,
                  ),
                  decoration: BoxDecoration(
                    color:
                        candidateData.isNotEmpty
                            ? Theme.of(context).colorScheme.primary
                            : Colors.transparent,
                    borderRadius:
                        candidateData.isNotEmpty
                            ? BorderRadius.circular(2)
                            : null,
                    boxShadow:
                        candidateData.isNotEmpty
                            ? [
                              BoxShadow(
                                color: Theme.of(
                                  context,
                                ).colorScheme.primary.withAlpha(76),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ]
                            : null,
                  ),
                );
              },
            );
          } else if (index == _notes.length + 1) {
            // End drop zone
            return DragTarget<Map<String, dynamic>>(
              onWillAcceptWithDetails: (details) {
                final data = details.data;
                if (data['type'] == 'note') {
                  return true;
                }
                return false;
              },
              onAcceptWithDetails: (details) async {
                final data = details.data;
                if (data['type'] == 'note') {
                  final draggedNote = data['note'] as Note;
                  await _moveNote(draggedNote, _notes.length);
                }
              },
              builder: (context, candidateData, rejectedData) {
                return Container(
                  height: candidateData.isNotEmpty ? 4 : 0,
                  margin: EdgeInsets.symmetric(
                    horizontal: candidateData.isNotEmpty ? 8 : 0,
                  ),
                  decoration: BoxDecoration(
                    color:
                        candidateData.isNotEmpty
                            ? Theme.of(context).colorScheme.primary
                            : Colors.transparent,
                    borderRadius:
                        candidateData.isNotEmpty
                            ? BorderRadius.circular(2)
                            : null,
                    boxShadow:
                        candidateData.isNotEmpty
                            ? [
                              BoxShadow(
                                color: Theme.of(
                                  context,
                                ).colorScheme.primary.withAlpha(76),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ]
                            : null,
                  ),
                );
              },
            );
          }

          final note =
              _notes[index - 1]; // -1 because index 0 is the start drop zone
          return _buildNoteWithDropZone(note, index - 1);
        },
      ),
    );
  }

  @override
  void didUpdateWidget(NotesPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedNotebookId != oldWidget.selectedNotebookId ||
        widget.filterByTag != oldWidget.filterByTag) {
      _loadPreferencesAndNotes();
    } else if (widget.selectedNote?.id != oldWidget.selectedNote?.id ||
        widget.selectedNote?.title != oldWidget.selectedNote?.title) {
      if (widget.selectedNote != null) {
        updateNoteTitle(widget.selectedNote!);
      }
    }
  }
}
