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
import '../../services/tags_service.dart';
import '../../widgets/custom_date_picker_dialog.dart';

enum SortMode { order, date, completion }

class HomeScreen extends StatefulWidget {
  final Note? selectedNote;
  final Notebook? selectedNotebook;
  final String? selectedTag;
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
    this.selectedTag,
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
  SortMode _sortMode = SortMode.order;
  bool _completionSubSortByDate = false;
  static const String _sortPreferenceKey = 'mobile_notes_sort_mode';
  static const String _completionSubSortPreferenceKey =
      'mobile_notes_completion_sub_sort_by_date';
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
    _loadCompletionSubSortPreference();
    _loadLastSelectedNotebook();
    _loadIconSettings();
    _setupIconSettingsListener();
  }

  @override
  void didUpdateWidget(HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedNotebook?.id != oldWidget.selectedNotebook?.id ||
        widget.selectedTag != oldWidget.selectedTag) {
      if (widget.selectedNotebook?.id != oldWidget.selectedNotebook?.id) {
        _saveLastSelectedNotebook(widget.selectedNotebook?.id);
      }
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

      List<Note> notes;
      if (widget.selectedTag != null) {
        notes = await TagsService().getNotesByTag(widget.selectedTag!);
      } else {
        final notebookId = widget.selectedNotebook?.id ?? 0;
        notes = await _noteRepository.getNotesByNotebookId(notebookId);
      }

      _sortNotes(notes);

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
          _sortNotes(_notes);
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
          _sortNotes(_notes);
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
            _sortNotes(_notes);
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

  Future<void> _toggleSortMode() async {
    setState(() {
      final modes = SortMode.values;
      final currentIndex = modes.indexOf(_sortMode);
      _sortMode = modes[(currentIndex + 1) % modes.length];
    });
    await _saveSortPreference();
    _pendingCompletionChanges.clear();
    _completionDebounceTimer?.cancel();
    DatabaseHelper.notifyDatabaseChanged();
  }

  Future<void> _toggleCompletionSubSort() async {
    setState(() {
      _completionSubSortByDate = !_completionSubSortByDate;
    });
    await _saveCompletionSubSortPreference();
    _pendingCompletionChanges.clear();
    _completionDebounceTimer?.cancel();
    DatabaseHelper.notifyDatabaseChanged();
  }

  void _sortNotes(List<Note> notes) {
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
              return b.createdAt.compareTo(a.createdAt); // Más reciente primero
            } else {
              return a.title.compareTo(b.title);
            }
          } else {
            return a.isCompleted ? 1 : -1;
          }
        });
        break;
    }
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
      // Re-sort the notes after completion change
      _sortNotes(_notes);
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

    List<Widget> buildAppBarActions() {
      if (_sortMode == SortMode.completion) {
        return [
          IconButton(
            icon: Icon(
              _completionSubSortByDate
                  ? Icons.access_time
                  : Icons.sort_by_alpha,
            ),
            onPressed: _toggleCompletionSubSort,
          ),
          IconButton(icon: Icon(_getSortIcon()), onPressed: _toggleSortMode),
        ];
      } else {
        return [
          IconButton(icon: Icon(_getSortIcon()), onPressed: _toggleSortMode),
        ];
      }
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
            Expanded(
              child: Text(
                widget.selectedTag != null
                    ? 'Tag: ${widget.selectedTag}'
                    : (widget.selectedNotebook?.name ?? 'Notes'),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: buildAppBarActions(),
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
                if (widget.selectedTag != null) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 16),
                        Text(
                          'No notes found with tag "${widget.selectedTag}"',
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
                                                            .check_box_rounded
                                                        : Icons
                                                            .check_box_outline_blank_rounded,
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
                                            if (_showNoteIcons && note.isPinned)
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                  left: 8,
                                                ),
                                                child: Icon(
                                                  Icons.push_pin_rounded,
                                                  size: 14,
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
                              const SizedBox(width: 12),
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
                          isPinned: !note.isPinned,
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
                              note.isPinned
                                  ? Icons.push_pin_rounded
                                  : Icons.push_pin_outlined,
                              size: 20,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: 12),
                            Text(note.isPinned ? 'Unpin' : 'Pin to top'),
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

  Future<void> _showCalendarDatePicker(Note note) async {
    final eventDates = _calendarEvents.map((e) => e.date).toList();
    final selectedDate = await showDialog<DateTime>(
      context: context,
      builder:
          (context) => CustomDatePickerDialog(
            initialDate: DateTime.now(),
            eventDates: eventDates,
          ),
    );

    if (selectedDate != null) {
      await _handleNoteDrop(note, selectedDate);
    }
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

  Future<void> _handleNoteDrop(Note note, DateTime date) async {
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
