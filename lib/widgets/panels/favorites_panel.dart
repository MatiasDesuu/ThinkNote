import 'package:flutter/material.dart';
import 'dart:async';
import '../../database/models/notebook.dart';
import '../../database/models/note.dart';
import '../../database/models/think.dart';
import '../../database/models/notebook_icons.dart';
import '../../database/repositories/notebook_repository.dart';
import '../../database/repositories/note_repository.dart';
import '../../database/repositories/think_repository.dart';
import '../../database/database_helper.dart';
import '../../database/database_service.dart';

class FavoritesPanel extends StatefulWidget {
  final Function(Notebook) onNotebookSelected;
  final Function(Note) onNoteSelected;
  final Function(Note)? onNoteSelectedFromPanel;
  final Function(Think)? onThinkSelected;
  final VoidCallback? onFavoritesUpdated;
  final VoidCallback? onClose;
  final FocusNode appFocusNode;

  const FavoritesPanel({
    super.key,
    required this.onNotebookSelected,
    required this.onNoteSelected,
    required this.appFocusNode,
    this.onThinkSelected,
    this.onFavoritesUpdated,
    this.onNoteSelectedFromPanel,
    this.onClose,
  });

  @override
  State<FavoritesPanel> createState() => FavoritesPanelState();
}

class FavoritesPanelState extends State<FavoritesPanel> {
  late final NoteRepository _noteRepository;
  late final NotebookRepository _notebookRepository;
  late final ThinkRepository _thinkRepository;
  late StreamController<List<dynamic>> _favoritesController;
  late Stream<List<dynamic>> _favoritesStream;
  late StreamSubscription<void> _databaseChangeSubscription;

  @override
  void initState() {
    super.initState();
    _favoritesController = StreamController<List<dynamic>>.broadcast();
    _favoritesStream = _favoritesController.stream;
    _initializeRepositories();

    _databaseChangeSubscription = DatabaseService().onDatabaseChanged.listen((
      _,
    ) {
      reloadFavorites();
    });
  }

  @override
  void dispose() {
    _favoritesController.close();
    _databaseChangeSubscription.cancel();
    super.dispose();
  }

  Future<void> _initializeRepositories() async {
    final dbHelper = DatabaseHelper();
    await dbHelper.database;
    _notebookRepository = NotebookRepository(dbHelper);
    _noteRepository = NoteRepository(dbHelper);
    _thinkRepository = ThinkRepository(dbHelper);
    _loadFavorites();
  }

  void _loadFavorites() {
    _getFavorites().then((list) => _favoritesController.add(list));
  }

  Future<List<dynamic>> _getFavorites() async {
    final notebooks = await _notebookRepository.getFavoriteNotebooks();
    final notes = await _noteRepository.getFavoriteNotes();
    final thinks = await _thinkRepository.getFavoriteThinks();
    return [...notebooks, ...notes, ...thinks];
  }

  /// Reloads all favorites data
  /// Used for refreshing after sync operations
  void reloadFavorites() {
    _loadFavorites();
  }

  Future<void> _toggleNotebookFavorite(Notebook notebook) async {
    final updatedNotebook = notebook.copyWith(isFavorite: !notebook.isFavorite);
    await _notebookRepository.updateNotebook(updatedNotebook);
    widget.onFavoritesUpdated?.call();
    reloadFavorites();
  }

  Future<void> _toggleNoteFavorite(Note note) async {
    final updatedNote = note.copyWith(isFavorite: !note.isFavorite);
    await _noteRepository.updateNote(updatedNote);
    widget.onFavoritesUpdated?.call();
    reloadFavorites();
  }

