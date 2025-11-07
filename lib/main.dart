// ignore_for_file: avoid_print, library_private_types_in_public_api

import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:launch_at_startup/launch_at_startup.dart';
import 'package:package_info_plus/package_info_plus.dart';

// Handlers
import 'shortcuts_handler.dart';
import 'theme_handler.dart';
import 'widgets/Editor/editor_screen.dart';
import 'animations/animations_handler.dart';
import 'widgets/notebooks_panel.dart';
import 'widgets/resizable_panel.dart';
import 'widgets/trash_screen.dart';
import 'widgets/favorites_screen.dart';
import 'database/models/note.dart';
import 'database/models/notebook.dart';
import 'database/models/editor_tab.dart';
import 'database/database_helper.dart';
import 'database/repositories/note_repository.dart';
import 'database/repositories/notebook_repository.dart';
import 'database/database_service.dart';
import 'database/sync_service.dart';
import 'Mobile/main_mobile.dart';
import 'widgets/notes_panel.dart';
import 'widgets/custom_snackbar.dart';
import 'widgets/calendar_panel.dart';
import 'widgets/search_screen_desktop.dart';
import 'widgets/Editor/editor_tabs.dart';
import 'database/models/notebook_icons.dart';
import 'widgets/resizable_icon_sidebar.dart';
import 'services/immersive_mode_service.dart';
import 'services/tab_manager.dart';
import 'Settings/editor_settings_panel.dart';
import 'widgets/draggable_header.dart';

class WindowStateManager {
  static const String _windowWidthKey = 'window_width';
  static const String _windowHeightKey = 'window_height';
  static const String _windowXKey = 'window_x';
  static const String _windowYKey = 'window_y';
  static const String _isMaximizedKey = 'window_is_maximized';
  static const String _preMaxWidthKey = 'window_pre_max_width';
  static const String _preMaxHeightKey = 'window_pre_max_height';
  static const String _preMaxXKey = 'window_pre_max_x';
  static const String _preMaxYKey = 'window_pre_max_y';
  static const String _maxMonitorXKey = 'window_max_monitor_x';
  static const String _maxMonitorYKey = 'window_max_monitor_y';

  static Future<void> saveWindowState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isMaximized = await windowManager.isMaximized();
      
      await prefs.setBool(_isMaximizedKey, isMaximized);
      
      if (!isMaximized) {
        // Solo guardar tamaño y posición si no está maximizada
        final size = await windowManager.getSize();
        final position = await windowManager.getPosition();
        
        await prefs.setDouble(_windowWidthKey, size.width);
        await prefs.setDouble(_windowHeightKey, size.height);
        await prefs.setDouble(_windowXKey, position.dx);
        await prefs.setDouble(_windowYKey, position.dy);
      }
    } catch (e) {
      print('Error saving window state: $e');
    }
  }

  static Future<void> savePreMaximizeState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isMaximized = await windowManager.isMaximized();
      
      if (!isMaximized) {
        // Guardar estado actual antes de maximizar
        final size = await windowManager.getSize();
        final position = await windowManager.getPosition();
        
        await prefs.setDouble(_preMaxWidthKey, size.width);
        await prefs.setDouble(_preMaxHeightKey, size.height);
        await prefs.setDouble(_preMaxXKey, position.dx);
        await prefs.setDouble(_preMaxYKey, position.dy);
      }
    } catch (e) {
      print('Error saving pre-maximize state: $e');
    }
  }

  static Future<void> onMaximized() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_isMaximizedKey, true);
      
      // Guardar la posición del monitor donde se maximizó
      final position = await windowManager.getPosition();
      await prefs.setDouble(_maxMonitorXKey, position.dx);
      await prefs.setDouble(_maxMonitorYKey, position.dy);
      
    } catch (e) {
      print('Error saving maximized state: $e');
    }
  }

  static Future<void> onUnmaximized() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_isMaximizedKey, false);
    
    // Restaurar al tamaño y posición previa, pero ajustar la posición al monitor actual
    final preMaxWidth = prefs.getDouble(_preMaxWidthKey);
    final preMaxHeight = prefs.getDouble(_preMaxHeightKey);
    
    if (preMaxWidth != null && preMaxHeight != null) {
      // Usar el tamaño previo
      await windowManager.setSize(Size(preMaxWidth, preMaxHeight));
      
      // Usar una posición centrada en la pantalla actual
      // En lugar de tratar de calcular el monitor exacto, simplemente centrar
      await windowManager.center();
      
      // Obtener la nueva posición centrada
      final newPosition = await windowManager.getPosition();
      
      // Guardar esta nueva posición como estado normal
      await prefs.setDouble(_windowWidthKey, preMaxWidth);
      await prefs.setDouble(_windowHeightKey, preMaxHeight);
      await prefs.setDouble(_windowXKey, newPosition.dx);
      await prefs.setDouble(_windowYKey, newPosition.dy);
    }
  }

  static Future<void> restoreWindowState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isMaximized = prefs.getBool(_isMaximizedKey) ?? false;
      
      if (isMaximized) {
        // Obtener la posición del monitor donde se maximizó
        final maxMonitorX = prefs.getDouble(_maxMonitorXKey);
        final maxMonitorY = prefs.getDouble(_maxMonitorYKey);
        
        if (maxMonitorX != null && maxMonitorY != null) {
          // Primero posicionar la ventana en el monitor correcto
          // Usar una posición temporal en el monitor donde se maximizó
          await windowManager.setPosition(Offset(maxMonitorX, maxMonitorY));
        }
        
        // Luego maximizar en ese monitor
        await windowManager.maximize();
      } else {
        // Restaurar tamaño y posición normal
        final savedWidth = prefs.getDouble(_windowWidthKey);
        final savedHeight = prefs.getDouble(_windowHeightKey);
        final savedX = prefs.getDouble(_windowXKey);
        final savedY = prefs.getDouble(_windowYKey);
        
        if (savedWidth != null && savedHeight != null) {
          await windowManager.setSize(Size(savedWidth, savedHeight));
        }
        
        if (savedX != null && savedY != null) {
          await windowManager.setPosition(Offset(savedX, savedY));
        }
      }
    } catch (e) {
      print('Error restoring window state: $e');
    }
  }

  static Future<Offset?> getMaximizedMonitorPosition() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final maxMonitorX = prefs.getDouble(_maxMonitorXKey);
      final maxMonitorY = prefs.getDouble(_maxMonitorYKey);
      
      return maxMonitorX != null && maxMonitorY != null 
          ? Offset(maxMonitorX, maxMonitorY) 
          : null;
    } catch (e) {
      print('Error getting maximized monitor position: $e');
      return null;
    }
  }

  static Future<Size> getDefaultSize() async {
    final prefs = await SharedPreferences.getInstance();
    final savedWidth = prefs.getDouble(_windowWidthKey);
    final savedHeight = prefs.getDouble(_windowHeightKey);
    
    return savedWidth != null && savedHeight != null
        ? Size(savedWidth, savedHeight)
        : const Size(800, 600);
  }

  static Future<Offset?> getDefaultPosition() async {
    final prefs = await SharedPreferences.getInstance();
    final savedX = prefs.getDouble(_windowXKey);
    final savedY = prefs.getDouble(_windowYKey);
    
    return savedX != null && savedY != null ? Offset(savedX, savedY) : null;
  }

  static Future<bool> shouldStartMaximized() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isMaximized = prefs.getBool(_isMaximizedKey);
      return isMaximized ?? false;
    } catch (e) {
      print('Error checking maximized state: $e');
      return false;
    }
  }
}

class WindowEventHandler extends WindowListener {
  bool _isMaximizedBefore = false;

  @override
  void onWindowResize() async {
    try {
      // Solo guardar si no está maximizada para evitar sobrescribir el estado pre-maximizado
      final isMaximized = await windowManager.isMaximized();
      if (!isMaximized) {
        await WindowStateManager.saveWindowState();
      }
    } catch (e) {
      print('Error in onWindowResize: $e');
    }
  }

