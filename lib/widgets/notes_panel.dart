import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../database/models/note.dart';
import '../database/repositories/note_repository.dart';
import '../database/database_helper.dart';
import '../database/database_service.dart';
import '../Settings/editor_settings_panel.dart';
import 'custom_snackbar.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'context_menu.dart';

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
  bool _sortByDate = false;
  late StreamSubscription<void> _databaseChangeSubscription;
  static const String _sortPreferenceKey = 'notes_sort_by_date';
  bool _showNoteIcons = true;
  StreamSubscription<bool>? _showNoteIconsSubscription;

  final Set<int> _selectedNoteIds = {};
  bool get hasSelection => _selectedNoteIds.isNotEmpty;

  int? _lastSelectedNoteId;

  bool _isProcessingAction = false;

  final Map<int, bool> _pendingCompletionChanges = {};

  Timer? _completionDebounceTimer;

  bool _isReloading = false;

  bool _isContextMenuOpen = false;

  // Drag and drop state
  int? _dragTargetIndex;
  bool _dragTargetIsAbove = false;
  bool _isDragging = false;

  // Element bounds tracking
  final Map<int, Rect> _elementBounds = {};

  // Visual position tracking
  double? _currentVisualLineY;

  bool get sortByDate => _sortByDate;
  bool get isExpanded => _isExpanded;

  Widget buildTrailingButton() {
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
          sortByDate
              ? Icons.sort_by_alpha_rounded
              : Icons.hourglass_bottom_rounded,
          size: 16,
          key: ValueKey<bool>(sortByDate),
        ),
      ),
      onPressed: toggleSortOrder,
    );
  }

  void _handleNoteSelection(
    Note note,
    bool isCtrlPressed,
    bool isShiftPressed,
  ) {
    setState(() {
      if (isShiftPressed && _lastSelectedNoteId != null) {
        final startIndex = _notes.indexWhere(
          (n) => n.id == _lastSelectedNoteId,
        );
        final endIndex = _notes.indexWhere((n) => n.id == note.id);

        if (startIndex != -1 && endIndex != -1) {
          final start = startIndex < endIndex ? startIndex : endIndex;
          final end = startIndex < endIndex ? endIndex : startIndex;

          for (int i = start; i <= end; i++) {
            _selectedNoteIds.add(_notes[i].id!);
          }
        }

        _lastSelectedNoteId = note.id;
        widget.onNoteSelected(note);
      } else if (isCtrlPressed) {
        if (_selectedNoteIds.isEmpty && widget.selectedNote != null) {
          _selectedNoteIds.add(widget.selectedNote!.id!);
        }

        if (_selectedNoteIds.contains(note.id)) {
          _selectedNoteIds.remove(note.id);
        } else {
          _selectedNoteIds.add(note.id!);
        }

        _lastSelectedNoteId = note.id;
        widget.onNoteSelected(note);
      } else {
        _selectedNoteIds.clear();
        _lastSelectedNoteId = note.id;
        widget.onNoteSelected(note);
      }
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedNoteIds.clear();
      _lastSelectedNoteId = null;
    });
    _pendingCompletionChanges.clear();
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

  Future<void> _deleteSelectedNotes() async {
    try {
      for (final noteId in _selectedNoteIds) {
        final note = await _noteRepository.getNote(noteId);
        if (note != null) {
          await _noteRepository.deleteNote(noteId);
          widget.onNoteDeleted?.call(note);
        }
      }
      _clearSelection();
      if (mounted) {
        widget.onTrashUpdated?.call();
        CustomSnackbar.show(
          context: context,
          message: 'Selected notes moved to trash',
          type: CustomSnackbarType.success,
        );
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
          onTap: () {
            if (_isProcessingAction) return;
            _isProcessingAction = true;

            Future.wait(
                  _selectedNoteIds.map((noteId) async {
                    final note = await _noteRepository.getNote(noteId);
                    if (note != null) {
                      return _noteRepository.updateNote(
                        note.copyWith(isTask: true, isCompleted: false),
                      );
                    }
                    return 0;
                  }),
                )
                .then((_) {
                  if (mounted) {
                    _loadNotes();
                    CustomSnackbar.show(
                      context: context,
                      message: 'Selected notes converted to todos',
                      type: CustomSnackbarType.success,
                    );
                  }
                })
                .catchError((e) {
                  if (mounted) {
                    CustomSnackbar.show(
                      context: context,
                      message: 'Error converting notes: ${e.toString()}',
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
          icon: Icons.description_outlined,
          label: 'Convert Selected to Note',
          onTap: () {
            if (_isProcessingAction) return;
            _isProcessingAction = true;

            Future.wait(
                  _selectedNoteIds.map((noteId) async {
                    final note = await _noteRepository.getNote(noteId);
                    if (note != null) {
                      return _noteRepository.updateNote(
                        note.copyWith(isTask: false, isCompleted: false),
                      );
                    }
                    return 0;
                  }),
                )
                .then((_) {
                  if (mounted) {
                    _loadNotes();
                    CustomSnackbar.show(
                      context: context,
                      message: 'Selected todos converted to notes',
                      type: CustomSnackbarType.success,
                    );
                  }
                })
                .catchError((e) {
                  if (mounted) {
                    CustomSnackbar.show(
                      context: context,
                      message: 'Error converting todos: ${e.toString()}',
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
    _loadSortPreference();
    _loadIconSettings();
    _setupIconSettingsListener();
    _databaseChangeSubscription = DatabaseService().onDatabaseChanged.listen((
      _,
    ) {
      _loadNotes();
    });
  }

  @override
  void dispose() {
    _databaseChangeSubscription.cancel();
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
    setState(() {
      _sortByDate = prefs.getBool(_sortPreferenceKey) ?? false;
    });
  }

  Future<void> _saveSortPreference() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_sortPreferenceKey, _sortByDate);
  }

  Future<void> toggleSortOrder() async {
    setState(() {
      _sortByDate = !_sortByDate;
    });
    await _saveSortPreference();
    await _loadNotes();
    widget.onSortChanged?.call();
  }

  Future<void> _initializeRepository() async {
    try {
      final dbHelper = DatabaseHelper();
      await dbHelper.database;
      _noteRepository = NoteRepository(dbHelper);
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

  Future<void> _loadNotes() async {
    if (!mounted || _isReloading) return;

    final currentSelection = Set<int>.from(_selectedNoteIds);
    final currentLastSelected = _lastSelectedNoteId;

    _isReloading = true;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final notes = await _noteRepository.getNotesByNotebookId(
        widget.selectedNotebookId ?? 0,
      );

      if (!mounted) return;

      if (_sortByDate) {
        notes.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      } else {
        notes.sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
      }

      setState(() {
        _notes = notes;
        _isLoading = false;
        _selectedNoteIds.clear();
        for (final noteId in currentSelection) {
          if (notes.any((note) => note.id == noteId)) {
            _selectedNoteIds.add(noteId);
          }
        }
        if (currentLastSelected != null &&
            notes.any((note) => note.id == currentLastSelected)) {
          _lastSelectedNoteId = currentLastSelected;
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
                isSelected
                    ? Theme.of(context).colorScheme.primaryContainer
                    : widget.selectedNote?.id == note.id
                    ? Theme.of(context).colorScheme.surfaceContainerHigh
                    : Colors.transparent,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(
                  height: 24,
                  child:
                      _showNoteIcons
                          ? (note.isTask
                              ? GestureDetector(
                                onTap: () {
                                  _toggleNoteCompletion(note.id!);
                                },
                                behavior: HitTestBehavior.opaque,
                                child: Container(
                                  padding: const EdgeInsets.all(2),
                                  child: Icon(
                                    note.isCompleted
                                        ? Icons.check_circle_rounded
                                        : Icons.radio_button_unchecked_rounded,
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
                                ),
                              )
                              : Container(
                                padding: const EdgeInsets.all(2),
                                child: Icon(
                                  Icons.description_outlined,
                                  size: 20,
                                  color:
                                      isSelected
                                          ? Theme.of(
                                            context,
                                          ).colorScheme.onPrimaryContainer
                                          : Theme.of(
                                            context,
                                          ).colorScheme.primary,
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
                          isSelected
                              ? Theme.of(context).colorScheme.onPrimaryContainer
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
                      color:
                          isSelected
                              ? Theme.of(context).colorScheme.onPrimaryContainer
                              : Theme.of(context).colorScheme.primary,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDraggableNote(Note note) {
    return Draggable<Map<String, dynamic>>(
      data: {
        'type': 'note',
        'note': note,
        'isMultiDrag': hasSelection,
        'selectedNotes':
            hasSelection
                ? _notes.where((n) => _selectedNoteIds.contains(n.id)).toList()
                : [note],
      },
      onDragStarted: () {
        setState(() {
          _isDragging = true;
        });
      },
      onDragEnd: (details) {
        setState(() {
          _isDragging = false;
          _dragTargetIndex = null;
          _currentVisualLineY = null;
          _elementBounds.clear(); // Clear bounds when drag ends
        });
      },
      feedback: Material(
        color: Colors.transparent,
        child: Container(
          width: 220,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(51),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Opacity(opacity: 0.9, child: _buildNoteRow(note)),
              ),
              if (hasSelection)
                Padding(
                  padding: const EdgeInsets.only(top: 4, bottom: 4),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${_selectedNoteIds.length} notes selected',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      child: GestureDetector(
        onTap: () => widget.onNoteSelectedFromPanel?.call(note) ?? widget.onNoteSelected(note),
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
      // Selection via pointer should be treated as originating from the panel
      widget.onNoteSelectedFromPanel?.call(note);
      _handleNoteSelection(note, isCtrlPressed, isShiftPressed);
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
                            ? Theme.of(context).colorScheme.primary
                            : Colors.transparent,
                    borderRadius:
                        isTarget && _dragTargetIsAbove
                            ? BorderRadius.circular(2)
                            : null,
                    boxShadow:
                        isTarget && _dragTargetIsAbove
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
                            ? Theme.of(context).colorScheme.primary
                            : Colors.transparent,
                    borderRadius:
                        isTarget && !_dragTargetIsAbove
                            ? BorderRadius.circular(2)
                            : null,
                    boxShadow:
                        isTarget && !_dragTargetIsAbove
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

    if (_sortByDate) {
      if (mounted) {
        CustomSnackbar.show(
          context: context,
          message: 'Cannot reorder notes while sorting by date',
          type: CustomSnackbarType.warning,
        );
      }
      return;
    }

    final currentIndex = _notes.indexWhere((note) => note.id == draggedNote.id);
    if (currentIndex == -1) return;

    // Actualizar la UI inmediatamente para feedback visual
    setState(() {
      final adjustedTargetIndex =
          targetIndex > currentIndex ? targetIndex - 1 : targetIndex;
      final newNotes = List<Note>.from(_notes);
      newNotes.removeAt(currentIndex);
      newNotes.insert(adjustedTargetIndex, draggedNote);
      _notes = newNotes;
    });

    try {
      final repo = NoteRepository(DatabaseHelper());

      // Obtener todas las notas del notebook ordenadas
      final allNotes = await repo.getNotesByNotebookId(draggedNote.notebookId);
      allNotes.sort((a, b) => a.orderIndex.compareTo(b.orderIndex));

      // Remover la nota que se está moviendo de la lista
      allNotes.removeWhere((note) => note.id == draggedNote.id);

      // Insertar la nota en la nueva posición
      final adjustedTargetIndex =
          targetIndex > currentIndex ? targetIndex - 1 : targetIndex;
      allNotes.insert(adjustedTargetIndex, draggedNote);

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
    if (widget.selectedNotebookId != oldWidget.selectedNotebookId) {
      _loadNotes();
    } else if (widget.selectedNote?.id != oldWidget.selectedNote?.id ||
        widget.selectedNote?.title != oldWidget.selectedNote?.title) {
      if (widget.selectedNote != null) {
        updateNoteTitle(widget.selectedNote!);
      }
    }
  }
}
