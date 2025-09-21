import 'package:flutter/material.dart';
import '../database/models/notebook.dart';
import '../database/models/note.dart';
import '../database/models/think.dart';
import '../database/repositories/notebook_repository.dart';
import '../database/repositories/note_repository.dart';
import '../database/repositories/think_repository.dart';
import '../database/database_helper.dart';
import 'confirmation_dialogue.dart';

class TrashScreen extends StatefulWidget {
  final Function(Notebook)? onNotebookRestored;
  final Function(Note)? onNoteRestored;
  final Function(Think)? onThinkRestored;
  final VoidCallback? onTrashUpdated;

  const TrashScreen({
    super.key,
    this.onNotebookRestored,
    this.onNoteRestored,
    this.onThinkRestored,
    this.onTrashUpdated,
  });

  @override
  State<TrashScreen> createState() => TrashScreenState();
}

class TrashScreenState extends State<TrashScreen> {
  late final NoteRepository _noteRepository;
  late final NotebookRepository _notebookRepository;
  late final ThinkRepository _thinkRepository;
  List<Notebook> _deletedNotebooks = [];
  List<Note> _deletedNotes = [];
  List<Think> _deletedThinks = [];
  bool _isLoading = true;
  final Map<String, bool> _hoverStates = {};

  @override
  void initState() {
    super.initState();
    _initializeRepositories();
  }

  Future<void> _initializeRepositories() async {
    final dbHelper = DatabaseHelper();
    await dbHelper.database;
    _notebookRepository = NotebookRepository(dbHelper);
    _noteRepository = NoteRepository(dbHelper);
    _thinkRepository = ThinkRepository(dbHelper);
    await _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final notebooks = await _notebookRepository.getDeletedNotebooks();
      final notes = await _noteRepository.getDeletedNotes();
      final thinks = await _thinkRepository.getDeletedThinks();

      setState(() {
        _deletedNotebooks = notebooks;
        _deletedNotes = notes;
        _deletedThinks = thinks;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading trash: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _restoreNotebook(Notebook notebook) async {
    await _notebookRepository.restoreNotebook(notebook.id!);
    widget.onNotebookRestored?.call(notebook);
    widget.onTrashUpdated?.call();
    await _loadData();
  }

  Future<void> _restoreNote(Note note) async {
    await _noteRepository.restoreNote(note.id!);
    widget.onNoteRestored?.call(note);
    widget.onTrashUpdated?.call();
    await _loadData();
  }

  Future<void> _restoreThink(Think think) async {
    await _thinkRepository.restoreThink(think.id!);
    widget.onThinkRestored?.call(think);
    widget.onTrashUpdated?.call();
    await _loadData();
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
      await _loadData();
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
      await _loadData();
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
      await _loadData();
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
      for (final notebook in _deletedNotebooks) {
        await _notebookRepository.hardDeleteNotebook(notebook.id!);
      }
      for (final note in _deletedNotes) {
        await _noteRepository.hardDeleteNote(note.id!);
      }
      for (final think in _deletedThinks) {
        await _thinkRepository.permanentlyDeleteThink(think.id!);
      }
      widget.onTrashUpdated?.call();
      await _loadData();
    }
  }

  Widget _buildItem(dynamic item) {
    final isNotebook = item is Notebook;
    final isNote = item is Note;
    final colorScheme = Theme.of(context).colorScheme;

    IconData iconData;
    Color iconColor;
    String title;
    DateTime? deletedAt;
    String itemId;

    if (isNotebook) {
      iconData = Icons.folder_rounded;
      iconColor = colorScheme.primary;
      title = (item).name;
      deletedAt = item.deletedAt;
      itemId = 'notebook_${item.id}';
    } else if (isNote) {
      iconData = Icons.description_outlined;
      iconColor = colorScheme.primary;
      title = (item).title;
      deletedAt = item.deletedAt;
      itemId = 'note_${item.id}';
    } else {
      // Think
      iconData = Icons.lightbulb_outline_rounded;
      iconColor = colorScheme.primary;
      title = (item as Think).title;
      deletedAt = item.deletedAt;
      itemId = 'think_${item.id}';
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _hoverStates[itemId] = true),
      onExit: (_) => setState(() => _hoverStates[itemId] = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        decoration: BoxDecoration(
          color:
              _hoverStates[itemId] == true
                  ? colorScheme.surfaceContainerHigh
                  : colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: colorScheme.outlineVariant.withAlpha(127),
            width: 0.5,
          ),
        ),
        child: ListTile(
          dense: true,
          leading: Icon(iconData, color: iconColor, size: 20),
          title: Text(
            title,
            style: TextStyle(fontSize: 14, color: colorScheme.onSurface),
          ),
          subtitle: Text(
            'Deleted on ${deletedAt?.toLocal().toString().split('.')[0] ?? 'Unknown'}',
            style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: Icon(
                  Icons.restore_rounded,
                  size: 20,
                  color: colorScheme.tertiary,
                ),
                onPressed: () {
                  if (isNotebook) {
                    _restoreNotebook(item);
                  } else if (isNote) {
                    _restoreNote(item);
                  } else {
                    _restoreThink(item);
                  }
                },
              ),
              IconButton(
                icon: Icon(
                  Icons.delete_forever_rounded,
                  size: 20,
                  color: colorScheme.error,
                ),
                onPressed: () {
                  if (isNotebook) {
                    _permanentlyDeleteNotebook(item);
                  } else if (isNote) {
                    _permanentlyDeleteNote(item);
                  } else {
                    _permanentlyDeleteThink(item);
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final allItems = [..._deletedNotebooks, ..._deletedNotes, ..._deletedThinks]
      ..sort((a, b) {
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

    return Dialog(
      backgroundColor: Colors.transparent,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 500,
          height: 400,
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Container(
                height: 56,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Icon(
                      Icons.delete_outline_rounded,
                      color: colorScheme.error,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Trash',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const Spacer(),
                    if (!_isLoading && allItems.isNotEmpty)
                      TextButton.icon(
                        onPressed: _deleteAllItems,
                        icon: Icon(
                          Icons.delete_sweep_rounded,
                          size: 20,
                          color: colorScheme.error,
                        ),
                        label: Text(
                          'Empty Trash',
                          style: TextStyle(color: colorScheme.error),
                        ),
                      ),
                    IconButton(
                      icon: Icon(
                        Icons.close_rounded,
                        color: colorScheme.onSurface,
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              Expanded(
                child:
                    _isLoading
                        ? Center(
                          child: CircularProgressIndicator(
                            color: colorScheme.primary,
                          ),
                        )
                        : allItems.isEmpty
                        ? Center(
                          child: Text(
                            'No items in trash',
                            style: TextStyle(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        )
                        : ListView.builder(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: allItems.length,
                          itemBuilder:
                              (context, index) => _buildItem(allItems[index]),
                        ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
