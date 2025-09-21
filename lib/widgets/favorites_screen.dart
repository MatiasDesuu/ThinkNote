import 'package:flutter/material.dart';
import '../database/models/notebook.dart';
import '../database/models/note.dart';
import '../database/models/think.dart';
import '../database/repositories/notebook_repository.dart';
import '../database/repositories/note_repository.dart';
import '../database/repositories/think_repository.dart';
import '../database/database_helper.dart';

class FavoritesScreen extends StatefulWidget {
  final Function(Notebook) onNotebookSelected;
  final Function(Note) onNoteSelected;
  final VoidCallback? Function(Note)? onNoteSelectedFromPanel;
  final Function(Think)? onThinkSelected;
  final VoidCallback? onFavoritesUpdated;

  const FavoritesScreen({
    super.key,
    required this.onNotebookSelected,
    required this.onNoteSelected,
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
      final notebooks = await _notebookRepository.getFavoriteNotebooks();
      final notes = await _noteRepository.getFavoriteNotes();
      final thinks = await _thinkRepository.getFavoriteThinks();

      setState(() {
        _favoriteNotebooks = notebooks;
        _favoriteNotes = notes;
        _favoriteThinks = thinks;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading favorites: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleNotebookFavorite(Notebook notebook) async {
    final updatedNotebook = notebook.copyWith(isFavorite: !notebook.isFavorite);
    await _notebookRepository.updateNotebook(updatedNotebook);
    widget.onFavoritesUpdated?.call();
    await _loadData();
  }

  Future<void> _toggleNoteFavorite(Note note) async {
    final updatedNote = note.copyWith(isFavorite: !note.isFavorite);
    await _noteRepository.updateNote(updatedNote);
    widget.onFavoritesUpdated?.call();
    await _loadData();
  }

  Future<void> _toggleThinkFavorite(Think think) async {
    await _thinkRepository.toggleFavorite(think.id!, !think.isFavorite);
    widget.onFavoritesUpdated?.call();
    await _loadData();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final allItems = [
      ..._favoriteNotebooks,
      ..._favoriteNotes,
      ..._favoriteThinks,
    ];

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
                    Icon(Icons.favorite_rounded, color: colorScheme.primary),
                    const SizedBox(width: 12),
                    Text(
                      'Favorites',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const Spacer(),
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
                            'No favorites yet',
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

  Widget _buildItem(dynamic item) {
    final isNotebook = item is Notebook;
    final isNote = item is Note;
    final isThink = item is Think;
    final colorScheme = Theme.of(context).colorScheme;

    IconData iconData;
    Color iconColor;
    String title;
    String itemId;

    if (isNotebook) {
      iconData = Icons.folder_rounded;
      iconColor = colorScheme.primary;
      title = item.name;
      itemId = 'notebook_${item.id}';
    } else if (isNote) {
      iconData = Icons.description_outlined;
      iconColor = colorScheme.primary;
      title = item.title;
      itemId = 'note_${item.id}';
    } else {
      // Think
      iconData = Icons.lightbulb_outline_rounded;
      iconColor = colorScheme.primary;
      title = item.title;
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
          trailing: IconButton(
            icon: Icon(
              Icons.favorite_rounded,
              size: 20,
              color: colorScheme.primary,
            ),
            onPressed: () {
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
            }
            Navigator.of(context).pop();
          },
        ),
      ),
    );
  }
}
