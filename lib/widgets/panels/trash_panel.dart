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
import '../confirmation_dialogue.dart';

class TrashPanel extends StatefulWidget {
  final Function(Notebook)? onNotebookRestored;
  final Function(Note)? onNoteRestored;
  final Function(Think)? onThinkRestored;
  final VoidCallback? onTrashUpdated;
  final VoidCallback? onClose;
  final FocusNode appFocusNode;

  const TrashPanel({
    super.key,
    required this.appFocusNode,
    this.onNotebookRestored,
    this.onNoteRestored,
    this.onThinkRestored,
    this.onTrashUpdated,
    this.onClose,
  });

  @override
  State<TrashPanel> createState() => TrashPanelState();
}

class TrashPanelState extends State<TrashPanel> {
  late final NoteRepository _noteRepository;
  late final NotebookRepository _notebookRepository;
  late final ThinkRepository _thinkRepository;
  late StreamController<List<dynamic>> _trashController;
  late Stream<List<dynamic>> _trashStream;
  late StreamSubscription<void> _databaseChangeSubscription;

  @override
  void initState() {
    super.initState();
    _trashController = StreamController<List<dynamic>>.broadcast();
    _trashStream = _trashController.stream;
    _initializeRepositories();

    _databaseChangeSubscription = DatabaseService().onDatabaseChanged.listen(
      (_) {
        reloadTrash();
      },
    );
  }

  @override
  void dispose() {
    _trashController.close();
    _databaseChangeSubscription.cancel();
    super.dispose();
  }

  Future<void> _initializeRepositories() async {
    final dbHelper = DatabaseHelper();
    await dbHelper.database;
    _notebookRepository = NotebookRepository(dbHelper);
    _noteRepository = NoteRepository(dbHelper);
    _thinkRepository = ThinkRepository(dbHelper);
    _loadTrash();
  }

  void _loadTrash() {
    _getTrash().then((list) => _trashController.add(list));
  }

  Future<List<dynamic>> _getTrash() async {
    final notebooks = await _notebookRepository.getDeletedNotebooks();
    final notes = await _noteRepository.getDeletedNotes();
    final thinks = await _thinkRepository.getDeletedThinks();
    return [...notebooks, ...notes, ...thinks];
  }

  /// Reloads all trash data
  /// Used for refreshing after sync operations
  void reloadTrash() {
    _loadTrash();
  }

  Future<void> _restoreNotebook(Notebook notebook) async {
    await _notebookRepository.restoreNotebook(notebook.id!);
    widget.onNotebookRestored?.call(notebook);
    widget.onTrashUpdated?.call();
    reloadTrash();
  }

  Future<void> _restoreNote(Note note) async {
    await _noteRepository.restoreNote(note.id!);
    widget.onNoteRestored?.call(note);
    widget.onTrashUpdated?.call();
    reloadTrash();
  }

  Future<void> _restoreThink(Think think) async {
    await _thinkRepository.restoreThink(think.id!);
    widget.onThinkRestored?.call(think);
    widget.onTrashUpdated?.call();
    reloadTrash();
  }

  Future<void> _permanentlyDeleteNotebook(Notebook notebook) async {
    final colorScheme = Theme.of(context).colorScheme;
    final confirmed = await showDeleteConfirmationDialog(
      context: context,
      title: 'Delete Permanently',
      message:
          'Are you sure you want to permanently delete this notebook and all its contents?\n${notebook.name}\nThis action cannot be undone.',
      confirmText: 'Delete',
      confirmColor: colorScheme.error,
    );

    if (confirmed == true) {
      await _notebookRepository.hardDeleteNotebook(notebook.id!);
      widget.onTrashUpdated?.call();
      reloadTrash();
    }
  }

  Future<void> _permanentlyDeleteNote(Note note) async {
    final colorScheme = Theme.of(context).colorScheme;
    final confirmed = await showDeleteConfirmationDialog(
      context: context,
      title: 'Delete Permanently',
      message:
          'Are you sure you want to permanently delete this note?\n${note.title}\nThis action cannot be undone.',
      confirmText: 'Delete',
      confirmColor: colorScheme.error,
    );

    if (confirmed == true) {
      await _noteRepository.hardDeleteNote(note.id!);
      widget.onTrashUpdated?.call();
      reloadTrash();
    }
  }

  Future<void> _permanentlyDeleteThink(Think think) async {
    final colorScheme = Theme.of(context).colorScheme;
    final confirmed = await showDeleteConfirmationDialog(
      context: context,
      title: 'Delete Permanently',
      message:
          'Are you sure you want to permanently delete this think?\n${think.title}\nThis action cannot be undone.',
      confirmText: 'Delete',
      confirmColor: colorScheme.error,
    );

    if (confirmed == true) {
      await _thinkRepository.permanentlyDeleteThink(think.id!);
      widget.onTrashUpdated?.call();
      reloadTrash();
    }
  }

