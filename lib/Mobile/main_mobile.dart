import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/services.dart';
import 'screens/home_screen.dart';
import 'screens/search_screen.dart';
import 'screens/tasks_screen.dart';
import 'screens/favorites_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/thinks_screen.dart';
import 'screens/bookmarks_screen.dart';
import 'screens/bookmarks_tags_screen.dart' as bookmarks;
import 'screens/tags_screen.dart' as tasks;
import 'theme_handler.dart';
import 'widgets/left_drawer.dart';
import '../database/models/note.dart';
import '../database/models/notebook.dart';
import '../database/models/think.dart';
import '../database/database_helper.dart';
import '../database/repositories/note_repository.dart';
import '../database/repositories/think_repository.dart';
import '../database/services/think_service.dart';
import 'services/webdav_service.dart';
import 'services/bookmark_sharing_handler.dart';
import '../widgets/custom_snackbar.dart';
import 'dart:async';
import 'widgets/think_editor.dart';
import 'screens/calendar_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThinkNoteMobile extends StatefulWidget {
  const ThinkNoteMobile({super.key});

  @override
  State<ThinkNoteMobile> createState() => _ThinkNoteMobileState();
}

class _ThinkNoteMobileState extends State<ThinkNoteMobile>
    with SingleTickerProviderStateMixin {
  int _selectedIndex = 0;
  bool _isImmersiveMode = false;
  bool _isEditing = true;
  late Future<bool> _brightnessFuture;
  late Future<bool> _colorModeFuture;
  late Future<bool> _monochromeFuture;
  late Future<bool> _einkFuture;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final GlobalKey<TasksScreenState> _tasksKey = GlobalKey<TasksScreenState>();
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  final GlobalKey<CalendarScreenState> _calendarKey = GlobalKey<CalendarScreenState>();
  Note? _selectedNote;
  Notebook? _selectedNotebook;
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  final FocusNode _contentFocusNode = FocusNode();
  Timer? _debounceNote;
  Timer? _debounceTitle;
  late final AnimationController _scaleController;
  final GlobalKey<BookmarksScreenState> _bookmarksKey = GlobalKey();

  late List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _loadThemePreferences();
    _noteController.addListener(_onNoteChanged);
    _titleController.addListener(_onTitleChanged);
    _initializeScreens();
    _initializeWebDAV();
    _initializeSharing();
  }

  Future<void> _initializeWebDAV() async {
    try {
      // Check WebDAV configuration first (fast operation)
      final prefs = await SharedPreferences.getInstance();
      final isEnabled = prefs.getBool('webdav_enabled') ?? false;

      if (!isEnabled) {
        return;
      }

      // Initialize and sync WebDAV in background (don't block UI)
      // Database and SyncService are already initialized in main()
      final webdavService = WebDAVService();
      await webdavService.initialize();
      
      // Run sync in background without blocking
      webdavService.sync().catchError((e) {
        print('WebDAV sync error: $e');
      });
    } catch (e) {
      print('Error initializing WebDAV: $e');
    }
  }

  void _initializeScreens() {
    _screens = [
      HomeScreen(
        selectedNote: _selectedNote,
        selectedNotebook: _selectedNotebook,
        titleController: _titleController,
        contentController: _noteController,
        contentFocusNode: _contentFocusNode,
        isEditing: _isEditing,
        isImmersiveMode: _isImmersiveMode,
        onSaveNote: _handleSaveNote,
        onToggleEditing: _handleToggleEditing,
        onTitleChanged: _handleTitleChanged,
        onContentChanged: _handleNoteChanged,
        onToggleImmersiveMode: _handleToggleImmersiveMode,
        onNoteSelected: _handleNoteSelected,
        onNotebookSelected: _handleNotebookSelected,
        onTrashUpdated: _handleTrashUpdated,
      ),
      CalendarScreen(
        key: _calendarKey,
        onNoteSelected: (note) {
          setState(() {
            _selectedNote = note;
            _titleController.text = note.title;
            _noteController.text = note.content;
            _selectedIndex = 0;
            _isEditing = true;
          });
          _initializeScreens();
        },
      ),
      TasksScreen(key: _tasksKey),
      BookmarksScreen(key: _bookmarksKey),
    ];
  }

  void _initializeSharing() {
    // Inicializar el SharingHandler con el navigatorKey
    BookmarkSharingHandler.initSharingListener(_navigatorKey);
  }

  @override
  void dispose() {
    _scaleController.dispose();
    _debounceNote?.cancel();
    _debounceTitle?.cancel();
    _noteController.removeListener(_onNoteChanged);
    _titleController.removeListener(_onTitleChanged);
    _contentFocusNode.dispose();
    _noteController.dispose();
    _titleController.dispose();
    super.dispose();
  }

  void _loadThemePreferences() {
    _brightnessFuture = ThemeManager.getThemeBrightness();
    _colorModeFuture = ThemeManager.getColorModeEnabled();
    _monochromeFuture = ThemeManager.getMonochromeEnabled();
    _einkFuture = ThemeManager.getEInkEnabled();
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  void _openSearchScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => SearchScreen(
              onNoteSelected: (Note note) {
                setState(() {
                  _selectedNote = note;
                  _titleController.text = note.title;
                  _noteController.text = note.content;
                  _selectedIndex = 0;
                  _isEditing = true;
                });
                _initializeScreens();
              },
              onNotebookSelected: (Notebook notebook) async {
                if (mounted) {
                  setState(() {
                    _selectedNotebook = notebook;
                    _selectedIndex = 0;
                  });
                  _initializeScreens();
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ThinkNoteMobile(),
                    ),
                  ).then((_) {
                    if (mounted) {
                      _scaffoldKey.currentState?.openDrawer();
                      Future.delayed(const Duration(milliseconds: 300), () {
                        if (mounted) {
                          setState(() {
                            _selectedNotebook = null;
                          });
                          Future.delayed(
                            const Duration(milliseconds: 50),
                            () {
                              if (mounted) {
                                setState(() {
                                  _selectedNotebook = notebook;
                                });
                              }
                            },
                          );
                        }
                      });
                    }
                  });
                }
              },
            ),
      ),
    );
  }

  void _updateTheme({
    bool? isDarkMode,
    bool? isColorMode,
    bool? isMonochrome,
    bool? isEInk,
  }) async {
    await ThemeManager.saveTheme(
      isDarkMode: isDarkMode ?? false,
      colorModeEnabled: isColorMode,
      monochromeEnabled: isMonochrome,
      einkEnabled: isEInk,
    );
    setState(() {
      _loadThemePreferences();
    });
  }

  void _handleNoteSelected(Note note) {
    setState(() {
      _selectedNote = note;
      _titleController.text = note.title;
      _noteController.text = note.content;
      _selectedIndex = 0;
      _scaffoldKey.currentState?.closeDrawer();
      _isImmersiveMode = false;
    });
    _initializeScreens();
  }

  Future<void> _handleSaveNote() async {
    if (_selectedNote == null) return;

    try {
      final dbHelper = DatabaseHelper();
      final noteRepository = NoteRepository(dbHelper);

      final updatedNote = Note(
        id: _selectedNote!.id,
        title: _titleController.text.trim(),
        content: _noteController.text,
        notebookId: _selectedNote!.notebookId,
        createdAt: _selectedNote!.createdAt,
        updatedAt: DateTime.now(),
        isFavorite: _selectedNote!.isFavorite,
        tags: _selectedNote!.tags,
        orderIndex: _selectedNote!.orderIndex,
        isTask: _selectedNote!.isTask,
        isCompleted: _selectedNote!.isCompleted,
      );

      final result = await noteRepository.updateNote(updatedNote);

      if (result > 0) {
        if (mounted) {
          setState(() {
            _selectedNote = updatedNote;
          });
        }
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
  }

  void _handleToggleEditing() {
    setState(() {
      _isEditing = !_isEditing;
      _initializeScreens();
    });
  }

  void _handleTitleChanged() {
    _debounceTitle?.cancel();
    _debounceTitle = Timer(const Duration(seconds: 1), () {
      if (_selectedNote != null) {
        _handleSaveNote();
      }
    });
  }

  void _handleNoteChanged() {
    _debounceNote?.cancel();
    _debounceNote = Timer(const Duration(seconds: 1), () {
      if (_selectedNote != null) {
        _handleSaveNote();
      }
    });
  }

  void _handleNotebookSelected(Notebook notebook) {
    setState(() {
      _selectedNotebook = notebook;
      _selectedNote = null;
      _titleController.clear();
      _noteController.clear();
    });
    _initializeScreens();
  }

  void _onNoteChanged() {
    _debounceNote?.cancel();
    _debounceNote = Timer(const Duration(seconds: 1), () {
      if (_selectedNote != null) {
        _handleSaveNote();
      }
    });
  }

  void _onTitleChanged() {
    _debounceTitle?.cancel();
    _debounceTitle = Timer(const Duration(seconds: 1), () {
      if (_selectedNote != null) {
        _handleSaveNote();
      }
    });
  }

  void _handleToggleImmersiveMode(bool isImmersive) {
    setState(() {
      _isImmersiveMode = isImmersive;
    });
  }

  void _showThinksScreen() {
    if (_scaleController.status == AnimationStatus.forward) {
      _scaleController.reverse();
    }
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder:
                (context) => DynamicColorBuilder(
                  builder: (
                    ColorScheme? lightDynamic,
                    ColorScheme? darkDynamic,
                  ) {
                    return FutureBuilder(
                      future: Future.wait([
                        _brightnessFuture,
                        _colorModeFuture,
                        _monochromeFuture,
                        _einkFuture,
                      ]),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) return const SizedBox.shrink();

                        final isDarkMode = snapshot.data![0];
                        final colorMode = snapshot.data![1];
                        final monochromeMode = snapshot.data![2];
                        final einkMode = snapshot.data![3];

                        return Theme(
                          data: ThemeManager.buildTheme(
                            lightDynamic: lightDynamic,
                            darkDynamic: darkDynamic,
                            isDarkMode: isDarkMode,
                            colorModeEnabled: colorMode,
                            monochromeEnabled: monochromeMode,
                            einkEnabled: einkMode,
                          ),
                          child: ThinksScreen(
                            onThinkSelected: (Note note) async {
                              setState(() {
                                _selectedNote = note;
                                _titleController.text = note.title;
                                _noteController.text = note.content;
                                _selectedIndex = 0;
                                _isEditing = true;
                              });
                              _initializeScreens();
                            },
                          ),
                        );
                      },
                    );
                  },
                ),
          ),
        )
        .then((_) {
          if (mounted) {
            setState(() {
              _scaleController.value = 0.0;
            });
          }
        });
  }

  void _createNewThink() async {
    try {
      final dbHelper = DatabaseHelper();
      final thinkRepository = ThinkRepository(dbHelper);
      final thinkService = ThinkService(thinkRepository);

      final createdThink = await thinkService.createThink();
      if (createdThink != null) {
        if (mounted) {
          final titleController = TextEditingController(
            text: createdThink.title,
          );
          final contentController = TextEditingController(
            text: createdThink.content,
          );

          Navigator.push(
            context,
            MaterialPageRoute(
              builder:
                  (context) => DynamicColorBuilder(
                    builder: (
                      ColorScheme? lightDynamic,
                      ColorScheme? darkDynamic,
                    ) {
                      return FutureBuilder(
                        future: Future.wait([
                          _brightnessFuture,
                          _colorModeFuture,
                          _monochromeFuture,
                          _einkFuture,
                        ]),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) return const SizedBox.shrink();

                          final isDarkMode = snapshot.data![0];
                          final colorMode = snapshot.data![1];
                          final monochromeMode = snapshot.data![2];
                          final einkMode = snapshot.data![3];

                          return Theme(
                            data: ThemeManager.buildTheme(
                              lightDynamic: lightDynamic,
                              darkDynamic: darkDynamic,
                              isDarkMode: isDarkMode,
                              colorModeEnabled: colorMode,
                              monochromeEnabled: monochromeMode,
                              einkEnabled: einkMode,
                            ),
                            child: ThinkEditor(
                              selectedThink: createdThink,
                              titleController: titleController,
                              contentController: contentController,
                              contentFocusNode: FocusNode(),
                              isEditing: true,
                              isImmersiveMode: false,
                              onSaveThink: () async {
                                try {
                                  final updatedThink = Think(
                                    id: createdThink.id,
                                    title: titleController.text.trim(),
                                    content: contentController.text,
                                    createdAt: createdThink.createdAt,
                                    updatedAt: DateTime.now(),
                                    isFavorite: createdThink.isFavorite,
                                    orderIndex: createdThink.orderIndex,
                                    tags: createdThink.tags,
                                  );

                                  await thinkRepository.updateThink(
                                    updatedThink,
                                  );
                                  DatabaseHelper.notifyDatabaseChanged();
                                } catch (e) {
                                  debugPrint('Error saving think: $e');
                                  if (mounted) {
                                    CustomSnackbar.show(
                                      context: context,
                                      message:
                                          'Error saving think: ${e.toString()}',
                                      type: CustomSnackbarType.error,
                                    );
                                  }
                                }
                              },
                              onToggleEditing: () {},
                              onTitleChanged: () {},
                              onContentChanged: () {},
                              onToggleImmersiveMode: (isImmersive) {},
                            ),
                          );
                        },
                      );
                    },
                  ),
            ),
          ).then((_) {
            if (mounted) {
              setState(() {
                _scaleController.value = 0.0;
              });
            }
          });
        }
      }
    } catch (e) {
      if (mounted) {
        CustomSnackbar.show(
          context: context,
          message: 'Error creating Think: ${e.toString()}',
          type: CustomSnackbarType.error,
        );
      }
    }
  }

  void _handleTrashUpdated() {
    // Notificar a la pantalla de papelera que debe actualizarse
    DatabaseHelper.notifyDatabaseChanged();
  }

  @override
  Widget build(BuildContext context) {
    return DynamicColorBuilder(
      builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
        return FutureBuilder(
          future: Future.wait([
            _brightnessFuture,
            _colorModeFuture,
            _monochromeFuture,
            _einkFuture,
          ]),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const SizedBox.shrink();

            final isDarkMode = snapshot.data![0];
            final colorMode = snapshot.data![1];
            final monochromeMode = snapshot.data![2];
            final einkMode = snapshot.data![3];

            return PopScope(
              canPop: true,
              onPopInvokedWithResult: (bool didPop, bool? result) {
                if (didPop) return;
                // Si no se pudo hacer pop, verificar si hay algo que cerrar
                if (Navigator.canPop(context)) {
                  Navigator.pop(context);
                }
              },
              child: MaterialApp(
                navigatorKey: _navigatorKey,
                theme: ThemeManager.buildTheme(
                  lightDynamic: lightDynamic,
                  darkDynamic: darkDynamic,
                  isDarkMode: isDarkMode,
                  colorModeEnabled: colorMode,
                  monochromeEnabled: monochromeMode,
                  einkEnabled: einkMode,
                ),
                home: Builder(
                  builder: (context) {
                    final colorScheme = Theme.of(context).colorScheme;
                    final isKeyboardVisible =
                        MediaQuery.of(context).viewInsets.bottom > 0;

                    return Scaffold(
                      key: _scaffoldKey,
                      drawer:
                          _selectedIndex == 2 || _selectedIndex == 3
                              ? null
                              : MobileDrawer(
                                onNavigateBack: () {},
                                onCreateNewNotebook: () {},
                                onNotebookSelected: _handleNotebookSelected,
                                selectedNotebook: _selectedNotebook,
                                scaffoldKey: _scaffoldKey,
                              ),
                      drawerEdgeDragWidth:
                          (_selectedIndex == 2 || _selectedIndex == 3)
                              ? 0
                              : 150,
                      onDrawerChanged: (isOpened) {
                        if (isOpened) {
                          FocusManager.instance.primaryFocus?.unfocus();
                        }
                      },
                      extendBodyBehindAppBar: false,
                      appBar: AppBar(
                        automaticallyImplyLeading: false,
                        scrolledUnderElevation: 0,
                        surfaceTintColor: Colors.transparent,
                        backgroundColor: colorScheme.surface,
                        title: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _selectedIndex == 0
                                  ? Icons.home_rounded
                                  : _selectedIndex == 1
                                  ? Icons.calendar_month_rounded
                                  : _selectedIndex == 2
                                  ? Icons.check_circle_rounded
                                  : Icons.bookmarks_rounded,
                              size: 24,
                              color: colorScheme.primary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _selectedIndex == 0
                                  ? 'Home'
                                  : _selectedIndex == 1
                                  ? 'Calendar'
                                  : _selectedIndex == 2
                                  ? 'Tasks'
                                  : 'Bookmarks',
                            ),
                          ],
                        ),
                        actions: [
                          if (_selectedIndex == 0 || _selectedIndex == 1)
                            IconButton(
                              icon: Icon(
                                Icons.cloud_sync_rounded,
                                color: colorScheme.primary,
                              ),
                              onPressed: () async {
                                try {
                                  final webdavService = WebDAVService();
                                  await webdavService.sync();
                                  if (!mounted) return;
                                  CustomSnackbar.show(
                                    context: context,
                                    message:
                                        'Synchronization completed successfully',
                                    type: CustomSnackbarType.success,
                                  );
                                } catch (e) {
                                  if (!mounted) return;
                                  CustomSnackbar.show(
                                    context: context,
                                    message:
                                        'Error in synchronization: ${e.toString()}',
                                    type: CustomSnackbarType.error,
                                  );
                                }
                              },
                            ),
                          if (_selectedIndex == 0)
                            IconButton(
                              icon: Icon(
                                Icons.search_rounded,
                                color: colorScheme.primary,
                              ),
                              onPressed: _openSearchScreen,
                            ),
                          if (_selectedIndex == 2)
                            IconButton(
                              icon: Icon(
                                Icons.label_rounded,
                                color: colorScheme.primary,
                              ),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder:
                                        (context) => const tasks.TagsScreen(),
                                  ),
                                );
                              },
                            ),
                          if (_selectedIndex == 3)
                            IconButton(
                              icon: Icon(
                                Icons.label_rounded,
                                color: colorScheme.primary,
                              ),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder:
                                        (context) =>
                                            const bookmarks.TagsScreen(),
                                  ),
                                );
                              },
                            ),
                          if (_selectedIndex == 1)
                            IconButton(
                              icon: Icon(
                                Icons.label_rounded,
                                color: colorScheme.primary,
                              ),
                              onPressed: () {
                                _calendarKey.currentState?.showStatusManager();
                              },
                            ),
                          IconButton(
                            icon: Icon(
                              Icons.favorite_rounded,
                              color: colorScheme.primary,
                            ),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder:
                                      (context) => FavoritesScreen(
                                        onNotebookSelected: (
                                          Notebook notebook,
                                        ) async {
                                          if (mounted) {
                                            setState(() {
                                              _selectedNotebook = notebook;
                                              _selectedIndex = 0;
                                            });
                                            _initializeScreens();
                                            Navigator.pushReplacement(
                                              context,
                                              MaterialPageRoute(
                                                builder:
                                                    (context) =>
                                                        ThinkNoteMobile(),
                                              ),
                                            ).then((_) {
                                              if (mounted) {
                                                _scaffoldKey.currentState
                                                    ?.openDrawer();
                                                Future.delayed(
                                                  const Duration(
                                                    milliseconds: 300,
                                                  ),
                                                  () {
                                                    if (mounted) {
                                                      setState(() {
                                                        _selectedNotebook =
                                                            null;
                                                      });
                                                      Future.delayed(
                                                        const Duration(
                                                          milliseconds: 50,
                                                        ),
                                                        () {
                                                          if (mounted) {
                                                            setState(() {
                                                              _selectedNotebook =
                                                                  notebook;
                                                            });
                                                          }
                                                        },
                                                      );
                                                    }
                                                  },
                                                );
                                              }
                                            });
                                          }
                                        },
                                        onNoteSelected: _handleNoteSelected,
                                        onThinkSelected: (Think think) async {
                                          setState(() {
                                            _selectedNote = Note(
                                              id: think.id,
                                              title: think.title,
                                              content: think.content,
                                              notebookId: 0,
                                              createdAt: think.createdAt,
                                              updatedAt: think.updatedAt,
                                              isFavorite: think.isFavorite,
                                            );
                                            _titleController.text = think.title;
                                            _noteController.text =
                                                think.content;
                                            _selectedIndex = 0;
                                            _isEditing = true;
                                          });
                                          _initializeScreens();
                                        },
                                        onFavoritesUpdated: () {
                                          setState(() {});
                                        },
                                      ),
                                ),
                              );
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.settings_rounded),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder:
                                      (context) => SettingsScreen(
                                        onUpdateTheme: _updateTheme,
                                        isDarkMode: isDarkMode,
                                        isColorModeEnabled: colorMode,
                                        isMonochromeEnabled: monochromeMode,
                                        isEInkEnabled: einkMode,
                                      ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                      body: _screens[_selectedIndex],
                      bottomNavigationBar: NavigationBar(
                        selectedIndex: _selectedIndex,
                        onDestinationSelected: _onItemTapped,
                        destinations: const [
                          NavigationDestination(
                            icon: Icon(Icons.home_outlined),
                            selectedIcon: Icon(Icons.home_rounded),
                            label: 'Home',
                          ),
                          NavigationDestination(
                            icon: Icon(Icons.calendar_month_outlined),
                            selectedIcon: Icon(Icons.calendar_month_rounded),
                            label: 'Calendar',
                          ),
                          NavigationDestination(
                            icon: Icon(Icons.check_circle_outline_rounded),
                            selectedIcon: Icon(Icons.check_circle_rounded),
                            label: 'Tasks',
                          ),
                          NavigationDestination(
                            icon: Icon(Icons.bookmarks_outlined),
                            selectedIcon: Icon(Icons.bookmarks_rounded),
                            label: 'Bookmarks',
                          ),
                        ],
                        backgroundColor: colorScheme.surfaceContainer,
                        labelBehavior:
                            NavigationDestinationLabelBehavior.onlyShowSelected,
                      ),
                      floatingActionButton:
                          !isKeyboardVisible && !_isImmersiveMode && _selectedIndex != 1
                              ? GestureDetector(
                                onTapDown: (_) {
                                  _scaleController.forward();
                                },
                                onTapUp: (_) {
                                  HapticFeedback.lightImpact();
                                  if (_selectedIndex == 0) {
                                    _createNewThink();
                                  } else if (_selectedIndex == 2) {
                                    _tasksKey.currentState?.createNewTask();
                                  } else if (_selectedIndex == 3) {
                                    _bookmarksKey.currentState?.showAddDialog();
                                  }
                                  _scaleController.reverse();
                                },
                                onTapCancel: () {
                                  _scaleController.reverse();
                                },
                                onLongPressStart: (_) {
                                  if (_selectedIndex == 0) {
                                    _scaleController.forward();
                                  } else if (_selectedIndex == 3) {
                                    _scaleController.forward();
                                  }
                                },
                                onLongPress: () {
                                  if (_selectedIndex == 0 &&
                                      _scaleController.status ==
                                          AnimationStatus.completed) {
                                    _showThinksScreen();
                                  } else if (_selectedIndex == 3 &&
                                      _scaleController.status ==
                                          AnimationStatus.completed) {
                                    _bookmarksKey.currentState?.showSearch();
                                  }
                                },
                                onLongPressEnd: (_) {
                                  if (_selectedIndex == 0 ||
                                      _selectedIndex == 3) {
                                    _scaleController.reverse();
                                  }
                                },
                                child: ScaleTransition(
                                  scale: _scaleController.drive(
                                    Tween<double>(begin: 1.0, end: 1.2).chain(
                                      CurveTween(curve: Curves.easeOutBack),
                                    ),
                                  ),
                                  child: SizedBox(
                                    child: FloatingActionButton(
                                      heroTag: UniqueKey(),
                                      onPressed: null,
                                      backgroundColor: colorScheme.primary,
                                      foregroundColor: colorScheme.onPrimary,
                                      elevation: 4,
                                      child: Icon(
                                        _selectedIndex == 0
                                            ? Symbols.neurology_rounded
                                            : _selectedIndex == 2
                                            ? Symbols.add_task_rounded
                                            : Icons.bookmark_add_rounded,
                                        size: 36,
                                        grade: 200,
                                      ),
                                    ),
                                  ),
                                ),
                              )
                              : null,
                      floatingActionButtonLocation:
                          FloatingActionButtonLocation.centerDocked,
                    );
                  },
                ),
              ),
            );
          },
        );
      },
    );
  }
}
