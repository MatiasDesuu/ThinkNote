// ignore_for_file: library_private_types_in_public_api

import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../animations/animations_handler.dart';
import '../database/models/diary_entry.dart';
import '../database/services/diary_service.dart';
import '../database/database_helper.dart';
import '../database/repositories/diary_repository.dart';
import '../widgets/favorites_screen.dart';
import '../widgets/trash_screen.dart';
import '../Settings/settings_screen.dart';
import '../widgets/Editor/editor_screen.dart';
import '../database/models/note.dart';
import '../widgets/custom_snackbar.dart';
import '../database/sync_service.dart';
import 'diary_calendar_panel.dart';
import 'diary_entries_panel.dart';
import '../widgets/resizable_icon_sidebar.dart';

class SaveDiaryIntent extends Intent {
  const SaveDiaryIntent();
}

class NewDiaryIntent extends Intent {
  const NewDiaryIntent();
}

class _ToggleSidebarIntent extends Intent {
  const _ToggleSidebarIntent();
}

class DiaryScreen extends StatefulWidget {
  final Directory rootDir;
  final Function(File) onOpenNote;
  final Function() onClose;

  const DiaryScreen({
    super.key,
    required this.rootDir,
    required this.onOpenNote,
    required this.onClose,
  });

  @override
  _DiaryScreenState createState() => _DiaryScreenState();
}