  Future<void> _deleteAllItems() async {
    final colorScheme = Theme.of(context).colorScheme;
    final confirmed = await showDeleteConfirmationDialog(
      context: context,
      title: 'Empty Trash',
      message:
          'Are you sure you want to permanently delete all items in the trash?\nThis action cannot be undone.',
      confirmText: 'Delete All',
      confirmColor: colorScheme.error,
    );

    if (confirmed == true) {
      final notebooks = await _notebookRepository.getDeletedNotebooks();
      final notes = await _noteRepository.getDeletedNotes();
      final thinks = await _thinkRepository.getDeletedThinks();
      for (final notebook in notebooks) {
        await _notebookRepository.hardDeleteNotebook(notebook.id!);
      }
      for (final note in notes) {
        await _noteRepository.hardDeleteNote(note.id!);
      }
      for (final think in thinks) {
        await _thinkRepository.permanentlyDeleteThink(think.id!);
      }
      widget.onTrashUpdated?.call();
      reloadTrash();
    }
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
            child: StreamBuilder<List<dynamic>>(
              stream: _trashStream,
              initialData: [],
              builder: (context, snapshot) {
                final allItems = snapshot.data!;
                return Column(
                  children: [
                    _buildHeader(allItems),
                    Expanded(
                      child: _buildContent(allItems),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(List<dynamic> allItems) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(
                Icons.delete_outline_rounded,
                size: 20,
                color: colorScheme.error,
              ),
              const SizedBox(width: 8),
              Text(
                'Trash',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: colorScheme.onSurface,
                    ),
              ),
            ],
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (allItems.isNotEmpty)
                IconButton(
                  icon: Icon(
                    Icons.delete_sweep_rounded,
                    size: 20,
                    color: colorScheme.error,
                  ),
                  onPressed: _deleteAllItems,
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                  padding: EdgeInsets.zero,
                ),
              IconButton(
                icon: Icon(
                  Icons.close_rounded,
                  color: colorScheme.primary,
                ),
                onPressed: widget.onClose,
                constraints: const BoxConstraints(
                  minWidth: 32,
                  minHeight: 32,
                ),
                padding: EdgeInsets.zero,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildContent(List<dynamic> allItems) {
    final colorScheme = Theme.of(context).colorScheme;
    final sortedItems = allItems..sort((a, b) {
        DateTime? aDate;
        DateTime? bDate;

        if (a is Notebook) {
          aDate = a.deletedAt;
        } else if (a is Note) {
          aDate = a.deletedAt;
        } else if (a is Think) {
          aDate = a.deletedAt;
        }

        if (b is Notebook) {
          bDate = b.deletedAt;
        } else if (b is Note) {
          bDate = b.deletedAt;
        } else if (b is Think) {
          bDate = b.deletedAt;
        }

        if (aDate == null && bDate == null) return 0;
        if (aDate == null) return 1;
        if (bDate == null) return -1;
        return bDate.compareTo(aDate);
      });

    if (sortedItems.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.delete_outline_rounded,
              size: 64,
              color: colorScheme.onSurfaceVariant.withAlpha(127),
            ),
            const SizedBox(height: 16),
            Text(
              'No items in trash',
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Deleted items will appear here',
              style: TextStyle(
                color: colorScheme.onSurfaceVariant.withAlpha(179),
                fontSize: 12,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: sortedItems.length,
      itemBuilder: (context, index) => _buildItem(sortedItems[index]),
    );
  }

  Widget _buildItem(dynamic item) {
    final isNotebook = item is Notebook;
    final isNote = item is Note;
    final isThink = item is Think;
    final colorScheme = Theme.of(context).colorScheme;

    IconData iconData;
    String title;
    DateTime? deletedAt;

    if (isNotebook) {
      final notebookIcon = item.iconId != null
          ? NotebookIconsRepository.getIconById(item.iconId!)
          : null;
      final iconToShow = notebookIcon ?? NotebookIconsRepository.getDefaultIcon();
      iconData = iconToShow.icon;
      title = item.name;
      deletedAt = item.deletedAt;
    } else if (isNote) {
      iconData = Icons.description_outlined;
      title = item.title;
      deletedAt = item.deletedAt;
    } else {
      // Think
      iconData = Icons.lightbulb_outline_rounded;
      title = item.title;
      deletedAt = item.deletedAt;
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
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 6,
            ),
            child: Row(
              children: [
                Icon(
                  iconData,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurface,
                              fontWeight: FontWeight.w500,
                            ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (deletedAt != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            'Deleted on ${_formatDate(deletedAt)}',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                  fontSize: 10,
                                ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                  ),
                ),
                // Action buttons (only visible on hover)
                Opacity(
                  opacity: isHovering ? 1.0 : 0.0,
                  child: IgnorePointer(
                    ignoring: !isHovering,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Restore button
                        Padding(
                          padding: const EdgeInsets.only(left: 4),
                          child: MouseRegion(
                            cursor: SystemMouseCursors.click,
                            child: GestureDetector(
                              onTap: () {
                                if (isNotebook) {
                                  _restoreNotebook(item);
                                } else if (isNote) {
                                  _restoreNote(item);
                                } else if (isThink) {
                                  _restoreThink(item);
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: colorScheme.tertiary.withAlpha(20),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Icon(
                                  Icons.restore_rounded,
                                  size: 14,
                                  color: colorScheme.tertiary,
                                ),
                              ),
                            ),
                          ),
                        ),
                        // Permanent delete button
                        Padding(
                          padding: const EdgeInsets.only(left: 4),
                          child: MouseRegion(
                            cursor: SystemMouseCursors.click,
                            child: GestureDetector(
                              onTap: () {
                                if (isNotebook) {
                                  _permanentlyDeleteNotebook(item);
                                } else if (isNote) {
                                  _permanentlyDeleteNote(item);
                                } else if (isThink) {
                                  _permanentlyDeleteThink(item);
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: colorScheme.error.withAlpha(20),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Icon(
                                  Icons.delete_forever_rounded,
                                  size: 14,
                                  color: colorScheme.error,
                                ),
                              ),
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
        );
      },
    );
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${date.day} ${months[date.month - 1]}, ${date.year}';
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
