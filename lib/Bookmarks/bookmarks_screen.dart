import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:async';
import 'package:intl/intl.dart';
import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';
import '../widgets/resizable_icon_sidebar.dart';
import '../Settings/settings_screen.dart';
import '../database/database_service.dart';
import '../database/database_helper.dart';
import '../database/models/bookmark.dart';
import 'bookmarks_handler.dart';
import 'bookmarks_tags_handler.dart';
import '../widgets/custom_snackbar.dart';
import '../widgets/custom_tooltip.dart';
import '../widgets/context_menu.dart';
import '../widgets/confirmation_dialogue.dart';
import 'bookmarks_sidebar_panel.dart';
import 'bookmarks_dialogs.dart';

class LinksScreenDesktopDB extends StatefulWidget {
  final VoidCallback onLinkRemoved;
  final VoidCallback onBack;

  const LinksScreenDesktopDB({
    super.key,
    required this.onLinkRemoved,
    required this.onBack,
  });

  @override
  State<LinksScreenDesktopDB> createState() => LinksScreenDesktopDBState();
}

class LinksScreenDesktopDBState extends State<LinksScreenDesktopDB>
    with TickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final LinksHandlerDB _linksHandler = LinksHandlerDB();
  final TagsHandlerDB _tagsHandler = TagsHandlerDB();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _appFocusNode = FocusNode();
  Directory? _rootDir;
  bool _isLoading = true;
  List<Bookmark> _filteredBookmarks = [];
  StreamSubscription? _dbSubscription;

  // Variables for resizable panel
  double _sidebarWidth = 240;
  bool _isSidebarVisible = true;
  late AnimationController _sidebarAnimController;
  late Animation<double> _sidebarWidthAnimation;

  void refresh() {
    _loadBookmarks();
  }

  @override
  void initState() {
    super.initState();
    _linksHandler.resetSearch();
    
    // Initialize sidebar animation
    _sidebarAnimController = AnimationController(
        duration: const Duration(milliseconds: 200),
        vsync: this,
        value: 1.0,
    );
    _sidebarWidthAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _sidebarAnimController, curve: Curves.easeInOut),
    );
    
    _initializeBookmarks();
    _loadRootDir();
    _loadSidebarSettings();

    // Listen to database changes for background sync updates
    _dbSubscription = DatabaseHelper.onDatabaseChanged.listen((_) {
      if (mounted) {
        _loadBookmarks();
      }
    });
  }

  Future<void> _loadSidebarSettings() async {
      final prefs = await SharedPreferences.getInstance();
      final width = prefs.getDouble('bookmarks_sidebar_width') ?? 240;
      if (mounted) {
          setState(() {
              _sidebarWidth = width;
          });
      }
  }

  Future<void> _saveSidebarWidth(double width) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('bookmarks_sidebar_width', width);
  }

  void _onDragUpdate(DragUpdateDetails details) {
    setState(() {
      _sidebarWidth = (_sidebarWidth + details.delta.dx).clamp(200.0, 400.0);
    });
  }

  void _onDragEnd() async {
    await _saveSidebarWidth(_sidebarWidth);
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

  @override
  void dispose() {
    _sidebarAnimController.dispose();
    _dbSubscription?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    _appFocusNode.dispose();
    super.dispose();
  }

  Future<void> _initializeBookmarks() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Inicializar la base de datos y cargar datos en paralelo
      await Future.wait([
        DatabaseService().initializeDatabase(),
        _loadBookmarks(),
        _tagsHandler.loadPatterns(),
      ]);
    } catch (e) {
      print('Error initializing bookmarks: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadBookmarks() async {
    try {
      // Cargar bookmarks con filtrado asíncrono
      final bookmarks = await _linksHandler.getFilteredBookmarks();
      if (mounted) {
        setState(() {
          _filteredBookmarks = bookmarks;
        });
      }
    } catch (e) {
      print('Error loading bookmarks: $e');
      if (mounted) {
        setState(() {
          _filteredBookmarks = [];
        });
      }
    }
  }

  Future<void> _handleBookmarkDropOnTag(Bookmark bookmark, String tag) async {
    if (bookmark.id == null) return;

    final List<String> currentTags;

    if (tag == 'Untagged') {
      if (bookmark.tags.isEmpty) return;
      currentTags = [];
    } else {
      currentTags = List<String>.from(bookmark.tags);
      if (currentTags.contains(tag)) return;
      currentTags.add(tag);
    }

    try {
      await _linksHandler.updateBookmark(
        id: bookmark.id!,
        newTitle: bookmark.title,
        newUrl: bookmark.url,
        newDescription: bookmark.description,
        newTags: currentTags,
      );
      await _loadBookmarks();
    } catch (e) {
      if (mounted) {
        CustomSnackbar.show(
          context: context,
          message: 'Error updating bookmark tags: $e',
          type: CustomSnackbarType.error,
        );
      }
    }
  }

  Future<void> _loadRootDir() async {
    final prefs = await SharedPreferences.getInstance();
    final dirPath = prefs.getString('notes_directory');
    if (dirPath != null) {
      setState(() {
        _rootDir = Directory(dirPath);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: Stack(
        children: [
          // Main content
          Row(
            children: [
              // Left sidebar
              ResizableIconSidebar(
                rootDir: _rootDir,
                onOpenNote: (file) {},
                onOpenFolder: (dir) {},
                onNotebookSelected: null,
                onNoteSelected: null,
                onBack: widget.onBack,
                onDirectorySet: () {},
                onThemeUpdated: () {},
                onFavoriteRemoved: () {},
                onNavigateToMain: () {},
                onClose: () {},
                onCreateNewNote: null,
                onCreateNewNotebook: null,
                onCreateNewTodo: null,
                onShowManageTags: null,
                onCreateThink: null,
                onOpenSettings: _openSettings,
                onOpenTrash: null,
                onOpenFavorites: null,
                showBackButton: true,
                isTasksScreen: false,
                isThinksScreen: false,
                isSettingsScreen: false,
                isBookmarksScreen: true,
                onAddBookmark: () => BookmarksDialogs.showAddBookmarkDialog(
                  context: context,
                  linksHandler: _linksHandler,
                  onSuccess: _loadBookmarks,
                ),
                onManageTags: () => BookmarksDialogs.showManageTagsDialog(
                  context: context,
                  tagsHandler: _tagsHandler,
                ),
                appFocusNode: _appFocusNode,
                onToggleSidebar: _toggleSidebar,
              ),

              // Animated Sidebar
              AnimatedBuilder(
                animation: _sidebarWidthAnimation,
                builder: (context, child) {
                  final animatedWidth =
                      _sidebarWidthAnimation.value * (_sidebarWidth + 1);
                  if (animatedWidth <= 0 && !_isSidebarVisible) {
                    return const SizedBox.shrink();
                  }
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      /* Fixed: Added vertical divider */
                      VerticalDivider(
                        width: 1,
                        thickness: 1,
                        color: colorScheme.surfaceContainerHighest,
                      ),
                      ClipRect(
                        child: SizedBox(
                          width: animatedWidth,
                          child: OverflowBox(
                            alignment: Alignment.centerLeft,
                            minWidth: 0,
                            maxWidth: _sidebarWidth + 1,
                            child: child,
                          ),
                        ),
                      ),
                    ],
                  );
                },
                child: BookmarksSidebarPanel(
                  width: _sidebarWidth,
                  totalBookmarks: _filteredBookmarks.length,
                  tags: _linksHandler.allTags,
                  selectedTag: _linksHandler.selectedTag,
                  isOldestFirst: _linksHandler.isOldestFirst,
                  searchQuery: _linksHandler.searchQuery,
                  searchController: _searchController,
                  onSearchChanged: (value) {
                    _linksHandler.setSearchQuery(value);
                    _loadBookmarks();
                    setState(() {});
                  },
                  onTagSelected: (tag) {
                    _linksHandler.setSelectedTag(
                      _linksHandler.selectedTag == tag ? null : tag,
                    );
                    _loadBookmarks();
                    setState(() {});
                  },
                  onSortToggle: () {
                    _linksHandler.toggleSortOrder();
                    _loadBookmarks();
                    setState(() {});
                  },
                  onDragUpdate: _onDragUpdate,
                  onDragEnd: _onDragEnd,
                  onBookmarkDropped: _handleBookmarkDropOnTag,
                ),
              ),

              // Main content (List only)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 40),
                  child: Column(
                    children: [
                      Expanded(
                        child:
                            _isLoading
                                ? Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      CircularProgressIndicator(),
                                      const SizedBox(height: 16),
                                      Text(
                                        'Loading bookmarks...',
                                        style: TextStyle(
                                          color: colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                                : _buildBookmarksList(
                                  _filteredBookmarks,
                                  colorScheme,
                                ),
                      ),
                    ],
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
            height: 48,
            child: MoveWindow(
                child: Container(
                  color: Colors.transparent,
                ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBookmarksList(
    List<Bookmark> bookmarks,
    ColorScheme colorScheme,
  ) {
    if (bookmarks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _linksHandler.isSearching
                  ? Icons.search_off_rounded
                  : Icons.bookmarks_outlined,
              size: 48,
              color: colorScheme.onSurfaceVariant.withAlpha(127),
            ),
            const SizedBox(height: 16),
            Text(
              _linksHandler.isSearching
                  ? 'No results found for "${_linksHandler.searchQuery}"'
                  : 'No saved bookmarks',
              style: TextStyle(color: colorScheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            if (_linksHandler.isSearching)
              Padding(
                padding: const EdgeInsets.only(top: 12.0),
                child: TextButton.icon(
                  icon: const Icon(Icons.clear_rounded),
                  label: const Text('Clear search'),
                  onPressed: () {
                    _linksHandler.setSearchQuery('');
                    _loadBookmarks();
                    setState(() {});
                  },
                ),
              ),
            if (!_linksHandler.isSearching)
              Padding(
                padding: const EdgeInsets.only(top: 12.0),
                child: TextButton.icon(
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Add a bookmark'),
                  onPressed: () => BookmarksDialogs.showAddBookmarkDialog(
                    context: context,
                    linksHandler: _linksHandler,
                    onSuccess: _loadBookmarks,
                  ),
                ),
              ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: EdgeInsets.zero,
      itemCount: bookmarks.length,
      itemBuilder: (context, index) {
        final bookmark = bookmarks[index];
        final uri = Uri.tryParse(bookmark.url);

        return _BookmarkListItem(
          bookmark: bookmark,
          colorScheme: colorScheme,
          onDelete: () => _showDeleteConfirmation(bookmark),
          onEdit: () => BookmarksDialogs.showEditBookmarkDialog(
            context: context,
            linksHandler: _linksHandler,
            bookmark: bookmark,
            onSuccess: _loadBookmarks,
          ),
          onCopy: () => _copyLinkToClipboard(bookmark.url),
          onTap: () async {
            if (uri != null && await canLaunchUrl(uri)) {
              await _launchUrl(bookmark.url);
            }
          },
        );
      },
    );
  }

  Future<void> _showDeleteConfirmation(Bookmark bookmark) async {
    final confirmed = await showDeleteConfirmationDialog(
      context: context,
      title: 'Delete Bookmark',
      message:
          'Are you sure you want to delete this bookmark?\n${bookmark.title}',
      confirmText: 'Delete',
      confirmColor: Theme.of(context).colorScheme.error,
    );

    if (confirmed == true) {
      await _linksHandler.removeBookmark(bookmark.id!);
      widget.onLinkRemoved();
      await _loadBookmarks();
      setState(() {});
    }
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (mounted) {
        CustomSnackbar.show(
          context: context,
          message: 'Could not open URL: $url',
          type: CustomSnackbarType.error,
        );
      }
    }
  }

  Future<void> _copyLinkToClipboard(String url) async {
    await Clipboard.setData(ClipboardData(text: url));
    if (mounted) {
      CustomSnackbar.show(
        context: context,
        message: 'Link copied to clipboard',
        type: CustomSnackbarType.success,
      );
    }
  }

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
  }
}

class _BookmarkIcon extends StatelessWidget {
  final String url;
  final double size;
  final ColorScheme colorScheme;

  const _BookmarkIcon({
    required this.url,
    required this.size,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    final uri = Uri.tryParse(url);
    final host = uri?.host.replaceAll('www.', '') ?? '';

    if (host.isEmpty) {
      return _buildFallback('?');
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(size * 0.2),
        border: Border.all(
          color: colorScheme.outlineVariant.withAlpha(50),
          width: 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.2 - 1),
        child: Image.network(
          'https://www.google.com/s2/favicons?domain=${uri!.host}&sz=32',
          width: size,
          height: size,
          fit: BoxFit.contain,
          errorBuilder:
              (context, error, stackTrace) =>
                  _buildFallback(host[0].toUpperCase()),
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return _buildFallback(host[0].toUpperCase());
          },
        ),
      ),
    );
  }

  Widget _buildFallback(String initial) {
    // Generate a consistent color based on the initial
    final List<Color> colors = [
      Colors.blue,
      Colors.red,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.teal,
      Colors.indigo,
      Colors.pink,
      Colors.amber,
      Colors.cyan,
    ];

    final colorIndex = initial.codeUnitAt(0) % colors.length;
    final baseColor = colors[colorIndex];

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: baseColor.withAlpha(30),
        borderRadius: BorderRadius.circular(size * 0.2),
        border: Border.all(color: baseColor.withAlpha(50), width: 1),
      ),
      child: Center(
        child: Text(
          initial,
          style: TextStyle(
            color: baseColor,
            fontWeight: FontWeight.bold,
            fontSize: size * 0.5,
          ),
        ),
      ),
    );
  }
}

class _BookmarkListItem extends StatefulWidget {
  final Bookmark bookmark;
  final ColorScheme colorScheme;
  final VoidCallback onDelete;
  final VoidCallback onEdit;
  final VoidCallback onCopy;
  final VoidCallback onTap;

  const _BookmarkListItem({
    required this.bookmark,
    required this.colorScheme,
    required this.onDelete,
    required this.onEdit,
    required this.onCopy,
    required this.onTap,
  });

  @override
  State<_BookmarkListItem> createState() => _BookmarkListItemState();
}

class _BookmarkListItemState extends State<_BookmarkListItem> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    final date = DateTime.parse(widget.bookmark.timestamp);
    final formattedDate = DateFormat("dd/MMM/yyyy - HH:mm").format(date);

    return Draggable<Bookmark>(
      data: widget.bookmark,
      dragAnchorStrategy: pointerDragAnchorStrategy,
      feedback: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          constraints: const BoxConstraints(maxWidth: 250),
          decoration: BoxDecoration(
            color: widget.colorScheme.surfaceContainerHighest.withAlpha(230),
            borderRadius: BorderRadius.circular(10),
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
              _BookmarkIcon(
                url: widget.bookmark.url,
                size: 24,
                colorScheme: widget.colorScheme,
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  widget.bookmark.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: widget.colorScheme.onSurface,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovering = true),
        onExit: (_) => setState(() => _isHovering = false),
        child: Container(
          margin: const EdgeInsets.only(bottom: 4, left: 8, right: 8),
          decoration: BoxDecoration(
            color:
                _isHovering
                    ? widget.colorScheme.surfaceContainerHighest
                    : widget.colorScheme.surface,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: widget.onTap,
              onSecondaryTapDown: (details) {
                ContextMenuOverlay.show(
                  context: context,
                  tapPosition: details.globalPosition,
                  items: [
                    ContextMenuItem(
                      icon: Icons.edit_rounded,
                      label: 'Edit',
                      onTap: widget.onEdit,
                    ),
                    ContextMenuItem(
                      icon: Icons.copy_rounded,
                      label: 'Copy Link',
                      onTap: widget.onCopy,
                    ),
                    ContextMenuItem(
                      icon: Icons.delete_forever_rounded,
                      label: 'Delete',
                      iconColor: Theme.of(context).colorScheme.error,
                      onTap: widget.onDelete,
                    ),
                  ],
                );
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Ícono de bookmark (favicon)
                    _BookmarkIcon(
                      url: widget.bookmark.url,
                      size: 32,
                      colorScheme: widget.colorScheme,
                    ),
                    const SizedBox(width: 16),
                    // Título y detalles
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.bookmark.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: widget.colorScheme.onSurface,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.bookmark.url,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: widget.colorScheme.onSurface.withAlpha(
                                130,
                              ),
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.access_time_rounded,
                                size: 14,
                                color: widget.colorScheme.primary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                formattedDate,
                                style: TextStyle(
                                  color: widget.colorScheme.onSurface.withAlpha(
                                    130,
                                  ),
                                  fontSize: 11,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: SizedBox(
                                  height: 20,
                                  child: ListView(
                                    scrollDirection: Axis.horizontal,
                                    children:
                                        widget.bookmark.tags
                                            .map(
                                              (tag) => Container(
                                                margin: const EdgeInsets.only(
                                                  right: 6,
                                                ),
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 6,
                                                      vertical: 2,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: widget
                                                      .colorScheme
                                                      .primary
                                                      .withAlpha(20),
                                                  borderRadius:
                                                      BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  tag,
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    color:
                                                        widget
                                                            .colorScheme
                                                            .primary,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ),
                                            )
                                            .toList(),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Botón eliminar
                    Opacity(
                      opacity: _isHovering ? 1.0 : 0.0,
                      child: IgnorePointer(
                        ignoring: !_isHovering,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CustomTooltip(
                              message: 'Edit',
                              builder:
                                  (context, isHovering) => IconButton(
                                    icon: Icon(
                                      Icons.edit_rounded,
                                      color: widget.colorScheme.primary,
                                      size: 18,
                                    ),
                                    onPressed: widget.onEdit,
                                    constraints: const BoxConstraints(
                                      minWidth: 32,
                                      minHeight: 32,
                                    ),
                                    padding: EdgeInsets.zero,
                                  ),
                            ),
                            CustomTooltip(
                              message: 'Copy Link',
                              builder:
                                  (context, isHovering) => IconButton(
                                    icon: Icon(
                                      Icons.copy_rounded,
                                      color: widget.colorScheme.primary,
                                      size: 18,
                                    ),
                                    onPressed: widget.onCopy,
                                    constraints: const BoxConstraints(
                                      minWidth: 32,
                                      minHeight: 32,
                                    ),
                                    padding: EdgeInsets.zero,
                                  ),
                            ),
                            CustomTooltip(
                              message: 'Delete',
                              builder:
                                  (context, isHovering) => IconButton(
                                    icon: Icon(
                                      Icons.delete_forever_rounded,
                                      color: widget.colorScheme.error,
                                      size: 18,
                                    ),
                                    onPressed: widget.onDelete,
                                    constraints: const BoxConstraints(
                                      minWidth: 32,
                                      minHeight: 32,
                                    ),
                                    padding: EdgeInsets.zero,
                                  ),
                            ),
                          ],
                        ),
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
  }
}
