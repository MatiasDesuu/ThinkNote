import 'package:flutter/material.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import '../../database/models/note.dart';
import '../../database/models/notebook.dart';
import '../../database/models/notebook_icons.dart';
import '../../database/repositories/note_repository.dart';
import '../../database/repositories/notebook_repository.dart';
import '../../database/controllers/app_controller.dart';
import 'notebook_selector_screen.dart';
import '../../database/database_helper.dart';
import '../../database/models/calendar_event.dart';
import '../../database/repositories/calendar_event_repository.dart';
import '../../Settings/editor_settings_panel.dart';
import '../widgets/note_editor.dart';
import '../../widgets/custom_snackbar.dart';
import '../../widgets/confirmation_dialogue.dart';
import '../../database/sync_service.dart';
import '../../animations/animations_handler.dart';

class HomeScreen extends StatefulWidget {
  final Note? selectedNote;
  final Notebook? selectedNotebook;
  final TextEditingController titleController;
  final TextEditingController contentController;
  final FocusNode contentFocusNode;
  final bool isEditing;
  final bool isImmersiveMode;
  final Future<void> Function() onSaveNote;
  final VoidCallback onToggleEditing;
  final VoidCallback onTitleChanged;
  final VoidCallback onContentChanged;
  final Function(bool) onToggleImmersiveMode;
  final Function(Note)? onNoteSelected;
  final Function(Notebook)? onNotebookSelected;
  final VoidCallback? onTrashUpdated;

  const HomeScreen({
    super.key,
    this.selectedNote,
    this.selectedNotebook,
    required this.titleController,
    required this.contentController,
    required this.contentFocusNode,
    required this.isEditing,
    required this.isImmersiveMode,
    required this.onSaveNote,
    required this.onToggleEditing,
    required this.onTitleChanged,
    required this.onContentChanged,
    required this.onToggleImmersiveMode,
    this.onNoteSelected,
    this.onNotebookSelected,
    this.onTrashUpdated,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  late final NoteRepository _noteRepository;
  late final CalendarEventRepository _calendarEventRepository;
  late final SyncAnimationController _syncController;
  late final SyncService _syncService;
  bool _isInitialLoad = true;
  String? _errorMessage;
  bool _sortByDate = false;
  static const String _sortPreferenceKey = 'notes_sort_by_date';
  static const String _lastSelectedNotebookIdKey =
      'mobile_last_selected_notebook_id';

  final Map<int, bool> _pendingCompletionChanges = {};

  Timer? _completionDebounceTimer;

  List<Note> _notes = [];
  List<CalendarEvent> _calendarEvents = [];
  bool _isLocalUpdate = false;
  bool _showNoteIcons = true;
  StreamSubscription<bool>? _showNoteIconsSubscription;

  @override
  void initState() {
    super.initState();
    _syncController = SyncAnimationController(vsync: this);
    _syncService = SyncService();
    _initializeRepository();
    _loadSortPreference();
    _loadLastSelectedNotebook();
    _loadIconSettings();
    _setupIconSettingsListener();
  }

  @override
  void didUpdateWidget(HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedNotebook?.id != oldWidget.selectedNotebook?.id) {
      _saveLastSelectedNotebook(widget.selectedNotebook?.id);
      _pendingCompletionChanges.clear();
      _completionDebounceTimer?.cancel();
      setState(() {
        _notes = [];
      });
    }
  }

  @override
  void dispose() {
    _completionDebounceTimer?.cancel();
    _showNoteIconsSubscription?.cancel();
    _syncController.dispose();
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

  Future<void> _initializeRepository() async {
    try {
      final dbHelper = DatabaseHelper();
      await dbHelper.database;
      _noteRepository = NoteRepository(dbHelper);
      _calendarEventRepository = CalendarEventRepository(dbHelper);

      // Cargar eventos del calendario
      await _loadCalendarEvents();
    } catch (e) {
      print('Error initializing repository: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'Error initializing database';
        });
      }
    }
  }