  Future<void> _toggleThinkFavorite(Think think) async {
    await _thinkRepository.toggleFavorite(think.id!, !think.isFavorite);
    widget.onFavoritesUpdated?.call();
    reloadFavorites();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        return SizedBox(
          width: constraints.maxWidth,
          child: Container(
            decoration: BoxDecoration(color: colorScheme.surfaceContainerLow),
            child: Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: StreamBuilder<List<dynamic>>(
                    stream: _favoritesStream,
                    initialData: [],
                    builder: (context, snapshot) {
                      final allItems = snapshot.data!;
                      return _buildContent(allItems);
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader() {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(
                Icons.favorite_rounded,
                size: 20,
                color: colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'Favorites',
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(color: colorScheme.onSurface),
              ),
            ],
          ),
          IconButton(
            icon: Icon(Icons.close_rounded, color: colorScheme.primary),
            onPressed: widget.onClose,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            padding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }

  Widget _buildContent(List<dynamic> allItems) {
    if (allItems.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: allItems.length,
      itemBuilder: (context, index) => _buildItem(allItems[index]),
    );
  }

  Widget _buildEmptyState() {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.favorite_border_rounded,
            size: 64,
            color: colorScheme.onSurfaceVariant.withAlpha(127),
          ),
          const SizedBox(height: 16),
          Text(
            'No favorites yet',
            style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            'Mark items as favorite to see them here',
            style: TextStyle(
              color: colorScheme.onSurfaceVariant.withAlpha(179),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItem(dynamic item) {
    final isNotebook = item is Notebook;
    final isNote = item is Note;
    final isThink = item is Think;
    final colorScheme = Theme.of(context).colorScheme;

    IconData iconData;
    String title;

    if (isNotebook) {
      final notebookIcon =
          item.iconId != null
              ? NotebookIconsRepository.getIconById(item.iconId!)
              : null;
      final iconToShow =
          notebookIcon ?? NotebookIconsRepository.getDefaultIcon();
      iconData = iconToShow.icon;
      title = item.name;
    } else if (isNote) {
      iconData = Icons.description_outlined;
      title = item.title;
    } else {
      // Think
      iconData = Icons.lightbulb_outline_rounded;
      title = item.title;
    }

    return MouseRegionHoverItem(
      builder: (context, isHovering) {
        return Card(
          key: Key('${item.runtimeType}_${item.id}'),
          margin: const EdgeInsets.only(bottom: 8),
          color: colorScheme.surfaceContainerHighest,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () {
                if (isNotebook) {
                  widget.onNotebookSelected(item);
                } else if (isNote) {
                  // Notify parent that this selection came from a panel so it can
                  // suppress tab animations when replacing the active tab.
                  try {
                    widget.onNoteSelectedFromPanel?.call(item);
                  } catch (_) {}
                  widget.onNoteSelected(item);
                } else if (isThink && widget.onThinkSelected != null) {
                  widget.onThinkSelected!(item);
                  widget.onClose?.call();
                }
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 6,
                ),
                child: Row(
                  children: [
                    Icon(iconData, color: colorScheme.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            title,
                            style: Theme.of(
                              context,
                            ).textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurface,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          FutureBuilder<String>(
                            future: _getItemPath(item),
                            builder: (context, snapshot) {
                              if (snapshot.hasData &&
                                  snapshot.data!.isNotEmpty) {
                                return Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Text(
                                    snapshot.data!,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                      fontSize: 10,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                );
                              }
                              return const SizedBox.shrink();
                            },
                          ),
                        ],
                      ),
                    ),
                    // Remove from favorites button (only visible on hover)
                    Opacity(
                      opacity: isHovering ? 1.0 : 0.0,
                      child: IgnorePointer(
                        ignoring: !isHovering,
                        child: Padding(
                          padding: const EdgeInsets.only(left: 4),
                          child: MouseRegion(
                            cursor: SystemMouseCursors.click,
                            child: GestureDetector(
                              onTap: () {
                                if (isNotebook) {
                                  _toggleNotebookFavorite(item);
                                } else if (isNote) {
                                  _toggleNoteFavorite(item);
                                } else {
                                  _toggleThinkFavorite(item);
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: colorScheme.primary.withAlpha(20),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Icon(
                                  Icons.favorite_rounded,
                                  size: 14,
                                  color: colorScheme.primary,
                                ),
                              ),
                            ),
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
    );
  }

  Future<String> _getItemPath(dynamic item) async {
    try {
      if (item is Notebook) {
        // Para notebooks, mostrar la ruta del parent
        if (item.parentId != null) {
          final parent = await _notebookRepository.getNotebook(item.parentId!);
          if (parent != null) {
            final parentPath = await _getNotebookPath(parent);
            return parentPath.isNotEmpty ? parentPath : parent.name;
          }
        }
        return '';
      } else if (item is Note) {
        // Para notes, mostrar el notebook donde está
        final notebook = await _notebookRepository.getNotebook(item.notebookId);
        if (notebook != null) {
          final notebookPath = await _getNotebookPath(notebook);
          return notebookPath.isNotEmpty ? notebookPath : notebook.name;
        }
        return '';
      } else if (item is Think) {
        // Para thinks, mostrar "Thinks"
        return 'Thinks';
      }
    } catch (e) {
      // Ignore errors
    }
    return '';
  }

  Future<String> _getNotebookPath(Notebook notebook) async {
    try {
      final List<String> pathParts = [];
      Notebook? current = notebook;

      while (current != null) {
        pathParts.insert(0, current.name);
        if (current.parentId != null) {
          current = await _notebookRepository.getNotebook(current.parentId!);
        } else {
          current = null;
        }
      }

      return pathParts.join(' / ');
    } catch (e) {
      return notebook.name;
    }
  }
}

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
