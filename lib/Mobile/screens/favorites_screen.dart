import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../database/models/notebook.dart';
import '../../database/models/note.dart';
import '../../database/models/think.dart';
import '../../database/repositories/notebook_repository.dart';
import '../../database/repositories/note_repository.dart';
import '../../database/repositories/think_repository.dart';
import '../../database/database_helper.dart';
import '../../widgets/custom_snackbar.dart';
import '../widgets/think_editor.dart';
import '../widgets/note_editor.dart';

class FavoritesScreen extends StatefulWidget {
  final Function(Notebook)? onNotebookSelected;
  final Function(Note)? onNoteSelected;
  final Function(Think)? onThinkSelected;
  final VoidCallback? onFavoritesUpdated;
  final VoidCallback? Function(Note)? onNoteSelectedFromPanel;

  const FavoritesScreen({
    super.key,
    this.onNotebookSelected,
    this.onNoteSelected,
    this.onThinkSelected,
    this.onFavoritesUpdated,
    this.onNoteSelectedFromPanel,
  });

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  late final NoteRepository _noteRepository;
  late final NotebookRepository _notebookRepository;
  late final ThinkRepository _thinkRepository;
  List<Notebook> _favoriteNotebooks = [];
  List<Note> _favoriteNotes = [];
  List<Think> _favoriteThinks = [];
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
      final notebooks = await _notebookRepository.getFavoriteNotebooks();
      final notes = await _noteRepository.getFavoriteNotes();
      final thinks = await _thinkRepository.getFavoriteThinks();

