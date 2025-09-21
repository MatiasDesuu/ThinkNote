import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:html/parser.dart' as html;
import 'package:http/http.dart' as http;
import '../../database/database_service.dart';
import '../../database/models/bookmark.dart';
import '../../Bookmarks/bookmarks_handler_db.dart';
import '../../Bookmarks/bookmarks_tags_handler_db.dart';
import '../../widgets/custom_snackbar.dart';
import '../../widgets/confirmation_dialogue.dart';

class BookmarksHandler {
  static final BookmarksHandler _instance = BookmarksHandler._internal();
  factory BookmarksHandler() => _instance;
  BookmarksHandler._internal();

  // Constant for hidden tag
  static const String hiddenTag = 'hidden';

  final LinksHandlerDB _linksHandler = LinksHandlerDB();
  final TagsHandlerDB _tagsHandler = TagsHandlerDB();
  List<Bookmark> _bookmarks = [];
  List<String> _allTags = [];

  String? _selectedTag;
  bool _isOldestFirst = false;
  bool _isSearching = false;
  String _searchQuery = '';

  List<Bookmark> get filteredBookmarks {
    var filtered = List<Bookmark>.from(_bookmarks);

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered =
          filtered.where((bookmark) {
            final title = bookmark.title.toLowerCase();
            final url = bookmark.url.toLowerCase();
            return title.contains(query) || url.contains(query);
          }).toList();
    }

    // Sort by date
    filtered.sort((a, b) {
      final dateA = DateTime.parse(a.timestamp);
      final dateB = DateTime.parse(b.timestamp);
      return _isOldestFirst ? dateA.compareTo(dateB) : dateB.compareTo(dateA);
    });