  Future<void> _performManualSync() async {
    setState(() {
      _syncController.start();
    });

    try {
      // Verificar si WebDAV está habilitado antes de intentar sincronizar
      final prefs = await SharedPreferences.getInstance();
      final isEnabled = prefs.getBool('webdav_enabled') ?? false;
      final url = prefs.getString('webdav_url') ?? '';
      final username = prefs.getString('webdav_username') ?? '';
      final password = prefs.getString('webdav_password') ?? '';

      if (!isEnabled || url.isEmpty || username.isEmpty || password.isEmpty) {
        throw Exception(
          'WebDAV not configured. Please configure WebDAV settings first.',
        );
      }

      await _syncService.forceSync();

      if (!mounted) return;

      CustomSnackbar.show(
        context: context,
        message: 'Synchronization completed successfully',
        type: CustomSnackbarType.success,
      );
    } catch (e) {
      if (mounted) {
        CustomSnackbar.show(
          context: context,
          message: 'Error synchronizing: ${e.toString()}',
          type: CustomSnackbarType.error,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _syncController.stop();
        });
      }
    }
  }

  Future<List<Note>> _loadNotes() async {
    try {
      if (_isLocalUpdate) {
        _isLocalUpdate = false;
        return _notes;
      }

      final notebookId = widget.selectedNotebook?.id ?? 0;
      final notes = await _noteRepository.getNotesByNotebookId(notebookId);

      if (_sortByDate) {
        notes.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      } else {
        notes.sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
      }

      final updatedNotes =
          notes.map((note) {
            if (_pendingCompletionChanges.containsKey(note.id)) {
              return note.copyWith(
                isCompleted: _pendingCompletionChanges[note.id]!,
              );
            }
            return note;
          }).toList();

      setState(() {
        _notes = updatedNotes;
      });

      return updatedNotes;
    } catch (e) {
      print('Error loading notes: $e');
      throw Exception('Error loading notes: ${e.toString()}');
    }
  }

  Future<void> _loadCalendarEvents() async {
    try {
      final currentMonth = DateTime.now();
      final events = await _calendarEventRepository.getCalendarEventsByMonth(
        currentMonth,
      );

      if (mounted) {
        setState(() {
          _calendarEvents = events;
        });
      }
    } catch (e) {
      print('Error loading calendar events: $e');
    }
  }

  Future<void> createNewNote() async {
    try {
      if (widget.selectedNotebook == null) {
        if (mounted) {
          CustomSnackbar.show(
            context: context,
            message: 'Please select a notebook first',
            type: CustomSnackbarType.error,
          );
        }
        return;
      }

      final notebookId = widget.selectedNotebook!.id!;

      final newNote = Note(
        title: 'New Note',
        content: '',
        notebookId: notebookId,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        isFavorite: false,
        tags: '',
        orderIndex: 0,
      );

      final noteId = await _noteRepository.createNote(newNote);
      final createdNote = await _noteRepository.getNote(noteId);

      if (createdNote != null && mounted) {
        setState(() {
          _isLocalUpdate = true;
          _notes = [..._notes, createdNote];
          if (_sortByDate) {
            _notes.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          } else {
            _notes.sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
          }
        });
        DatabaseHelper.notifyDatabaseChanged();
      }
    } catch (e) {
      debugPrint('Error creating note: $e');
      if (mounted) {
        CustomSnackbar.show(
          context: context,
          message: 'Error creating note: ${e.toString()}',
          type: CustomSnackbarType.error,
        );
      }
    }
  }

  Future<void> createNewTodo() async {
    try {
      if (widget.selectedNotebook == null) {
        if (mounted) {
          CustomSnackbar.show(
            context: context,
            message: 'Please select a notebook first',
            type: CustomSnackbarType.error,
          );
        }
        return;
      }

      final notebookId = widget.selectedNotebook!.id!;

      final newTodo = Note(
        title: 'New Todo',
        content: '',
        notebookId: notebookId,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        isFavorite: false,
        tags: '',
        orderIndex: 0,
        isTask: true,
        isCompleted: false,
      );

      final noteId = await _noteRepository.createNote(newTodo);
      final createdTodo = await _noteRepository.getNote(noteId);

      if (createdTodo != null && mounted) {
        setState(() {
          _isLocalUpdate = true;
          _notes = [..._notes, createdTodo];
          if (_sortByDate) {
            _notes.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          } else {
            _notes.sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
          }
        });
        DatabaseHelper.notifyDatabaseChanged();
      }
    } catch (e) {
      debugPrint('Error creating todo: $e');
      if (mounted) {
        CustomSnackbar.show(
          context: context,
          message: 'Error creating todo: ${e.toString()}',
          type: CustomSnackbarType.error,
        );
      }
    }
  }

  Future<void> _updateNote(Note note, Note updatedNote) async {
    try {
      await _noteRepository.updateNote(updatedNote);
      if (mounted) {
        setState(() {
          _isLocalUpdate = true;
          final index = _notes.indexWhere((n) => n.id == note.id);
          if (index != -1) {
            _notes[index] = updatedNote;
          }
        });
        DatabaseHelper.notifyDatabaseChanged();
      }
    } catch (e) {
      debugPrint('Error updating note: $e');
      if (mounted) {
        setState(() {
          final index = _notes.indexWhere((n) => n.id == note.id);
          if (index != -1) {
            _notes[index] = note; // Revert to original state
          }
        });
        CustomSnackbar.show(
          context: context,
          message: 'Error updating note: ${e.toString()}',
          type: CustomSnackbarType.error,
        );
      }
    }
  }

  Future<void> _deleteNote(Note note) async {
    try {
      await _noteRepository.deleteNote(note.id!);
      if (mounted) {
        setState(() {
          _isLocalUpdate = true;
          _notes.removeWhere((n) => n.id == note.id);
        });
        DatabaseHelper.notifyDatabaseChanged();
        widget.onTrashUpdated?.call();
      }
    } catch (e) {
      debugPrint('Error deleting note: $e');
      if (mounted) {
        setState(() {
          if (!_notes.any((n) => n.id == note.id)) {
            _notes.add(note); // Restore note if deletion failed
            if (_sortByDate) {
              _notes.sort((a, b) => b.createdAt.compareTo(a.createdAt));
            } else {
              _notes.sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
            }
          }
        });
        CustomSnackbar.show(
          context: context,
          message: 'Error deleting note: ${e.toString()}',
          type: CustomSnackbarType.error,
        );
      }
    }
  }

  void _openNoteEditor(Note note) {
    final editorTitleController = TextEditingController(text: note.title);
    final editorContentController = TextEditingController(text: note.content);
    final editorFocusNode = FocusNode();

    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder:
                (context) => NoteEditor(
                  selectedNote: note,
                  titleController: editorTitleController,
                  contentController: editorContentController,
                  contentFocusNode: editorFocusNode,
                  isEditing: widget.isEditing,
                  isImmersiveMode: widget.isImmersiveMode,
                  onSaveNote: () async {
                    try {
                      final dbHelper = DatabaseHelper();
                      final noteRepository = NoteRepository(dbHelper);

                      final updatedNote = Note(
                        id: note.id,
                        title: editorTitleController.text.trim(),
                        content: editorContentController.text,
                        notebookId: note.notebookId,
                        createdAt: note.createdAt,
                        updatedAt: DateTime.now(),
                        isFavorite: note.isFavorite,
                        tags: note.tags,
                        orderIndex: note.orderIndex,
                        isTask: note.isTask,
                        isCompleted: note.isCompleted,
                      );

                      final result = await noteRepository.updateNote(
                        updatedNote,
                      );
                      if (result > 0) {
                        DatabaseHelper.notifyDatabaseChanged();
                      }
                    } catch (e) {
                      debugPrint('Error saving note: $e');
                      if (mounted) {
                        CustomSnackbar.show(
                          context: context,
                          message: 'Error saving note: ${e.toString()}',
                          type: CustomSnackbarType.error,
                        );
                      }
                    }
                  },
                  onToggleEditing: widget.onToggleEditing,
                  onTitleChanged: () {
                    widget.onTitleChanged();
                  },
                  onContentChanged: () {
                    widget.onContentChanged();
                  },
                  onToggleImmersiveMode: widget.onToggleImmersiveMode,
                ),
          ),
        )
        .then((_) {});
  }

  Future<void> _loadSortPreference() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _sortByDate = prefs.getBool(_sortPreferenceKey) ?? false;
    });
  }

  Future<void> _saveSortPreference() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_sortPreferenceKey, _sortByDate);
  }

  Future<void> _loadLastSelectedNotebook() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastNotebookId = prefs.getInt(_lastSelectedNotebookIdKey);

      if (lastNotebookId != null && widget.onNotebookSelected != null) {
        final notebookRepo = NotebookRepository(DatabaseHelper());
        final notebook = await notebookRepo.getNotebook(lastNotebookId);

        if (notebook != null && mounted) {
          widget.onNotebookSelected!(notebook);
        }
      }
    } catch (e) {
      print('Error loading last selected notebook: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isInitialLoad = false;
        });
      }
    }
  }

  Future<void> _saveLastSelectedNotebook(int? notebookId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (notebookId != null) {
        await prefs.setInt(_lastSelectedNotebookIdKey, notebookId);
      } else {
        await prefs.remove(_lastSelectedNotebookIdKey);
      }
    } catch (e) {
      print('Error saving last selected notebook: $e');
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
    final notesToUpdate = <Note>[];

    for (final entry in changesToProcess.entries) {
      final noteId = entry.key;
      final newState = entry.value;
      final noteIndex = _notes.indexWhere((n) => n.id == noteId);
      if (noteIndex != -1) {
        notesToUpdate.add(_notes[noteIndex].copyWith(isCompleted: newState));
      }
    }

    _pendingCompletionChanges.clear();

    try {
      await Future.wait(
        notesToUpdate.map((note) async {
          await _noteRepository.toggleNoteCompletion(
            note.id!,
            note.isCompleted,
          );
        }),
      );

      if (mounted) {
        setState(() {
          _isLocalUpdate = true;
          for (final updatedNote in notesToUpdate) {
            final index = _notes.indexWhere((n) => n.id == updatedNote.id);
            if (index != -1) {
              _notes[index] = updatedNote;
            }
          }
        });
        DatabaseHelper.notifyDatabaseChanged();
      }
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

  @override
  Widget build(BuildContext context) {
    if (_isInitialLoad) {
      return const SizedBox.shrink();
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
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _errorMessage = null;
                });
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: Row(
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Icon(
                widget.selectedNotebook?.iconId != null
                    ? (NotebookIconsRepository.getIconById(
                          widget.selectedNotebook!.iconId!,
                        )?.icon ??
                        Icons.folder_rounded)
                    : Icons.folder_rounded,
                size: 24,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            Text(widget.selectedNotebook?.name ?? 'Notes'),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(
              _sortByDate
                  ? Icons.sort_by_alpha_rounded
                  : Icons.hourglass_bottom_rounded,
            ),
            onPressed: () async {
              setState(() {
                _sortByDate = !_sortByDate;
              });
              await _saveSortPreference();
              _pendingCompletionChanges.clear();
              _completionDebounceTimer?.cancel();
              DatabaseHelper.notifyDatabaseChanged();
            },
          ),
        ],
      ),
      body: StreamBuilder<void>(
        stream: DatabaseHelper.onDatabaseChanged,
        builder: (context, snapshot) {
          // Recargar eventos del calendario cuando hay cambios en la base de datos
          if (snapshot.hasData) {
            _loadCalendarEvents();
          }

          return FutureBuilder<List<Note>>(
            future: _loadNotes(),
            builder: (context, notesSnapshot) {
              if (notesSnapshot.connectionState == ConnectionState.waiting &&
                  notesSnapshot.data == null) {
                return const Center(child: CircularProgressIndicator());
              }

              if (notesSnapshot.hasError) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Error loading notes: ${notesSnapshot.error}',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          DatabaseHelper.notifyDatabaseChanged();
                        },
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                );
              }

              final notes = notesSnapshot.data ?? [];

              if (notes.isEmpty) {
                if (widget.selectedNotebook?.id == null) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.folder_open_rounded,
                          size: 64,
                          color: Theme.of(
                            context,
                          ).colorScheme.primary.withAlpha(127),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Select a notebook to view its notes',
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withAlpha(127),
                          ),
                        ),
                      ],
                    ),
                  );
                }
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.note_alt_outlined,
                        size: 64,
                        color: Theme.of(
                          context,
                        ).colorScheme.primary.withAlpha(127),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No notes in this notebook',
                        style: TextStyle(
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withAlpha(127),
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: createNewNote,
                        icon: const Icon(Icons.add_rounded),
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              Theme.of(context).colorScheme.primary,
                          foregroundColor:
                              Theme.of(context).colorScheme.onPrimary,
                        ),
                        label: const Text('Create New Note'),
                      ),
                    ],
                  ),
                );
              }

              return Stack(
                children: [
                  Column(
                    children: [
                      Expanded(
                        child: RefreshIndicator(
                          onRefresh: _performManualSync,
                          child: ListView.builder(
                            itemCount: notes.length,
                            itemBuilder: (context, index) {
                              final note = notes[index];
                              final isSelected =
                                  widget.selectedNote?.id == note.id;
                              final colorScheme = Theme.of(context).colorScheme;

                              return Column(
                                children: [
                                  Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      onTap: () => _openNoteEditor(note),
                                      onLongPress: () {
                                        _showContextMenu(note);
                                      },
                                      borderRadius: BorderRadius.circular(8),
                                      child: Container(
                                        color:
                                            isSelected
                                                ? colorScheme
                                                    .surfaceContainerHigh
                                                : Colors.transparent,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 12,
                                        ),
                                        child: Row(
                                          children: [
                                            if (_showNoteIcons) ...[
                                              if (note.isTask)
                                                GestureDetector(
                                                  onTap: () {
                                                    _toggleNoteCompletion(
                                                      note.id!,
                                                    );
                                                  },
                                                  child: Icon(
                                                    note.isCompleted
                                                        ? Icons
                                                            .check_circle_rounded
                                                        : Icons
                                                            .radio_button_unchecked_rounded,
                                                    size: 20,
                                                    color:
                                                        note.isCompleted
                                                            ? colorScheme
                                                                .primary
                                                            : colorScheme
                                                                .onSurfaceVariant,
                                                  ),
                                                )
                                              else
                                                Icon(
                                                  Icons.description_outlined,
                                                  size: 20,
                                                  color: colorScheme.primary,
                                                ),
                                              const SizedBox(width: 12),
                                            ],
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    note.title,
                                                    style: TextStyle(
                                                      fontSize: 16,
                                                      fontWeight:
                                                          isSelected
                                                              ? FontWeight.bold
                                                              : FontWeight.w600,
                                                      color:
                                                          note.isTask &&
                                                                  note.isCompleted
                                                              ? colorScheme
                                                                  .onSurfaceVariant
                                                                  .withAlpha(
                                                                    153,
                                                                  )
                                                              : null,
                                                    ),
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ],
                                              ),
                                            ),
                                            if (_showNoteIcons &&
                                                note.isFavorite)
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                  left: 8,
                                                ),
                                                child: Icon(
                                                  Icons.favorite_rounded,
                                                  size: 16,
                                                  color: colorScheme.primary,
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  if (index < notes.length - 1)
                                    Divider(
                                      height: 1,
                                      indent: 16,
                                      endIndent: 16,
                                      color: colorScheme.outlineVariant,
                                    ),
                                ],
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (widget.selectedNotebook?.id != null)
                    Positioned(
                      bottom: MediaQuery.of(context).viewPadding.bottom + 16,
                      right: 16,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          FloatingActionButton(
                            elevation: 4,
                            onPressed: createNewTodo,
                            heroTag: "new_todo_button",
                            child: const Icon(Icons.add_task_rounded),
                          ),
                          const SizedBox(height: 12),
                          FloatingActionButton(
                            elevation: 4,
                            onPressed: createNewNote,
                            heroTag: "new_note_button",
                            child: const Icon(Icons.note_add_rounded),
                          ),
                        ],
                      ),
                    ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  void _showContextMenu(Note note) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      isScrollControlled: true,
      builder:
          (context) => Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).padding.bottom,
            ),
            child: Container(
              decoration: const BoxDecoration(
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withAlpha(50),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  // Opción de completar/descompletar solo si es un todo
                  if (note.isTask)
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          Navigator.pop(context);
                          final updatedNote = note.copyWith(
                            isCompleted: !note.isCompleted,
                          );
                          _updateNote(note, updatedNote);
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                note.isCompleted
                                    ? Icons.radio_button_unchecked_rounded
                                    : Icons.check_circle_rounded,
                                size: 20,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                note.isCompleted
                                    ? 'Mark as incomplete'
                                    : 'Mark as complete',
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        Navigator.pop(context);
                        final updatedNote = note.copyWith(
                          isFavorite: !note.isFavorite,
                        );
                        _updateNote(note, updatedNote);
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              note.isFavorite
                                  ? Icons.favorite_rounded
                                  : Icons.favorite_border_rounded,
                              size: 20,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              note.isFavorite
                                  ? 'Remove from Favorites'
                                  : 'Add to Favorites',
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        Navigator.pop(context);
                        _showCalendarDatePicker(note);
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.calendar_month_rounded,
                              size: 20,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: 8),
                            const Text('Add to Calendar'),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        Navigator.pop(context);
                        final updatedNote = note.copyWith(
                          isTask: !note.isTask,
                          isCompleted: false,
                        );
                        _updateNote(note, updatedNote);
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              note.isTask
                                  ? Icons.description_outlined
                                  : Icons.check_circle_outline_rounded,
                              size: 20,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              note.isTask
                                  ? 'Convert to Note'
                                  : 'Convert to Todo',
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        Navigator.pop(context);
                        _showMoveToNotebookDialog(note);
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.folder_rounded,
                              size: 20,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: 8),
                            const Text('Move to Notebook'),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () async {
                        Navigator.pop(context);
                        final confirmed = await showDeleteConfirmationDialog(
                          context: context,
                          title: 'Move to Trash',
                          message:
                              'Are you sure you want to move this note to trash?\n${note.title}',
                          confirmText: 'Move to Trash',
                          confirmColor: Theme.of(context).colorScheme.error,
                        );

                        if (confirmed == true) {
                          _deleteNote(note);
                        }
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.delete_rounded,
                              size: 20,
                              color: Theme.of(context).colorScheme.error,
                            ),
                            const SizedBox(width: 8),
                            const Text('Move to Trash'),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }

  void _showCalendarDatePicker(Note note) {
    final colorScheme = Theme.of(context).colorScheme;
    DateTime? selectedDate;
    DateTime currentMonth = DateTime.now();

    showDialog(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setState) => Dialog(
                  backgroundColor: Colors.transparent,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: 400,
                      decoration: BoxDecoration(
                        color: colorScheme.surface,
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
                                  Icons.calendar_month_rounded,
                                  color: colorScheme.primary,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Row(
                                    children: [
                                      IconButton(
                                        icon: const Icon(
                                          Icons.chevron_left_rounded,
                                        ),
                                        onPressed: () {
                                          setState(() {
                                            currentMonth = DateTime(
                                              currentMonth.year,
                                              currentMonth.month - 1,
                                              1,
                                            );
                                          });
                                        },
                                        constraints: const BoxConstraints(
                                          minWidth: 32,
                                          minHeight: 32,
                                        ),
                                        padding: EdgeInsets.zero,
                                      ),
                                      Expanded(
                                        child: Text(
                                          '${_getMonthName(currentMonth.month)} ${currentMonth.year}',
                                          style: Theme.of(
                                            context,
                                          ).textTheme.titleMedium?.copyWith(
                                            color: colorScheme.onSurface,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.chevron_right_rounded,
                                        ),
                                        onPressed: () {
                                          setState(() {
                                            currentMonth = DateTime(
                                              currentMonth.year,
                                              currentMonth.month + 1,
                                              1,
                                            );
                                          });
                                        },
                                        constraints: const BoxConstraints(
                                          minWidth: 32,
                                          minHeight: 32,
                                        ),
                                        padding: EdgeInsets.zero,
                                      ),
                                    ],
                                  ),
                                ),
                                TextButton(
                                  onPressed: () {
                                    setState(() {
                                      currentMonth = DateTime.now();
                                      selectedDate = DateTime.now();
                                    });
                                  },
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                    ),
                                    minimumSize: const Size(40, 32),
                                  ),
                                  child: const Text('Today'),
                                ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              children: [
                                _buildCalendarGrid(currentMonth, selectedDate, (
                                  date,
                                ) {
                                  setState(() {
                                    selectedDate = date;
                                  });
                                }),
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextButton(
                                        onPressed: () => Navigator.pop(context),
                                        style: ButtonStyle(
                                          backgroundColor:
                                              WidgetStateProperty.all<Color>(
                                                colorScheme
                                                    .surfaceContainerHigh,
                                              ),
                                          foregroundColor:
                                              WidgetStateProperty.all<Color>(
                                                colorScheme.onSurface,
                                              ),
                                          minimumSize:
                                              WidgetStateProperty.all<Size>(
                                                const Size(0, 44),
                                              ),
                                          shape: WidgetStateProperty.all<
                                            RoundedRectangleBorder
                                          >(
                                            RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                          ),
                                        ),
                                        child: FittedBox(
                                          fit: BoxFit.scaleDown,
                                          child: Text(
                                            'Cancel',
                                            style: TextStyle(
                                              color: colorScheme.onSurface,
                                              fontWeight: FontWeight.normal,
                                              fontSize: 15,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                            maxLines: 1,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: ElevatedButton(
                                        style: ButtonStyle(
                                          backgroundColor:
                                              WidgetStateProperty.all<Color>(
                                                colorScheme.primary,
                                              ),
                                          foregroundColor:
                                              WidgetStateProperty.all<Color>(
                                                colorScheme.onPrimary,
                                              ),
                                          minimumSize:
                                              WidgetStateProperty.all<Size>(
                                                const Size(0, 44),
                                              ),
                                          elevation:
                                              WidgetStateProperty.all<double>(
                                                0,
                                              ),
                                          shape: WidgetStateProperty.all<
                                            RoundedRectangleBorder
                                          >(
                                            RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                          ),
                                        ),
                                        onPressed:
                                            selectedDate == null
                                                ? null
                                                : () async {
                                                  Navigator.pop(context);
                                                  await _handleNoteDrop(
                                                    note,
                                                    selectedDate!.day,
                                                  );
                                                },
                                        child: FittedBox(
                                          fit: BoxFit.scaleDown,
                                          child: Text(
                                            'Add to Calendar',
                                            style: TextStyle(
                                              color: colorScheme.onPrimary,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 15,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                            maxLines: 1,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
          ),
    );
  }

  String _getMonthName(int month) {
    final months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return months[month - 1];
  }

  Widget _buildCalendarGrid(
    DateTime currentMonth,
    DateTime? selectedDate,
    Function(DateTime) onDateSelected,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final firstDayOfMonth = DateTime(currentMonth.year, currentMonth.month, 1);
    final lastDayOfMonth = DateTime(
      currentMonth.year,
      currentMonth.month + 1,
      0,
    );
    final firstWeekday = firstDayOfMonth.weekday;
    final daysInMonth = lastDayOfMonth.day;

    final List<Widget> calendarRows = [];
    int currentDay = 1;

    while (currentDay <= daysInMonth) {
      final List<Widget> rowChildren = [];

      for (int i = 1; i <= 7; i++) {
        if (currentDay == 1 && i < firstWeekday) {
          rowChildren.add(const SizedBox(width: 40, height: 40));
        } else if (currentDay <= daysInMonth) {
          final day = currentDay;
          final date = DateTime(currentMonth.year, currentMonth.month, day);
          final isSelected =
              selectedDate != null &&
              selectedDate.year == date.year &&
              selectedDate.month == date.month &&
              selectedDate.day == date.day;

          final hasEvents = _calendarEvents.any(
            (event) =>
                event.date.year == date.year &&
                event.date.month == date.month &&
                event.date.day == date.day,
          );

          rowChildren.add(
            SizedBox(
              width: 40,
              height: 40,
              child: Container(
                margin: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color:
                      isSelected
                          ? colorScheme.primaryFixed.withAlpha(50)
                          : null,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => onDateSelected(date),
                    borderRadius: BorderRadius.circular(8),
                    child: Stack(
                      children: [
                        Center(
                          child: Text(
                            day.toString(),
                            style: TextStyle(
                              color:
                                  isSelected
                                      ? colorScheme.primaryFixed
                                      : colorScheme.onSurface,
                              fontWeight:
                                  isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                              fontSize: isSelected ? 16 : 14,
                            ),
                          ),
                        ),
                        if (hasEvents)
                          Positioned(
                            bottom: 2,
                            left: 0,
                            right: 0,
                            child: Center(
                              child: Container(
                                width: 4,
                                height: 4,
                                decoration: BoxDecoration(
                                  color:
                                      isSelected
                                          ? colorScheme.primary
                                          : colorScheme.primary,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
          currentDay++;
        } else {
          rowChildren.add(const SizedBox(width: 40, height: 40));
        }
      }

      calendarRows.add(
        Row(mainAxisAlignment: MainAxisAlignment.center, children: rowChildren),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 24,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children:
                ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
                    .map(
                      (day) => SizedBox(
                        width: 40,
                        child: Center(
                          child: Text(
                            day,
                            style: TextStyle(
                              color: colorScheme.onSurfaceVariant,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                    )
                    .toList(),
          ),
        ),
        ...calendarRows,
      ],
    );
  }

  void _showMoveToNotebookDialog(Note note) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => NotebookSelectorScreen(
              currentNotebook: widget.selectedNotebook,
              onNotebookSelected: (Notebook selectedNotebook) async {
                await _moveNoteToNotebook(note, selectedNotebook);
              },
            ),
      ),
    );
  }

  Future<void> _moveNoteToNotebook(Note note, Notebook targetNotebook) async {
    try {
      final dbHelper = DatabaseHelper();
      final appController = AppController(dbHelper);

      await appController.moveNote(note.id!, targetNotebook.id!);

      if (mounted) {
        CustomSnackbar.show(
          context: context,
          message: 'Note moved to "${targetNotebook.name}" successfully',
          type: CustomSnackbarType.success,
        );

        // Remove the note from the current list since it's now in a different notebook
        setState(() {
          _notes.removeWhere((n) => n.id == note.id);
        });

        DatabaseHelper.notifyDatabaseChanged();
      }
    } catch (e) {
      print('Error moving note: $e');
      if (mounted) {
        CustomSnackbar.show(
          context: context,
          message: 'Error moving note: ${e.toString()}',
          type: CustomSnackbarType.error,
        );
      }
    }
  }

  Future<void> _handleNoteDrop(Note note, int day) async {
    if (note.id == null) {
      if (mounted) {
        CustomSnackbar.show(
          context: context,
          message: 'Cannot add unsaved note to calendar',
          type: CustomSnackbarType.error,
        );
      }
      return;
    }

    try {
      final date = DateTime(DateTime.now().year, DateTime.now().month, day);
      final events = await _calendarEventRepository.getCalendarEventsByMonth(
        date,
      );

      final existingEvent = events.firstWhere(
        (event) => event.noteId == note.id && event.date.isAtSameMomentAs(date),
        orElse:
            () => CalendarEvent(id: 0, noteId: 0, date: date, orderIndex: 0),
      );

      if (existingEvent.id != 0) {
        if (mounted) {
          CustomSnackbar.show(
            context: context,
            message: 'This note is already assigned to this day',
            type: CustomSnackbarType.error,
          );
        }
        return;
      }

      final nextOrderIndex = await _calendarEventRepository.getNextOrderIndex();
      final event = CalendarEvent(
        id: 0,
        noteId: note.id!,
        date: date,
        orderIndex: nextOrderIndex,
      );

      await _calendarEventRepository.createCalendarEvent(event);
      DatabaseHelper.notifyDatabaseChanged();

      // Recargar eventos del calendario
      await _loadCalendarEvents();

      if (mounted) {
        CustomSnackbar.show(
          context: context,
          message: 'Note added to calendar',
          type: CustomSnackbarType.success,
        );
      }
    } catch (e) {
      print('Error adding note to calendar: $e');
      if (mounted) {
        CustomSnackbar.show(
          context: context,
          message: 'Error adding note to calendar: $e',
          type: CustomSnackbarType.error,
        );
      }
    }
  }
}
