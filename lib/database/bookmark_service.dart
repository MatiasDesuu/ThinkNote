import 'dart:async';
import 'dart:convert';
import 'models/bookmark.dart';
import 'models/bookmark_tag.dart';
import 'database_helper.dart';

class BookmarkService {
  final DatabaseHelper _dbHelper;
  final StreamController<void> _changeController =
      StreamController<void>.broadcast();
  bool _isInitialized = false;

  Stream<void> get onChange => _changeController.stream;

  BookmarkService(this._dbHelper) {
    _ensureInitialized();
  }

  Future<void> _ensureInitialized() async {
    if (!_isInitialized) {
      await _initializeTables();
      _isInitialized = true;
    }
  }

  Future<void> _initializeTables() async {
    final db = await _dbHelper.database;

    // Verificar si las tablas existen
    final tables = db.select('''
      SELECT name FROM sqlite_master 
      WHERE type='table' AND name IN ('bookmarks', 'bookmarks_tags', 'bookmarks_tag_url_patterns')
    ''');

    // Si no existen todas las tablas, crearlas
    if (tables.length < 3) {
      // Crear tablas si no existen
      db.execute('''
        CREATE TABLE IF NOT EXISTS bookmarks (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          title TEXT NOT NULL,
          url TEXT NOT NULL,
          description TEXT,
          timestamp TEXT NOT NULL,
          hidden INTEGER DEFAULT 0,
          tag_ids TEXT DEFAULT '[]'
        )
      ''');

      db.execute('''
        CREATE TABLE IF NOT EXISTS bookmarks_tags (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          tag TEXT NOT NULL UNIQUE
        )
      ''');

      db.execute('''
        CREATE TABLE IF NOT EXISTS bookmarks_tag_url_patterns (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          url_pattern TEXT NOT NULL,
          tag TEXT NOT NULL,
          UNIQUE(url_pattern, tag)
        )
      ''');
    }
  }

  // Método para eliminar la tabla bookmark_tag_mappings
  Future<void> removeBookmarkTagMappingsTable() async {
    final db = await _dbHelper.database;

    // Iniciar transacción
    db.execute('BEGIN TRANSACTION;');

    try {
      // Verificar si la tabla existe
      final tables = db.select(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='bookmark_tag_mappings'",
      );

      if (tables.isNotEmpty) {
        // Eliminar la tabla
        db.execute('DROP TABLE bookmark_tag_mappings;');
      }

      // Confirmar transacción
      db.execute('COMMIT;');
    } catch (e) {
      // Si hay algún error, revertir la transacción
      db.execute('ROLLBACK;');
      print('Error removing bookmark_tag_mappings table: $e');
    }
  }

  // Bookmark operations
  Future<List<Bookmark>> getAllBookmarks() async {
    await _ensureInitialized();
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = db.select(
      'SELECT * FROM bookmarks',
    );

    return maps.map((map) {
      final tagIds = List<int>.from(
        json.decode(map['tag_ids'] as String? ?? '[]'),
      );
      return Bookmark.fromMap({
        'id': map['id'],
        'title': map['title'],
        'url': map['url'],
        'description': map['description'],
        'timestamp': map['timestamp'],
        'hidden': map['hidden'],
        'tag_ids': tagIds,
      });
    }).toList();
  }

  Future<List<Bookmark>> getVisibleBookmarks() async {
    await _ensureInitialized();
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = db.select(
      'SELECT * FROM bookmarks WHERE hidden = 0',
    );

    return maps.map((map) {
      final tagIds = List<int>.from(
        json.decode(map['tag_ids'] as String? ?? '[]'),
      );
      return Bookmark.fromMap({
        'id': map['id'],
        'title': map['title'],
        'url': map['url'],
        'description': map['description'],
        'timestamp': map['timestamp'],
        'hidden': map['hidden'],
        'tag_ids': tagIds,
      });
    }).toList();
  }

  Future<List<Bookmark>> getHiddenBookmarks() async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = db.select(
      'SELECT * FROM bookmarks WHERE hidden = 1',
    );

