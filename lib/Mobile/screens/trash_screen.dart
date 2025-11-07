import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'dart:math' as math;
import '../../database/models/notebook.dart';
import '../../database/models/note.dart';
import '../../database/models/think.dart';
import '../../database/repositories/notebook_repository.dart';
import '../../database/repositories/note_repository.dart';
import '../../database/repositories/think_repository.dart';
import '../../database/database_helper.dart';
import '../../widgets/custom_snackbar.dart';
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

class _TrashScreenState extends State<TrashScreen>
    with TickerProviderStateMixin {
  late final NoteRepository _noteRepository;
  late final NotebookRepository _notebookRepository;
  late final ThinkRepository _thinkRepository;
  late final AnimationController _sweepController;
  late final Animation<double> _sweepAnimation;
  bool _isClearing = false;
  bool _isLoading = true;
  List<Notebook> _deletedNotebooks = [];
  List<Note> _deletedNotes = [];
  List<Think> _deletedThinks = [];

  @override
  void initState() {
    super.initState();
    _sweepController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
      value: 0.5,
    );

    _sweepAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _sweepController, curve: const SawTooth(3)),
    );
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
      if (mounted) {
        CustomSnackbar.show(
          context: context,
          message: 'Error loading trash: ${e.toString()}',
          type: CustomSnackbarType.error,
        );
      }
    }
  }

  void _toggleSweepAnimation(bool sweeping) {
    if (sweeping) {
      _sweepController.repeat();
    } else {
      _sweepController
          .fling(
            velocity: 0.5,
            springDescription: SpringDescription.withDampingRatio(
              mass: 0.5,
              stiffness: 100.0,
              ratio: 1.1,
            ),
          )
          .then((_) => _sweepController.reset());
    }
  }

  Future<void> _restoreNotebook(Notebook notebook) async {
    try {
      await _notebookRepository.restoreNotebook(notebook.id!);
      widget.onNotebookRestored?.call(notebook);
      widget.onTrashUpdated?.call();
      await _loadData();
    } catch (e) {
      if (mounted) {
        CustomSnackbar.show(
          context: context,
          message: 'Error restoring notebook: ${e.toString()}',
          type: CustomSnackbarType.error,
        );
      }
    }
  }

  Future<void> _restoreNote(Note note) async {
    try {
      await _noteRepository.restoreNote(note.id!);
      widget.onNoteRestored?.call(note);
      widget.onTrashUpdated?.call();
      DatabaseHelper.notifyDatabaseChanged();
      await _loadData();
    } catch (e) {
      if (mounted) {
        CustomSnackbar.show(
          context: context,
          message: 'Error restoring note: ${e.toString()}',
          type: CustomSnackbarType.error,
        );
      }
    }
  }

  Future<void> _restoreThink(Think think) async {
    try {
      await _thinkRepository.restoreThink(think.id!);
      widget.onThinkRestored?.call(think);
      widget.onTrashUpdated?.call();
      await _loadData();
    } catch (e) {
      if (mounted) {
        CustomSnackbar.show(
          context: context,
          message: 'Error restoring think: ${e.toString()}',
          type: CustomSnackbarType.error,
        );
      }
    }
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
      try {
        await _notebookRepository.hardDeleteNotebook(notebook.id!);
        widget.onTrashUpdated?.call();
        await _loadData();
        if (mounted) {
          CustomSnackbar.show(
            context: context,
            message: 'Notebook permanently deleted',
            type: CustomSnackbarType.success,
          );
        }
      } catch (e) {
        if (mounted) {
          CustomSnackbar.show(
            context: context,
            message: 'Error deleting notebook: ${e.toString()}',
            type: CustomSnackbarType.error,
          );
        }
      }
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
      try {
        await _noteRepository.hardDeleteNote(note.id!);
        widget.onTrashUpdated?.call();
        await _loadData();
        if (mounted) {
          CustomSnackbar.show(
            context: context,
            message: 'Note permanently deleted',
            type: CustomSnackbarType.success,
          );
        }
      } catch (e) {
        if (mounted) {
          CustomSnackbar.show(
            context: context,
            message: 'Error deleting note: ${e.toString()}',
            type: CustomSnackbarType.error,
          );
        }
      }
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
      try {
        await _thinkRepository.permanentlyDeleteThink(think.id!);
        widget.onTrashUpdated?.call();
        await _loadData();
        if (mounted) {
          CustomSnackbar.show(
            context: context,
            message: 'Think permanently deleted',
            type: CustomSnackbarType.success,
          );
        }
      } catch (e) {
        if (mounted) {
          CustomSnackbar.show(
            context: context,
            message: 'Error deleting think: ${e.toString()}',
            type: CustomSnackbarType.error,
          );
        }
      }
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
      _toggleSweepAnimation(true);
      setState(() => _isClearing = true);

      try {
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
        if (mounted) {
          CustomSnackbar.show(
            context: context,
            message: 'All items permanently deleted',
            type: CustomSnackbarType.success,
          );
        }
      } catch (e) {
        if (mounted) {
          CustomSnackbar.show(
            context: context,
            message: 'Error deleting items: ${e.toString()}',
            type: CustomSnackbarType.error,
          );
        }
      } finally {
        _toggleSweepAnimation(false);
        setState(() => _isClearing = false);
      }
    }
  }

  @override
  void dispose() {
    _sweepController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, bool? shouldPop) {
        if (!didPop) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          scrolledUnderElevation: 0,
          surfaceTintColor: Colors.transparent,
          backgroundColor: Theme.of(context).colorScheme.surface,
          title: const Text('Trash'),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 4.0),
              child: IconButton(
                icon: AnimatedBuilder(
                  animation: _sweepController,
                  builder: (context, child) {
                    return Transform(
                      alignment: Alignment.topCenter,
                      transform:
                          Matrix4.identity()
                            ..rotateZ(
                              math.sin(_sweepAnimation.value * 2 * math.pi) *
                                  0.2,
                            )
                            ..translateByDouble(
                              0.0,
                              4 * (1 - _sweepAnimation.value.abs()),
                              0.0,
                              1.0,
                            ),
                      child: child,
                    );
                  },
                  child: Icon(
                    Symbols.mop,
                    size: 32,
                    color:
                        allItems.isNotEmpty
                            ? Theme.of(context).colorScheme.error
                            : Theme.of(
                              context,
                            ).colorScheme.onSurface.withAlpha(100),
                  ),
                ),
                onPressed:
                    allItems.isNotEmpty && !_isClearing
                        ? _deleteAllItems
                        : null,
                color:
                    allItems.isNotEmpty
                        ? Theme.of(
                          context,
                        ).colorScheme.error.withAlpha(_isClearing ? 100 : 255)
                        : null,
              ),
            ),
          ],
        ),
        body:
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : allItems.isEmpty
                ? Center(
                  child: Text(
                    'No items in trash',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                )
                : ListView.builder(
                  itemCount: allItems.length,
                  itemBuilder: (context, index) {
                    final item = allItems[index];
                    final isNotebook = item is Notebook;
                    final isNote = item is Note;
                    final colorScheme = Theme.of(context).colorScheme;

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
                      iconData = Icons.lightbulb_outline_rounded;
                      iconColor = colorScheme.primary;
                      title = (item as Think).title;
                      deletedAt = item.deletedAt;
                    }

                    return SizedBox(
                      height: 56,
                      child: Row(
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(
                              left: 16.0,
                              right: 24.0,
                            ),
                            child: Icon(iconData, size: 28, color: iconColor),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  title,
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: colorScheme.onSurface,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (deletedAt != null)
                                  Text(
                                    'Deleted on ${deletedAt.toLocal().toString().split('.')[0]}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.only(right: 4),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.restore_rounded),
                                  onPressed: () {
                                    if (isNotebook) {
                                      _restoreNotebook(item);
                                    } else if (isNote) {
                                      _restoreNote(item);
                                    } else {
                                      _restoreThink(item as Think);
                                    }
                                  },
                                  iconSize: 28,
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  color: colorScheme.tertiary,
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete_forever_rounded,
                                  ),
                                  onPressed: () {
                                    if (isNotebook) {
                                      _permanentlyDeleteNotebook(item);
                                    } else if (isNote) {
                                      _permanentlyDeleteNote(item);
                                    } else {
                                      _permanentlyDeleteThink(item as Think);
                                    }
                                  },
                                  iconSize: 28,
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  color: colorScheme.error,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
      ),
    );
  }
}
