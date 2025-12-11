import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'icon_sidebar.dart';
import '../database/models/note.dart';
import '../database/models/notebook.dart';

class ResizableIconSidebar extends StatefulWidget {
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
  final VoidCallback? onFavoritesReload;
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
  final FocusNode appFocusNode;
  final VoidCallback? onForceSync;

  const ResizableIconSidebar({
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
    this.onFavoritesReload,
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
    required this.appFocusNode,
    this.onForceSync,
  });

  @override
  ResizableIconSidebarState createState() => ResizableIconSidebarState();
}

class ResizableIconSidebarState extends State<ResizableIconSidebar>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _widthAnimation;
  late GlobalIconSidebarState _globalIconSidebarState;
  double _currentWidth = 70;

  bool get isExpanded => _globalIconSidebarState.isExpanded;

  @override
  void initState() {
    super.initState();
    _globalIconSidebarState = GlobalIconSidebarState();
    _currentWidth = _globalIconSidebarState.width;
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _widthAnimation = Tween<double>(begin: 0, end: _currentWidth).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    // Al abrir, setear el valor final sin animación
    if (_globalIconSidebarState.isExpanded) {
      _animationController.value = 1.0;
    }
    // Escuchar cambios globales para sincronizar el ancho
    _globalIconSidebarState.addListener(_onGlobalSidebarChanged);
  }

  void _onGlobalSidebarChanged() {
    if (!mounted) return;
    if (_globalIconSidebarState.isExpanded) {
      setState(() {
        _currentWidth = _globalIconSidebarState.width;
        _widthAnimation = Tween<double>(begin: 0, end: _currentWidth).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Curves.easeInOut,
          ),
        );
        _animationController.value = 1.0;
      });
    } else {
      setState(() {
        _animationController.value = 0.0;
      });
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _globalIconSidebarState.removeListener(_onGlobalSidebarChanged);
    super.dispose();
  }

  void _onDragUpdate(DragUpdateDetails details) {
    if (!_globalIconSidebarState.isExpanded) return;
    setState(() {
      final newWidth = (_currentWidth + details.delta.dx).clamp(50.0, 80.0);
      _currentWidth = newWidth;
      _widthAnimation = Tween<double>(begin: 0, end: _currentWidth).animate(
        CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
      );
      _animationController.value = 1.0;
    });
  }

  void _onDragEnd(DragEndDetails details) {
    _globalIconSidebarState.setWidth(_currentWidth);
  }

  void togglePanel() {
    final navigatorContext = context;
    _globalIconSidebarState.setExpanded(!_globalIconSidebarState.isExpanded);
    Future.delayed(const Duration(milliseconds: 300), () {
      if (!navigatorContext.mounted) return;
      if (widget.appFocusNode.canRequestFocus) {
        FocusScope.of(navigatorContext).requestFocus(widget.appFocusNode);
      }
    });
  }

  void hidePanel() {
    final navigatorContext = context;
    _globalIconSidebarState.setExpanded(false);
    Future.delayed(const Duration(milliseconds: 300), () {
      if (!navigatorContext.mounted) return;
      if (widget.appFocusNode.canRequestFocus) {
        FocusScope.of(navigatorContext).requestFocus(widget.appFocusNode);
      }
    });
  }

  void showPanel() {
    final navigatorContext = context;
    _globalIconSidebarState.setExpanded(true);
    Future.delayed(const Duration(milliseconds: 300), () {
      if (!navigatorContext.mounted) return;
      if (widget.appFocusNode.canRequestFocus) {
        FocusScope.of(navigatorContext).requestFocus(widget.appFocusNode);
      }
    });
  }

  void collapsePanel() {
    if (!_globalIconSidebarState.isExpanded) return; // Already collapsed

    final navigatorContext = context;
    _globalIconSidebarState.setExpanded(false);
    Future.delayed(const Duration(milliseconds: 300), () {
      if (!navigatorContext.mounted) return;
      if (widget.appFocusNode.canRequestFocus) {
        FocusScope.of(navigatorContext).requestFocus(widget.appFocusNode);
      }
    });
  }

  void expandPanel() {
    if (_globalIconSidebarState.isExpanded) return; // Already expanded

    final navigatorContext = context;
    _globalIconSidebarState.setExpanded(true);
    Future.delayed(const Duration(milliseconds: 300), () {
      if (!navigatorContext.mounted) return;
      if (widget.appFocusNode.canRequestFocus) {
        FocusScope.of(navigatorContext).requestFocus(widget.appFocusNode);
      }
    });
  }

  double _getIconSize() {
    final availableWidth = _currentWidth - 10;
    final iconSize = (availableWidth * 0.6).clamp(16.0, 48.0);
    return iconSize.toDouble();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        final targetWidth = _globalIconSidebarState.isExpanded
            ? _widthAnimation.value
            : 0.0;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRect(
              child: SizedBox(
                width: targetWidth,
                child: OverflowBox(
                  alignment: Alignment.centerLeft,
                  minWidth: _currentWidth,
                  maxWidth: _currentWidth,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Container(
                        width: double.infinity,
                        height: double.infinity,
                        color: Theme.of(context).colorScheme.surfaceContainerLow,
                        child: IconSidebar(
                          rootDir: widget.rootDir,
                          onOpenNote: widget.onOpenNote,
                          onOpenFolder: widget.onOpenFolder,
                          onNotebookSelected: widget.onNotebookSelected,
                          onNoteSelected: widget.onNoteSelected,
                          onNoteSelectedWithSearch: widget.onNoteSelectedWithSearch,
                          onBack: widget.onBack,
                          onDirectorySet: widget.onDirectorySet,
                          onThemeUpdated: widget.onThemeUpdated,
                          onFavoriteRemoved: widget.onFavoriteRemoved,
                          onNavigateToMain: widget.onNavigateToMain,
                          onClose: widget.onClose,
                          onCreateNewNote: widget.onCreateNewNote,
                          onCreateNewNotebook: widget.onCreateNewNotebook,
                          onCreateNewTodo: widget.onCreateNewTodo,
                          onShowManageTags: widget.onShowManageTags,
                          onCreateThink: widget.onCreateThink,
                          onOpenSettings: widget.onOpenSettings,
                          onOpenTrash: widget.onOpenTrash,
                          onOpenFavorites: widget.onOpenFavorites,
                          onFavoritesReload: widget.onFavoritesReload,
                          showBackButton: widget.showBackButton,
                          isWorkflowsScreen: widget.isWorkflowsScreen,
                          isTasksScreen: widget.isTasksScreen,
                          isThinksScreen: widget.isThinksScreen,
                          isSettingsScreen: widget.isSettingsScreen,
                          isBookmarksScreen: widget.isBookmarksScreen,
                          isDiaryScreen: widget.isDiaryScreen,
                          onPageChanged: widget.onPageChanged,
                          onAddBookmark: widget.onAddBookmark,
                          onManageTags: widget.onManageTags,
                          onToggleView: widget.onToggleView,
                          isGridView: widget.isGridView,
                          searchLayerLink: widget.searchLayerLink,
                          calendarPanelKey: widget.calendarPanelKey,
                          onToggleCalendar: widget.onToggleCalendar,
                          onToggleSidebar: widget.onToggleSidebar,
                          iconSize: _getIconSize(),
                          onForceSync: widget.onForceSync,
                        ),
                      ),
                      Positioned(
                        right: 0,
                        top: 0,
                        bottom: 0,
                        child: MouseRegion(
                          cursor: SystemMouseCursors.resizeLeftRight,
                          child: GestureDetector(
                            onPanUpdate: _onDragUpdate,
                            onPanEnd: _onDragEnd,
                            child: Container(width: 8, color: Colors.transparent),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class GlobalIconSidebarState extends ChangeNotifier {
  static final GlobalIconSidebarState _instance =
      GlobalIconSidebarState._internal();
  factory GlobalIconSidebarState() => _instance;
  GlobalIconSidebarState._internal();

  double _width = 70;
  bool _isExpanded = true;
  bool _isInitialized = false;

  double get width => _width;
  bool get isExpanded => _isExpanded;

  Future<void> initialize() async {
    if (_isInitialized) return;

    final prefs = await SharedPreferences.getInstance();
    _width = prefs.getDouble('icon_sidebar_width') ?? 70;
    // Always start with icon sidebar expanded on app restart
    _isExpanded = true;
    await prefs.setBool('icon_sidebar_expanded', true);
    _isInitialized = true;
    notifyListeners();
  }

  Future<void> setWidth(double width) async {
    _width = width;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('icon_sidebar_width', width);
    notifyListeners();
  }

  Future<void> setExpanded(bool isExpanded) async {
    _isExpanded = isExpanded;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('icon_sidebar_expanded', isExpanded);
    notifyListeners();
  }
}
