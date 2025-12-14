import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:any_link_preview/any_link_preview.dart';
import 'package:flutter/services.dart';
import '../widgets/resizable_icon_sidebar.dart';
import '../Settings/settings_screen.dart';
import '../database/database_service.dart';
import '../database/models/bookmark.dart';
import '../database/models/bookmark_tag.dart';
import 'bookmarks_handler_db.dart';
import 'bookmarks_tags_handler_db.dart';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html;
import '../widgets/custom_snackbar.dart';
import '../widgets/context_menu.dart';
import '../widgets/confirmation_dialogue.dart';

class LinksScreenDesktopDB extends StatefulWidget {
  final VoidCallback onLinkRemoved;
  final VoidCallback onBack;

  const LinksScreenDesktopDB({
    super.key,
    required this.onLinkRemoved,
    required this.onBack,
  });

  @override
  State<LinksScreenDesktopDB> createState() => _LinksScreenDesktopDBState();
}

class _LinksScreenDesktopDBState extends State<LinksScreenDesktopDB>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final LinksHandlerDB _linksHandler = LinksHandlerDB();
  final TagsHandlerDB _tagsHandler = TagsHandlerDB();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _appFocusNode = FocusNode();
  bool _isGridView = false;
  Directory? _rootDir;
  bool _isLoading = true;
  List<Bookmark> _filteredBookmarks = [];

  @override
  void initState() {
    super.initState();
    _linksHandler.resetSearch();
    _initializeBookmarks();
    _loadViewPreference();
    _loadRootDir();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _appFocusNode.dispose();
    super.dispose();
  }

  Widget _buildTagChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    required ColorScheme colorScheme,
  }) {
    return Material(
      color: isSelected ? colorScheme.primary.withAlpha(25) : colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        hoverColor: colorScheme.primary.withAlpha(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                label == LinksHandlerDB.hiddenTag ? (isSelected ? Icons.visibility_rounded : Icons.visibility_off_rounded) : (isSelected ? Icons.label_rounded : Icons.label_outline_rounded),
                size: 20,
                color: colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: isSelected ? colorScheme.primary : colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
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

  Future<void> _loadViewPreference() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isGridView = prefs.getBool('bookmarks_grid_view') ?? false;
    });
  }

  Future<void> _saveViewPreference(bool isGridView) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('bookmarks_grid_view', isGridView);
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
                isWorkflowsScreen: false,
                isTasksScreen: false,
                isThinksScreen: false,
                isSettingsScreen: false,
                isBookmarksScreen: true,
                onAddBookmark: _showAddLinkDialog,
                onManageTags: _showManageTagsDialog,
                onToggleView: () {
                  setState(() {
                    _isGridView = !_isGridView;
                    _saveViewPreference(_isGridView);
                  });
                },
                isGridView: _isGridView,
                appFocusNode: _appFocusNode,
              ),

              VerticalDivider(
                width: 1,
                thickness: 1,
                color: colorScheme.surfaceContainerHighest,
              ),

              // Main content
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 40),
                  child: Column(
                    children: [
                      // Sort button and Tags
                      Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        child: Row(
                          children: [
                            // Botón de búsqueda
                            IconButton(
                              icon: Icon(
                                _linksHandler.isSearching
                                    ? Icons.search_off_rounded
                                    : Icons.search_rounded,
                                color:
                                    _linksHandler.isSearching
                                        ? colorScheme.primary
                                        : colorScheme.onSurfaceVariant,
                              ),
                              onPressed: () {
                                _linksHandler.toggleSearch();
                                _loadBookmarks();
                                setState(() {});
                              },
                            ),
                            // Campo de búsqueda
                            AnimatedSize(
                              duration: const Duration(milliseconds: 200),
                              curve: Curves.easeInOut,
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                curve: Curves.easeInOut,
                                width: _linksHandler.isSearching ? 200 : 0,
                                child:
                                    _linksHandler.isSearching
                                        ? Padding(
                                          padding: const EdgeInsets.only(
                                            right: 8,
                                          ),
                                          child: TextField(
                                            autofocus: true,
                                            decoration: const InputDecoration(
                                              hintText: 'Search bookmarks...',
                                              isDense: true,
                                              contentPadding:
                                                  EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 8,
                                                  ),
                                              border: OutlineInputBorder(),
                                            ),
                                            onChanged: (value) {
                                              _linksHandler.setSearchQuery(
                                                value,
                                              );
                                              _loadBookmarks();
                                              setState(() {});
                                            },
                                          ),
                                        )
                                        : const SizedBox.shrink(),
                              ),
                            ),
                            // Botón de ordenamiento
                            IconButton(
                              icon: Tooltip(
                                message: _linksHandler.isOldestFirst ? '' : '',
                                child: RotatedBox(
                                  quarterTurns:
                                      _linksHandler.isOldestFirst ? 2 : 0,
                                  child: Icon(
                                    Icons.arrow_downward_rounded,
                                    color:
                                        _linksHandler.isOldestFirst
                                            ? colorScheme.primary
                                            : colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                              onPressed: () {
                                _linksHandler.toggleSortOrder();
                                _loadBookmarks();
                                setState(() {});
                              },
                            ),
                            // Eliminamos los botones de la barra superior
                            if (_linksHandler.allTags.isNotEmpty)
                              Expanded(
                                child: SizedBox(
                                  height: 40,
                                  child: ListView(
                                    scrollDirection: Axis.horizontal,
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 2,
                                        ),
                                        child: _buildTagChip(
                                          label: 'All',
                                          isSelected: _linksHandler.selectedTag == null,
                                          onTap: () {
                                            _linksHandler.setSelectedTag(null);
                                            _loadBookmarks();
                                            setState(() {});
                                          },
                                          colorScheme: colorScheme,
                                        ),
                                      ),
                                      ..._linksHandler.allTags.map(
                                        (tag) => Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 2,
                                          ),
                                          child: _buildTagChip(
                                            label: tag,
                                            isSelected: _linksHandler.selectedTag == tag,
                                            onTap: () {
                                              _linksHandler.setSelectedTag(
                                                _linksHandler.selectedTag == tag ? null : tag,
                                              );
                                              _loadBookmarks();
                                              setState(() {});
                                            },
                                            colorScheme: colorScheme,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),

                      // Bookmarks list/grid
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
                                : _isGridView
                                ? _buildBookmarksGrid(
                                  _filteredBookmarks,
                                  colorScheme,
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
                color: colorScheme.surface,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Center(
                  child: Row(
                    children: [
                      Icon(
                        Icons.bookmarks_rounded,
                        size: 20,
                        color: colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Bookmarks',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text(
                          '${_filteredBookmarks.length}',
                          style: TextStyle(
                            color: colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const Spacer(),
                    ],
                  ),
                ),
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
                  ? Icons.search_off
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
                  icon: const Icon(Icons.clear),
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
                  icon: const Icon(Icons.add),
                  label: const Text('Add a bookmark'),
                  onPressed: _showAddLinkDialog,
                ),
              ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.only(top: 8),
      itemCount: bookmarks.length,
      itemBuilder: (context, index) {
        final bookmark = bookmarks[index];
        final uri = Uri.tryParse(bookmark.url);
        final date = DateTime.parse(bookmark.timestamp);
        final formattedDate = DateFormat("dd/MMM/yyyy - HH:mm").format(date);

        return Material(
          color: Colors.transparent,
          child: GestureDetector(
            onSecondaryTapDown: (details) {
              ContextMenuOverlay.show(
                context: context,
                tapPosition: details.globalPosition,
                items: [
                  ContextMenuItem(
                    icon: Icons.copy,
                    label: 'Copy Link',
                    onTap: () => _copyLinkToClipboard(bookmark.url),
                  ),
                  ContextMenuItem(
                    icon: Icons.edit,
                    label: 'Edit',
                    onTap: () => _showEditLinkDialog(bookmark),
                  ),
                  ContextMenuItem(
                    icon: Icons.delete_forever_rounded,
                    label: 'Delete',
                    iconColor: Theme.of(context).colorScheme.error,
                    onTap: () => _showDeleteConfirmation(bookmark),
                  ),
                ],
              );
            },
            child: InkWell(
              onTap: () async {
                if (uri != null && await canLaunchUrl(uri)) {
                  await _launchUrl(bookmark.url);
                }
              },
              splashColor: colorScheme.primary.withAlpha(30),
              child: Container(
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: colorScheme.outline.withAlpha(26),
                      width: 1,
                    ),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainer,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Material(
                            shape: const CircleBorder(),
                            color: Colors.transparent,
                            child: Center(
                              child:
                                  uri != null
                                      ? Image.network(
                                        'https://www.google.com/s2/favicons?domain=${uri.host}&sz=64',
                                        width: 32,
                                        height: 32,
                                        errorBuilder:
                                            (_, __, ___) => Icon(
                                              Icons.link_rounded,
                                              size: 32,
                                              color: colorScheme.primary,
                                            ),
                                      )
                                      : Icon(
                                        Icons.link_rounded,
                                        size: 28,
                                        color: colorScheme.primary,
                                      ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              bookmark.title,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w500),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              bookmark.url,
                              style: Theme.of(
                                context,
                              ).textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurface.withAlpha(150),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 6),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Text(
                                  formattedDate,
                                  style: Theme.of(
                                    context,
                                  ).textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSurface.withAlpha(150),
                                  ),
                                ),
                                FutureBuilder<List<String>>(
                                  future: DatabaseService().bookmarkService
                                      .getTagsByBookmarkId(bookmark.id!),
                                  builder: (context, snapshot) {
                                    if (!snapshot.hasData ||
                                        snapshot.data!.isEmpty) {
                                      return const SizedBox.shrink();
                                    }

                                    final tags = snapshot.data!;
                                    // Mostrar todos los tags, incluyendo hidden
                                    final visibleTags = tags.toList();

                                    return Row(
                                      children: [
                                        if (visibleTags.isNotEmpty) ...[
                                          const Padding(
                                            padding: EdgeInsets.symmetric(
                                              horizontal: 4,
                                            ),
                                            child: Text(
                                              '|',
                                              style: TextStyle(
                                                color: Colors.grey,
                                                fontSize: 10,
                                              ),
                                            ),
                                          ),
                                          SizedBox(
                                            height: 18,
                                            child: SingleChildScrollView(
                                              scrollDirection: Axis.horizontal,
                                              child: Row(
                                                children:
                                                    visibleTags
                                                        .map(
                                                          (tag) => Padding(
                                                            padding:
                                                                const EdgeInsets.only(
                                                                  right: 4,
                                                                ),
                                                            child: Text(
                                                              '#$tag',
                                                              style: TextStyle(
                                                                fontSize: 11,
                                                                color:
                                                                    colorScheme
                                                                        .primary,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w500,
                                                              ),
                                                            ),
                                                          ),
                                                        )
                                                        .toList(),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    );
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      SizedBox(
                        width: 40,
                        height: 40,
                        child: IconButton(
                          icon: Icon(
                            Icons.delete_forever_rounded,
                            size: 20,
                            color: colorScheme.error,
                          ),
                          onPressed: () async {
                            await _showDeleteConfirmation(bookmark);
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBookmarksGrid(
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
                  onPressed: _showAddLinkDialog,
                ),
              ),
          ],
        ),
      );
    }

    return MasonryGridView.count(
      controller: _scrollController,
      crossAxisCount: (MediaQuery.of(context).size.width / 300).floor().clamp(
        1,
        8,
      ),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      padding: const EdgeInsets.all(16),
      itemCount: bookmarks.length,
      itemBuilder: (context, index) {
        final bookmark = bookmarks[index];
        final uri = Uri.tryParse(bookmark.url);

        return _BookmarkCard(
          bookmark: bookmark,
          colorScheme: colorScheme,
          onEdit: () => _showEditLinkDialog(bookmark),
          onDelete: () => _showDeleteConfirmation(bookmark),
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
  }

  Future<void> _showEditLinkDialog(Bookmark bookmark) async {
    if (!mounted) return;

    final formKey = GlobalKey<FormState>();
    final titleController = TextEditingController(text: bookmark.title);
    final urlController = TextEditingController(text: bookmark.url);
    final descController = TextEditingController(text: bookmark.description);
    final tagsFuture = DatabaseService().bookmarkService.getTagsByBookmarkId(
      bookmark.id!,
    );

    String tagsText = '';

    await tagsFuture.then((tags) {
      if (!mounted) return;
      // No excluir el tag hidden al editar, para que pueda ser gestionado
      tagsText = tags.join(', ');
    });

    if (!mounted) return;

    final tagsController = TextEditingController(text: tagsText);

    await showDialog(
      context: context,
      builder:
          (context) => Dialog(
            backgroundColor: Colors.transparent,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: 500,
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
                              'Edit Bookmark',
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
                              controller: titleController,
                              decoration: InputDecoration(
                                labelText: 'Title*',
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
                              validator:
                                  (value) =>
                                      value?.isEmpty ?? true
                                          ? 'Required'
                                          : null,
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: urlController,
                              decoration: InputDecoration(
                                labelText: 'URL*',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                filled: true,
                                fillColor: Theme.of(context)
                                    .colorScheme
                                    .surfaceContainerHighest
                                    .withAlpha(76),
                                prefixIcon: const Icon(Icons.link_rounded),
                              ),
                              validator: (value) {
                                if (value?.isEmpty ?? true) return 'Required';
                                if (!Uri.parse(value!).isAbsolute) {
                                  return 'Invalid URL';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: descController,
                              decoration: InputDecoration(
                                labelText: 'Description',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                filled: true,
                                fillColor: Theme.of(context)
                                    .colorScheme
                                    .surfaceContainerHighest
                                    .withAlpha(76),
                                prefixIcon: const Icon(
                                  Icons.description_rounded,
                                ),
                              ),
                              maxLines: 1,
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: tagsController,
                              decoration: InputDecoration(
                                labelText: 'Tags (comma separated)',
                                hintText: 'e.g.: work, research, personal',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                filled: true,
                                fillColor: Theme.of(context)
                                    .colorScheme
                                    .surfaceContainerHighest
                                    .withAlpha(76),
                                prefixIcon: const Icon(Icons.tag_rounded),
                              ),
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
                                onPressed: () async {
                                  if (formKey.currentState!.validate()) {
                                    await _linksHandler.updateBookmark(
                                      id: bookmark.id!,
                                      newTitle: titleController.text,
                                      newUrl: urlController.text,
                                      newDescription: descController.text,
                                      newTags:
                                          tagsController.text
                                              .split(',')
                                              .map((e) => e.trim())
                                              .where((e) => e.isNotEmpty)
                                              .toList(),
                                    );
                                    await _loadBookmarks();
                                    if (context.mounted) {
                                      Navigator.pop(context);
                                    }
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
                                  'Save Changes',
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
    );
  }

  Future<void> _showAddLinkDialog() async {
    final formKey = GlobalKey<FormState>();
    final titleController = TextEditingController();
    final urlController = TextEditingController();
    final descController = TextEditingController();
    final tagsController = TextEditingController();
    bool isFetchingTitle = false;
    bool isTitleEdited = false;

    String getDefaultTitle(String url) {
      try {
        final uri = Uri.parse(url);
        return uri.host.replaceAll('www.', '');
      } catch (e) {
        return 'New Bookmark';
      }
    }

    Future<String?> getRedditTitle(String url) async {
      try {
        final uri = Uri.parse(url);
        if (!uri.path.contains('/comments/')) return null;

        final pathSegments = uri.pathSegments;
        final postIdIndex = pathSegments.indexOf('comments');
        if (postIdIndex == -1 || postIdIndex + 1 >= pathSegments.length) return null;

        final postId = pathSegments[postIdIndex + 1];
        final apiUrl = 'https://www.reddit.com/comments/$postId.json';

        final response = await http.get(Uri.parse(apiUrl)).timeout(const Duration(seconds: 3));
        if (response.statusCode == 200) {
          final jsonData = jsonDecode(response.body);
          if (jsonData is List && jsonData.isNotEmpty) {
            final postData = jsonData[0]['data']['children'][0]['data'];
            return postData['title'];
          }
        }
      } catch (e) {
        print('Error getting Reddit title: $e');
      }
      return null;
    }

    Future<void> fetchWebTitle(String url) async {
      if (url.isEmpty) return;

      final uri = Uri.tryParse(url);
      if (uri == null || !uri.isAbsolute) return;

      setState(() => isFetchingTitle = true);

      try {
        final response = await http
            .get(uri)
            .timeout(const Duration(seconds: 3));
        if (response.statusCode == 200) {
          final document = html.parse(response.body);
          final ogTitle = document.querySelector('meta[property="og:title"]')?.attributes['content'];
          String? pageTitle;

          if (ogTitle != null && ogTitle.isNotEmpty) {
            pageTitle = ogTitle;
          } else {
            // Check if it's a Reddit URL and use API
            if (url.contains('reddit.com')) {
              pageTitle = await getRedditTitle(url);
            }
            if (pageTitle == null || pageTitle.isEmpty) {
              pageTitle = document.querySelector('title')?.text;
            }
          }

          if (pageTitle != null && pageTitle.isNotEmpty && !isTitleEdited) {
            titleController.text = pageTitle;
          }
        }
      } catch (e) {
        if (!isTitleEdited) {
          titleController.text = getDefaultTitle(url);
        }
      } finally {
        setState(() => isFetchingTitle = false);
      }
    }

    await showDialog(
      context: context,
      builder:
          (context) => Dialog(
            backgroundColor: Colors.transparent,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: 500,
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
                              Icons.bookmark_rounded,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'New Bookmark',
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
                              controller: urlController,
                              decoration: InputDecoration(
                                labelText: 'URL*',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                filled: true,
                                fillColor: Theme.of(context)
                                    .colorScheme
                                    .surfaceContainerHighest
                                    .withAlpha(76),
                                prefixIcon: const Icon(Icons.link_rounded),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    Icons.search_rounded,
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                  ),
                                  onPressed:
                                      () => fetchWebTitle(urlController.text),
                                ),
                              ),
                              validator: (value) {
                                if (value?.isEmpty ?? true) return 'Required';
                                if (!Uri.parse(value!).isAbsolute) {
                                  return 'Invalid URL';
                                }
                                return null;
                              },
                              onChanged: (value) async {
                                if (titleController.text.isEmpty ||
                                    !isTitleEdited) {
                                  await fetchWebTitle(value);
                                }
                              },
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: titleController,
                              decoration: InputDecoration(
                                labelText: 'Title*',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                filled: true,
                                fillColor: Theme.of(context)
                                    .colorScheme
                                    .surfaceContainerHighest
                                    .withAlpha(76),
                                prefixIcon: const Icon(Icons.title_rounded),
                                suffixIcon:
                                    isFetchingTitle
                                        ? const Padding(
                                          padding: EdgeInsets.all(12.0),
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                        : null,
                              ),
                              validator:
                                  (value) =>
                                      value?.isEmpty ?? true
                                          ? 'Required'
                                          : null,
                              onChanged: (value) {
                                if (value.isNotEmpty) {
                                  setState(() => isTitleEdited = true);
                                }
                              },
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: descController,
                              decoration: InputDecoration(
                                labelText: 'Description',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                filled: true,
                                fillColor: Theme.of(context)
                                    .colorScheme
                                    .surfaceContainerHighest
                                    .withAlpha(76),
                                prefixIcon: const Icon(
                                  Icons.description_rounded,
                                ),
                              ),
                              maxLines: 1,
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: tagsController,

                              decoration: InputDecoration(
                                labelText: 'Tags (comma separated)',
                                hintText: 'e.g.: work, research, personal',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                filled: true,
                                fillColor: Theme.of(context)
                                    .colorScheme
                                    .surfaceContainerHighest
                                    .withAlpha(76),
                                prefixIcon: const Icon(Icons.tag_rounded),
                              ),
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
                                onPressed: () async {
                                  if (formKey.currentState!.validate()) {
                                    await _linksHandler.addBookmark(
                                      title: titleController.text,
                                      url: urlController.text,
                                      description: descController.text,
                                      tags:
                                          tagsController.text
                                              .split(',')
                                              .map((e) => e.trim())
                                              .where((e) => e.isNotEmpty)
                                              .toList(),
                                    );
                                    await _loadBookmarks();
                                    if (context.mounted) {
                                      Navigator.pop(context);
                                    }
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
                                  'Save Link',
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
    );
  }

  void _showManageTagsDialog() async {
    if (!mounted) return;

    await _tagsHandler.loadPatterns();

    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              backgroundColor: Colors.transparent,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 500,
                  height: 400,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Container(
                        height: 56,
                        decoration: BoxDecoration(),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: [
                            Icon(
                              Icons.label_rounded,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Predefined Tags',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const Spacer(),
                            IconButton(
                              icon: Icon(
                                Icons.new_label_rounded,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              onPressed: () async {
                                await _showAddTagDialog();
                                await _tagsHandler.loadPatterns();
                                setState(() {});
                              },
                            ),
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
                      Expanded(
                        child: FutureBuilder<List<TagUrlPattern>>(
                          // Usar FutureBuilder para tener los datos más actualizados
                          future: Future.value(_tagsHandler.allPatterns),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const Center(
                                child: CircularProgressIndicator(),
                              );
                            }

                            final patterns = snapshot.data ?? [];

                            return patterns.isEmpty
                                ? Center(
                                  child: Text(
                                    'No predefined tags',
                                    style: TextStyle(
                                      color:
                                          Theme.of(
                                            context,
                                          ).colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                )
                                : ListView.builder(
                                  itemCount: patterns.length,
                                  itemBuilder: (context, index) {
                                    final pattern = patterns[index];
                                    return ListTile(
                                      title: Row(
                                        children: [
                                          // URL Pattern (primera columna)
                                          Expanded(
                                            child: Text(
                                              pattern.urlPattern,
                                              style: TextStyle(
                                                color:
                                                    Theme.of(
                                                      context,
                                                    ).colorScheme.onSurface,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          // Flecha (columna central)
                                          Padding(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 16,
                                            ),
                                            child: Icon(
                                              Icons.arrow_forward_rounded,
                                              color:
                                                  Theme.of(
                                                    context,
                                                  ).colorScheme.primary,
                                            ),
                                          ),
                                          // Tag (tercera columna)
                                          Expanded(
                                            child: Text(
                                              pattern.tag,
                                              style: TextStyle(
                                                color:
                                                    Theme.of(
                                                      context,
                                                    ).colorScheme.primary,
                                                fontWeight: FontWeight.w500,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                      trailing: IconButton(
                                        icon: Icon(
                                          Icons.delete_forever_rounded,
                                          color:
                                              Theme.of(
                                                context,
                                              ).colorScheme.error,
                                        ),
                                        onPressed: () async {
                                          final confirmed =
                                              await showDeleteConfirmationDialog(
                                                context: context,
                                                title: 'Delete Tag Mapping',
                                                message:
                                                    'Are you sure you want to delete this tag mapping?\n\nURL Pattern: ${pattern.urlPattern}\nTag: ${pattern.tag}',
                                                confirmText: 'Delete',
                                                confirmColor:
                                                    Theme.of(
                                                      context,
                                                    ).colorScheme.error,
                                              );

                                          if (confirmed == true) {
                                            await _tagsHandler.removeTagMapping(
                                              pattern.urlPattern,
                                              pattern.tag,
                                            );
                                            // Actualizar el estado después de eliminar un tag
                                            setState(() {});
                                          }
                                        },
                                      ),
                                    );
                                  },
                                );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showAddTagDialog() async {
    final urlController = TextEditingController();
    final tagController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    await showDialog(
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
                              Icons.label_rounded,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'New Predefined Tag',
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
                              controller: urlController,
                              decoration: InputDecoration(
                                labelText: 'URL Pattern*',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                filled: true,
                                fillColor: Theme.of(context)
                                    .colorScheme
                                    .surfaceContainerHighest
                                    .withAlpha(76),
                                prefixIcon: const Icon(Icons.link_rounded),
                              ),
                              validator:
                                  (value) =>
                                      value?.isEmpty ?? true
                                          ? 'Required'
                                          : null,
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: tagController,
                              decoration: InputDecoration(
                                labelText: 'Tag*',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                filled: true,
                                fillColor: Theme.of(context)
                                    .colorScheme
                                    .surfaceContainerHighest
                                    .withAlpha(76),
                                prefixIcon: const Icon(Icons.tag_rounded),
                              ),
                              validator:
                                  (value) =>
                                      value?.isEmpty ?? true
                                          ? 'Required'
                                          : null,
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
                                onPressed: () async {
                                  if (formKey.currentState!.validate()) {
                                    try {
                                      await _tagsHandler.addTagMapping(
                                        urlController.text.trim(),
                                        tagController.text.trim(),
                                      );
                                      if (context.mounted) {
                                        Navigator.pop(context);
                                      }
                                    } catch (e) {
                                      if (context.mounted) {
                                        String errorMessage =
                                            'Error adding pattern';

                                        if (e.toString().contains(
                                          'already exists',
                                        )) {
                                          errorMessage =
                                              'A tag pattern with this URL and tag already exists.';
                                        } else if (e.toString().contains(
                                          'UNIQUE constraint failed',
                                        )) {
                                          errorMessage =
                                              'A tag pattern with this URL and tag already exists.';
                                        } else {
                                          errorMessage =
                                              'Error adding pattern: ${e.toString()}';
                                        }

                                        CustomSnackbar.show(
                                          context: context,
                                          message: errorMessage,
                                          type: CustomSnackbarType.error,
                                        );
                                      }
                                    }
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
                                  'Save',
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
    );
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

class _BookmarkCard extends StatefulWidget {
  final Bookmark bookmark;
  final ColorScheme colorScheme;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onCopy;
  final VoidCallback onTap;

  const _BookmarkCard({
    required this.bookmark,
    required this.colorScheme,
    required this.onEdit,
    required this.onDelete,
    required this.onCopy,
    required this.onTap,
  });

  @override
  State<_BookmarkCard> createState() => _BookmarkCardState();
}

class _BookmarkCardState extends State<_BookmarkCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final uri = Uri.tryParse(widget.bookmark.url);
    final date = DateTime.parse(widget.bookmark.timestamp);
    final formattedDate = DateFormat("dd/MMM/yyyy").format(date);

    return Material(
      color: Colors.transparent,
      child: GestureDetector(
        onSecondaryTapDown: (details) {
          ContextMenuOverlay.show(
            context: context,
            tapPosition: details.globalPosition,
            items: [
              ContextMenuItem(
                icon: Icons.copy,
                label: 'Copy Link',
                onTap: () => widget.onCopy(),
              ),
              ContextMenuItem(
                icon: Icons.edit_rounded,
                label: 'Edit',
                onTap: () => widget.onEdit(),
              ),
              ContextMenuItem(
                icon: Icons.delete_forever_rounded,
                label: 'Delete',
                iconColor: Theme.of(context).colorScheme.error,
                onTap: () => widget.onDelete(),
              ),
            ],
          );
        },
        child: InkWell(
          onTap: widget.onTap,
          splashColor: widget.colorScheme.primary.withAlpha(30),
          child: MouseRegion(
            onEnter: (_) => setState(() => _isHovered = true),
            onExit: (_) => setState(() => _isHovered = false),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 0),
              width: 280,
              margin: const EdgeInsets.only(bottom: 2),
              decoration: BoxDecoration(
                color:
                    _isHovered
                        ? widget.colorScheme.primary.withAlpha(50)
                        : widget.colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Link Preview
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(8),
                    ),
                    child: AnyLinkPreview(
                      link: widget.bookmark.url,
                      displayDirection: UIDirection.uiDirectionVertical,
                      showMultimedia: true,
                      bodyMaxLines: 2,
                      bodyTextOverflow: TextOverflow.ellipsis,
                      titleStyle: TextStyle(
                        color: widget.colorScheme.onSurface,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                      bodyStyle: TextStyle(
                        color: widget.colorScheme.onSurface.withAlpha(150),
                        fontSize: 12,
                      ),
                      errorBody: 'No preview available',
                      errorTitle: 'Error loading preview',
                      errorWidget: Container(
                        height: 100,
                        color: widget.colorScheme.surfaceContainerLow,
                        child: Center(
                          child: Icon(
                            Icons.link_rounded,
                            color: widget.colorScheme.primary,
                          ),
                        ),
                      ),
                      cache: const Duration(days: 7),
                      backgroundColor:
                          _isHovered
                              ? widget.colorScheme.primary.withAlpha(50)
                              : widget.colorScheme.surfaceContainerHigh,
                      borderRadius: 0,
                      removeElevation: true,
                      onTap: widget.onTap,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // URL and date
                        Row(
                          children: [
                            if (uri != null)
                              Container(
                                width: 16,
                                height: 16,
                                margin: const EdgeInsets.only(right: 4),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(3),
                                  child: Image.network(
                                    'https://www.google.com/s2/favicons?domain=${uri.host}&sz=64',
                                    width: 16,
                                    height: 16,
                                    errorBuilder:
                                        (_, __, ___) => Icon(
                                          Icons.link_rounded,
                                          size: 12,
                                          color: widget.colorScheme.primary,
                                        ),
                                  ),
                                ),
                              ),
                            Expanded(
                              child: Text(
                                widget.bookmark.url,
                                style: Theme.of(
                                  context,
                                ).textTheme.bodySmall?.copyWith(
                                  color: widget.colorScheme.onSurface.withAlpha(
                                    150,
                                  ),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        // Date and tags
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              formattedDate,
                              style: Theme.of(
                                context,
                              ).textTheme.bodySmall?.copyWith(
                                color: widget.colorScheme.onSurface.withAlpha(
                                  150,
                                ),
                              ),
                            ),
                            FutureBuilder<List<String>>(
                              future: DatabaseService().bookmarkService
                                  .getTagsByBookmarkId(widget.bookmark.id!),
                              builder: (context, snapshot) {
                                if (!snapshot.hasData ||
                                    snapshot.data!.isEmpty) {
                                  return const SizedBox.shrink();
                                }

                                final tags = snapshot.data!;
                                // Mostrar todos los tags, incluyendo hidden
                                final visibleTags = tags.toList();

                                return Row(
                                  children: [
                                    if (visibleTags.isNotEmpty) ...[
                                      const Padding(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 4,
                                        ),
                                        child: Text(
                                          '|',
                                          style: TextStyle(
                                            color: Colors.grey,
                                            fontSize: 10,
                                          ),
                                        ),
                                      ),
                                      SizedBox(
                                        height: 18,
                                        child: SingleChildScrollView(
                                          scrollDirection: Axis.horizontal,
                                          child: Row(
                                            children:
                                                visibleTags
                                                    .map(
                                                      (tag) => Padding(
                                                        padding:
                                                            const EdgeInsets.only(
                                                              right: 4,
                                                            ),
                                                        child: Text(
                                                          '#$tag',
                                                          style: TextStyle(
                                                            fontSize: 11,
                                                            color:
                                                                widget
                                                                    .colorScheme
                                                                    .primary,
                                                            fontWeight:
                                                                FontWeight.w500,
                                                          ),
                                                        ),
                                                      ),
                                                    )
                                                    .toList(),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                );
                              },
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
}