  @override
  void onWindowMove() async {
    try {
      // Solo guardar si no está maximizada
      final isMaximized = await windowManager.isMaximized();
      if (!isMaximized) {
        await WindowStateManager.saveWindowState();
      }
    } catch (e) {
      print('Error in onWindowMove: $e');
    }
  }

  @override
  void onWindowMaximize() async {
    try {
      await WindowStateManager.onMaximized();
      _isMaximizedBefore = true;
    } catch (e) {
      print('Error in onWindowMaximize: $e');
    }
  }

  @override
  void onWindowUnmaximize() async {
    try {
      await WindowStateManager.onUnmaximized();
      _isMaximizedBefore = false;
    } catch (e) {
      print('Error in onWindowUnmaximize: $e');
    }
  }

  @override
  void onWindowClose() async {
    try {
      // Guardar estado final antes de cerrar
      await WindowStateManager.saveWindowState();
    } catch (e) {
      print('Error in onWindowClose: $e');
    }
  }

  @override
  void onWindowFocus() async {
    try {
      // Verificar si el estado de maximizado cambió (para casos donde se maximiza por otros medios)
      final isMaximized = await windowManager.isMaximized();
      if (isMaximized && !_isMaximizedBefore) {
        // Se acaba de maximizar por otros medios (doble click en title bar, etc.)
        await WindowStateManager.savePreMaximizeState();
        await WindowStateManager.onMaximized();
        _isMaximizedBefore = true;
      } else if (!isMaximized && _isMaximizedBefore) {
        // Se acaba de restaurar por otros medios
        await WindowStateManager.onUnmaximized();
        _isMaximizedBefore = false;
      }
    } catch (e) {
      print('Error in onWindowFocus: $e');
    }
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isWindows) {
    PackageInfo packageInfo = await PackageInfo.fromPlatform();
    launchAtStartup.setup(
      appName: packageInfo.appName,
      appPath: Platform.resolvedExecutable,
    );
  }

  final iconSidebarState = GlobalIconSidebarState();
  await iconSidebarState.initialize();

  try {
    await DatabaseService().initializeDatabase();
    final syncService = SyncService();
    await syncService.initialize();

    final immersiveModeService = ImmersiveModeService();
    await immersiveModeService.initialize();
  } catch (e) {
    debugPrint('Error al inicializar la base de datos: $e');
  }

  final themeColor = await ThemeManager.getThemeColor();
  final themeBrightness = await ThemeManager.getThemeBrightness();
  final colorMode = await ThemeManager.getColorModeEnabled();
  final monochromeMode = await ThemeManager.getMonochromeEnabled();
  final catppuccinEnabled = await ThemeManager.getCatppuccinEnabled();
  final catppuccinFlavor = await ThemeManager.getCatppuccinFlavor();
  final catppuccinAccent = await ThemeManager.getCatppuccinAccent();

  final initialTheme = ThemeManager.buildTheme(
    color: themeColor,
    brightness: themeBrightness,
    colorMode: colorMode,
    customAdjustmentsEnabled: false,
    saturation: 1.0,
    brightnessValue: 1.0,
    monochromeEnabled: monochromeMode,
    catppuccinEnabled: catppuccinEnabled,
    catppuccinFlavor: catppuccinFlavor,
    catppuccinAccent: catppuccinAccent,
  );

  try {
    await EditorSettings.preloadSettings();
  } catch (e) {
    debugPrint('Error initializing editor settings cache: $e');
  }

  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    await windowManager.ensureInitialized();

    final shouldStartMaximized = await WindowStateManager.shouldStartMaximized();
    final defaultSize = await WindowStateManager.getDefaultSize();
    final defaultPosition = await WindowStateManager.getDefaultPosition();
    final maximizedMonitorPosition = await WindowStateManager.getMaximizedMonitorPosition();

    WindowOptions windowOptions = WindowOptions(
      size: defaultSize,
      minimumSize: const Size(800, 600),
      center: defaultPosition == null && !shouldStartMaximized,
      title: 'ThinkNote',
      titleBarStyle:
          Platform.isLinux ? TitleBarStyle.hidden : TitleBarStyle.normal,
      backgroundColor: Colors.transparent,
      skipTaskbar: false,
    );

    await windowManager.waitUntilReadyToShow(windowOptions);

    // Si debe empezar maximizada, posicionar en el monitor correcto primero
    if (shouldStartMaximized && maximizedMonitorPosition != null) {
      await windowManager.setPosition(maximizedMonitorPosition);
    } else if (defaultPosition != null && !shouldStartMaximized) {
      // Configurar posición normal si no debe empezar maximizada
      await windowManager.setPosition(defaultPosition);
    }

    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      // Agregar listener antes de mostrar
      windowManager.addListener(WindowEventHandler());
    }
  }

  runApp(ThinkNoteApp(initialTheme: initialTheme));
}

class ThinkNoteApp extends StatefulWidget {
  final ThemeData initialTheme;

  const ThinkNoteApp({super.key, required this.initialTheme});

  @override
  State<ThinkNoteApp> createState() => _ThinkNoteAppState();
}

class _ThinkNoteAppState extends State<ThinkNoteApp> {
  late Future<Color> _colorFuture;
  late Future<Brightness> _brightnessFuture;
  late Future<bool> _colorModeFuture;
  late ThemeData _currentTheme;

  final GlobalKey<_ThinkNoteHomeState> thinkNoteHomeKey =
      GlobalKey<_ThinkNoteHomeState>();

  @override
  void initState() {
    super.initState();
    _currentTheme = widget.initialTheme;
    _initializeTheme();
    _handleDelayedMaximize();
  }

