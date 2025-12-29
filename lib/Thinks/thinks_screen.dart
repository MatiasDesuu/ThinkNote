// ignore_for_file: library_private_types_in_public_api

import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../database/models/think.dart';
import '../database/services/think_service.dart';
import '../database/database_helper.dart';
import '../database/repositories/think_repository.dart';
import '../Settings/settings_screen.dart';
import '../widgets/Editor/editor_screen.dart';
import '../database/models/note.dart';
import '../widgets/custom_snackbar.dart';
import '../widgets/context_menu.dart';
import '../widgets/confirmation_dialogue.dart';
import '../widgets/resizable_icon_sidebar.dart';

class SaveThinkIntent extends Intent {
  const SaveThinkIntent();
}

class NewThinkIntent extends Intent {
  const NewThinkIntent();
}

class _ToggleSidebarIntent extends Intent {
  const _ToggleSidebarIntent();
}

class ThinksScreen extends StatefulWidget {
  final Directory rootDir;
  final Function(File) onOpenNote;
  final Function() onClose;

  const ThinksScreen({
    super.key,
    required this.rootDir,
    required this.onOpenNote,
    required this.onClose,
  });

  @override
  _ThinksScreenState createState() => _ThinksScreenState();
}

class _ThinksScreenState extends State<ThinksScreen>
    with TickerProviderStateMixin {
  List<Think> _thinks = [];
  final ScrollController _scrollController = ScrollController();
  Think? _selectedThink;
  final TextEditingController _noteController = TextEditingController();
  final TextEditingController _titleController = TextEditingController();
  Timer? _debounceNote;
  bool _isEditorCentered = false;
  final FocusNode _appFocusNode = FocusNode();

  // Variables for resizable panel
  double _sidebarWidth = 240;
  bool _isDragging = false;
  bool _isSidebarVisible = true;
  late AnimationController _sidebarAnimController;
  late Animation<double> _sidebarWidthAnimation;

  // Loading state
  bool _isLoading = true;

  // Services
  late ThinkService _thinkService;
  StreamSubscription? _thinkChangesSubscription;

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
    final thinkRepository = ThinkRepository(dbHelper);
    _thinkService = ThinkService(thinkRepository);

    // Subscribe to changes in thinks
    _thinkChangesSubscription = _thinkService.onThinkChanged.listen((_) {
      _loadThinks();
    });

    // Initialize everything in parallel and then update state once
    _initializeData();
  }

  Future<void> _initializeData() async {
    try {
      // Load saved settings
      final prefs = await SharedPreferences.getInstance();
      final savedWidth = prefs.getDouble('thinks_sidebar_width') ?? 240;
      final editorCentered = prefs.getBool('editor_centered') ?? false;

      // Load thinks
      List<Think> loadedThinks = await _thinkService.getAllThinks();

      // Update state once with all loaded data
      if (mounted) {
        setState(() {
          _sidebarWidth = savedWidth;
          _isEditorCentered = editorCentered;
          _thinks = loadedThinks;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error in Thinks initialization: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _saveWidth(double width) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('thinks_sidebar_width', width);
  }


  @override
  void dispose() {
    _noteController.dispose();
    _titleController.dispose();
    _scrollController.dispose();
    _debounceNote?.cancel();
    _thinkChangesSubscription?.cancel();
    _appFocusNode.dispose();
    _sidebarAnimController.dispose();
    super.dispose();
  }

  // Method to load thinks (used after operations)
  Future<void> _loadThinks() async {
    try {
      // Get thinks using the thinkService
      final loadedThinks = await _thinkService.getAllThinks();

      // Update state with new thinks
      if (mounted) {
        setState(() {
          _thinks = loadedThinks;
        });
      }
    } catch (e) {
      print('Error in _loadThinks: $e');
      if (mounted) {
        CustomSnackbar.show(
          context: context,
          message: 'Error loading content: $e',
          type: CustomSnackbarType.error,
        );
      }
    }
  }

  String _formatDate(DateTime dateTime) {
    return DateFormat("dd/MM/yyyy - HH:mm").format(dateTime);
  }

  Future<void> _createNewThink() async {
    try {
      final createdThink = await _thinkService.createThink();
      if (createdThink != null) {
        await _loadThinks();
        _openThink(createdThink);
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

  Future<void> _deleteThink(Think think) async {
    final colorScheme = Theme.of(context).colorScheme;
    final confirmed = await showDeleteConfirmationDialog(
      context: context,
      title: 'Move to Trash',
      message:
          'Are you sure you want to move this Think to the trash?\n${think.title}',
      confirmText: 'Move to Trash',
      confirmColor: colorScheme.error,
    );

    if (confirmed == true) {
      try {
        await _thinkService.deleteThink(think.id!);

        if (mounted) {
          // If the deleted Think is the current one, clear the editor
          if (_selectedThink?.id == think.id) {
            setState(() {
              _selectedThink = null;
              _noteController.text = '';
              _titleController.text = '';
            });
          }

          await _loadThinks();
        }
      } catch (e) {
        if (mounted) {
          CustomSnackbar.show(
            context: context,
            message: 'Error moving to trash: ${e.toString()}',
            type: CustomSnackbarType.error,
          );
        }
      }
    }
  }

  Future<void> _openThink(Think think) async {
    try {
      // Save the current think before opening a new one
      if (_selectedThink != null) {
        await _saveThink();
      }

      setState(() {
        _selectedThink = think;
        _noteController.text = think.content;
        _titleController.text = think.title;
      });
    } catch (e) {
      if (mounted) {
        CustomSnackbar.show(
          context: context,
          message: 'Error opening Think: ${e.toString()}',
          type: CustomSnackbarType.error,
        );
      }
    }
  }

  // Save Think content
  Future<void> _saveThink() async {
    if (_selectedThink == null) return;

    try {
      // Update the think with new content and title
      final updatedThink = _selectedThink!.copyWith(
        title: _titleController.text.trim(),
        content: _noteController.text,
        updatedAt: DateTime.now(),
      );

      // Save using service
      await _thinkService.updateThink(updatedThink);

      // Update the reference to the selected think
      setState(() {
        _selectedThink = updatedThink;
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

  void _onNoteChanged() {
    _debounceNote?.cancel();
    _debounceNote = Timer(const Duration(seconds: 3), _saveThink);
  }

  void _onDragUpdate(DragUpdateDetails details) {
    setState(() {
      _sidebarWidth = (_sidebarWidth + details.delta.dx).clamp(200.0, 400.0);
    });
  }

  void _onDragEnd(DragEndDetails details) async {
    await _saveWidth(_sidebarWidth);
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

  Widget _buildThinkItem(Think think) {
    final colorScheme = Theme.of(context).colorScheme;
    final bool isSelected = _selectedThink?.id == think.id;

    return ReorderableDragStartListener(
      key: ValueKey(think.id),
      index: _thinks.indexOf(think),
      child: MouseRegionHoverItem(
        builder: (context, isHovering) {
          return Container(
            margin: const EdgeInsets.only(bottom: 4, left: 8, right: 8),
            decoration: BoxDecoration(
              color: isSelected
                  ? colorScheme.primary.withAlpha(25)
                  : isHovering
                      ? colorScheme.surfaceContainerHighest
                      : colorScheme.surface,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => _openThink(think),
                onSecondaryTapDown:
                    (details) => _showContextMenu(context, think, details),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 10,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Ícono de think y favorito
                      Stack(
                        alignment: Alignment.center,
                        clipBehavior: Clip.none,
                        children: [
                          Icon(
                            isSelected
                                ? Icons.lightbulb_rounded
                                : Icons.lightbulb_outline_rounded,
                            color: colorScheme.primary,
                            size: 24,
                          ),
                          if (think.isFavorite)
                            Positioned(
                              right: -4,
                              bottom: -4,
                              child: Container(
                                padding: const EdgeInsets.all(1),
                                decoration: BoxDecoration(
                                  color: colorScheme.surface,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.favorite_rounded,
                                  size: 12,
                                  color: colorScheme.primary,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(width: 12),
                      // Título y detalles
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              think.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight:
                                    isSelected
                                        ? FontWeight.bold
                                        : FontWeight.w500,
                                color: colorScheme.onSurface,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Icon(
                                  Icons.today_rounded,
                                  size: 14,
                                  color: colorScheme.primary,
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  _formatDate(think.updatedAt),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 4),
                      // Botón eliminar
                      Opacity(
                        opacity: isHovering ? 1.0 : 0.0,
                        child: IgnorePointer(
                          ignoring: !isHovering,
                          child: Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: IconButton(
                              icon: Icon(
                                Icons.delete_forever_rounded,
                                color: colorScheme.error,
                                size: 18,
                              ),
                              onPressed: () => _deleteThink(think),
                              constraints: const BoxConstraints(
                                minWidth: 32,
                                minHeight: 32,
                              ),
                              padding: EdgeInsets.zero,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showContextMenu(
    BuildContext context,
    Think think,
    TapDownDetails details,
  ) {
    ContextMenuOverlay.show(
      context: context,
      tapPosition: details.globalPosition,
      items: [
        ContextMenuItem(
          icon:
              think.isFavorite
                  ? Icons.favorite_rounded
                  : Icons.favorite_border_rounded,
          label:
              think.isFavorite ? 'Remove from Favorites' : 'Add to Favorites',
          onTap: () => _toggleFavorite(think),
        ),
        ContextMenuItem(
          icon: Icons.delete_rounded,
          label: 'Move to Trash',
          iconColor: Theme.of(context).colorScheme.error,
          onTap: () => _deleteThink(think),
        ),
      ],
    );
  }

  Future<void> _toggleFavorite(Think think) async {
    try {
      await _thinkService.toggleFavorite(think.id!, !think.isFavorite);
      await _loadThinks();
    } catch (e) {
      if (mounted) {
        CustomSnackbar.show(
          context: context,
          message: 'Error toggling favorite: ${e.toString()}',
          type: CustomSnackbarType.error,
        );
      }
    }
  }

  // Method to open the settings screen
  void _openSettings() async {
    await Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder:
            (context, animation, secondaryAnimation) => SettingsScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 150),
      ),
    );

    // Reload editor settings
    if (_selectedThink != null) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (_isLoading) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: colorScheme.primary),
              const SizedBox(height: 16),
              Text(
                'Loading Thinks...',
                style: TextStyle(color: colorScheme.onSurface),
              ),
            ],
          ),
        ),
      );
    }

    return Shortcuts(
      shortcuts: <LogicalKeySet, Intent>{
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyS):
            const SaveThinkIntent(),
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyN):
            const NewThinkIntent(),
        LogicalKeySet(LogicalKeyboardKey.f2): const _ToggleSidebarIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          SaveThinkIntent: CallbackAction<SaveThinkIntent>(
            onInvoke: (intent) async {
              if (_selectedThink != null) {
                await _saveThink();
              }
              return null;
            },
          ),
          NewThinkIntent: CallbackAction<NewThinkIntent>(
            onInvoke: (intent) async {
              await _createNewThink();
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
                Row(
                  children: [
                    // Left sidebar with new implementation
                    ResizableIconSidebar(
                      rootDir: widget.rootDir,
                      onOpenNote: widget.onOpenNote,
                      onOpenFolder: (_) {},
                      onNotebookSelected: (_) {},
                      onNoteSelected: (_) {},
                      onBack: widget.onClose,
                      onDirectorySet: () {},
                      onThemeUpdated: () {},
                      onFavoriteRemoved: () {},
                      onNavigateToMain: () {},
                      onClose: () {},
                      onCreateNewNote: null,
                      onCreateNewNotebook: null,
                      onCreateNewTodo: null,
                      onShowManageTags: null,
                      onCreateThink: _createNewThink,
                      onOpenSettings: _openSettings,
                      onOpenFavorites: null,
                      showBackButton: true,
                      isTasksScreen: false,
                      isThinksScreen: true,
                      isSettingsScreen: false,
                      isBookmarksScreen: false,
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

                          // Central panel with thinks list (resizable)
                          Container(
                          width: _sidebarWidth,
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainerLow,
                          ),
                          child: Stack(
                            children: [
                              Column(
                                children: [
                                  // Thinks header
                                  Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Symbols.neurology_rounded,
                                          size: 20,
                                          color: colorScheme.primary,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Thinks',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: colorScheme.onSurfaceVariant,
                                          ),
                                        ),
                                        const Spacer(),
                                        Text(
                                          '${_thinks.length}',
                                          style: TextStyle(
                                            color: colorScheme.onSurfaceVariant,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Thinks list
                                  Expanded(
                                    child:
                                    _thinks.isEmpty
                                        ? Center(
                                          child: Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Icon(
                                                Symbols.lightbulb_2,
                                                size: 48,
                                                color: colorScheme
                                                    .onSurfaceVariant
                                                    .withAlpha(100),
                                              ),
                                              const SizedBox(height: 16),
                                              Text(
                                                'No Thinks created',
                                                style: TextStyle(
                                                  color: colorScheme
                                                      .onSurfaceVariant
                                                      .withAlpha(150),
                                                ),
                                              ),
                                              const SizedBox(height: 8),
                                              TextButton.icon(
                                                onPressed: _createNewThink,
                                                icon: Icon(
                                                  Icons
                                                      .add_circle_outline_rounded,
                                                  size: 18,
                                                  color: colorScheme.primary,
                                                ),
                                                label: Text(
                                                  'Create Think',
                                                  style: TextStyle(
                                                    color: colorScheme.primary,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        )
                                        : ReorderableListView.builder(
                                          scrollController: _scrollController,
                                          padding: const EdgeInsets.fromLTRB(
                                            4,
                                            4,
                                            4,
                                            0,
                                          ),
                                          itemCount: _thinks.length,
                                          buildDefaultDragHandles: false,
                                          onReorder: (
                                            oldIndex,
                                            newIndex,
                                          ) async {
                                            if (newIndex > oldIndex) {
                                              newIndex--;
                                            }

                                            setState(() {
                                              final item = _thinks.removeAt(
                                                oldIndex,
                                              );
                                              _thinks.insert(newIndex, item);
                                            });

                                            try {
                                              await _thinkService.reorderThinks(
                                                _thinks,
                                              );
                                              await _loadThinks();
                                            } catch (e) {
                                              if (!context.mounted) return;
                                              CustomSnackbar.show(
                                                context: context,
                                                message:
                                                    'Error reordering: ${e.toString()}',
                                                type: CustomSnackbarType.error,
                                              );
                                              await _loadThinks();
                                            }
                                          },
                                          itemBuilder: (context, index) {
                                            final think = _thinks[index];
                                            return _buildThinkItem(think);
                                          },
                                        ),
                              ),
                            ],
                          ),
                          // Resize control
                          Positioned(
                            right: 0,
                            top: 0,
                            bottom: 0,
                            child: MouseRegion(
                              cursor: SystemMouseCursors.resizeLeftRight,
                              child: GestureDetector(
                                onPanUpdate: _onDragUpdate,
                                onPanStart:
                                    (_) => setState(() => _isDragging = true),
                                onPanEnd: (details) {
                                  setState(() => _isDragging = false);
                                  _onDragEnd(details);
                                },
                                child: Container(
                                  width: 6,
                                  decoration: BoxDecoration(
                                    color:
                                        _isDragging
                                            ? colorScheme.primary.withAlpha(50)
                                            : Colors.transparent,
                                  ),
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

                    // Right editor panel
                    Expanded(
                      child: Container(
                        color: colorScheme.surface,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 40.0),
                          child:
                              _selectedThink == null
                                  ? Center(
                                    child: Text(
                                      'Select a Think or create a new one',
                                      style: TextStyle(
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  )
                                  : NotaEditor(
                                    selectedNote: Note(
                                      id: _selectedThink!.id!,
                                      title: _selectedThink!.title,
                                      content: _selectedThink!.content,
                                      notebookId:
                                          0, // Usamos 0 como ID por defecto para thinks
                                      createdAt: _selectedThink!.createdAt,
                                      updatedAt: _selectedThink!.updatedAt,
                                      isFavorite: _selectedThink!.isFavorite,
                                    ),
                                    noteController: _noteController,
                                    titleController: _titleController,
                                    onSave: _saveThink,
                                    onTitleChanged: _onNoteChanged,
                                    onContentChanged: _onNoteChanged,
                                    initialEditorCentered: _isEditorCentered,
                                    onEditorCenteredChanged: (isEditorCentered) async {
                                      final prefs = await SharedPreferences.getInstance();
                                      await prefs.setBool('editor_centered', isEditorCentered);
                                      setState(() {
                                        _isEditorCentered = isEditorCentered;
                                      });
                                    },
                                  ),
                        ),
                      ),
                    ),
                  ],
                ),

                // Window controls in top right corner
                Positioned(
                  top: 0,
                  right: 0,
                  height: 40,
                  child: Container(
                    color: colorScheme.surface,
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

                // Title drag area - correctly placed
                Positioned(
                  top: 0,
                  left: 60, // Left sidebar width
                  right: 138, // Control buttons width
                  height: 40,
                  child: MoveWindow(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Widget auxiliar para gestionar el estado de hover
class MouseRegionHoverItem extends StatefulWidget {
  final Widget Function(BuildContext, bool) builder;

  const MouseRegionHoverItem({super.key, required this.builder});

  @override
  State<MouseRegionHoverItem> createState() => _MouseRegionHoverItemState();
}

class _MouseRegionHoverItemState extends State<MouseRegionHoverItem> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: widget.builder(context, _isHovering),
    );
  }
}
