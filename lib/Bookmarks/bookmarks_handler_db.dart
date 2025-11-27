import '../database/database_service.dart';
import '../database/models/bookmark.dart';

class LinksHandlerDB {
  static final LinksHandlerDB _instance = LinksHandlerDB._internal();
  factory LinksHandlerDB() => _instance;
  LinksHandlerDB._internal();

  // Constant for hidden tag
  static const String hiddenTag = 'hidden';

  final DatabaseService _databaseService = DatabaseService();
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
            // Simple check without async/await - we'll pre-load tags separately
            return title.contains(query) || url.contains(query);
            // Tag filtering will be handled separately with async/await
          }).toList();
    }

    // Apply tag filter
    if (_selectedTag != null) {
      // Si se selecciona el tag 'hidden', mostrar solo los bookmarks con ese tag
      if (_selectedTag == hiddenTag) {
        // No filtramos nada más, ya que queremos mostrar todos los hidden
        // El filtrado real de hidden se hace por tags en getFilteredBookmarks()
      } else {
        // Para cualquier otro tag, excluir los bookmarks hidden a menos que estemos en el filtro hidden
        filtered = filtered.where((bookmark) => !bookmark.hidden).toList();
        // El filtrado por tag específico se hace en getFilteredBookmarks()
      }
    } else {
      // Si no hay tag seleccionado, excluir los bookmarks hidden
      filtered = filtered.where((bookmark) => !bookmark.hidden).toList();
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

  void setSelectedTag(String? tag) {
    _selectedTag = tag;
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

  void resetSearch() {
    _isSearching = false;
    _searchQuery = '';
  }

  Future<void> loadBookmarks() async {
    try {
      // Cargar todos los bookmarks con sus tags en una sola consulta
      _bookmarks =
          await _databaseService.bookmarkService.getAllBookmarksWithTags();

      // Obtener todos los tags únicos de los bookmarks
      final Set<String> activeTags = {};
      for (final bookmark in _bookmarks) {
        if (bookmark.id != null) {
          final tags = await _databaseService.bookmarkService
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

  Future<void> addBookmark({
    required String title,
    required String url,
    String description = '',
    List<String> tags = const [],
  }) async {
    List<String> finalTags = List.from(tags);
    if (finalTags.isEmpty) {
      final predefinedTags = await _databaseService.bookmarkService
          .getTagsForUrl(url);
      finalTags.addAll(predefinedTags);
    }

    final bookmark = Bookmark(
      title: title,
      url: url,
      description: description,
      timestamp: DateTime.now().toIso8601String(),
      hidden: false,
      tagIds: [],
    );

    try {
      final bookmarkId = await _databaseService.bookmarkService.createBookmark(
        bookmark,
      );
      await _databaseService.bookmarkService.updateBookmarkTags(
        bookmarkId,
        finalTags,
      );

      await loadBookmarks();
    } catch (e) {
      print('Error adding bookmark: $e');
      rethrow;
    }
  }

  Future<void> removeBookmark(int id) async {
    try {
      await _databaseService.bookmarkService.deleteBookmark(id);
      await loadBookmarks();
    } catch (e) {
      print('Error removing bookmark: $e');
      rethrow;
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
      final bookmark = _bookmarks.firstWhere((b) => b.id == id);

      final updatedBookmark = bookmark.copyWith(
        title: newTitle,
        url: newUrl,
        description: newDescription,
        timestamp: DateTime.now().toIso8601String(),
      );

      await _databaseService.bookmarkService.updateBookmark(updatedBookmark);
      await _databaseService.bookmarkService.updateBookmarkTags(id, newTags);

      await loadBookmarks();
    } catch (e) {
      print('Error updating bookmark: $e');
      rethrow;
    }
  }

  bool isBookmarkHidden(Bookmark bookmark) {
    return bookmark.hidden;
  }

  Future<void> toggleBookmarkVisibility(int id) async {
    await _databaseService.bookmarkService.toggleBookmarkVisibility(id);
    await loadBookmarks();
  }

  Future<List<Bookmark>> getFilteredBookmarks() async {
    await loadBookmarks();
    var filtered = filteredBookmarks;

    // Aplicar filtrado por tag si es necesario
    if (_selectedTag != null) {
      final List<Bookmark> tagFiltered = [];

      for (final bookmark in filtered) {
        if (bookmark.id != null) {
          final tags = await _databaseService.bookmarkService
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
          final tags = await _databaseService.bookmarkService
              .getTagsByBookmarkId(bookmark.id!);
          if (!tags.contains(hiddenTag)) {
            nonHiddenBookmarks.add(bookmark);
          }
        }
      }

      filtered = nonHiddenBookmarks;
    }

    // Aplicar filtrado por búsqueda si es necesario
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      final List<Bookmark> searchTagFiltered = [];

      for (final bookmark in _bookmarks) {
        if (bookmark.id != null) {
          final tags = await _databaseService.bookmarkService
              .getTagsByBookmarkId(bookmark.id!);

          // Si encuentra tags que coinciden con la búsqueda
          if (tags.any((tag) => tag.toLowerCase().contains(query))) {
            // Si estamos mostrando hidden, o el bookmark no es hidden
            if (_selectedTag == hiddenTag || !tags.contains(hiddenTag)) {
              // Si no está ya en la lista filtrada
              if (!filtered.any((b) => b.id == bookmark.id)) {
                searchTagFiltered.add(bookmark);
              }
            }
          }
        }
      }

      // Agregar los resultados de búsqueda a la lista filtrada (evitando duplicados)
      for (final bookmark in searchTagFiltered) {
        if (!filtered.any((b) => b.id == bookmark.id)) {
          filtered.add(bookmark);
        }
      }
    }

    return filtered;
  }
}
