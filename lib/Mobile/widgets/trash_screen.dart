import 'package:flutter/material.dart';
import '../../database/models/notebook.dart';
import '../../database/models/note.dart';
import '../../database/models/think.dart';
import '../../database/repositories/notebook_repository.dart';
import '../../database/repositories/note_repository.dart';
import '../../database/repositories/think_repository.dart';
import '../../database/database_helper.dart';
import '../../widgets/confirmation_dialogue.dart';

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
  State<TrashScreen> createState() => _TrashScreenState();
}

class _TrashScreenState extends State<TrashScreen> {
  late final NoteRepository _noteRepository;
  late final NotebookRepository _notebookRepository;
  late final ThinkRepository _thinkRepository;
  List<Notebook> _deletedNotebooks = [];
  List<Note> _deletedNotes = [];
  List<Think> _deletedThinks = [];
  bool _isLoading = true;

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
      for (final note in _deletedNotes) {
        await _noteRepository.hardDeleteNote(note.id!);
      }

      for (final think in _deletedThinks) {
        await _thinkRepository.permanentlyDeleteThink(think.id!);
      }

      for (final notebook in _deletedNotebooks) {
        await _notebookRepository.hardDeleteNotebook(notebook.id!);
      }

      widget.onTrashUpdated?.call();
      await _loadData();
    }
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Trash'),
        actions: [
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
        ],
      ),
      body:
          _isLoading
              ? Center(
                child: CircularProgressIndicator(color: colorScheme.primary),
              )
              : allItems.isEmpty
              ? Center(
                child: Text(
                  'No items in trash',
                  style: TextStyle(color: colorScheme.onSurfaceVariant),
                ),
              )
              : ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: allItems.length,
                itemBuilder: (context, index) {
                  final item = allItems[index];
                  final isNotebook = item is Notebook;
                  final isNote = item is Note;

                  IconData iconData;
                  Color iconColor;
                  String title;
                  DateTime? deletedAt;

                  if (isNotebook) {
                    iconData = Icons.folder_rounded;
                    iconColor = colorScheme.primary;
                    title = item.name;
                    deletedAt = item.deletedAt;
                  } else if (isNote) {
                    iconData = Icons.description_outlined;
                    iconColor = colorScheme.primary;
                    title = item.title;
                    deletedAt = item.deletedAt;
                  } else {
                    iconData = Icons.lightbulb_outline;
                    iconColor = colorScheme.primary;
                    title = (item as Think).title;
                    deletedAt = item.deletedAt;
                  }

                  return ListTile(
                    leading: Icon(iconData, color: iconColor),
                    title: Text(title),
                    subtitle: Text(
                      'Deleted on ${deletedAt != null ? _formatDate(deletedAt) : 'Unknown'}',
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(
                            Icons.restore_rounded,
                            color: colorScheme.primary,
                          ),
                          onPressed: () {
                            if (isNotebook) {
                              _notebookRepository.restoreNotebook((item).id!);
                              widget.onNotebookRestored?.call(item);
                            } else if (isNote) {
                              _noteRepository.restoreNote((item).id!);
                              widget.onNoteRestored?.call(item);
                            } else {
                              _thinkRepository.restoreThink(
                                (item as Think).id!,
                              );
                              widget.onThinkRestored?.call(item);
                            }
                            widget.onTrashUpdated?.call();
                            _loadData();
                          },
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.delete_forever_rounded,
                            color: colorScheme.error,
                          ),
                          onPressed: () async {
                            if (isNotebook) {
                              await _notebookRepository.hardDeleteNotebook(
                                (item).id!,
                              );
                            } else if (isNote) {
                              await _noteRepository.hardDeleteNote((item).id!);
                            } else {
                              await _thinkRepository.permanentlyDeleteThink(
                                (item as Think).id!,
                              );
                            }
                            widget.onTrashUpdated?.call();
                            _loadData();
                          },
                        ),
                      ],
                    ),
                  );
                },
              ),
    );
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}