    return filtered;
  }

  List<String> get allTags => _allTags;
  bool get isOldestFirst => _isOldestFirst;
  bool get isSearching => _isSearching;
  String? get selectedTag => _selectedTag;
  String get searchQuery => _searchQuery;

  void toggleSortOrder() {
    _isOldestFirst = !_isOldestFirst;
  }

  void setSelectedTag(String? tag) async {
    _selectedTag = tag;
    await loadData(); // Recargar los datos cuando se cambia el tag seleccionado
  }

  void toggleSearch() {
    _isSearching = !_isSearching;
    if (!_isSearching) {
      _searchQuery = '';
    }
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
  }

  Future<void> loadData() async {
    try {
      // Solo inicializamos la base de datos si no está inicializada
      if (!DatabaseService().isInitialized) {
        await DatabaseService().initializeDatabase();
      }

      // Cargar datos en paralelo
      await Future.wait([_loadBookmarks(), _tagsHandler.loadPatterns()]);
    } catch (e) {
      print('Error loading bookmarks: $e');
      _bookmarks = [];
      _allTags = [];
    }
  }

  Future<void> _loadBookmarks() async {
    try {
      // Cargar bookmarks con sus tags
      _bookmarks =
          await DatabaseService().bookmarkService.getAllBookmarksWithTags();

      // Obtener todos los tags únicos de los bookmarks
      final Set<String> activeTags = {};
      for (final bookmark in _bookmarks) {
        if (bookmark.id != null) {
          final tags = await DatabaseService().bookmarkService
              .getTagsByBookmarkId(bookmark.id!);
          activeTags.addAll(tags);
        }
      }

      // Convertir el Set a List y ordenar
      _allTags = activeTags.toList()..sort();

      // Mover el tag hidden al final de la lista si existe
      if (_allTags.contains(hiddenTag)) {
        _allTags.remove(hiddenTag);
        _allTags.add(hiddenTag);
      }
    } catch (e) {
      print('Error loading bookmarks: $e');
      _bookmarks = [];
      _allTags = [];
    }
  }

  Future<Bookmark?> createBookmark({
    required String title,
    required String url,
    String description = '',
    List<String> tags = const [],
  }) async {
    try {
      List<String> finalTags = List.from(tags);
      if (finalTags.isEmpty) {
        final predefinedTags = await DatabaseService().bookmarkService
            .getTagsForUrl(url);
        finalTags.addAll(predefinedTags);
      }

      final bookmarkId = await DatabaseService().bookmarkService.createBookmark(
        Bookmark(
          title: title,
          url: url,
          description: description,
          timestamp: DateTime.now().toIso8601String(),
          hidden: false,
          tagIds: [],
        ),
      );

      final bookmark = await DatabaseService().bookmarkService.getBookmarkByUrl(
        url,
      );
      if (bookmark != null) {
        await DatabaseService().bookmarkService.updateBookmarkTags(
          bookmarkId,
          finalTags,
        );
      }
      await loadData();
      return bookmark;
    } catch (e) {
      print('Error creating bookmark: $e');
      return null;
    }
  }

  Future<void> updateBookmark({
    required int id,
    required String newTitle,
    required String newUrl,
    String newDescription = '',
    List<String> newTags = const [],
  }) async {
    try {
      // Actualizar el bookmark
      await DatabaseService().bookmarkService.updateBookmark(
        Bookmark(
          id: id,
          title: newTitle,
          url: newUrl,
          description: newDescription,
          timestamp: DateTime.now().toIso8601String(),
          hidden: false,
        ),
      );

      // Actualizar los tags
      await DatabaseService().bookmarkService.updateBookmarkTags(id, newTags);

      // Recargar los datos
      await loadData();
    } catch (e) {
      print('Error updating bookmark: $e');
    }
  }

  Future<void> deleteBookmark(int id) async {
    try {
      await _linksHandler.removeBookmark(id);
      await loadData();
    } catch (e) {
      print('Error deleting bookmark: $e');
    }
  }

  bool isBookmarkHidden(Bookmark bookmark) {
    return bookmark.hidden;
  }

  Future<void> toggleBookmarkVisibility(int id) async {
    try {
      await _linksHandler.toggleBookmarkVisibility(id);
      await loadData();
    } catch (e) {
      print('Error toggling bookmark visibility: $e');
    }
  }

  Future<List<Bookmark>> getFilteredBookmarks() async {
    await loadData();
    var filtered = filteredBookmarks;

    // Aplicar filtrado por tag si es necesario
    if (_selectedTag != null) {
      final List<Bookmark> tagFiltered = [];

      for (final bookmark in filtered) {
        if (bookmark.id != null) {
          final tags = await DatabaseService().bookmarkService
              .getTagsByBookmarkId(bookmark.id!);

          // Si estamos en el filtro "hidden", mostrar solo los que tienen ese tag
          if (_selectedTag == hiddenTag) {
            if (tags.contains(_selectedTag)) {
              tagFiltered.add(bookmark);
            }
          } else {
            // Para otros tags, mostrar los que tienen el tag y NO tienen el tag hidden
            if (tags.contains(_selectedTag) && !tags.contains(hiddenTag)) {
              tagFiltered.add(bookmark);
            }
          }
        }
      }

      filtered = tagFiltered;
    } else {
      // Si no hay tag seleccionado (filtro "All"), excluir explícitamente los bookmarks con tag hidden
      final List<Bookmark> nonHiddenBookmarks = [];

      for (final bookmark in filtered) {
        if (bookmark.id != null) {
          final tags = await DatabaseService().bookmarkService
              .getTagsByBookmarkId(bookmark.id!);
          if (!tags.contains(hiddenTag)) {
            nonHiddenBookmarks.add(bookmark);
          }
        }
      }

      filtered = nonHiddenBookmarks;
    }

    return filtered;
  }
}

class BookmarksScreen extends StatefulWidget {
  const BookmarksScreen({super.key});

  @override
  BookmarksScreenState createState() => BookmarksScreenState();
}

class BookmarksScreenState extends State<BookmarksScreen> {
  static BookmarksScreenState? currentState;
  final TextEditingController _searchController = TextEditingController();
  final BookmarksHandler _handler = BookmarksHandler();
  bool _showSearchField = false;
  List<Bookmark> _bookmarks = [];

