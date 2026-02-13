import 'dart:async';
import '../database/database_service.dart';
import '../database/models/bookmark.dart';

class LinksHandlerDB {
  static final LinksHandlerDB _instance = LinksHandlerDB._internal();
  factory LinksHandlerDB() => _instance;
  LinksHandlerDB._internal();

  static const String hiddenTag = 'hidden';
  static const String untaggedTag = 'untagged_filter';

  final DatabaseService _databaseService = DatabaseService();
  List<Bookmark> _bookmarks = [];
  List<String> _allTags = [];

  String? _selectedTag;
  bool _isOldestFirst = false;
  bool _isSearching = false;
  String _searchQuery = '';

  List<Bookmark> get filteredBookmarks {
    var filtered = List<Bookmark>.from(_bookmarks);

    if (_selectedTag != null) {
      if (_selectedTag == hiddenTag) {
        filtered = filtered.where((b) => b.tags.contains(hiddenTag)).toList();
      } else if (_selectedTag == untaggedTag) {
        filtered = filtered.where((b) => b.tags.isEmpty).toList();
      } else {
        filtered =
            filtered
                .where(
                  (b) =>
                      b.tags.contains(_selectedTag) &&
                      !b.tags.contains(hiddenTag),
                )
                .toList();
      }
    } else {
      filtered =
          filtered
              .where((b) => !b.hidden && !b.tags.contains(hiddenTag))
              .toList();
    }

    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered =
          filtered.where((bookmark) {
            final title = bookmark.title.toLowerCase();
            final url = bookmark.url.toLowerCase();
            final tagsMatch = bookmark.tags.any(
              (tag) => tag.toLowerCase().contains(query),
            );

            return title.contains(query) || url.contains(query) || tagsMatch;
          }).toList();
    }

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

  bool _isLoadingBookmarks = false;
  Completer<void>? _loadCompleter;

  Future<void> loadBookmarks() async {
    if (_isLoadingBookmarks) {
      return _loadCompleter?.future;
    }

    _isLoadingBookmarks = true;
    _loadCompleter = Completer<void>();

    try {
      _bookmarks =
          await _databaseService.bookmarkService.getAllBookmarksWithTags();

      final Set<String> activeTags = {};
      for (final bookmark in _bookmarks) {
        activeTags.addAll(bookmark.tags);
      }

      _allTags = activeTags.toList()..sort();

      if (_allTags.contains(hiddenTag)) {
        _allTags.remove(hiddenTag);
        _allTags.add(hiddenTag);
      }
      _loadCompleter?.complete();
    } catch (e) {
      print('Error loading bookmarks: $e');
      _bookmarks = [];
      _allTags = [];
      _loadCompleter?.completeError(e);
    } finally {
      _isLoadingBookmarks = false;
      _loadCompleter = null;
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
    return filteredBookmarks;
  }
}