class _DiaryScreenState extends State<DiaryScreen>
    with TickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  DiaryEntry? _selectedEntry;
  final TextEditingController _contentController = TextEditingController();
  final TextEditingController _titleController = TextEditingController();
  Timer? _debounceContent;
  bool _isEditorCentered = false;
  final FocusNode _appFocusNode = FocusNode();

  // Variables for resizable panel
  double _sidebarWidth = 240;
  bool _isCalendarExpanded = true;
  bool _isSidebarVisible = true;
  late AnimationController _sidebarAnimController;
  late Animation<double> _sidebarWidthAnimation;
  DateTime? _selectedDate;

  // Loading state

  // Services
  late DiaryService _diaryService;
  StreamSubscription? _diaryChangesSubscription;
  late SyncAnimationController _syncController;
  late SyncService _syncService;

  // Global keys for panels
  final GlobalKey<DiaryEntriesPanelState> _entriesPanelKey =
      GlobalKey<DiaryEntriesPanelState>();
  final GlobalKey<DiaryCalendarPanelState> _calendarPanelKey =
      GlobalKey<DiaryCalendarPanelState>();

  @override
  void initState() {
    super.initState();

    // Inicializar animación del sidebar
    _sidebarAnimController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
      value: 1.0, // Empieza visible
    );
    _sidebarWidthAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _sidebarAnimController, curve: Curves.easeInOut),
    );

    // Initialize database service and repository
    final dbHelper = DatabaseHelper();
    final diaryRepository = DiaryRepository(dbHelper);
    _diaryService = DiaryService(diaryRepository);

    // Initialize sync
    _syncController = SyncAnimationController(vsync: this);
    _syncService = SyncService();

    // Subscribe to changes in diary entries
    _diaryChangesSubscription = _diaryService.onDiaryChanged.listen((_) {
      _loadDiaryEntries();
      _entriesPanelKey.currentState?.loadEntries();
    });

    // Initialize everything in parallel and then update state once
    _initializeData();
  }

  Future<void> _initializeData() async {
    try {
      // Load saved settings
      final prefs = await SharedPreferences.getInstance();
      final savedWidth = prefs.getDouble('diary_sidebar_width') ?? 300;
      final editorCentered = prefs.getBool('editor_centered') ?? false;
      final calendarExpanded = prefs.getBool('diary_calendar_expanded') ?? true;

      // Load diary entries

      // Update state once with all loaded data
      if (mounted) {
        setState(() {
          _sidebarWidth = savedWidth;
          _isEditorCentered = editorCentered;
          _isCalendarExpanded = calendarExpanded;
        });
      }
    } catch (e) {
      print('Error in Diary initialization: $e');
      if (mounted) {
        setState(() {});
      }
    }
  }

  @override
  void dispose() {
    _contentController.dispose();
    _titleController.dispose();
    _debounceContent?.cancel();
    _scrollController.dispose();
    _diaryChangesSubscription?.cancel();
    _syncController.dispose();
    _syncService.dispose();
    _appFocusNode.dispose();
    _sidebarAnimController.dispose();
    super.dispose();
  }

  Future<void> _loadDiaryEntries() async {
    try {
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      debugPrint('Error in _loadDiaryEntries: $e');
    }
  }

  Future<void> _createNewDiaryEntry() async {
    try {
      DateTime dateToUse;

      if (_selectedDate != null) {
        // Use the selected date from calendar
        dateToUse = _selectedDate!;
      } else {
        // Use today's date
        dateToUse = DateTime.now();
      }

      final existingEntry = await _diaryService.getDiaryEntryByDate(dateToUse);

      if (existingEntry != null) {
        // If entry for this date exists, open it
        _openDiaryEntry(existingEntry);
        return;
      }

      final createdEntry = await _diaryService.createDiaryEntry(dateToUse);
      if (createdEntry != null) {
        await _loadDiaryEntries();
        _entriesPanelKey.currentState?.loadEntries();
        // Reload calendar data to update the dots
        _calendarPanelKey.currentState?.reloadEntries();
        _openDiaryEntry(createdEntry);
      }
    } catch (e) {
      debugPrint('Error creating Diary Entry: ${e.toString()}');
      if (mounted) {
        CustomSnackbar.show(
          context: context,
          message: 'Error creating Diary Entry: ${e.toString()}',
          type: CustomSnackbarType.error,
        );
      }
    }
  }

  Future<void> _openDiaryEntry(DiaryEntry entry) async {
    try {
      // Save the current entry before opening a new one
      if (_selectedEntry != null) {
        await _saveDiaryEntry();
      }

      setState(() {
        _selectedEntry = entry;
        _contentController.text = entry.content;
      });
    } catch (e) {
      if (mounted) {
        CustomSnackbar.show(
          context: context,
          message: 'Error opening Diary Entry: ${e.toString()}',
          type: CustomSnackbarType.error,
        );
      }
    }
  }

  Future<void> _saveDiaryEntry() async {
    if (_selectedEntry == null) return;

    try {
      // Update the entry with new content
      final updatedEntry = _selectedEntry!.copyWith(
        content: _contentController.text,
        updatedAt: DateTime.now(),
      );

      // Save using service
      await _diaryService.updateDiaryEntry(updatedEntry);

      // Update the reference to the selected entry
      setState(() {
        _selectedEntry = updatedEntry;
      });
    } catch (e) {
      if (mounted) {
        CustomSnackbar.show(
          context: context,
          message: 'Error saving: ${e.toString()}',
          type: CustomSnackbarType.error,
        );
      }
    }
  }

  void _onContentChanged() {
    _debounceContent?.cancel();
    _debounceContent = Timer(const Duration(seconds: 3), _saveDiaryEntry);
  }

  void _onDragUpdate(DragUpdateDetails details) {
    setState(() {
      _sidebarWidth = (_sidebarWidth + details.delta.dx).clamp(250.0, 500.0);
    });
  }

  void _onDragEnd(DragEndDetails details) async {
    await _saveWidth(_sidebarWidth);
  }

  Future<void> _saveWidth(double width) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('diary_sidebar_width', width);
  }

  void _toggleCalendar() async {
    setState(() {
      _isCalendarExpanded = !_isCalendarExpanded;
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('diary_calendar_expanded', _isCalendarExpanded);
  }

  void _toggleSidebar() {
    if (_isSidebarVisible) {
      _sidebarAnimController.reverse().then((_) {
        setState(() {
          _isSidebarVisible = false;
        });
      });
    } else {
      setState(() {
        _isSidebarVisible = true;
      });
      _sidebarAnimController.forward();
    }
  }

  void _onDateSelected(DateTime date) {
    setState(() {
      _selectedDate = date;
    });
  }

  void _openSettings() {
    showDialog(context: context, builder: (context) => const SettingsScreen());
  }

  void _openTrashScreen() {
    showDialog(
      context: context,
      builder:
          (context) => TrashScreen(
            onNotebookRestored: (notebook) {},
            onNoteRestored: (note) {},
            onTrashUpdated: () {},
          ),
    );
  }

  void _openFavoritesScreen() {
    showDialog(
      context: context,
      builder:
          (context) => FavoritesScreen(
            onNotebookSelected: (notebook) {},
            onNoteSelected: (note) {},
            onNoteSelectedFromPanel: (note) {
              // Parent (main) will wire the actual suppression when needed.
              return null;
            },
            onFavoritesUpdated: () {},
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Shortcuts(
      shortcuts: <LogicalKeySet, Intent>{
        LogicalKeySet(LogicalKeyboardKey.f2): const _ToggleSidebarIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          SaveDiaryIntent: CallbackAction<SaveDiaryIntent>(
            onInvoke: (intent) async {
              if (_selectedEntry != null) {
                await _saveDiaryEntry();
              }
              return null;
            },
          ),
          NewDiaryIntent: CallbackAction<NewDiaryIntent>(
            onInvoke: (intent) async {
              await _createNewDiaryEntry();
              return null;
            },
          ),
          _ToggleSidebarIntent: CallbackAction<_ToggleSidebarIntent>(
            onInvoke: (intent) {
              _toggleSidebar();
              return null;
            },
          ),
        },
        child: Focus(
        autofocus: true,
        child: Scaffold(
          body: Stack(
            children: [
              // Main content
              WindowBorder(
                color: Colors.transparent,
                width: 0,
                child: Row(
                  children: [
                    // Left sidebar with new implementation
                    ResizableIconSidebar(
                      rootDir: widget.rootDir,
                      onOpenNote: widget.onOpenNote,
                      onOpenFolder: (_) {},
                      onNotebookSelected: null,
                      onNoteSelected: null,
                      onBack: widget.onClose,
                      onDirectorySet: null,
                      onThemeUpdated: null,
                      onFavoriteRemoved: null,
                      onNavigateToMain: null,
                      onClose: null,
                      onCreateNewNote: _createNewDiaryEntry,
                      onCreateNewNotebook: null,
                      onCreateNewTodo: null,
                      onShowManageTags: null,
                      onCreateThink: null,
                      onOpenSettings: _openSettings,
                      onOpenTrash: _openTrashScreen,
                      onOpenFavorites: _openFavoritesScreen,
                      showBackButton: true,
                      isWorkflowsScreen: false,
                      isTasksScreen: false,
                      isThinksScreen: false,
                      isSettingsScreen: false,
                      isBookmarksScreen: false,
                      isDiaryScreen: true,
                      onToggleCalendar: _toggleCalendar,
                      onToggleSidebar: _toggleSidebar,
                      appFocusNode: _appFocusNode,
                    ),

                    // Animated sidebar
                    AnimatedBuilder(
                      animation: _sidebarWidthAnimation,
                      builder: (context, child) {
                        final animatedWidth = _sidebarWidthAnimation.value * (_sidebarWidth + 1);
                        if (animatedWidth == 0 && !_isSidebarVisible) {
                          return const SizedBox.shrink();
                        }
                        return ClipRect(
                          child: SizedBox(
                            width: animatedWidth,
                            child: OverflowBox(
                              alignment: Alignment.centerLeft,
                              minWidth: 0,
                              maxWidth: _sidebarWidth + 1,
                              child: child,
                            ),
                          ),
                        );
                      },
                      child: Row(
                        children: [
                          VerticalDivider(
                            width: 1,
                            thickness: 1,
                            color: colorScheme.surfaceContainerHighest,
                          ),

                          // Central panel with calendar and entries (resizable)
                          Container(
                          width: _sidebarWidth,
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainerLow,
                          ),
                          child: Stack(
                            children: [
                              Column(
                                children: [
                                  // Calendar panel (expandable) - Fixed height like main calendar
                                  if (_isCalendarExpanded)
                                    Expanded(
                                      flex: 6,
                                      child: DiaryCalendarPanel(
                                        key: _calendarPanelKey,
                                        onDiaryEntrySelected: _openDiaryEntry,
                                        onDateSelected: _onDateSelected,
                                        selectedDate: _selectedDate,
                                        appFocusNode: _appFocusNode,
                                      ),
                                    ),
                                  if (_isCalendarExpanded)
                                    Divider(
                                      height: 1,
                                      thickness: 1,
                                      color: colorScheme.surfaceContainerHighest,
                                    ),
                                  // Entries list
                                  Expanded(
                                    flex: 10,
                                    child: DiaryEntriesPanel(
                                      key: _entriesPanelKey,
                                      selectedEntry: _selectedEntry,
                                      onEntrySelected: _openDiaryEntry,
                                      onEntryDeleted: () async {
                                        // Reload calendar data to update the dots
                                        await _loadDiaryEntries();
                                    _calendarPanelKey.currentState
                                        ?.reloadEntries();
                                    setState(() {});
                                  },
                                ),
                              ),
                            ],
                          ),
                          // Drag handle on the right edge
                          Positioned(
                            right: 0,
                            top: 0,
                            bottom: 0,
                            child: MouseRegion(
                              cursor: SystemMouseCursors.resizeLeftRight,
                              child: GestureDetector(
                                onPanUpdate: _onDragUpdate,
                                onPanEnd: _onDragEnd,
                                child: Container(
                                  width: 8,
                                  color: Colors.transparent,
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

                    // Editor panel
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 24.0),
                        child:
                            _selectedEntry == null
                                ? Center(
                                  child: Text(
                                    'Select a diary entry to edit',
                                    style:
                                        Theme.of(context).textTheme.bodyLarge,
                                  ),
                                )
                                : NotaEditor(
                                  selectedNote: Note(
                                    id: _selectedEntry!.id,
                                    title: DateFormat(
                                      'MMM dd, yyyy',
                                    ).format(_selectedEntry!.date),
                                    content: _selectedEntry!.content,
                                    notebookId: 0,
                                    createdAt: _selectedEntry!.createdAt,
                                    updatedAt: _selectedEntry!.updatedAt,
                                    isFavorite: _selectedEntry!.isFavorite,
                                  ),
                                  noteController: _contentController,
                                  titleController: _titleController,
                                  onSave: _saveDiaryEntry,
                                  isEditorCentered: _isEditorCentered,
                                  onTitleChanged: () {},
                                  onContentChanged: _onContentChanged,
                                ),
                      ),
                    ),
                  ],
                ),
              ),
              // Window controls
              if (Platform.isWindows || Platform.isLinux)
                Positioned(
                  top: 0,
                  right: 0,
                  height: 40,
                  child: Container(
                    color: Colors.transparent,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 46,
                          height: 40,
                          child: MinimizeWindowButton(
                            colors: WindowButtonColors(
                              iconNormal: colorScheme.onSurface,
                              mouseOver: colorScheme.surfaceContainerHighest,
                              mouseDown: colorScheme.surfaceContainerHigh,
                              iconMouseOver: colorScheme.onSurface,
                              iconMouseDown: colorScheme.onSurface,
                            ),
                            onPressed: () {
                              appWindow.minimize();
                            },
                          ),
                        ),
                        SizedBox(
                          width: 46,
                          height: 40,
                          child: MaximizeWindowButton(
                            colors: WindowButtonColors(
                              iconNormal: colorScheme.onSurface,
                              mouseOver: colorScheme.surfaceContainerHighest,
                              mouseDown: colorScheme.surfaceContainerHigh,
                              iconMouseOver: colorScheme.onSurface,
                              iconMouseDown: colorScheme.onSurface,
                            ),
                            onPressed: () {
                              appWindow.maximizeOrRestore();
                            },
                          ),
                        ),
                        SizedBox(
                          width: 46,
                          height: 40,
                          child: CloseWindowButton(
                            colors: WindowButtonColors(
                              iconNormal: colorScheme.onSurface,
                              mouseOver: colorScheme.error,
                              mouseDown: colorScheme.error.withAlpha(128),
                              iconMouseOver: colorScheme.onError,
                              iconMouseDown: colorScheme.onError,
                            ),
                            onPressed: () {
                              appWindow.close();
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              // MoveWindow for the rest of the screen (only the editor area)
              if (Platform.isWindows || Platform.isLinux)
                AnimatedBuilder(
                  animation: _sidebarWidthAnimation,
                  builder: (context, child) {
                    return Positioned(
                      top: 0,
                      left: 60 + (_sidebarWidthAnimation.value * _sidebarWidth),
                      right: 138,
                      height: 40,
                      child: MoveWindow(),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
      ),
    );
  }
}
