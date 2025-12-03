import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'dart:io';
import '../animations/animations_handler.dart';
import '../Settings/settings_screen.dart';
import '../Tasks/tasks_screen.dart';
import '../Bookmarks/bookmarks_screen_db.dart';
import '../Thinks/thinks_screen.dart';
import '../Diary/diary_screen.dart';
import '../database/sync_service.dart';
import 'custom_snackbar.dart';
import 'search_screen_desktop.dart';
import '../database/models/note.dart';
import '../database/models/notebook.dart';
import '../services/immersive_mode_service.dart';

class IconSidebarButton {
  final IconData icon;
  final dynamic onPressed;
  final Color? color;
  final Widget? child;
  final bool showInBookmarks;

  const IconSidebarButton({
    required this.icon,
    required this.onPressed,
    this.color,
    this.child,
    this.showInBookmarks = false,
  });
}

class HoverMenuItem {
  final IconData icon;
  final VoidCallback? onTap;
  final String label;

  const HoverMenuItem({
    required this.icon,
    required this.onTap,
    required this.label,
  });
}

class HoverMenuOverlay extends StatefulWidget {
  final List<HoverMenuItem> menuItems;
  final double iconSize;

  const HoverMenuOverlay({
    super.key,
    required this.menuItems,
    required this.iconSize,
  });

  @override
  State<HoverMenuOverlay> createState() => _HoverMenuOverlayState();
}

class _HoverMenuOverlayState extends State<HoverMenuOverlay> {
  bool isHovered = false;
  OverlayEntry? _overlayEntry;
  int? hoveredIndex;
  final LayerLink _layerLink = LayerLink();

