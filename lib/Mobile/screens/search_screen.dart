import 'package:flutter/material.dart';
import 'dart:async';
import 'package:dynamic_color/dynamic_color.dart';
import '../theme_handler.dart';
import '../../database/models/note.dart';
import '../../database/models/notebook.dart';
import '../../database/models/notebook_icons.dart';
import '../../database/database_helper.dart';
import '../../database/repositories/note_repository.dart';
import '../../database/repositories/notebook_repository.dart';
import '../../widgets/custom_snackbar.dart';
import '../widgets/note_editor.dart';

class SearchScreen extends StatefulWidget {
  final Function(Note)? onNoteSelected;
  final Function(Notebook)? onNotebookSelected;

  const SearchScreen({super.key, this.onNoteSelected, this.onNotebookSelected});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounceTimer;
  List<dynamic> _searchResults = [];
  late Future<bool> _brightnessFuture;
  late Future<bool> _colorModeFuture;
  late Future<bool> _monochromeFuture;
  late NoteRepository _noteRepository;
  late NotebookRepository _notebookRepository;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _loadThemePreferences();
    _initializeRepositories();
  }

  Future<void> _initializeRepositories() async {
    final dbHelper = DatabaseHelper();
    await dbHelper.database;
    _noteRepository = NoteRepository(dbHelper);
    _notebookRepository = NotebookRepository(dbHelper);
  }

  void _loadThemePreferences() {
    _brightnessFuture = ThemeManager.getThemeBrightness();
    _colorModeFuture = ThemeManager.getColorModeEnabled();
    _monochromeFuture = ThemeManager.getMonochromeEnabled();
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  Future<void> _performSearch(String query) async {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
      });
      return;
    }

    try {
      final notes = await _noteRepository.searchNotes(query);
      final notebooks = await _notebookRepository.searchNotebooks(query);

      if (mounted) {
        setState(() {
          _searchResults = [...notebooks, ...notes];
        });
      }
    } catch (e) {
      debugPrint('Error performing search: $e');
      if (mounted) {
        CustomSnackbar.show(
          context: context,
          message: 'Error performing search: ${e.toString()}',
          type: CustomSnackbarType.error,
        );
      }
    }
  }

  void _onSearchChanged() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      _performSearch(_searchController.text);
    });
  }

  void _handleItemTap(dynamic item) {
    if (item is Note) {
      final editorTitleController = TextEditingController(text: item.title);
      final editorContentController = TextEditingController(text: item.content);
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

                    final dbHelper = DatabaseHelper();
                    final noteRepository = NoteRepository(dbHelper);
                    await noteRepository.updateNote(updatedNote);
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
        Navigator.pop(context);
      });
    } else if (item is Notebook) {
      widget.onNotebookSelected?.call(item);
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DynamicColorBuilder(
      builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
        return FutureBuilder(
          future: Future.wait([
            _brightnessFuture,
            _colorModeFuture,
            _monochromeFuture,
          ]),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const SizedBox.shrink();

            final isDarkMode = snapshot.data![0];
            final colorMode = snapshot.data![1];
            final monochromeMode = snapshot.data![2];

            final theme = ThemeManager.buildTheme(
              lightDynamic: lightDynamic,
              darkDynamic: darkDynamic,
              isDarkMode: isDarkMode,
              colorModeEnabled: colorMode,
              monochromeEnabled: monochromeMode,
            );

            final customTheme = theme.copyWith(
              appBarTheme: AppBarTheme(
                elevation: 0,
                scrolledUnderElevation: 0,
                surfaceTintColor: Colors.transparent,
                backgroundColor: theme.colorScheme.surface,
                toolbarHeight: 64,
              ),
              inputDecorationTheme: InputDecorationTheme(
                filled: true,
                fillColor: theme.colorScheme.surface,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
                hintStyle: TextStyle(
                  color: theme.colorScheme.onSurface.withAlpha(128),
                  fontSize: 16,
                ),
              ),
              textTheme: theme.textTheme.copyWith(
                titleLarge: TextStyle(
                  color: theme.colorScheme.onSurface,
                  fontSize: 16,
                ),
              ),
              textSelectionTheme: TextSelectionThemeData(
                cursorColor: theme.colorScheme.primary,
                selectionColor: theme.colorScheme.primary.withAlpha(76),
                selectionHandleColor: theme.colorScheme.primary,
              ),
              iconTheme: IconThemeData(color: theme.colorScheme.primary),
            );

            return Theme(
              data: customTheme,
              child: PopScope(
                canPop: Navigator.canPop(context),
                onPopInvokedWithResult: (bool didPop, bool? result) {
                  if (didPop) return;
                  // Si no se pudo hacer pop, verificar si hay algo que cerrar
                  if (Navigator.canPop(context)) {
                    Navigator.pop(context);
                  }
                },
                child: Scaffold(
                  appBar: AppBar(
                    elevation: 0,
                    scrolledUnderElevation: 0,
                    surfaceTintColor: Colors.transparent,
                    backgroundColor: theme.colorScheme.surface,
                    toolbarHeight: 64,
                    leading: IconButton(
                      icon: Icon(
                        Icons.arrow_back_rounded,
                        color: theme.colorScheme.onSurface,
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                    title: TextField(
                      controller: _searchController,
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: 'Search...',
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        hintStyle: TextStyle(
                          color: theme.colorScheme.onSurface.withAlpha(128),
                          fontSize: 16,
                        ),
                      ),
                      style: TextStyle(
                        color: theme.colorScheme.onSurface,
                        fontSize: 16,
                      ),
                    ),
                    actions: [
                      if (_searchController.text.isNotEmpty)
                        IconButton(
                          icon: Icon(
                            Icons.clear_rounded,
                            color: theme.colorScheme.onSurface,
                          ),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {
                              _searchResults = [];
                            });
                          },
                        ),
                    ],
                  ),
                  body:
                      _searchResults.isEmpty
                          ? Center(
                            child: Text(
                              'No results found',
                              style: TextStyle(
                                color: theme.colorScheme.onSurface.withAlpha(
                                  153,
                                ),
                              ),
                            ),
                          )
                          : ListView.builder(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            itemCount: _searchResults.length,
                            itemBuilder: (context, index) {
                              return _buildSearchResultItem(
                                _searchResults[index],
                                theme,
                              );
                            },
                          ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSearchResultItem(dynamic item, ThemeData theme) {
    final isNotebook = item is Notebook;
    final hasContent = isNotebook ? false : (item.content.isNotEmpty);

    // Obtener el icono apropiado
    IconData iconData;
    if (isNotebook) {
      // Para notebooks, usar el icono personalizado o el por defecto
      iconData =
          item.iconId != null
              ? NotebookIconsRepository.getIconById(item.iconId!)?.icon ??
                  Icons.folder_rounded
              : Icons.folder_rounded;
    } else {
      // Para notas, usar el icono de descripción
      iconData = Icons.description_outlined;
    }

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      leading: Icon(iconData, color: theme.colorScheme.primary, size: 28),
      title:
          hasContent
              ? Text(
                isNotebook ? item.name : item.title,
                style: TextStyle(
                  fontSize: 16,
                  color: theme.colorScheme.onSurface,
                ),
              )
              : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isNotebook ? item.name : item.title,
                    style: TextStyle(
                      fontSize: 16,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
      subtitle:
          hasContent && !isNotebook
              ? Text(
                item.content,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: theme.colorScheme.onSurface.withAlpha(153),
                  fontSize: 14,
                ),
              )
              : null,
      trailing:
          item.isFavorite
              ? Padding(
                padding: const EdgeInsets.only(),
                child: Icon(
                  Icons.favorite_rounded,
                  color: theme.colorScheme.primary,
                  size: 20,
                ),
              )
              : null,
      onTap: () => _handleItemTap(item),
    );
  }
}