  Future<void> _handleDelayedMaximize() async {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      // Esperar a que la UI esté completamente renderizada
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await Future.delayed(const Duration(milliseconds: 50));
        
        if (mounted) {
          final shouldStartMaximized = await WindowStateManager.shouldStartMaximized();
          if (shouldStartMaximized) {
            final maximizedMonitorPosition = await WindowStateManager.getMaximizedMonitorPosition();
            
            // Si tenemos información del monitor, posicionar primero
            if (maximizedMonitorPosition != null) {
              await windowManager.setPosition(maximizedMonitorPosition);
              await Future.delayed(const Duration(milliseconds: 10));
            }
            
            await windowManager.maximize();
          }
        }
      });
    }
  }

  Future<void> _initializeTheme() async {
    try {
      _colorFuture = ThemeManager.getThemeColor();
      _brightnessFuture = ThemeManager.getThemeBrightness();
      _colorModeFuture = ThemeManager.getColorModeEnabled();

      final results = await Future.wait([
        _colorFuture,
        _brightnessFuture,
        _colorModeFuture,
        ThemeManager.getMonochromeEnabled(),
        ThemeManager.getCatppuccinEnabled(),
        ThemeManager.getCatppuccinFlavor(),
        ThemeManager.getCatppuccinAccent(),
      ]);

      if (mounted) {
        setState(() {
          _currentTheme = ThemeManager.buildTheme(
            color: results[0] as Color,
            brightness: results[1] as Brightness,
            colorMode: results[2] as bool,
            customAdjustmentsEnabled: false,
            saturation: 1.0,
            brightnessValue: 1.0,
            monochromeEnabled: results[3] as bool,
            catppuccinEnabled: results[4] as bool,
            catppuccinFlavor: results[5] as String,
            catppuccinAccent: results[6] as String,
          );
        });

        await Future.delayed(const Duration(milliseconds: 100));

        if (Platform.isWindows || Platform.isLinux) {
          if (!mounted) return;

          try {
            await windowManager.show();
            await windowManager.focus();
          } catch (e) {
            debugPrint('Error showing window: $e');
          }
        }
      }
    } catch (e) {
      debugPrint('Error initializing theme: $e');
    }
  }

  void _updateTheme() async {
    try {
      final results = await Future.wait([
        ThemeManager.getThemeColor(),
        ThemeManager.getThemeBrightness(),
        ThemeManager.getColorModeEnabled(),
        ThemeManager.getMonochromeEnabled(),
        ThemeManager.getCatppuccinEnabled(),
        ThemeManager.getCatppuccinFlavor(),
        ThemeManager.getCatppuccinAccent(),
      ]);

      if (mounted) {
        setState(() {
          _currentTheme = ThemeManager.buildTheme(
            color: results[0] as Color,
            brightness: results[1] as Brightness,
            colorMode: results[2] as bool,
            customAdjustmentsEnabled: false,
            saturation: 1.0,
            brightnessValue: 1.0,
            monochromeEnabled: results[3] as bool,
            catppuccinEnabled: results[4] as bool,
            catppuccinFlavor: results[5] as String,
            catppuccinAccent: results[6] as String,
          );
        });
      }
    } catch (e) {
      debugPrint('Error updating theme: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ThinkNotes',
      theme: _currentTheme,
      home:
          Platform.isAndroid
              ? const ThinkNoteMobile()
              : (Platform.isWindows || Platform.isLinux)
              ? Builder(
                builder: (context) {
                  final colorScheme = Theme.of(context).colorScheme;
                  return Scaffold(
                    body: Stack(
                      children: [
                        WindowBorder(
                          color: Colors.transparent,
                          width: 0,
                          child: ThinkNoteHome(
                            key: thinkNoteHomeKey,
                            onThemeUpdated: _updateTheme,
                          ),
                        ),
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
                                      mouseOver:
                                          colorScheme.surfaceContainerHighest,
                                      mouseDown:
                                          colorScheme.surfaceContainerHigh,
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
                                      mouseOver:
                                          colorScheme.surfaceContainerHighest,
                                      mouseDown:
                                          colorScheme.surfaceContainerHigh,
                                      iconMouseOver: colorScheme.onSurface,
                                      iconMouseDown: colorScheme.onSurface,
                                    ),
                                    onPressed: () async {
                                      try {
                                        final isMaximized = await windowManager.isMaximized();
                                        
                                        if (!isMaximized) {
                                          // Guardar estado antes de maximizar
                                          await WindowStateManager.savePreMaximizeState();
                                        }
                                        
                                        appWindow.maximizeOrRestore();
                                        
                                        // Pequeño delay para asegurar que el estado se actualice
                                        await Future.delayed(const Duration(milliseconds: 50));
                                        
                                        // Guardar el nuevo estado
                                        await WindowStateManager.saveWindowState();
                                      } catch (e) {
                                        print('Error in maximize button: $e');
                                      }
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
                                      mouseDown: colorScheme.error.withAlpha(
                                        128,
                                      ),
                                      iconMouseOver: colorScheme.onError,
                                      iconMouseDown: colorScheme.onError,
                                    ),
                                    onPressed: () async {
                                      try {
                                        // Guardar estado antes de cerrar
                                        await WindowStateManager.saveWindowState();
                                        appWindow.close();
                                      } catch (e) {
                                        print('Error saving state before close: $e');
                                        appWindow.close(); // Cerrar de todas formas
                                      }
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              )
              : ThinkNoteHome(
                key: thinkNoteHomeKey,
                onThemeUpdated: _updateTheme,
              ),
    );
  }
}

class ThinkNoteHome extends StatefulWidget {
  final VoidCallback onThemeUpdated;

  const ThinkNoteHome({super.key, required this.onThemeUpdated});

  @override
  State<ThinkNoteHome> createState() => _ThinkNoteHomeState();
}

class _ThinkNoteHomeState extends State<ThinkNoteHome>
    with SingleTickerProviderStateMixin {
  Note? _selectedNote;
  Notebook? _selectedNotebook;
  late TextEditingController _noteController;
  late TextEditingController _titleController;
  bool isEditing = false;
  bool isSaving = false;
  bool showSavedIndicator = false;
  bool _isDialogOpen = false;
  VoidCallback? _closeCurrentDialog;
  final FocusNode _appFocusNode = FocusNode();
  Timer? _debounceNote;
  Timer? _debounceTitle;
  Timer? _autoSyncTimer;
  bool _isEditorCentered = false;
  bool _isEditorCenteredTemporary = false;
  final GlobalKey<ResizableIconSidebarState> _iconSidebarKey =
      GlobalKey<ResizableIconSidebarState>();
  final GlobalKey<ResizablePanelState> _sidebarKey =
      GlobalKey<ResizablePanelState>();
  final GlobalKey<DatabaseSidebarState> _databaseSidebarKey =
      GlobalKey<DatabaseSidebarState>();
  final GlobalKey<ResizablePanelState> _notesPanelKey =
      GlobalKey<ResizablePanelState>();
  final GlobalKey<NotesPanelState> _notesPanelStateKey =
      GlobalKey<NotesPanelState>();
  final GlobalKey<ResizablePanelLeftState> _calendarPanelKey =
      GlobalKey<ResizablePanelLeftState>();
  final GlobalKey<EditorTabsState> _editorTabsKey =
      GlobalKey<EditorTabsState>();
  late SyncAnimationController _syncController;
  late final SyncService _syncService;
  final Map<int, AnimationController> _animationControllers = {};
  static const String _lastSelectedNotebookIdKey = 'last_selected_notebook_id';
  late ImmersiveModeService _immersiveModeService;
  String _searchQuery = '';
  bool _isAdvancedSearch = false;
  StreamSubscription? _editorCenteredSubscription;
  StreamSubscription? _hideTabsInImmersiveSubscription;
  late TabManager _tabManager;

  bool _isLoadingNoteContent = false;

  @override
  void initState() {
    super.initState();
    _syncController = SyncAnimationController(vsync: this);
    _noteController = TextEditingController();
    _titleController = TextEditingController();
    // Los listeners se manejan en cada pestaña individualmente
    _tabManager = TabManager();
    _tabManager.addListener(() {
      if (mounted) setState(() {});
    });
    
    // Configure notebook change callback for note links
    _tabManager.onNotebookChangeRequested = (Note note) async {
      final notebookId = note.notebookId;
      
      if (mounted && _selectedNotebook?.id != notebookId) {
        try {
          // Create notebook repository instance
          final dbHelper = DatabaseHelper();
          final notebookRepository = NotebookRepository(dbHelper);
          
          // Load the target notebook
          final notebook = await notebookRepository.getNotebook(notebookId);
          
          if (notebook != null && mounted) {
            setState(() {
              _selectedNotebook = notebook;
            });
            
            await _saveLastSelectedNotebook(notebookId);
            
            // Reload notes panel and select the specific note
            _notesPanelStateKey.currentState?.selectNoteAfterNotebookChange(note);
          }
        } catch (e) {
          debugPrint('Error changing notebook from note link: $e');
        }
      } else {
        debugPrint('DEBUG: Same notebook or widget not mounted');
        // Even if same notebook, we should still select the note
        if (mounted) {
          _notesPanelStateKey.currentState?.selectNoteAfterNotebookChange(note);
        }
      }
    };
    // Load saved tabs or create initial empty tab
    _loadSavedTabs();
    _loadEditorSettings();
    _initializeRepositories();
    _loadLastSelectedNotebook();
    _startAutoSyncTimer();
    _initializeImmersiveMode();
    _setupEditorSettingsListeners();
    _setupDatabaseChangeListener();
  }

  void _initializeImmersiveMode() {
    _immersiveModeService = ImmersiveModeService();
    _immersiveModeService.addListener(_onImmersiveModeChanged);
  }

  void _setupEditorSettingsListeners() {
    _editorCenteredSubscription?.cancel();
    _editorCenteredSubscription = EditorSettingsEvents.editorCenteredStream
        .listen((isCentered) {
          if (mounted) {
            setState(() {
              _isEditorCentered = isCentered;
              if (_selectedNote == null) {
                _isEditorCenteredTemporary = isCentered;
              }
            });
          }
        });

    _hideTabsInImmersiveSubscription?.cancel();
    _hideTabsInImmersiveSubscription = EditorSettingsEvents
        .hideTabsInImmersiveStream
        .listen((hideTabs) {
          if (mounted) {
            setState(() {});
          }
        });
  }

  void _setupDatabaseChangeListener() {
    // Listen for database changes and check for deleted notes in tabs
    DatabaseService().onDatabaseChanged.listen((_) {
      if (mounted) {
        _checkAndCloseDeletedNoteTabs();
      }
    });
  }

  void _resetTemporaryEditorState() {
    if (mounted) {
      setState(() {
        _isEditorCenteredTemporary = _isEditorCentered;
      });
    }
  }

  void _selectNote(Note? note) {
    setState(() {
      _selectedNote = note;
      _resetTemporaryEditorState();
    });
  }

  void _loadNoteContent(Note note) {
    _isLoadingNoteContent = true;
    final activeTab = _tabManager.activeTab;
    if (activeTab != null) {
      activeTab.titleController.text = note.title;
      activeTab.noteController.text = note.content;
    } else {
      _titleController.text = note.title;
      _noteController.text = note.content;
    }
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        _isLoadingNoteContent = false;
      }
    });
  }

  void _onImmersiveModeChanged() {
    if (mounted) {
      setState(() {});
      _handleImmersiveModeChange();
    }
  }

  void _handleImmersiveModeChange() {
    if (_immersiveModeService.isImmersiveMode) {
      _immersiveModeService.savePanelStates(
        iconSidebarExpanded: _iconSidebarKey.currentState?.isExpanded ?? true,
        notebooksPanelExpanded: _sidebarKey.currentState?.isExpanded ?? true,
        notesPanelExpanded: _notesPanelKey.currentState?.isExpanded ?? true,
        calendarPanelExpanded:
            _calendarPanelKey.currentState?.isExpanded ?? true,
      );

      _sidebarKey.currentState?.collapsePanel();
      _notesPanelKey.currentState?.collapsePanel();
      _calendarPanelKey.currentState?.collapsePanel();
      _iconSidebarKey.currentState?.collapsePanel();
    } else {
      final savedStates = _immersiveModeService.getSavedPanelStates();

      if (savedStates['iconSidebar'] == true) {
        _iconSidebarKey.currentState?.expandPanel();
      }

      if (savedStates['notebooks'] == true) {
        _sidebarKey.currentState?.expandPanel();
      }

      if (savedStates['notes'] == true) {
        _notesPanelKey.currentState?.expandPanel();
      }

      if (savedStates['calendar'] == true) {
        _calendarPanelKey.currentState?.expandPanel();
      }
    }
  }

  void _startAutoSyncTimer() {
    _autoSyncTimer = Timer.periodic(const Duration(minutes: 30), (timer) {
      _performAutoSync();
    });
  }

  Future<void> _performAutoSync() async {
    try {
      await _syncService.forceSync();

      DatabaseHelper.notifyDatabaseChanged();

      if (mounted) {
        _databaseSidebarKey.currentState?.reloadSidebar();
        _notesPanelStateKey.currentState?.reloadSidebar();
      }

    } catch (e) {
      debugPrint('Auto-sync error: $e');
    }
  }

  Future<void> _loadEditorSettings() async {
    final isEditorCentered = await EditorSettings.getEditorCentered();

    if (mounted) {
      setState(() {
        _isEditorCentered = isEditorCentered;
        _isEditorCenteredTemporary = isEditorCentered;
      });
    }

    if (_selectedNote != null) {
      setState(() {});
    }
  }

  Future<void> _handleSave() async {
    final activeTab = _tabManager.activeTab;
    if (activeTab?.note == null || isSaving || _isLoadingNoteContent) {
      return;
    }
    setState(() {
      isSaving = true;
    });

    try {
      final dbHelper = DatabaseHelper();
      final noteRepository = NoteRepository(dbHelper);

      final updatedNote = Note(
        id: activeTab!.note!.id,
        title: activeTab.titleController.text.trim(),
        content: activeTab.noteController.text,
        notebookId: activeTab.note!.notebookId,
        createdAt: activeTab.note!.createdAt,
        updatedAt: DateTime.now(),
        isFavorite: activeTab.note!.isFavorite,
        tags: activeTab.note!.tags,
        orderIndex: activeTab.note!.orderIndex,
        isTask: activeTab.note!.isTask,
        isCompleted: activeTab.note!.isCompleted,
      );

      final result = await noteRepository.updateNote(updatedNote);

      if (result > 0) {
        setState(() {
          _selectedNote = updatedNote;
          showSavedIndicator = true;
        });

        // Update tab manager
        _tabManager.markTabAsSaved(activeTab);
        _tabManager.updateNoteInTab(updatedNote);

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
    } finally {
      if (mounted) {
        setState(() {
          isSaving = false;
        });
      }
    }
  }

  Future<void> createNewNote() async {
    final dbHelper = DatabaseHelper();
    final noteRepository = NoteRepository(dbHelper);

    try {
      if (_selectedNotebook?.id == null) {
        if (mounted) {
          CustomSnackbar.show(
            context: context,
            message: 'Please select a notebook first to create a note',
            type: CustomSnackbarType.error,
          );
        }
        return;
      }

      final newNote = Note(
        title: 'New Note',
        content: '',
        notebookId: _selectedNotebook!.id!,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        isFavorite: false,
        tags: '',
      );

      final noteId = await noteRepository.createNote(newNote);
      final createdNote = await noteRepository.getNote(noteId);

      if (createdNote != null) {
        // Open the new note in a new tab
        _tabManager.openTab(createdNote);
        _selectNote(createdNote);
        _databaseSidebarKey.currentState?.reloadSidebar();
        DatabaseHelper.notifyDatabaseChanged();

        // Move focus to editor after creating a new note
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted && _appFocusNode.canRequestFocus) {
            FocusScope.of(context).requestFocus(_appFocusNode);
          }
        });
      }
    } catch (e) {
      debugPrint('Error creating note: $e');
      if (mounted) {
        CustomSnackbar.show(
          context: context,
          message:
              'Error creating note: ${e.toString().replaceAll('Exception: ', '')}',
          type: CustomSnackbarType.error,
        );
      }
    }
  }

  Future<void> createNewTodo() async {
    final dbHelper = DatabaseHelper();
    final noteRepository = NoteRepository(dbHelper);

    try {
      if (_selectedNotebook?.id == null) {
        if (mounted) {
          CustomSnackbar.show(
            context: context,
            message: 'Please select a notebook first to create a todo',
            type: CustomSnackbarType.error,
          );
        }
        return;
      }

      final newTodo = Note(
        title: 'New Todo',
        content: '',
        notebookId: _selectedNotebook!.id!,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        isFavorite: false,
        tags: '',
        isTask: true,
        isCompleted: false,
      );

      final noteId = await noteRepository.createNote(newTodo);
      final createdTodo = await noteRepository.getNote(noteId);

      if (createdTodo != null) {
        // Open the new todo in a new tab
        _tabManager.openTab(createdTodo);
        _selectNote(createdTodo);
        _databaseSidebarKey.currentState?.reloadSidebar();
        DatabaseHelper.notifyDatabaseChanged();

        // Move focus to editor after creating a new todo
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted && _appFocusNode.canRequestFocus) {
            FocusScope.of(context).requestFocus(_appFocusNode);
          }
        });
      }
    } catch (e) {
      debugPrint('Error creating todo: $e');
      if (mounted) {
        CustomSnackbar.show(
          context: context,
          message:
              'Error creating todo: ${e.toString().replaceAll('Exception: ', '')}',
          type: CustomSnackbarType.error,
        );
      }
    }
  }

  Future<void> createNewNotebook() async {
    final dbHelper = DatabaseHelper();
    final notebookRepository = NotebookRepository(dbHelper);

    try {
      final name = await _promptForName('Name of new Notebook', 'Name');
      if (name == null || name.trim().isEmpty) return;

      final newNotebook = Notebook(
        name: name.trim(),
        parentId: _selectedNotebook?.id,
        createdAt: DateTime.now(),
        iconId: NotebookIconsRepository.getDefaultIcon().id,
      );

      final notebookId = await notebookRepository.createNotebook(newNotebook);
      final createdNotebook = await notebookRepository.getNotebook(notebookId);

      if (createdNotebook != null) {
        setState(() {
          _selectedNotebook = createdNotebook;
        });
        _databaseSidebarKey.currentState?.reloadSidebar();
      }
    } catch (e) {
      debugPrint('Error creating notebook: $e');
      if (mounted) {
        CustomSnackbar.show(
          context: context,
          message:
              'Error creating notebook: ${e.toString().replaceAll('Exception: ', '')}',
          type: CustomSnackbarType.error,
        );
      }
    }
  }

  Future<String?> _promptForName(
    String title,
    String label, {
    String? initialValue,
  }) async {
    final nameController = TextEditingController(text: initialValue);
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<String>(
      barrierDismissible: true,
      context: context,
      builder: (context) {
        final FocusNode focusNode = FocusNode();

        WidgetsBinding.instance.addPostFrameCallback((_) {
          Future.delayed(const Duration(milliseconds: 100), () {
            if (focusNode.canRequestFocus) {
              focusNode.requestFocus();
            }
          });
        });

        WidgetsBinding.instance.addPostFrameCallback((_) {
          registerDialog(() {
            Navigator.of(context).pop();
          });
        });

        return AppShortcuts(
          shortcuts: ShortcutsHandler.getDialogShortcuts(
            onConfirm: () {
              if (nameController.text.isNotEmpty) {
                Navigator.of(context).pop(nameController.text);
              }
            },
            onCancel: () => Navigator.of(context).pop(null),
          ),
          child: Focus(
            autofocus: true,
            child: Dialog(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 400,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          height: 56,
                          decoration: BoxDecoration(),
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            children: [
                              Icon(
                                Icons.edit_rounded,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                title,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const Spacer(),
                              IconButton(
                                icon: Icon(
                                  Icons.close_rounded,
                                  color:
                                      Theme.of(context).colorScheme.onSurface,
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
                                controller: nameController,
                                focusNode: focusNode,
                                autofocus: true,
                                decoration: InputDecoration(
                                  labelText: label,
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
                                onFieldSubmitted: (value) {
                                  if (formKey.currentState!.validate()) {
                                    Navigator.of(context).pop(value);
                                  }
                                },
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter a name';
                                  }
                                  return null;
                                },
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
                                        Theme.of(
                                          context,
                                        ).colorScheme.surfaceContainerHigh,
                                    foregroundColor:
                                        Theme.of(context).colorScheme.onSurface,
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
                                  onPressed: () {
                                    if (formKey.currentState!.validate()) {
                                      Navigator.of(
                                        context,
                                      ).pop(nameController.text);
                                    }
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor:
                                        Theme.of(context).colorScheme.primary,
                                    foregroundColor:
                                        Theme.of(context).colorScheme.onPrimary,
                                    minimumSize: const Size(0, 44),
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  child: const Text(
                                    'Accept',
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
            ),
          ),
        );
      },
    );

    return result;
  }

  void _toggleEditorCentered() async {
    setState(() {
      _isEditorCenteredTemporary = !_isEditorCenteredTemporary;
    });
  }

  void registerDialog(VoidCallback closeCallback) {
    _isDialogOpen = true;
    _closeCurrentDialog = closeCallback;
  }

  void closeCurrentDialog() {
    if (_isDialogOpen && _closeCurrentDialog != null && mounted) {
      try {
        _closeCurrentDialog!();
        _isDialogOpen = false;
        _closeCurrentDialog = null;
      } catch (e) {
        debugPrint('Error while closing dialog: $e');
        if (mounted && Navigator.canPop(context)) {
          Navigator.pop(context);
        }
      }
    }
  }

  void _onNoteSelected(Note note) async {
    // Save current note if exists and has unsaved changes
    final activeTab = _tabManager.activeTab;
    if (_selectedNote != null && activeTab?.isDirty == true) {
      await _handleSave();
    }

    setState(() {
      _searchQuery = '';
      _isAdvancedSearch = false;
    });

    // Check if tab with this note already exists
    final existingTab = _tabManager.tabs.firstWhere(
      (tab) => tab.note?.id == note.id,
      orElse:
          () => EditorTab(
            note: null,
            noteController: TextEditingController(),
            titleController: TextEditingController(),
            lastAccessed: DateTime.now(),
          ),
    );

    if (existingTab.note != null) {
      // Tab already exists, just select it
      _tabManager.selectTab(existingTab);
      _loadNoteContent(note);
      _selectNote(note);

      // Move focus to editor after selecting existing tab
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted && _appFocusNode.canRequestFocus) {
          FocusScope.of(context).requestFocus(_appFocusNode);
        }
      });
    } else {
      // Check if active tab exists and decide where to open the note
      final activeTab = _tabManager.activeTab;
      if (activeTab != null) {
        // If the active tab is pinned, do not overwrite it: open in a new tab instead
        if (activeTab.isPinned) {
          _tabManager.openTab(note);
        } else if (activeTab.isEmpty) {
          // Assign note to empty tab
          _tabManager.assignNoteToActiveTab(note);
        } else {
          // Replace note in current tab
          _tabManager.replaceNoteInActiveTab(note);
        }

        _loadNoteContent(note);
        _selectNote(note);

        // Move focus to editor after assigning/replacing/opening note
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted && _appFocusNode.canRequestFocus) {
            FocusScope.of(context).requestFocus(_appFocusNode);
          }
        });
      } else {
        // No active tab, open note in new tab
        _tabManager.openTab(note);
        _loadNoteContent(note);
        _selectNote(note);

        // Move focus to editor after opening note in new tab
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted && _appFocusNode.canRequestFocus) {
            FocusScope.of(context).requestFocus(_appFocusNode);
          }
        });
      }
    }

    if (note.notebookId != 0) {
      try {
        final dbHelper = DatabaseHelper();
        final notebookRepository = NotebookRepository(dbHelper);
        final parentNotebook = await notebookRepository.getNotebook(
          note.notebookId,
        );

        if (parentNotebook != null) {
          _onNotebookSelected(parentNotebook);
        }
      } catch (e) {
        debugPrint('Error loading parent notebook: $e');
      }
    }
  }

  void _onNoteSelectedWithSearch(
    Note note,
    String searchQuery,
    bool isAdvancedSearch,
  ) async {
    // Save current note if exists and has unsaved changes
    final activeTab = _tabManager.activeTab;
    if (_selectedNote != null && activeTab?.isDirty == true) {
      await _handleSave();
    }

    setState(() {
      _searchQuery = searchQuery;
      _isAdvancedSearch = isAdvancedSearch;
    });

    // Check if tab with this note already exists
    final existingTab = _tabManager.tabs.firstWhere(
      (tab) => tab.note?.id == note.id,
      orElse:
          () => EditorTab(
            note: null,
            noteController: TextEditingController(),
            titleController: TextEditingController(),
            lastAccessed: DateTime.now(),
          ),
    );

    if (existingTab.note != null) {
      // Tab already exists, just select it
      _tabManager.selectTab(existingTab);
      _loadNoteContent(note);
      _selectNote(note);
    } else {
      // Check if active tab exists and decide where to open the note
      final activeTab = _tabManager.activeTab;
      if (activeTab != null) {
        if (activeTab.isPinned) {
          _tabManager.openTab(
            note,
            searchQuery: searchQuery,
            isAdvancedSearch: isAdvancedSearch,
          );
        } else if (activeTab.isEmpty) {
          // Assign note to empty tab
          _tabManager.assignNoteToActiveTab(note);
        } else {
          // Replace note in current tab
          _tabManager.replaceNoteInActiveTab(note);
        }
        _loadNoteContent(note);
        _selectNote(note);
      } else {
        // No active tab, open note in new tab with search parameters
        _tabManager.openTab(
          note,
          searchQuery: searchQuery,
          isAdvancedSearch: isAdvancedSearch,
        );
        _loadNoteContent(note);
        _selectNote(note);
      }
    }

    if (note.notebookId != 0) {
      try {
        final dbHelper = DatabaseHelper();
        final notebookRepository = NotebookRepository(dbHelper);
        final parentNotebook = await notebookRepository.getNotebook(
          note.notebookId,
        );

        if (parentNotebook != null) {
          _onNotebookSelected(parentNotebook);
        }
      } catch (e) {
        debugPrint('Error loading parent notebook: $e');
      }
    }
  }

  void _onNotebookSelected(Notebook notebook) {
    setState(() {
      _selectedNotebook = notebook;
    });
    _databaseSidebarKey.currentState?.handleNotebookSelection(notebook);
  }

  void _onNotebookSelectedFromFavorite(Notebook notebook) async {
    setState(() {
      _selectedNotebook = notebook;
    });
    final expand = await EditorSettings.getExpandNotebooksOnSelection();
    _databaseSidebarKey.currentState?.handleNotebookSelection(notebook, expand: expand);
  }

  void _onTrashUpdated() {
    _databaseSidebarKey.currentState?.reloadSidebar();
  }

  void _onNoteDeleted(Note deletedNote) {
    // Close any tabs that contain the deleted note
    final tabsToClose =
        _tabManager.tabs
            .where((tab) => tab.note?.id == deletedNote.id)
            .toList();

    for (final tab in tabsToClose) {
      _tabManager.closeTab(tab);
    }

    // Also check for any other tabs with notes that are now marked as deleted
    _checkAndCloseDeletedNoteTabs();
  }

  Future<void> _checkAndCloseDeletedNoteTabs() async {
    final tabsWithDeletedNotes = <EditorTab>[];
    for (final tab in _tabManager.tabs) {
      if (tab.note != null) {
        try {
          final dbHelper = DatabaseHelper();
          final noteRepository = NoteRepository(dbHelper);
          final currentNote = await noteRepository.getNote(tab.note!.id!);

          // If the note is null (deleted) or marked as deleted, close the tab
          if (currentNote == null || currentNote.deletedAt != null) {
            tabsWithDeletedNotes.add(tab);
          }
        } catch (e) {
          debugPrint('Error checking note status: $e');
          // If there's an error, assume the note is deleted and close the tab
          tabsWithDeletedNotes.add(tab);
        }
      }
    }

    for (final tab in tabsWithDeletedNotes) {
      _tabManager.closeTab(tab);
    }

    // Reload the notes panel to ensure it reflects any changes
    if (mounted) {
      _notesPanelStateKey.currentState?.reloadSidebar();
    }
  }

  void _onNotebookDeleted(Notebook deletedNotebook) async {
    // Get all child notebooks recursively
    final allChildNotebookIds = await _getAllChildNotebookIds(
      deletedNotebook.id!,
    );

    // Add the deleted notebook itself to the list
    final allAffectedNotebookIds = [
      deletedNotebook.id!,
      ...allChildNotebookIds,
    ];

    // Close any tabs that contain notes from the deleted notebook or any of its children
    final tabsToClose =
        _tabManager.tabs
            .where(
              (tab) =>
                  tab.note?.notebookId != null &&
                  allAffectedNotebookIds.contains(tab.note!.notebookId),
            )
            .toList();

    for (final tab in tabsToClose) {
      _tabManager.closeTab(tab);
    }

    // Also check for any tabs with notes that are now marked as deleted
    final tabsWithDeletedNotes = <EditorTab>[];
    for (final tab in _tabManager.tabs) {
      if (tab.note != null) {
        try {
          final dbHelper = DatabaseHelper();
          final noteRepository = NoteRepository(dbHelper);
          final currentNote = await noteRepository.getNote(tab.note!.id!);

          // If the note is null (deleted) or marked as deleted, close the tab
          if (currentNote == null || currentNote.deletedAt != null) {
            tabsWithDeletedNotes.add(tab);
          }
        } catch (e) {
          debugPrint('Error checking note status: $e');
          // If there's an error, assume the note is deleted and close the tab
          tabsWithDeletedNotes.add(tab);
        }
      }
    }

    for (final tab in tabsWithDeletedNotes) {
      _tabManager.closeTab(tab);
    }

    // Clear the selected notebook if it was the deleted one or any of its children
    if (_selectedNotebook?.id != null &&
        allAffectedNotebookIds.contains(_selectedNotebook!.id!)) {
      setState(() {
        _selectedNotebook = null;
        _selectedNote = null;
      });
    }

    // Always reload the notes panel to ensure it reflects the current state
    // after any notebook deletion, and force a rebuild
    if (mounted) {
      setState(() {
        // Force a rebuild to ensure the notes panel updates
      });
      _notesPanelStateKey.currentState?.reloadSidebar();
    }
  }

  Future<List<int>> _getAllChildNotebookIds(int parentNotebookId) async {
    final List<int> childIds = [];

    try {
      final dbHelper = DatabaseHelper();
      final notebookRepository = NotebookRepository(dbHelper);

      // Get direct children
      final directChildren = await notebookRepository.getNotebooksByParentId(
        parentNotebookId,
      );

      for (final child in directChildren) {
        if (child.id != null) {
          childIds.add(child.id!);
          // Recursively get children of this child
          final grandChildren = await _getAllChildNotebookIds(child.id!);
          childIds.addAll(grandChildren);
        }
      }
    } catch (e) {
      debugPrint('Error getting child notebook IDs: $e');
    }

    return childIds;
  }

  void _onNotebookRestored(Notebook notebook) {
    setState(() {
      _selectedNotebook = notebook;
    });
    _selectNote(null);
    _databaseSidebarKey.currentState?.reloadSidebar();
  }

  void _onNoteRestored(Note note) {
    _selectNote(note);
    _databaseSidebarKey.currentState?.reloadSidebar();
  }

  void _onFavoritesUpdated() {
    _databaseSidebarKey.currentState?.reloadSidebar();
  }

  @override
  void dispose() {
    _noteController.dispose();
    _titleController.dispose();
    _debounceNote?.cancel();
    _debounceTitle?.cancel();
    _appFocusNode.dispose();
    _syncController.dispose();
    for (final controller in _animationControllers.values) {
      controller.dispose();
    }
    _syncService.dispose();
    _autoSyncTimer?.cancel();
    _immersiveModeService.removeListener(_onImmersiveModeChanged);
    _editorCenteredSubscription?.cancel();
    _hideTabsInImmersiveSubscription?.cancel();
    _tabManager.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppShortcuts(
      shortcuts: ShortcutsHandler.getAppShortcuts(
        onCloseDialog: closeCurrentDialog,
        onToggleSidebar: _toggleSidebar,
        onToggleEditorCentered: _toggleEditorCentered,
        onCreateNote: createNewNote,
        onCreateNotebook: createNewNotebook,
        onCreateTodo: createNewTodo,
        onSaveNote: _handleSave,
        onToggleNotesPanel: _toggleNotesPanel,
        onForceSync: _forceSync,
        onSearch: _openSearchScreen,
        onToggleImmersiveMode:
            () => _immersiveModeService.toggleImmersiveMode(),
        onGlobalSearch: _openGlobalSearchScreen,
        onCloseTab: _closeCurrentTab,
        onNewTab: _onNewTab,
        onToggleReadMode: toggleActiveEditorReadMode,
      ),
      child: Focus(
        focusNode: _appFocusNode,
        autofocus: true,
        child: Scaffold(
          body: Row(
            children: [
              ResizableIconSidebar(
                key: _iconSidebarKey,
                rootDir: Directory.current,
                onOpenNote: (note) => _onNoteSelected(note as Note),
                onOpenFolder:
                    (folder) => _onNotebookSelected(folder as Notebook),
                onNotebookSelected: _onNotebookSelected,
                onNoteSelected: _onNoteSelected,
                onNoteSelectedWithSearch: _onNoteSelectedWithSearch,
                onThemeUpdated: widget.onThemeUpdated,
                onFavoriteRemoved: () {
                  if (mounted) {
                    setState(() {});
                  }
                },
                onCreateNewNote: createNewNote,
                onCreateNewNotebook: createNewNotebook,
                onCreateNewTodo: createNewTodo,
                onOpenTrash: () {
                  showDialog(
                    context: context,
                    builder:
                        (context) => TrashScreen(
                          onNotebookRestored: _onNotebookRestored,
                          onNoteRestored: _onNoteRestored,
                          onTrashUpdated: _onTrashUpdated,
                        ),
                  );
                },
                onOpenFavorites: () {
                  showDialog(
                    context: context,
                    builder:
                        (context) => FavoritesScreen(
                          onNotebookSelected: _onNotebookSelected,
                          onNoteSelected: _onNoteSelected,
                          onFavoritesUpdated: _onFavoritesUpdated,
                          onNoteSelectedFromPanel: (note) {
                            // Suppress the next update animations in EditorTabs so
                            // replacing the active tab from the favorites panel
                            // doesn't trigger the expand/collapse animation.
                            try {
                              _editorTabsKey.currentState?.suppressNextUpdateAnimations();
                            } catch (_) {}
                            return null;
                          },
                        ),
                  );
                },
                showBackButton: false,
                calendarPanelKey: _calendarPanelKey,
                appFocusNode: _appFocusNode,
              ),
              if (!_immersiveModeService.isImmersiveMode)
                Container(
                  width: 1,
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                ),
              ResizablePanel(
                key: _sidebarKey,
                minWidth: 200,
                maxWidth: 400,
                appFocusNode: _appFocusNode,
                title: 'Notebooks',
                preferencesKey: 'notebooks_panel',
                trailing: Builder(
                  builder: (context) {
                    final databaseSidebarState =
                        _databaseSidebarKey.currentState;
                    if (databaseSidebarState == null) {
                      return const SizedBox.shrink();
                    }
                    return databaseSidebarState.buildTrailingButton();
                  },
                ),
                child: DatabaseSidebar(
                  key: _databaseSidebarKey,
                  selectedNotebook: _selectedNotebook,
                  onNotebookSelected: (notebook) {
                    setState(() {
                      _selectedNotebook = notebook;
                      _titleController.clear();
                      _noteController.clear();
                    });
                    _selectNote(null);
                    _saveLastSelectedNotebook(notebook.id);
                  },
                  onTrashUpdated: () {
                    setState(() {
                      _titleController.clear();
                      _noteController.clear();
                    });
                    _selectNote(null);
                    _saveLastSelectedNotebook(null);
                  },
                  onExpansionChanged: () {
                    setState(() {});
                  },
                  onNotebookDeleted: _onNotebookDeleted,
                ),
              ),
              if (!_immersiveModeService.isImmersiveMode)
                Container(
                  width: 1,
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                ),
              ResizablePanel(
                key: _notesPanelKey,
                minWidth: 200,
                maxWidth: 400,
                appFocusNode: _appFocusNode,
                title: 'Notes',
                preferencesKey: 'notes_panel',
                trailing: Builder(
                  builder: (context) {
                    final notesPanel = _notesPanelStateKey.currentState;
                    if (notesPanel == null) {
                      return const SizedBox.shrink();
                    }
                    return notesPanel.buildTrailingButton();
                  },
                ),
                child: NotesPanel(
                  key: _notesPanelStateKey,
                  selectedNotebookId: _selectedNotebook?.id,
                    selectedNote: _selectedNote,
                    onNoteSelected: _onNoteSelected,
                    onNoteSelectedFromPanel: (note) {
                      // If this note already has an open tab, suppress the next open animation
                      if (mounted && _editorTabsKey.currentState != null) {
                        // Request EditorTabs to skip visual animations for the immediate update
                        _editorTabsKey.currentState!.suppressNextUpdateAnimations();
                      }

                      _onNoteSelected(note);
                    },
                  onNoteOpenInNewTab: (note) {
                    _onNoteOpenInNewTab(note);
                  },
                  onTrashUpdated: () {
                    _isLoadingNoteContent = true;

                    _titleController.clear();
                    _noteController.clear();

                    Future.delayed(const Duration(milliseconds: 500), () {
                      if (mounted) {
                        _isLoadingNoteContent = false;
                      }
                    });

                    _selectNote(null);
                  },
                  onSortChanged: () {
                    setState(() {});
                  },
                  onNoteDeleted: _onNoteDeleted,
                ),
              ),
              Expanded(
                child: Stack(
                  children: [
                    Column(
                      children: [
                        // Tabs bar (hidden in immersive mode if configured)
                        if (!_immersiveModeService.isImmersiveMode ||
                            !EditorSettingsCache.instance.hideTabsInImmersive)
                          EditorTabs(
                            key: _editorTabsKey,
                            tabs: _tabManager.tabs,
                            activeTab: _tabManager.activeTab,
                            onTabSelected: _onTabSelected,
                            onTabClosed: _onTabClosed,
                            onTabTogglePin: (tab) => _tabManager.togglePin(tab),
                            onNewTab: _onNewTab,
                            onTabReorder: _onTabReorder,
                          ),
                        // Editor content
                        Expanded(child: _buildEditorContent()),
                      ],
                    ),
                  ],
                ),
              ),

              SizedBox(
                height: MediaQuery.of(context).size.height,
                child: Padding(
                  padding: const EdgeInsets.only(top: 0),
                  child: ResizablePanelLeft(
                    key: _calendarPanelKey,
                    minWidth: 300,
                    maxWidth: 400,
                    appFocusNode: _appFocusNode,
                    title: '',
                    preferencesKey: 'calendar_panel',
                    child: CalendarPanel(
                      onNoteSelected: _onNoteSelected,
                      onNoteSelectedFromPanel: (note) {
                        if (mounted && _editorTabsKey.currentState != null) {
                          _editorTabsKey.currentState!.suppressNextUpdateAnimations();
                        }

                        _onNoteSelected(note);
                      },
                      onNoteOpenInNewTab: _onNoteOpenInNewTab,
                      onNotebookSelected: _onNotebookSelected,
                      onNotebookSelectedFromFavorite: _onNotebookSelectedFromFavorite,
                      appFocusNode: _appFocusNode,
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

  void _toggleSidebar() {
    if (_sidebarKey.currentState != null) {
      _sidebarKey.currentState!.togglePanel();
    }
  }

  void _toggleNotesPanel() {
    if (_notesPanelKey.currentState != null) {
      _notesPanelKey.currentState!.togglePanel();
    }
  }

  void _openSearchScreen() {
    showDialog(
      context: context,
      builder:
          (context) => SearchScreenDesktop(
            onNoteSelected: (Note note) {
              _onNoteSelected(note);
            },
            onNotebookSelected: (Notebook notebook) {
              _onNotebookSelected(notebook);
            },
            onNoteSelectedWithSearch: (
              Note note,
              String searchQuery,
              bool isAdvancedSearch,
            ) {
              _onNoteSelectedWithSearch(note, searchQuery, isAdvancedSearch);
            },
          ),
    );
  }

  Future<void> _initializeRepositories() async {
    try {
      final dbHelper = DatabaseHelper();
      await dbHelper.database;
      _syncService = SyncService();
      await _syncService.initialize();
      await _loadExpandedState();
      await _loadData();
    } catch (e) {
      debugPrint('Error initializing repositories: $e');
      if (mounted) {
        setState(() {});
      }
    }
  }

  Future<void> _loadExpandedState() async {}

  Future<void> _loadData() async {}

  Future<void> _loadLastSelectedNotebook() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastNotebookId = prefs.getInt(_lastSelectedNotebookIdKey);

      if (lastNotebookId != null) {
        final notebookRepo = NotebookRepository(DatabaseHelper());
        final notebook = await notebookRepo.getNotebook(lastNotebookId);

        if (notebook != null && mounted) {
          setState(() {
            _selectedNotebook = notebook;
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading last selected notebook: $e');
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
      debugPrint('Error saving last selected notebook: $e');
    }
  }

  void _forceSync() async {
    setState(() {
      _syncController.start();
    });

    try {
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

  void _openGlobalSearchScreen() {
    showDialog(
      context: context,
      builder:
          (context) => SearchScreenDesktop(
            onNoteSelected: (Note note) {
              _onNoteSelected(note);
            },
            onNotebookSelected: (Notebook notebook) {
              _onNotebookSelected(notebook);
            },
            onNoteSelectedWithSearch: (
              Note note,
              String searchQuery,
              bool isAdvancedSearch,
            ) {
              _onNoteSelectedWithSearch(note, searchQuery, isAdvancedSearch);
            },
          ),
    );
  }

  void _onTabSelected(EditorTab tab) async {
    // Save current note if exists and has unsaved changes
    final activeTab = _tabManager.activeTab;
    if (_selectedNote != null && activeTab?.isDirty == true) {
      await _handleSave();
    }

    setState(() {
      _searchQuery = tab.searchQuery ?? '';
      _isAdvancedSearch = tab.isAdvancedSearch;
    });

    if (tab.note != null) {
      _selectNote(tab.note);
    } else {
      // Empty tab - clear selected note
      setState(() {
        _selectedNote = null;
      });
    }
    _tabManager.selectTab(tab);

    // Move focus to editor after selecting a tab
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted && _appFocusNode.canRequestFocus) {
        FocusScope.of(context).requestFocus(_appFocusNode);
      }
    });
  }

  void _onTabClosed(EditorTab tab) async {
    // Save the tab before closing if it's dirty
    if (tab.isDirty) {
      try {
        final dbHelper = DatabaseHelper();
        final noteRepository = NoteRepository(dbHelper);

        final updatedNote = Note(
          id: tab.note!.id,
          title: tab.titleController.text.trim(),
          content: tab.noteController.text,
          notebookId: tab.note!.notebookId,
          createdAt: tab.note!.createdAt,
          updatedAt: DateTime.now(),
          isFavorite: tab.note!.isFavorite,
          tags: tab.note!.tags,
          orderIndex: tab.note!.orderIndex,
          isTask: tab.note!.isTask,
          isCompleted: tab.note!.isCompleted,
        );

        await noteRepository.updateNote(updatedNote);
        DatabaseHelper.notifyDatabaseChanged();
      } catch (e) {
        debugPrint('Error saving note before closing: $e');
        if (mounted) {
          CustomSnackbar.show(
            context: context,
            message: 'Error saving note: ${e.toString()}',
            type: CustomSnackbarType.error,
          );
        }
      }
    }

    _tabManager.closeTab(tab);

    // Update local state
    if (_tabManager.activeTab != null) {
      final activeTab = _tabManager.activeTab!;
      setState(() {
        _searchQuery = activeTab.searchQuery ?? '';
        _isAdvancedSearch = activeTab.isAdvancedSearch;
      });
      if (activeTab.note != null) {
        _selectNote(activeTab.note);
      } else {
        setState(() {
          _selectedNote = null;
        });
      }
    } else {
      setState(() {
        _selectedNote = null;
        _searchQuery = '';
        _isAdvancedSearch = false;
      });
    }
  }

  void _onNewTab() {
    _tabManager.createEmptyTab();

    // Move focus to tabs immediately after creating a new tab
    if (mounted && _editorTabsKey.currentState != null) {
      _editorTabsKey.currentState!.requestFocus();
    }
  }

  void _onTabReorder(int oldIndex, int newIndex) {
    _tabManager.reorderTabs(oldIndex, newIndex);
  }

  void _closeCurrentTab() {
    final activeTab = _tabManager.activeTab;
    if (activeTab != null) {
      if (mounted && _editorTabsKey.currentState != null) {
        _editorTabsKey.currentState!.requestCloseTab(activeTab);
      } else {
        _onTabClosed(activeTab);
      }
    }
  }

  Future<void> _loadSavedTabs() async {
    await _tabManager.loadTabsFromStorage();

    // No crear pestaña vacía automáticamente si no hay pestañas guardadas
    // El editor quedará vacío hasta que el usuario abra una nota
  }

  void _onNoteOpenInNewTab(Note note) async {
    // Save current note if exists
    if (_selectedNote != null) {
      await _handleSave();
    }

    setState(() {
      _searchQuery = '';
      _isAdvancedSearch = false;
    });

    // Check if tab with this note already exists
    final existingTab = _tabManager.tabs.firstWhere(
      (tab) => tab.note?.id == note.id,
      orElse:
          () => EditorTab(
            note: null,
            noteController: TextEditingController(),
            titleController: TextEditingController(),
            lastAccessed: DateTime.now(),
          ),
    );

    if (existingTab.note != null) {
      // Tab already exists, just select it
      _tabManager.selectTab(existingTab);
      _selectNote(note);
    } else {
      // Create new tab
      _tabManager.openTab(note);
      _selectNote(note);
    }

    if (note.notebookId != 0) {
      try {
        final dbHelper = DatabaseHelper();
        final notebookRepository = NotebookRepository(dbHelper);
        final parentNotebook = await notebookRepository.getNotebook(
          note.notebookId,
        );

        if (parentNotebook != null) {
          _onNotebookSelected(parentNotebook);
        }
      } catch (e) {
        debugPrint('Error loading parent notebook: $e');
      }
    }
  }

  Widget _buildEditorContent() {
    final activeTab = _tabManager.activeTab;

    if (activeTab == null) {
      return Column(
        children: [
          DraggableArea(height: 40),
          Expanded(
            child: Stack(
              children: [
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.note_outlined,
                        size: 64,
                        color: Theme.of(
                          context,
                        ).colorScheme.primary.withAlpha(127),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No tabs open',
                        style: Theme.of(
                          context,
                        ).textTheme.headlineSmall?.copyWith(
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withAlpha(127),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Select a note to start editing',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withAlpha(127),
                        ),
                      ),
                    ],
                  ),
                ),
                if (_immersiveModeService.isImmersiveMode)
                  Positioned(
                    top: 16,
                    left: 16,
                    child: IconButton(
                      icon: Icon(
                        Icons.fullscreen_exit_rounded,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      onPressed:
                          () => _immersiveModeService.exitImmersiveMode(),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        foregroundColor: Theme.of(context).colorScheme.primary,
                        hoverColor: Theme.of(
                          context,
                        ).colorScheme.primary.withAlpha(20),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      );
    }

    if (activeTab.isEmpty) {
      return Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.note_add_outlined,
                        size: 64,
                        color: Theme.of(
                          context,
                        ).colorScheme.primary.withAlpha(127),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Select a note to assign to this tab',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withAlpha(127),
                        ),
                      ),
                    ],
                  ),
                ),
                if (_immersiveModeService.isImmersiveMode)
                  Positioned(
                    top: 16,
                    left: 16,
                    child: IconButton(
                      icon: Icon(
                        Icons.fullscreen_exit_rounded,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      onPressed:
                          () => _immersiveModeService.exitImmersiveMode(),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        foregroundColor: Theme.of(context).colorScheme.primary,
                        hoverColor: Theme.of(
                          context,
                        ).colorScheme.primary.withAlpha(20),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      );
    }

    return NotaEditor(
      selectedNote: activeTab.note!,
      noteController: activeTab.noteController,
      titleController: activeTab.titleController,
      onSave: _handleSave,
      isEditorCentered: _isEditorCenteredTemporary,
      onTitleChanged: () {
        setState(() {
          isEditing = true;
          showSavedIndicator = false;
        });

        // Mark tab as dirty when title changes
        final activeTab = _tabManager.activeTab;
        if (activeTab != null) {
          _tabManager.markTabAsDirty(activeTab);
        }
      },
      onContentChanged: () {
        setState(() {
          isEditing = true;
          showSavedIndicator = false;
        });

        // Mark tab as dirty when content changes
        final activeTab = _tabManager.activeTab;
        if (activeTab != null) {
          _tabManager.markTabAsDirty(activeTab);
        }
      },
      onAutoSaveCompleted: () {
        // Mark tab as saved when auto-save completes
        final activeTab = _tabManager.activeTab;
        if (activeTab != null) {
          _tabManager.markTabAsSaved(activeTab);

          // Update the note object in the tab with the current content
          final updatedNote = activeTab.note!.copyWith(
            title: activeTab.titleController.text.trim(),
            content: activeTab.noteController.text,
            updatedAt: DateTime.now(),
          );
          _tabManager.updateNoteObjectInTab(updatedNote);
        }
      },
      onToggleEditorCentered: _toggleEditorCentered,
      searchQuery: _searchQuery,
      isAdvancedSearch: _isAdvancedSearch,
      tabManager: _tabManager, // Para navigation entre notas
    );
  }
}