  @override
  void dispose() {
    _removeOverlay();
    super.dispose();
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void toggleOverlay(BuildContext context) {
    if (_overlayEntry != null) {
      _removeOverlay();
    } else {
      _showOverlay(context);
    }
  }

  void _showOverlay(BuildContext context) {
    _removeOverlay();

    _overlayEntry = OverlayEntry(
      builder:
          (context) => Stack(
            children: [
              Positioned.fill(
                child: GestureDetector(
                  onTap: _removeOverlay,
                  behavior: HitTestBehavior.translucent,
                  child: Container(color: Colors.transparent),
                ),
              ),
              CompositedTransformFollower(
                link: _layerLink,
                offset: Offset(widget.iconSize + 16, -4),
                child: Material(
                  color: Theme.of(context).colorScheme.surface,
                  elevation: 8,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Theme.of(
                          context,
                        ).colorScheme.outline.withAlpha(26),
                      ),
                    ),
                    child: IntrinsicHeight(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 4,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children:
                              widget.menuItems.asMap().entries.map((entry) {
                                final index = entry.key;
                                final item = entry.value;
                                return _buildMenuItem(context, item, index);
                              }).toList(),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  Widget _buildMenuItem(BuildContext context, HoverMenuItem item, int index) {
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          item.onTap?.call();
          _removeOverlay();
        },
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Icon(
            item.icon,
            size: widget.iconSize,
            color: colorScheme.primary,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: SizedBox(
        width: widget.iconSize + 16,
        height: widget.iconSize + 16,
      ),
    );
  }
}

class IconSidebar extends StatefulWidget {
  final Directory? rootDir;
  final Function(File)? onOpenNote;
  final Function(Directory)? onOpenFolder;
  final Function(Notebook)? onNotebookSelected;
  final Function(Note)? onNoteSelected;
  final Function(Note, String, bool)? onNoteSelectedWithSearch;
  final VoidCallback? onBack;
  final VoidCallback? onDirectorySet;
  final VoidCallback? onThemeUpdated;
  final VoidCallback? onFavoriteRemoved;
  final VoidCallback? onNavigateToMain;
  final VoidCallback? onClose;
  final VoidCallback? onCreateNewNote;
  final VoidCallback? onCreateNewNotebook;
  final VoidCallback? onCreateNewTodo;
  final VoidCallback? onShowManageTags;
  final VoidCallback? onCreateThink;
  final VoidCallback? onOpenSettings;
  final VoidCallback? onOpenTrash;
  final VoidCallback? onOpenFavorites;
  final bool showBackButton;
  final bool isWorkflowsScreen;
  final bool isTasksScreen;
  final bool isThinksScreen;
  final bool isSettingsScreen;
  final bool isBookmarksScreen;
  final bool isDiaryScreen;
  final Function(int)? onPageChanged;
  final VoidCallback? onAddBookmark;
  final VoidCallback? onManageTags;
  final VoidCallback? onToggleView;
  final bool isGridView;
  final LayerLink? searchLayerLink;
  final GlobalKey<dynamic>? calendarPanelKey;
  final VoidCallback? onToggleCalendar;
  final VoidCallback? onToggleSidebar;
  final double iconSize;
  final VoidCallback? onForceSync;

  const IconSidebar({
    super.key,
    this.rootDir,
    this.onOpenNote,
    this.onOpenFolder,
    this.onNotebookSelected,
    this.onNoteSelected,
    this.onNoteSelectedWithSearch,
    this.onBack,
    this.onDirectorySet,
    this.onThemeUpdated,
    this.onFavoriteRemoved,
    this.onNavigateToMain,
    this.onClose,
    this.onCreateNewNote,
    this.onCreateNewNotebook,
    this.onCreateNewTodo,
    this.onShowManageTags,
    this.onCreateThink,
    this.onOpenSettings,
    this.onOpenTrash,
    this.onOpenFavorites,
    this.showBackButton = true,
    this.isWorkflowsScreen = false,
    this.isTasksScreen = false,
    this.isThinksScreen = false,
    this.isSettingsScreen = false,
    this.isBookmarksScreen = false,
    this.isDiaryScreen = false,
    this.onPageChanged,
    this.onAddBookmark,
    this.onManageTags,
    this.onToggleView,
    this.isGridView = false,
    this.searchLayerLink,
    this.calendarPanelKey,
    this.onToggleCalendar,
    this.onToggleSidebar,
    this.iconSize = 24,
    this.onForceSync,
  });

  @override
  State<IconSidebar> createState() => _IconSidebarState();
}

class _IconSidebarState extends State<IconSidebar>
    with SingleTickerProviderStateMixin {
  late SyncAnimationController _syncController;
  late ImmersiveModeService _immersiveModeService;
  final GlobalKey<_HoverMenuOverlayState> _menuOverlayKey =
      GlobalKey<_HoverMenuOverlayState>();

  @override
  void initState() {
    super.initState();
    _syncController = SyncAnimationController(vsync: this);
    _immersiveModeService = ImmersiveModeService();
    _immersiveModeService.initialize();
    _immersiveModeService.addListener(_onImmersiveModeChanged);
  }

  @override
  void dispose() {
    _syncController.dispose();
    _immersiveModeService.removeListener(_onImmersiveModeChanged);
    super.dispose();
  }

  void _onImmersiveModeChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void startSyncAnimation() {
    setState(() {
      _syncController.start();
    });
  }

  void stopSyncAnimation() {
    setState(() {
      _syncController.stop();
    });
  }

  void _forceSync() async {
    setState(() {
      _syncController.start();
    });

    try {
      final syncService = SyncService();
      await syncService.forceSync();

      if (!mounted) return;

      // Notify parent to refresh all panels after successful sync
      widget.onForceSync?.call();

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

  void _openToDoScreen() async {
    if (widget.rootDir == null) return;

    // Mostrar indicador de sincronización
    setState(() {
      _syncController.start();
    });

    // Force synchronization before opening the screen
    try {
      final syncService = SyncService();
      await syncService.forceSync();

      if (!mounted) return;
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

    if (!mounted) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        settings: const RouteSettings(name: '/todo'),
        builder:
            (context) => TodoScreenDB(
              rootDir: widget.rootDir!,
              onDirectorySet: widget.onDirectorySet ?? () {},
              onThemeUpdated: widget.onThemeUpdated,
            ),
      ),
    );
  }

  void _openSettings() {
    showDialog(
      context: context,
      builder:
          (context) => SettingsScreen(onThemeUpdated: widget.onThemeUpdated),
    );
  }

  void _openBookmarksScreen() async {
    if (widget.rootDir == null) return;

    // Mostrar indicador de sincronización
    setState(() {
      _syncController.start();
    });

    // Force synchronization before opening the screen
    try {
      final syncService = SyncService();
      await syncService.forceSync();

      if (!mounted) return;
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

    if (!mounted) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (context) => LinksScreenDesktopDB(
              onLinkRemoved: () {},
              onBack: () => Navigator.of(context).pop(),
            ),
      ),
    );
  }

  void _openThinksScreen() async {
    if (widget.rootDir == null) return;

    // Mostrar indicador de sincronización
    setState(() {
      _syncController.start();
    });

    // Force synchronization before opening the screen
    try {
      final syncService = SyncService();
      await syncService.forceSync();

      if (!mounted) return;
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

    if (!mounted) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        settings: const RouteSettings(name: '/thinks'),
        builder:
            (context) => ThinksScreen(
              rootDir: widget.rootDir!,
              onOpenNote: widget.onOpenNote ?? (_) {},
              onClose: () => Navigator.of(context).pop(),
            ),
      ),
    );
  }

  void _openDiaryScreen() async {
    if (widget.rootDir == null) return;

    // Mostrar indicador de sincronización
    setState(() {
      _syncController.start();
    });

    // Force synchronization before opening the screen
    try {
      final syncService = SyncService();
      await syncService.forceSync();

      if (!mounted) return;
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

    if (!mounted) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (context) => DiaryScreen(
              rootDir: Directory.current,
              onOpenNote: (file) {},
              onClose: () => Navigator.of(context).pop(),
            ),
      ),
    );
  }

  void _openSearchScreen() {
    showDialog(
      context: context,
      builder:
          (context) => SearchScreenDesktop(
            onNoteSelected: (Note note) {
              widget.onNoteSelected?.call(note);
            },
            onNotebookSelected: (Notebook notebook) {
              widget.onNotebookSelected?.call(notebook);
            },
            onNoteSelectedWithSearch: (
              Note note,
              String searchQuery,
              bool isAdvancedSearch,
            ) {
              // Use the advanced search callback if available, otherwise fallback to regular callback
              if (widget.onNoteSelectedWithSearch != null) {
                widget.onNoteSelectedWithSearch!(
                  note,
                  searchQuery,
                  isAdvancedSearch,
                );
              } else {
                widget.onNoteSelected?.call(note);
              }
            },
          ),
    );
  }

  void _openFavoritesScreen() async {
    // Mostrar indicador de sincronización
    setState(() {
      _syncController.start();
    });

    // Force synchronization before opening the screen
    try {
      final syncService = SyncService();
      await syncService.forceSync();

      if (!mounted) return;
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

    if (!mounted) return;

    // Llamar al callback original
    widget.onOpenFavorites?.call();
  }

  void _openTrashScreen() async {
    // Mostrar indicador de sincronización
    setState(() {
      _syncController.start();
    });

    // Force synchronization before opening the screen
    try {
      final syncService = SyncService();
      await syncService.forceSync();

      if (!mounted) return;
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

    if (!mounted) return;

    // Llamar al callback original
    widget.onOpenTrash?.call();
  }

  void _toggleImmersiveMode() async {
    await _immersiveModeService.enterImmersiveMode();
  }

  IconSidebarButton _buildNewNoteMenuButton() {
    return IconSidebarButton(
      icon: Icons.note_add_rounded,
      onPressed: null,
      child: Stack(
        children: [
          IconButton(
            icon: Icon(
              Icons.note_add_rounded,
              size: widget.iconSize,
              color: Theme.of(context).colorScheme.primary,
            ),
            style: IconButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              minimumSize: Size(widget.iconSize + 16, widget.iconSize + 16),
              hoverColor: Theme.of(context).colorScheme.primary.withAlpha(20),
              focusColor: Theme.of(context).colorScheme.primary.withAlpha(31),
              highlightColor: Theme.of(
                context,
              ).colorScheme.primary.withAlpha(31),
            ),
            onPressed: () {
              final state = _menuOverlayKey.currentState;
              if (state != null) {
                state.toggleOverlay(context);
              }
            },
          ),
          HoverMenuOverlay(
            key: _menuOverlayKey,
            menuItems: [
              HoverMenuItem(
                icon: Icons.note_add_rounded,
                onTap: widget.onCreateNewNote,
                label: 'New Note',
              ),
              HoverMenuItem(
                icon: Icons.add_task_rounded,
                onTap: widget.onCreateNewTodo,
                label: 'New Task',
              ),
            ],
            iconSize: widget.iconSize,
          ),
        ],
      ),
    );
  }

  List<IconSidebarButton> _getButtons() {
    final isBookmarksScreen =
        widget.isBookmarksScreen || widget.onAddBookmark != null;

    return [
      if (widget.showBackButton && widget.onBack != null)
        IconSidebarButton(
          icon: Icons.arrow_back_rounded,
          onPressed: widget.onBack!,
          showInBookmarks: true,
        ),
      // Botones específicos para diary
      if (widget.isDiaryScreen) ...[
        if (widget.onCreateNewNote != null)
          IconSidebarButton(
            icon: Icons.note_add_rounded,
            onPressed: widget.onCreateNewNote!,
          ),
        if (widget.onToggleCalendar != null)
          IconSidebarButton(
            icon: Icons.calendar_month_rounded,
            onPressed: widget.onToggleCalendar!,
          ),
      ],
      // Botones para otras pantallas (solo si no es diary)
      if (!widget.isDiaryScreen) ...[
        if (!widget.isWorkflowsScreen &&
            !isBookmarksScreen &&
            !widget.isTasksScreen &&
            !widget.isThinksScreen &&
            !widget.isSettingsScreen)
          IconSidebarButton(
            icon: Icons.search_rounded,
            onPressed: _openSearchScreen,
          ),
        if (widget.isWorkflowsScreen)
          IconSidebarButton(
            icon: Icons.filter_1_rounded,
            onPressed: () => widget.onPageChanged?.call(0),
            showInBookmarks: true,
          ),
        if (widget.isWorkflowsScreen)
          IconSidebarButton(
            icon: Icons.filter_2_rounded,
            onPressed: () => widget.onPageChanged?.call(1),
            showInBookmarks: true,
          ),
        // Botón combinado de New Note + New Todo con menú desplegable
        if (!widget.isTasksScreen &&
            (widget.onCreateNewNote != null || widget.onCreateNewTodo != null))
          _buildNewNoteMenuButton(),
        // Botón simple de New Task para la pantalla de tareas
        if (widget.isTasksScreen && widget.onCreateNewTodo != null)
          IconSidebarButton(
            icon: Icons.add_task_rounded,
            onPressed: widget.onCreateNewTodo!,
          ),
        if (widget.onCreateNewNotebook != null)
          IconSidebarButton(
            icon: Icons.create_new_folder_rounded,
            onPressed: widget.onCreateNewNotebook!,
          ),
        if (widget.onShowManageTags != null)
          IconSidebarButton(
            icon: Icons.label_rounded,
            onPressed: widget.onShowManageTags!,
          ),
        if (widget.onCreateThink != null)
          IconSidebarButton(
            icon: Icons.add_circle_outline_rounded,
            onPressed: widget.onCreateThink!,
          ),
        if (!widget.isWorkflowsScreen &&
            !isBookmarksScreen &&
            !widget.isTasksScreen &&
            !widget.isThinksScreen &&
            !widget.isSettingsScreen)
          IconSidebarButton(
            icon: Symbols.neurology,
            onPressed: _openThinksScreen,
            showInBookmarks: true,
          ),
        if (!widget.isWorkflowsScreen &&
            !isBookmarksScreen &&
            !widget.isTasksScreen &&
            !widget.isThinksScreen &&
            !widget.isSettingsScreen)
          IconSidebarButton(
            icon: Icons.book_rounded,
            onPressed: _openDiaryScreen,
            showInBookmarks: true,
          ),
        if (!widget.isWorkflowsScreen &&
            !isBookmarksScreen &&
            !widget.isTasksScreen &&
            !widget.isThinksScreen &&
            !widget.isSettingsScreen)
          IconSidebarButton(
            icon: Icons.task_alt_rounded,
            onPressed: _openToDoScreen,
            showInBookmarks: true,
          ),
        if (!widget.isWorkflowsScreen &&
            !isBookmarksScreen &&
            !widget.isTasksScreen &&
            !widget.isThinksScreen &&
            !widget.isSettingsScreen)
          IconSidebarButton(
            icon: Icons.bookmarks_rounded,
            onPressed: _openBookmarksScreen,
          ),
        if (isBookmarksScreen && widget.onAddBookmark != null)
          IconSidebarButton(
            icon: Icons.add_rounded,
            onPressed: widget.onAddBookmark!,
            showInBookmarks: true,
          ),
        if (isBookmarksScreen && widget.onManageTags != null)
          IconSidebarButton(
            icon: Icons.label_rounded,
            onPressed: widget.onManageTags!,
            showInBookmarks: true,
          ),
        if (!widget.isWorkflowsScreen &&
            !isBookmarksScreen &&
            !widget.isTasksScreen &&
            !widget.isThinksScreen &&
            !widget.isSettingsScreen)
          IconSidebarButton(
            icon: Icons.calendar_month_rounded,
            onPressed: () {
              final state = widget.calendarPanelKey?.currentState;
              if (state != null) {
                // Try calling known API methods if available. Use `togglePanel`
                // if present to mirror previous behavior, otherwise try
                // `showPanel`/`hidePanel` fallbacks.
                try {
                  // Prefer togglePanel
                  final toggle = state.togglePanel;
                  if (toggle is Function) {
                    toggle();
                    return;
                  }
                } catch (_) {}

                try {
                  // Fallback: if panel exposes show/hide use them
                  final hide = state.hidePanel;
                  final show = state.showPanel;
                  if (hide is Function && show is Function) {
                    // If currently visible, hide, otherwise show. We don't have
                    // direct access to visibility flag here, so call toggle if
                    // available; otherwise call show then hide as a safe noop.
                    hide();
                    return;
                  }
                } catch (_) {}
              }
            },
            showInBookmarks: true,
          ),
        if (!widget.isWorkflowsScreen &&
            !isBookmarksScreen &&
            !widget.isTasksScreen &&
            !widget.isThinksScreen &&
            !widget.isSettingsScreen)
          IconSidebarButton(
            icon: Icons.fullscreen_rounded,
            onPressed: _toggleImmersiveMode,
            showInBookmarks: true,
          ),
      ],
    ];
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isBookmarksScreen =
        widget.isBookmarksScreen || widget.onAddBookmark != null;

    List<IconSidebarButton> buttons = _getButtons();

    final bottomButtons = [
      IconSidebarButton(
        icon: Icons.cloud_sync_rounded,
        onPressed: _forceSync,
        child:
            _syncController.isAnimating
                ? SyncIcon(
                  animationController: _syncController,
                  color: colorScheme.primary,
                )
                : null,
      ),
      if (widget.onOpenFavorites != null)
        IconSidebarButton(
          icon: Icons.favorite_rounded,
          onPressed: _openFavoritesScreen,
        ),
      if (!isBookmarksScreen && widget.onOpenTrash != null)
        IconSidebarButton(
          icon: Icons.delete_rounded,
          color: colorScheme.error,
          onPressed: _openTrashScreen,
        ),
      // Botón para ocultar/mostrar panel lateral en tasks, thinks y diary
      if ((widget.isTasksScreen || widget.isThinksScreen || widget.isDiaryScreen) && widget.onToggleSidebar != null)
        IconSidebarButton(
          icon: Icons.view_sidebar_rounded,
          onPressed: widget.onToggleSidebar!,
        ),
      IconSidebarButton(
        icon: Icons.settings_rounded,
        onPressed: widget.onOpenSettings ?? _openSettings,
      ),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 5),
      decoration: BoxDecoration(color: colorScheme.surfaceContainerLow),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            children:
                buttons
                    .where(
                      (button) => !isBookmarksScreen || button.showInBookmarks,
                    )
                    .map(
                      (button) =>
                          button.child != null
                              ? button.child!
                              : IconButton(
                                icon: Icon(
                                  button.icon,
                                  size: widget.iconSize,
                                  color: button.color ?? colorScheme.primary,
                                ),
                                onPressed: () {
                                  if (button.onPressed
                                      is Function(BuildContext)) {
                                    button.onPressed(context);
                                  } else {
                                    button.onPressed();
                                  }
                                },
                                style: IconButton.styleFrom(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  minimumSize: Size(
                                    widget.iconSize + 16,
                                    widget.iconSize + 16,
                                  ),
                                  hoverColor: colorScheme.primary.withAlpha(20),
                                  focusColor: colorScheme.primary.withAlpha(31),
                                  highlightColor: colorScheme.primary.withAlpha(
                                    31,
                                  ),
                                ),
                              ),
                    )
                    .toList(),
          ),
          Column(
            children:
                bottomButtons
                    .map(
                      (button) => IconButton(
                        icon: Icon(
                          button.icon,
                          size: widget.iconSize,
                          color: button.color ?? colorScheme.primary,
                        ),
                        onPressed: () {
                          if (button.onPressed is Function(BuildContext)) {
                            button.onPressed(context);
                          } else {
                            button.onPressed();
                          }
                        },
                        style: IconButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          minimumSize: Size(
                            widget.iconSize + 16,
                            widget.iconSize + 16,
                          ),
                          hoverColor: colorScheme.primary.withAlpha(20),
                          focusColor: colorScheme.primary.withAlpha(31),
                          highlightColor: colorScheme.primary.withAlpha(31),
                        ),
                      ),
                    )
                    .toList(),
          ),
        ],
      ),
    );
  }
}