  // Métodos públicos para control externo desde main_mobile.dart
  void showAddDialog() => _showAddDialog();
  void showSearch() => setState(() => _showSearchField = true);

  Future<void> loadData() async {
    await _handler.loadData();
    if (mounted) {
      final bookmarks = await _handler.getFilteredBookmarks();
      setState(() {
        _bookmarks = bookmarks;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    currentState = this;
    loadData();
  }

  @override
  void dispose() {
    if (currentState == this) {
      currentState = null;
    }
    super.dispose();
  }

  Future<void> _deleteBookmark(Bookmark bookmark) async {
    if (bookmark.id != null) {
      try {
        await _handler.deleteBookmark(bookmark.id!);
        setState(() {
          _bookmarks.removeWhere((b) => b.id == bookmark.id);
        });
      } catch (e) {
        if (mounted) {
          CustomSnackbar.show(
            context: context,
            message: 'Error deleting bookmark: ${e.toString()}',
            type: CustomSnackbarType.error,
          );
        }
      }
    }
  }

  void _showEditDialog(Bookmark bookmark) {
    final formKey = GlobalKey<FormState>();
    final titleController = TextEditingController(text: bookmark.title);
    final urlController = TextEditingController(text: bookmark.url);
    final descController = TextEditingController(text: bookmark.description);
    final tagsController = TextEditingController();
    final colorScheme = Theme.of(context).colorScheme;

    // Cargar los tags del bookmark
    DatabaseService().bookmarkService.getTagsByBookmarkId(bookmark.id!).then((
      tags,
    ) {
      if (tagsController.text.isEmpty) {
        tagsController.text = tags.join(', ');
      }
    });

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext dialogContext) {
        final bottomPadding = MediaQuery.of(dialogContext).padding.bottom;
        final keyboardHeight = MediaQuery.of(dialogContext).viewInsets.bottom;

        return Padding(
          padding: EdgeInsets.only(
            bottom: keyboardHeight + bottomPadding,
            left: 16,
            right: 16,
            top: 16,
          ),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: colorScheme.onSurface.withAlpha(50),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: urlController,
                        decoration: InputDecoration(
                          labelText: 'URL*',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          filled: true,
                          fillColor: colorScheme.surfaceContainerHighest
                              .withAlpha(76),
                          prefixIcon: Icon(
                            Icons.link_rounded,
                            color: colorScheme.primary,
                          ),
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
                        controller: titleController,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: InputDecoration(
                          labelText: 'Title*',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          filled: true,
                          fillColor: colorScheme.surfaceContainerHighest
                              .withAlpha(76),
                          prefixIcon: Icon(
                            Icons.title_rounded,
                            color: colorScheme.primary,
                          ),
                        ),
                        validator:
                            (value) =>
                                value?.isEmpty ?? true ? 'Required' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: descController,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: InputDecoration(
                          labelText: 'Description',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          filled: true,
                          fillColor: colorScheme.surfaceContainerHighest
                              .withAlpha(76),
                          prefixIcon: Icon(
                            Icons.description_rounded,
                            color: colorScheme.primary,
                          ),
                        ),
                        maxLines: 1,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: tagsController,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: InputDecoration(
                          labelText: 'Tags',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          filled: true,
                          fillColor: colorScheme.surfaceContainerHighest
                              .withAlpha(76),
                          prefixIcon: Icon(
                            Icons.label_rounded,
                            color: colorScheme.primary,
                          ),
                          hintText: 'Separated by commas',
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.only(bottom: bottomPadding),
                  child: ElevatedButton(
                    onPressed: () async {
                      if (formKey.currentState!.validate()) {
                        try {
                          final newTags =
                              tagsController.text
                                  .split(',')
                                  .map((e) => e.trim())
                                  .where((e) => e.isNotEmpty)
                                  .toList();

                          await _handler.updateBookmark(
                            id: bookmark.id!,
                            newTitle: titleController.text,
                            newUrl: urlController.text,
                            newDescription: descController.text,
                            newTags: newTags,
                          );

                          if (dialogContext.mounted) {
                            Navigator.pop(dialogContext);
                          }

                          // Actualizar el estado de la pantalla
                          if (mounted) {
                            await loadData();
                          }
                        } catch (e) {
                          if (mounted) {
                            CustomSnackbar.show(
                              context: context,
                              message:
                                  'Error updating bookmark: ${e.toString()}',
                              type: CustomSnackbarType.error,
                            );
                          }
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorScheme.primary,
                      foregroundColor: colorScheme.onPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Save Changes',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
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

  void _showAddDialog() {
    final formKey = GlobalKey<FormState>();
    final titleController = TextEditingController();
    final urlController = TextEditingController();
    final descController = TextEditingController();
    final tagsController = TextEditingController();
    final colorScheme = Theme.of(context).colorScheme;
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
          final pageTitle = document.querySelector('title')?.text;

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

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext dialogContext) {
        final bottomPadding = MediaQuery.of(dialogContext).padding.bottom;
        final keyboardHeight = MediaQuery.of(dialogContext).viewInsets.bottom;

        return Padding(
          padding: EdgeInsets.only(
            bottom: keyboardHeight + bottomPadding,
            left: 16,
            right: 16,
            top: 16,
          ),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: colorScheme.onSurface.withAlpha(50),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: urlController,
                        decoration: InputDecoration(
                          labelText: 'URL*',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          filled: true,
                          fillColor: colorScheme.surfaceContainerHighest
                              .withAlpha(76),
                          prefixIcon: Icon(
                            Icons.link_rounded,
                            color: colorScheme.primary,
                          ),
                          suffixIcon: IconButton(
                            icon: Icon(
                              Icons.search_rounded,
                              color: colorScheme.primary,
                            ),
                            onPressed: () => fetchWebTitle(urlController.text),
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
                          if (titleController.text.isEmpty || !isTitleEdited) {
                            await fetchWebTitle(value);
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: titleController,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: InputDecoration(
                          labelText: 'Title*',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          filled: true,
                          fillColor: colorScheme.surfaceContainerHighest
                              .withAlpha(76),
                          prefixIcon: Icon(
                            Icons.title_rounded,
                            color: colorScheme.primary,
                          ),
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
                                value?.isEmpty ?? true ? 'Required' : null,
                        onChanged: (value) {
                          if (value.isNotEmpty) {
                            setState(() => isTitleEdited = true);
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: descController,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: InputDecoration(
                          labelText: 'Description',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          filled: true,
                          fillColor: colorScheme.surfaceContainerHighest
                              .withAlpha(76),
                          prefixIcon: Icon(
                            Icons.description_rounded,
                            color: colorScheme.primary,
                          ),
                        ),
                        maxLines: 1,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: tagsController,
                        decoration: InputDecoration(
                          labelText: 'Tags',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          filled: true,
                          fillColor: colorScheme.surfaceContainerHighest
                              .withAlpha(76),
                          prefixIcon: Icon(
                            Icons.label_rounded,
                            color: colorScheme.primary,
                          ),
                          hintText: 'Separated by commas',
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.only(bottom: bottomPadding),
                  child: ElevatedButton(
                    onPressed: () async {
                      if (formKey.currentState?.validate() ?? false) {
                        try {
                          final result = await _handler.createBookmark(
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

                          if (result != null) {
                            await loadData();
                            if (dialogContext.mounted) {
                              Navigator.pop(dialogContext);
                            }
                            if (mounted) {
                              setState(() {});
                            }
                          }
                        } catch (e) {
                          if (mounted) {
                            CustomSnackbar.show(
                              context: context,
                              message:
                                  'Error creating bookmark: ${e.toString()}',
                              type: CustomSnackbarType.error,
                            );
                          }
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorScheme.primary,
                      foregroundColor: colorScheme.onPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Save',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
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

  Widget _buildFallbackIcon() {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        Icons.link_rounded,
        size: 28,
        color: Theme.of(context).colorScheme.primary,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tags = _handler.allTags;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: Column(
        children: [
          Container(
            height: 50,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                GestureDetector(
                  onLongPress: () {
                    setState(() {
                      _showSearchField = true;
                    });
                  },
                  child: IconButton(
                    icon: Icon(
                      _showSearchField
                          ? Icons.search_off_rounded
                          : Icons.search_rounded,
                      color: _showSearchField ? colorScheme.primary : null,
                    ),
                    onPressed: () {
                      setState(() {
                        _showSearchField = !_showSearchField;
                        if (!_showSearchField) {
                          _handler.setSearchQuery('');
                          _searchController.clear();
                        }
                      });
                    },
                    tooltip:
                        _showSearchField
                            ? 'Hide search'
                            : 'Search (hold to search quickly)',
                  ),
                ),
                IconButton(
                  icon: Icon(
                    _handler.isOldestFirst
                        ? Icons.arrow_downward_rounded
                        : Icons.arrow_upward_rounded,
                    color: _handler.isOldestFirst ? colorScheme.primary : null,
                  ),
                  onPressed: () {
                    setState(() {
                      _handler.toggleSortOrder();
                    });
                  },
                  tooltip:
                      _handler.isOldestFirst
                          ? 'Show newest first'
                          : 'Show oldest first',
                ),
                if (tags.isNotEmpty)
                  Expanded(
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: tags.length + 1,
                      itemBuilder: (context, index) {
                        if (index == 0) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: FilterChip(
                              label: const Text('All'),
                              selected: _handler.selectedTag == null,
                              onSelected: (selected) async {
                                setState(() {
                                  _handler.setSelectedTag(null);
                                });
                                await loadData();
                              },
                              selectedColor: colorScheme.primaryContainer,
                              checkmarkColor: colorScheme.onPrimaryContainer,
                              labelStyle: TextStyle(
                                color:
                                    _handler.selectedTag == null
                                        ? colorScheme.onPrimaryContainer
                                        : colorScheme.onSurface,
                              ),
                              side: BorderSide(
                                color:
                                    _handler.selectedTag == null
                                        ? colorScheme.primary
                                        : colorScheme.outline,
                                width: 1,
                              ),
                            ),
                          );
                        }
                        final tag = tags[index - 1];
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChip(
                            label: Text(tag),
                            selected: _handler.selectedTag == tag,
                            onSelected: (selected) async {
                              setState(() {
                                _handler.setSelectedTag(selected ? tag : null);
                              });
                              await loadData();
                            },
                            selectedColor: colorScheme.primaryContainer,
                            checkmarkColor: colorScheme.onPrimaryContainer,
                            labelStyle: TextStyle(
                              color:
                                  _handler.selectedTag == tag
                                      ? colorScheme.onPrimaryContainer
                                      : colorScheme.onSurface,
                            ),
                            side: BorderSide(
                              color:
                                  _handler.selectedTag == tag
                                      ? colorScheme.primary
                                      : colorScheme.outline,
                              width: 1,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
          if (_showSearchField)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: TextField(
                autofocus: true,
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search in bookmarks...',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon:
                      _handler.searchQuery.isNotEmpty
                          ? IconButton(
                            icon: const Icon(Icons.clear_rounded),
                            onPressed: () {
                              setState(() {
                                _handler.setSearchQuery('');
                                _searchController.clear();
                              });
                            },
                          )
                          : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onChanged: (value) {
                  setState(() {
                    _handler.setSearchQuery(value);
                  });
                },
              ),
            ),
          Expanded(
            child:
                _bookmarks.isEmpty
                    ? Center(
                      child: Text(
                        _handler.searchQuery.isNotEmpty
                            ? 'No results found for "${_handler.searchQuery}"'
                            : 'No bookmarks saved',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    )
                    : ListView.builder(
                      itemCount: _bookmarks.length,
                      itemBuilder: (context, index) {
                        final bookmark = _bookmarks[index];
                        return _buildBookmarkCard(bookmark);
                      },
                    ),
          ),
        ],
      ),
    );
  }

  Widget _buildBookmarkCard(Bookmark bookmark) {
    final uri = Uri.tryParse(bookmark.url);
    final date = DateTime.parse(bookmark.timestamp);
    final formattedDate = DateFormat("dd/MM/yyyy - HH:mm").format(date);

    return Dismissible(
      key: ValueKey(bookmark.id),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Theme.of(context).colorScheme.error,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: Icon(
          Icons.delete_rounded,
          color: Theme.of(context).colorScheme.onError,
          size: 28,
        ),
      ),
      confirmDismiss: (direction) async {
        final result = await showDeleteConfirmationDialog(
          context: context,
          title: 'Delete Bookmark',
          message:
              'Are you sure you want to delete this bookmark?\n${bookmark.title}',
          confirmText: 'Delete',
          confirmColor: Theme.of(context).colorScheme.error,
        );
        return result ?? false;
      },
      onDismissed: (direction) {
        _deleteBookmark(bookmark);
      },
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        leading: SizedBox(
          width: 40,
          height: 40,
          child: Align(
            alignment: Alignment.center,
            child:
                uri != null
                    ? ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        color: Theme.of(context).colorScheme.surfaceContainer,
                        child: Image.network(
                          'https://www.google.com/s2/favicons?domain=${uri.host}&sz=64',
                          width: 32,
                          height: 32,
                          errorBuilder: (_, __, ___) => _buildFallbackIcon(),
                        ),
                      ),
                    )
                    : _buildFallbackIcon(),
          ),
        ),
        title: Text(
          bookmark.title,
          style: TextStyle(
            fontSize: 16,
            color:
                bookmark.hidden
                    ? Theme.of(context).colorScheme.onSurface.withAlpha(127)
                    : Theme.of(context).colorScheme.onSurface,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Text(
              bookmark.url,
              style: TextStyle(
                fontSize: 12,
                color:
                    bookmark.hidden
                        ? Theme.of(context).colorScheme.onSurface.withAlpha(76)
                        : Theme.of(
                          context,
                        ).colorScheme.onSurface.withAlpha(150),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  formattedDate,
                  style: TextStyle(
                    fontSize: 11,
                    color:
                        bookmark.hidden
                            ? Theme.of(
                              context,
                            ).colorScheme.onSurface.withAlpha(76)
                            : Theme.of(
                              context,
                            ).colorScheme.onSurface.withAlpha(150),
                  ),
                ),
                FutureBuilder<List<String>>(
                  future: DatabaseService().bookmarkService.getTagsByBookmarkId(
                    bookmark.id!,
                  ),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return const SizedBox.shrink();
                    }

                    final tags = snapshot.data!;
                    if (tags.isEmpty) {
                      return const SizedBox.shrink();
                    }

                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Text(
                            '|',
                            style: TextStyle(color: Colors.grey, fontSize: 10),
                          ),
                        ),
                        SizedBox(
                          height: 18,
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children:
                                  tags.map((tag) {
                                    final isHiddenTag = tag == 'hidden';
                                    return Padding(
                                      padding: const EdgeInsets.only(right: 4),
                                      child: Text(
                                        '#$tag',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color:
                                              isHiddenTag
                                                  ? Theme.of(
                                                    context,
                                                  ).colorScheme.error
                                                  : Theme.of(
                                                    context,
                                                  ).colorScheme.primary,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    );
                                  }).toList(),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ],
        ),
        onTap: () {
          if (uri != null) launchUrl(uri);
        },
        onLongPress: () => _showEditDialog(bookmark),
      ),
    );
  }
}