    return maps
        .map(
          (map) => Bookmark.fromMap({
            'id': map['id'],
            'title': map['title'],
            'url': map['url'],
            'description': map['description'],
            'timestamp': map['timestamp'],
            'hidden': map['hidden'],
            'tag_ids': List<int>.from(
              json.decode(map['tag_ids'] as String? ?? '[]'),
            ),
          }),
        )
        .toList();
  }

  Future<Bookmark?> getBookmarkByUrl(String url) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = db.select(
      'SELECT * FROM bookmarks WHERE url = ?',
      [url],
    );

    if (maps.isEmpty) return null;

    final map = maps.first;
    final tagIds = List<int>.from(
      json.decode(map['tag_ids'] as String? ?? '[]'),
    );
    return Bookmark.fromMap({
      'id': map['id'],
      'title': map['title'],
      'url': map['url'],
      'description': map['description'],
      'timestamp': map['timestamp'],
      'hidden': map['hidden'],
      'tag_ids': tagIds,
    });
  }

  Future<int> createBookmark(Bookmark bookmark) async {
    final db = await _dbHelper.database;
    final stmt = db.prepare('''
      INSERT INTO bookmarks (
        title,
        url,
        description,
        timestamp,
        hidden,
        tag_ids
      ) VALUES (?, ?, ?, ?, ?, ?)
    ''');

    try {
      stmt.execute([
        bookmark.title,
        bookmark.url,
        bookmark.description,
        bookmark.timestamp,
        bookmark.hidden ? 1 : 0,
        jsonEncode(bookmark.tagIds),
      ]);
      DatabaseHelper.notifyDatabaseChanged();
      return db.lastInsertRowId;
    } finally {
      stmt.dispose();
    }
  }

  Future<int> updateBookmark(Bookmark bookmark) async {
    final db = await _dbHelper.database;
    final stmt = db.prepare('''
      UPDATE bookmarks
      SET title = ?,
          url = ?,
          description = ?,
          hidden = ?,
          tag_ids = ?
      WHERE id = ?
    ''');

    try {
      stmt.execute([
        bookmark.title,
        bookmark.url,
        bookmark.description,
        bookmark.hidden ? 1 : 0,
        jsonEncode(bookmark.tagIds),
        bookmark.id,
      ]);
      DatabaseHelper.notifyDatabaseChanged();
      return 1;
    } finally {
      stmt.dispose();
    }
  }

  Future<int> deleteBookmark(int id) async {
    final db = await _dbHelper.database;
    final stmt = db.prepare('''
      DELETE FROM bookmarks
      WHERE id = ?
    ''');

    try {
      stmt.execute([id]);
      DatabaseHelper.notifyDatabaseChanged();
      return 1;
    } finally {
      stmt.dispose();
    }
  }

  Future<void> toggleBookmarkVisibility(int id) async {
    final db = await _dbHelper.database;
    final bookmark = db.select('SELECT * FROM bookmarks WHERE id = ?', [id]);
    if (bookmark.isNotEmpty) {
      final currentHidden = bookmark.first['hidden'] == 1;
      db.execute('UPDATE bookmarks SET hidden = ? WHERE id = ?', [
        currentHidden ? 0 : 1,
        id,
      ]);
      _changeController.add(null);
    }
  }

  // Tags operations
  Future<List<BookmarkTag>> getAllTags() async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = db.select(
      'SELECT * FROM bookmarks_tags',
    );

    return maps
        .map((map) => BookmarkTag.fromMap({'id': map['id'], 'tag': map['tag']}))
        .toList();
  }

  Future<List<String>> getAllTagNames() async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = db.select(
      'SELECT tag FROM bookmarks_tags',
    );

    return maps.map((map) => map['tag'] as String).toList();
  }

  Future<int> createTag(BookmarkTag tag) async {
    final db = await _dbHelper.database;
    final stmt = db.prepare('''
      INSERT INTO bookmarks_tags (tag)
      VALUES (?)
    ''');

    try {
      stmt.execute([tag.tag]);
      DatabaseHelper.notifyDatabaseChanged();
      return db.lastInsertRowId;
    } finally {
      stmt.dispose();
    }
  }

  Future<int> deleteTag(int id) async {
    final db = await _dbHelper.database;
    final stmt = db.prepare('''
      DELETE FROM bookmarks_tags
      WHERE id = ?
    ''');

    try {
      stmt.execute([id]);
      DatabaseHelper.notifyDatabaseChanged();
      return 1;
    } finally {
      stmt.dispose();
    }
  }

  // Tag mappings
  Future<List<String>> getTagsByBookmarkId(int bookmarkId) async {
    final db = await _dbHelper.database;
    final bookmark = db.select(
      '''
      SELECT GROUP_CONCAT(t.tag) as tags
      FROM bookmarks b
      LEFT JOIN bookmarks_tags t ON t.id IN (
        SELECT value FROM json_each(b.tag_ids)
      )
      WHERE b.id = ?
      GROUP BY b.id
    ''',
      [bookmarkId],
    );

    if (bookmark.isEmpty || bookmark.first['tags'] == null) return [];

    return (bookmark.first['tags'] as String).split(',');
  }

  Future<List<Bookmark>> getBookmarksByTag(String tag) async {
    final db = await _dbHelper.database;

    // Primero obtener el ID del tag
    final tagRecord = db.select('SELECT id FROM bookmarks_tags WHERE tag = ?', [
      tag,
    ]);
    if (tagRecord.isEmpty) return [];

    final tagId = tagRecord.first['id'] as int;

    // Buscar bookmarks que contengan este tag_id
    final List<Map<String, dynamic>> maps = db.select(
      'SELECT * FROM bookmarks WHERE json_each.value = ?',
      [tagId],
    );

    return maps.map((map) {
      final tagIds = List<int>.from(
        json.decode(map['tag_ids'] as String? ?? '[]'),
      );
      return Bookmark.fromMap({
        'id': map['id'],
        'title': map['title'],
        'url': map['url'],
        'description': map['description'],
        'timestamp': map['timestamp'],
        'hidden': map['hidden'],
        'tag_ids': tagIds,
      });
    }).toList();
  }

  Future<void> updateBookmarkTags(int bookmarkId, List<String> newTags) async {
    final db = await _dbHelper.database;

    // Crear los nuevos tags y obtener sus IDs
    final tagIds = <int>[];
    for (final tag in newTags) {
      // Primero verificar si el tag ya existe
      final existingTag = db.select(
        'SELECT id FROM bookmarks_tags WHERE tag = ?',
        [tag],
      );

      int tagId;
      if (existingTag.isNotEmpty) {
        // Si el tag existe, usar su ID
        tagId = existingTag.first['id'] as int;
      } else {
        // Si el tag no existe, crearlo
        final stmt = db.prepare('''
          INSERT INTO bookmarks_tags (tag)
          VALUES (?)
        ''');
        try {
          stmt.execute([tag]);
          tagId = db.lastInsertRowId;
        } finally {
          stmt.dispose();
        }
      }
      tagIds.add(tagId);
    }

    // Actualizar el bookmark con los nuevos tag_ids
    db.execute('UPDATE bookmarks SET tag_ids = ? WHERE id = ?', [
      json.encode(tagIds),
      bookmarkId,
    ]);

    // Limpiar tags huérfanos
    db.execute('''
      DELETE FROM bookmarks_tags 
      WHERE id NOT IN (
        SELECT DISTINCT json_each.value
        FROM bookmarks, json_each(bookmarks.tag_ids)
      )
    ''');

    _changeController.add(null);
  }

  // URL Pattern Tag operations
  Future<List<TagUrlPattern>> getAllTagUrlPatterns() async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = db.select(
      'SELECT * FROM bookmarks_tag_url_patterns',
    );

    return maps
        .map(
          (map) => TagUrlPattern.fromMap({
            'id': map['id'],
            'url_pattern': map['url_pattern'],
            'tag': map['tag'],
          }),
        )
        .toList();
  }

  Future<int> createTagUrlPattern(String urlPattern, String tag) async {
    final db = await _dbHelper.database;

    // Verificar si ya existe un patrón con la misma URL y tag
    final existingPattern = db.select(
      'SELECT id FROM bookmarks_tag_url_patterns WHERE url_pattern = ? AND tag = ?',
      [urlPattern, tag],
    );

    if (existingPattern.isNotEmpty) {
      throw Exception('A tag pattern with this URL and tag already exists.');
    }

    final stmt = db.prepare('''
      INSERT INTO bookmarks_tag_url_patterns (url_pattern, tag)
      VALUES (?, ?)
    ''');

    try {
      stmt.execute([urlPattern, tag]);
      DatabaseHelper.notifyDatabaseChanged();
      return db.lastInsertRowId;
    } catch (e) {
      // Si es un error de constraint UNIQUE, mostrar un mensaje más amigable
      if (e.toString().contains('UNIQUE constraint failed')) {
        throw Exception('A tag pattern with this URL and tag already exists.');
      }
      rethrow;
    } finally {
      stmt.dispose();
    }
  }

  Future<int> deleteTagUrlPattern(int id) async {
    final db = await _dbHelper.database;
    final stmt = db.prepare('''
      DELETE FROM bookmarks_tag_url_patterns
      WHERE id = ?
    ''');

    try {
      stmt.execute([id]);
      DatabaseHelper.notifyDatabaseChanged();
      return 1;
    } finally {
      stmt.dispose();
    }
  }

  Future<List<String>> getTagsForUrl(String url) async {
    final patterns = await getAllTagUrlPatterns();
    final matchingTags = <String>[];

    for (final pattern in patterns) {
      if (url.contains(pattern.urlPattern)) {
        matchingTags.add(pattern.tag);
      }
    }

    return matchingTags;
  }

  Future<List<Bookmark>> getAllBookmarksWithTags() async {
    final db = await _dbHelper.database;

    // Obtener todos los bookmarks con sus tags en una sola consulta usando JOIN
    final List<Map<String, dynamic>> maps = db.select('''
      SELECT 
        b.*,
        GROUP_CONCAT(t.tag) as tags
      FROM bookmarks b
      LEFT JOIN bookmarks_tags t ON t.id IN (
        SELECT value FROM json_each(b.tag_ids)
      )
      GROUP BY b.id
    ''');

    return maps.map((map) {
      final tagIds = List<int>.from(
        json.decode(map['tag_ids'] as String? ?? '[]'),
      );

      return Bookmark.fromMap({
        'id': map['id'],
        'title': map['title'],
        'url': map['url'],
        'description': map['description'],
        'timestamp': map['timestamp'],
        'hidden': map['hidden'],
        'tag_ids': tagIds,
        'tags': map['tags'],
      });
    }).toList();
  }

  // Cleanup
  void dispose() {
    _changeController.close();
  }
}