      if (!mounted) return;
      setState(() {
        _favoriteNotebooks = notebooks;
        _favoriteNotes = notes;
        _favoriteThinks = thinks;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading favorites: $e');
      if (mounted) {
        CustomSnackbar.show(
          context: context,
          message: 'Error loading favorites: ${e.toString()}',
          type: CustomSnackbarType.error,
        );
      }
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _toggleNotebookFavorite(Notebook notebook) async {
    try {
      final updatedNotebook = notebook.copyWith(
        isFavorite: !notebook.isFavorite,
      );
      await _notebookRepository.updateNotebook(updatedNotebook);
      widget.onFavoritesUpdated?.call();
      await _loadData();
    } catch (e) {
      if (mounted) {
        CustomSnackbar.show(
          context: context,
          message: 'Error updating notebook favorite status: ${e.toString()}',
          type: CustomSnackbarType.error,
        );
      }
    }
  }

  Future<void> _toggleNoteFavorite(Note note) async {
    try {
      final updatedNote = note.copyWith(isFavorite: !note.isFavorite);
      await _noteRepository.updateNote(updatedNote);
      widget.onFavoritesUpdated?.call();
      await _loadData();
    } catch (e) {
      if (mounted) {
        CustomSnackbar.show(
          context: context,
          message: 'Error updating note favorite status: ${e.toString()}',
          type: CustomSnackbarType.error,
        );
      }
    }
  }

  Future<void> _toggleThinkFavorite(Think think) async {
    try {
      await _thinkRepository.toggleFavorite(think.id!, !think.isFavorite);
      widget.onFavoritesUpdated?.call();
      await _loadData();
    } catch (e) {
      if (mounted) {
        CustomSnackbar.show(
          context: context,
          message: 'Error updating think favorite status: ${e.toString()}',
          type: CustomSnackbarType.error,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final allItems = [
      ..._favoriteNotebooks,
      ..._favoriteNotes,
      ..._favoriteThinks,
    ];

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, bool? shouldPop) {
        if (!didPop) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          toolbarHeight: 40.0,
          scrolledUnderElevation: 0,
          surfaceTintColor: Colors.transparent,
          backgroundColor: Theme.of(context).colorScheme.surface,
          title: const Text('Favorites'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
        ),
        body:
            _isLoading
                ? Center(
                  child: CircularProgressIndicator(color: colorScheme.primary),
                )
                : allItems.isEmpty
                ? Center(
                  child: Text(
                    'No favorites yet',
                    style: TextStyle(color: colorScheme.onSurfaceVariant),
                  ),
                )
                : ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: allItems.length,
                  itemBuilder: (context, index) => _buildItem(allItems[index]),
                ),
      ),
    );
  }

  Widget _buildItem(dynamic item) {
    final isNotebook = item is Notebook;
    final isNote = item is Note;
    final isThink = item is Think;
    final colorScheme = Theme.of(context).colorScheme;

    IconData iconData;
    Color iconColor;
    String title;

    if (isNotebook) {
      iconData = Icons.folder_rounded;
      iconColor = colorScheme.primary;
      title = item.name;
    } else if (isNote) {
      iconData = Icons.description_outlined;
      iconColor = colorScheme.primary;
      title = item.title;
    } else {
      // Think
      iconData = Icons.lightbulb_outline;
      iconColor = colorScheme.primary;
      title = item.title;
    }

    return SizedBox(
      height: 64,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 24.0),
        leading: Icon(iconData, size: 32, color: iconColor),
        title: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              height: 1.2,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        trailing: IconButton(
          icon: Icon(Icons.favorite_rounded, color: colorScheme.primary),
          onPressed: () {
            HapticFeedback.lightImpact();
            if (isNotebook) {
              _toggleNotebookFavorite(item);
            } else if (isNote) {
              _toggleNoteFavorite(item);
            } else {
              _toggleThinkFavorite(item);
            }
          },
        ),
        onTap: () {
          HapticFeedback.lightImpact();
          if (isNotebook && widget.onNotebookSelected != null) {
            widget.onNotebookSelected!(item);
            Navigator.pop(context);
          } else if (isNote && widget.onNoteSelected != null) {
            // Notify parent that this selection came from a panel so it can
            // suppress tab animations when replacing the active tab.
            try {
              widget.onNoteSelectedFromPanel?.call(item);
            } catch (_) {}
            widget.onNoteSelected!(item);
            if (isNote) {
              final editorTitleController = TextEditingController(
                text: item.title,
              );
              final editorContentController = TextEditingController(
                text: item.content,
              );
              final editorFocusNode = FocusNode();

              Navigator.push(
                context,
                MaterialPageRoute(
                  builder:
                      (context) => NoteEditor(
                        selectedNote: item,
                        titleController: editorTitleController,
                        contentController: editorContentController,
                        contentFocusNode: editorFocusNode,
                        isEditing: true,
                        isImmersiveMode: false,
                        onSaveNote: () async {
                          try {
                            final updatedNote = Note(
                              id: item.id,
                              title: editorTitleController.text.trim(),
                              content: editorContentController.text,
                              notebookId: item.notebookId,
                              createdAt: item.createdAt,
                              updatedAt: DateTime.now(),
                              isFavorite: item.isFavorite,
                              tags: item.tags,
                              orderIndex: item.orderIndex,
                              isTask: item.isTask,
                              isCompleted: item.isCompleted,
                            );

                            await _noteRepository.updateNote(updatedNote);
                            DatabaseHelper.notifyDatabaseChanged();
                          } catch (e) {
                            debugPrint('Error saving note: $e');
                            if (mounted) {
                              CustomSnackbar.show(
                                context: context,
                                message: 'Error saving note: ${e.toString()}',
                                type: CustomSnackbarType.error,
                              );
                            }
                          }
                        },
                        onToggleEditing: () {},
                        onTitleChanged: () {},
                        onContentChanged: () {},
                        onToggleImmersiveMode: (isImmersive) {},
                      ),
                ),
              ).then((_) {
                _loadData();
              });
            }
          } else if (isThink) {
            widget.onThinkSelected?.call(item);
            if (isThink) {
              final editorTitleController = TextEditingController(
                text: item.title,
              );
              final editorContentController = TextEditingController(
                text: item.content,
              );
              final editorFocusNode = FocusNode();

              Navigator.push(
                context,
                MaterialPageRoute(
                  builder:
                      (context) => ThinkEditor(
                        selectedThink: item,
                        titleController: editorTitleController,
                        contentController: editorContentController,
                        contentFocusNode: editorFocusNode,
                        isEditing: true,
                        isImmersiveMode: false,
                        onSaveThink: () async {
                          try {
                            final updatedThink = Think(
                              id: item.id,
                              title: editorTitleController.text.trim(),
                              content: editorContentController.text,
                              createdAt: item.createdAt,
                              updatedAt: DateTime.now(),
                              isFavorite: item.isFavorite,
                              orderIndex: item.orderIndex,
                              tags: item.tags,
                            );

                            await _thinkRepository.updateThink(updatedThink);
                            DatabaseHelper.notifyDatabaseChanged();
                          } catch (e) {
                            debugPrint('Error saving think: $e');
                            if (mounted) {
                              CustomSnackbar.show(
                                context: context,
                                message: 'Error saving think: ${e.toString()}',
                                type: CustomSnackbarType.error,
                              );
                            }
                          }
                        },
                        onToggleEditing: () {},
                        onTitleChanged: () {},
                        onContentChanged: () {},
                        onToggleImmersiveMode: (isImmersive) {},
                      ),
                ),
              ).then((_) {
                _loadData();
              });
            }
          }
        },
        tileColor: colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        minVerticalPadding: 0,
        dense: true,
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}
