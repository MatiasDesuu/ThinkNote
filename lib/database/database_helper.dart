import 'package:sqlite3/sqlite3.dart' as sqlite;
import 'package:sqlite3_flutter_libs/sqlite3_flutter_libs.dart';
import 'database_config.dart' as config;
import 'dart:developer' as developer;
import 'dart:async';
import 'dart:io';
import 'package:path/path.dart' as path;

class DatabaseHelper {
  static sqlite.Database? _database;
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static bool _isDisposed = false;
  static final List<sqlite.Database> _activeConnections = [];

  static final _onDatabaseChanged = StreamController<void>.broadcast();
  static Stream<void> get onDatabaseChanged => _onDatabaseChanged.stream;

  factory DatabaseHelper() => _instance;

  DatabaseHelper._internal();

  static void notifyDatabaseChanged() {
    _onDatabaseChanged.add(null);
  }

  Future<sqlite.Database> get database async {
    if (_isDisposed) {
      _isDisposed = false;
      _database = null;
    }
    if (_database != null) return _database!;
    _database = await _initDatabase();
    _activeConnections.add(_database!);
    return _database!;
  }

  Future<sqlite.Database> _initDatabase() async {
    try {
      final String dbPath = await config.DatabaseConfig.databasePath;

      final dbDir = path.dirname(dbPath);
      await Directory(dbDir).create(recursive: true);

      if (Platform.isAndroid) {
        await applyWorkaroundToOpenSqlite3OnOldAndroidVersions();
      }

      final db = sqlite.sqlite3.open(dbPath);

      db.execute('PRAGMA foreign_keys = ON;');

      _createTables(db);

      _runMigrations(db);

      return db;
    } catch (e) {
      developer.log('Error initializing database: $e', name: 'DatabaseHelper');
      rethrow;
    }
  }

  void _createTables(sqlite.Database db) {
    db.execute('''
      CREATE TABLE IF NOT EXISTS sync_info (
        id INTEGER PRIMARY KEY,
        last_modified INTEGER NOT NULL
      )
    ''');

    final syncInfoExists = db.select('SELECT 1 FROM sync_info LIMIT 1');
    if (syncInfoExists.isEmpty) {
      db.execute('INSERT INTO sync_info (id, last_modified) VALUES (1, ?)', [
        DateTime.now().millisecondsSinceEpoch,
      ]);
    }

    db.execute('''
      CREATE TABLE IF NOT EXISTS ${config.DatabaseConfig.tableNotebooks} (
        ${config.DatabaseConfig.columnId} INTEGER PRIMARY KEY AUTOINCREMENT,
        ${config.DatabaseConfig.columnName} TEXT NOT NULL,
        ${config.DatabaseConfig.columnParentId} INTEGER,
        ${config.DatabaseConfig.columnCreatedAt} INTEGER NOT NULL,
        ${config.DatabaseConfig.columnOrderIndex} INTEGER NOT NULL DEFAULT 0,
        ${config.DatabaseConfig.columnDeletedAt} INTEGER,
        ${config.DatabaseConfig.columnIsFavorite} INTEGER NOT NULL DEFAULT 0,
        ${config.DatabaseConfig.columnIconId} INTEGER,
        FOREIGN KEY (${config.DatabaseConfig.columnParentId}) REFERENCES ${config.DatabaseConfig.tableNotebooks} (${config.DatabaseConfig.columnId})
      )
    ''');

    db.execute('''
      CREATE TABLE IF NOT EXISTS ${config.DatabaseConfig.tableNotes} (
        ${config.DatabaseConfig.columnId} INTEGER PRIMARY KEY AUTOINCREMENT,
        ${config.DatabaseConfig.columnTitle} TEXT NOT NULL,
        ${config.DatabaseConfig.columnContent} TEXT NOT NULL,
        ${config.DatabaseConfig.columnNotebookId} INTEGER NOT NULL,
        ${config.DatabaseConfig.columnCreatedAt} INTEGER NOT NULL,
        ${config.DatabaseConfig.columnUpdatedAt} INTEGER NOT NULL,
        ${config.DatabaseConfig.columnDeletedAt} INTEGER,
        ${config.DatabaseConfig.columnIsFavorite} INTEGER NOT NULL DEFAULT 0,
        ${config.DatabaseConfig.columnTags} TEXT,
        ${config.DatabaseConfig.columnOrderNoteIndex} INTEGER NOT NULL DEFAULT 0,
        ${config.DatabaseConfig.columnIsTask} INTEGER NOT NULL DEFAULT 0,
        ${config.DatabaseConfig.columnIsCompleted} INTEGER NOT NULL DEFAULT 0,
        ${config.DatabaseConfig.columnNoteIsPinned} INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (${config.DatabaseConfig.columnNotebookId}) REFERENCES ${config.DatabaseConfig.tableNotebooks} (${config.DatabaseConfig.columnId})
      )
    ''');

    db.execute('''
      CREATE TABLE IF NOT EXISTS ${config.DatabaseConfig.tableThinks} (
        ${config.DatabaseConfig.columnId} INTEGER PRIMARY KEY AUTOINCREMENT,
        ${config.DatabaseConfig.columnTitle} TEXT NOT NULL,
        ${config.DatabaseConfig.columnContent} TEXT NOT NULL,
        ${config.DatabaseConfig.columnCreatedAt} INTEGER NOT NULL,
        ${config.DatabaseConfig.columnUpdatedAt} INTEGER NOT NULL,
        ${config.DatabaseConfig.columnDeletedAt} INTEGER,
        ${config.DatabaseConfig.columnIsFavorite} INTEGER NOT NULL DEFAULT 0,
        ${config.DatabaseConfig.columnTags} TEXT,
        ${config.DatabaseConfig.columnOrderIndex} INTEGER NOT NULL DEFAULT 0
      )
    ''');

    db.execute('''
      CREATE TABLE IF NOT EXISTS ${config.DatabaseConfig.tableTasks} (
        ${config.DatabaseConfig.columnId} INTEGER PRIMARY KEY AUTOINCREMENT,
        ${config.DatabaseConfig.columnTaskName} TEXT NOT NULL,
        ${config.DatabaseConfig.columnTaskDate} TEXT,
        ${config.DatabaseConfig.columnTaskCompleted} INTEGER NOT NULL DEFAULT 0,
        ${config.DatabaseConfig.columnTaskState} INTEGER NOT NULL DEFAULT 0,
        ${config.DatabaseConfig.columnCreatedAt} TEXT NOT NULL,
        ${config.DatabaseConfig.columnUpdatedAt} TEXT NOT NULL,
        ${config.DatabaseConfig.columnDeletedAt} TEXT,
        ${config.DatabaseConfig.columnOrderIndex} INTEGER NOT NULL DEFAULT 0,
        ${config.DatabaseConfig.columnTaskSortByPriority} INTEGER NOT NULL DEFAULT 0,
        ${config.DatabaseConfig.columnTaskIsPinned} INTEGER NOT NULL DEFAULT 0
      )
    ''');

    db.execute('''
      CREATE TABLE IF NOT EXISTS ${config.DatabaseConfig.tableSubtasks} (
        ${config.DatabaseConfig.columnId} INTEGER PRIMARY KEY AUTOINCREMENT,
        ${config.DatabaseConfig.columnTaskId} INTEGER NOT NULL,
        ${config.DatabaseConfig.columnSubtaskText} TEXT NOT NULL,
        ${config.DatabaseConfig.columnSubtaskCompleted} INTEGER NOT NULL DEFAULT 0,
        ${config.DatabaseConfig.columnSubtaskPriority} INTEGER NOT NULL DEFAULT 1,
        ${config.DatabaseConfig.columnOrderIndex} INTEGER NOT NULL DEFAULT 0,
        ${config.DatabaseConfig.columnParentId} INTEGER,
        FOREIGN KEY (${config.DatabaseConfig.columnTaskId}) REFERENCES ${config.DatabaseConfig.tableTasks} (${config.DatabaseConfig.columnId}) ON DELETE CASCADE,
        FOREIGN KEY (${config.DatabaseConfig.columnParentId}) REFERENCES ${config.DatabaseConfig.tableSubtasks} (${config.DatabaseConfig.columnId}) ON DELETE CASCADE
      )
    ''');

    db.execute('''
      CREATE TABLE IF NOT EXISTS habit_completions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        subtask_id INTEGER NOT NULL,
        date TEXT NOT NULL,
        UNIQUE(subtask_id, date),
        FOREIGN KEY(subtask_id) REFERENCES ${config.DatabaseConfig.tableSubtasks} (${config.DatabaseConfig.columnId}) ON DELETE CASCADE
      )
    ''');

    db.execute('''
      CREATE TABLE IF NOT EXISTS ${config.DatabaseConfig.tableTaskTags} (
        ${config.DatabaseConfig.columnId} INTEGER PRIMARY KEY AUTOINCREMENT,
        ${config.DatabaseConfig.columnTagName} TEXT NOT NULL,
        ${config.DatabaseConfig.columnTagTaskId} INTEGER,
        FOREIGN KEY (${config.DatabaseConfig.columnTagTaskId}) REFERENCES ${config.DatabaseConfig.tableTasks} (${config.DatabaseConfig.columnId}) ON DELETE CASCADE
      )
    ''');

    db.execute('''
      CREATE TABLE IF NOT EXISTS ${config.DatabaseConfig.tableCalendarEventStatuses} (
        ${config.DatabaseConfig.columnCalendarEventStatusId} INTEGER PRIMARY KEY AUTOINCREMENT,
        ${config.DatabaseConfig.columnCalendarEventStatusName} TEXT NOT NULL,
        ${config.DatabaseConfig.columnCalendarEventStatusColor} TEXT NOT NULL,
        ${config.DatabaseConfig.columnCalendarEventStatusOrderIndex} INTEGER NOT NULL DEFAULT 0
      )
    ''');

      db.execute('''
        CREATE TABLE IF NOT EXISTS ${config.DatabaseConfig.tableCalendarEvents} (
          ${config.DatabaseConfig.columnCalendarEventId} INTEGER PRIMARY KEY AUTOINCREMENT,
          ${config.DatabaseConfig.columnCalendarEventNoteId} INTEGER NOT NULL,
          ${config.DatabaseConfig.columnCalendarEventDate} INTEGER NOT NULL,
          ${config.DatabaseConfig.columnCalendarEventOrderIndex} INTEGER NOT NULL DEFAULT 0,
          ${config.DatabaseConfig.columnCalendarEventStatus} TEXT,
          FOREIGN KEY (${config.DatabaseConfig.columnCalendarEventNoteId}) REFERENCES ${config.DatabaseConfig.tableNotes} (${config.DatabaseConfig.columnId}) ON DELETE CASCADE
        )
      ''');

      db.execute('CREATE INDEX IF NOT EXISTS idx_notes_notebook_id ON ${config.DatabaseConfig.tableNotes}(${config.DatabaseConfig.columnNotebookId});');
      db.execute('CREATE INDEX IF NOT EXISTS idx_notes_deleted_at ON ${config.DatabaseConfig.tableNotes}(${config.DatabaseConfig.columnDeletedAt});');
      db.execute('CREATE INDEX IF NOT EXISTS idx_notebooks_parent_id ON ${config.DatabaseConfig.tableNotebooks}(${config.DatabaseConfig.columnParentId});');
      db.execute('CREATE INDEX IF NOT EXISTS idx_calendar_events_date ON ${config.DatabaseConfig.tableCalendarEvents}(${config.DatabaseConfig.columnCalendarEventDate});');
      db.execute('CREATE INDEX IF NOT EXISTS idx_notes_is_favorite ON ${config.DatabaseConfig.tableNotes}(${config.DatabaseConfig.columnIsFavorite});');
      db.execute('CREATE INDEX IF NOT EXISTS idx_notes_pinned_order ON ${config.DatabaseConfig.tableNotes}(${config.DatabaseConfig.columnNoteIsPinned}, order_index);');

      db.execute('''
        CREATE TABLE IF NOT EXISTS bookmarks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        url TEXT NOT NULL,
        order_index INTEGER NOT NULL DEFAULT 0
      )
    ''');

    db.execute('''
      CREATE TRIGGER IF NOT EXISTS update_last_modified_notes_insert
      AFTER INSERT ON notes
      BEGIN
        UPDATE sync_info SET last_modified = strftime('%s', 'now') * 1000 WHERE id = 1;
      END;
    ''');

    db.execute('''
      CREATE TRIGGER IF NOT EXISTS update_last_modified_notes_update
      AFTER UPDATE ON notes
      BEGIN
        UPDATE sync_info SET last_modified = strftime('%s', 'now') * 1000 WHERE id = 1;
      END;
    ''');

    db.execute('''
      CREATE TRIGGER IF NOT EXISTS update_last_modified_notes_delete
      AFTER DELETE ON notes
      BEGIN
        UPDATE sync_info SET last_modified = strftime('%s', 'now') * 1000 WHERE id = 1;
      END;
    ''');

    db.execute('''
      CREATE TRIGGER IF NOT EXISTS update_last_modified_notebooks_insert
      AFTER INSERT ON notebooks
      BEGIN
        UPDATE sync_info SET last_modified = strftime('%s', 'now') * 1000 WHERE id = 1;
      END;
    ''');

    db.execute('''
      CREATE TRIGGER IF NOT EXISTS update_last_modified_notebooks_update
      AFTER UPDATE ON notebooks
      BEGIN
        UPDATE sync_info SET last_modified = strftime('%s', 'now') * 1000 WHERE id = 1;
      END;
    ''');

    db.execute('''
      CREATE TRIGGER IF NOT EXISTS update_last_modified_notebooks_delete
      AFTER DELETE ON notebooks
      BEGIN
        UPDATE sync_info SET last_modified = strftime('%s', 'now') * 1000 WHERE id = 1;
      END;
    ''');

    db.execute('''
      CREATE TRIGGER IF NOT EXISTS update_last_modified_tasks_insert
      AFTER INSERT ON tasks
      BEGIN
        UPDATE sync_info SET last_modified = strftime('%s', 'now') * 1000 WHERE id = 1;
      END;
    ''');

    db.execute('''
      CREATE TRIGGER IF NOT EXISTS update_last_modified_tasks_update
      AFTER UPDATE ON tasks
      BEGIN
        UPDATE sync_info SET last_modified = strftime('%s', 'now') * 1000 WHERE id = 1;
      END;
    ''');

    db.execute('''
      CREATE TRIGGER IF NOT EXISTS update_last_modified_tasks_delete
      AFTER DELETE ON tasks
      BEGIN
        UPDATE sync_info SET last_modified = strftime('%s', 'now') * 1000 WHERE id = 1;
      END;
    ''');

    db.execute('''
      CREATE TRIGGER IF NOT EXISTS update_last_modified_thinks_insert
      AFTER INSERT ON thinks
      BEGIN
        UPDATE sync_info SET last_modified = strftime('%s', 'now') * 1000 WHERE id = 1;
      END;
    ''');

    db.execute('''
      CREATE TRIGGER IF NOT EXISTS update_last_modified_thinks_update
      AFTER UPDATE ON thinks
      BEGIN
        UPDATE sync_info SET last_modified = strftime('%s', 'now') * 1000 WHERE id = 1;
      END;
    ''');

    db.execute('''
      CREATE TRIGGER IF NOT EXISTS update_last_modified_thinks_delete
      AFTER DELETE ON thinks
      BEGIN
        UPDATE sync_info SET last_modified = strftime('%s', 'now') * 1000 WHERE id = 1;
      END;
    ''');

    db.execute('''
      CREATE TRIGGER IF NOT EXISTS update_last_modified_bookmarks_insert
      AFTER INSERT ON bookmarks
      BEGIN
        UPDATE sync_info SET last_modified = strftime('%s', 'now') * 1000 WHERE id = 1;
      END;
    ''');

    db.execute('''
      CREATE TRIGGER IF NOT EXISTS update_last_modified_bookmarks_update
      AFTER UPDATE ON bookmarks
      BEGIN
        UPDATE sync_info SET last_modified = strftime('%s', 'now') * 1000 WHERE id = 1;
      END;
    ''');

    db.execute('''
      CREATE TRIGGER IF NOT EXISTS update_last_modified_bookmarks_delete
      AFTER DELETE ON bookmarks
      BEGIN
        UPDATE sync_info SET last_modified = strftime('%s', 'now') * 1000 WHERE id = 1;
      END;
    ''');

    db.execute('''
      CREATE TRIGGER IF NOT EXISTS update_last_modified_calendar_events_insert
      AFTER INSERT ON calendar_events
      BEGIN
        UPDATE sync_info SET last_modified = strftime('%s', 'now') * 1000 WHERE id = 1;
      END;
    ''');

    db.execute('''
      CREATE TRIGGER IF NOT EXISTS update_last_modified_calendar_events_update
      AFTER UPDATE ON calendar_events
      BEGIN
        UPDATE sync_info SET last_modified = strftime('%s', 'now') * 1000 WHERE id = 1;
      END;
    ''');

    db.execute('''
      CREATE TRIGGER IF NOT EXISTS update_last_modified_calendar_events_delete
      AFTER DELETE ON calendar_events
      BEGIN
        UPDATE sync_info SET last_modified = strftime('%s', 'now') * 1000 WHERE id = 1;
      END;
    ''');

    db.execute('''
      CREATE TRIGGER IF NOT EXISTS update_last_modified_calendar_event_statuses_insert
      AFTER INSERT ON calendar_event_statuses
      BEGIN
        UPDATE sync_info SET last_modified = strftime('%s', 'now') * 1000 WHERE id = 1;
      END;
    ''');

    db.execute('''
      CREATE TRIGGER IF NOT EXISTS update_last_modified_calendar_event_statuses_update
      AFTER UPDATE ON calendar_event_statuses
      BEGIN
        UPDATE sync_info SET last_modified = strftime('%s', 'now') * 1000 WHERE id = 1;
      END;
    ''');

    db.execute('''
      CREATE TRIGGER IF NOT EXISTS update_last_modified_calendar_event_statuses_delete
      AFTER DELETE ON calendar_event_statuses
      BEGIN
        UPDATE sync_info SET last_modified = strftime('%s', 'now') * 1000 WHERE id = 1;
      END;
    ''');
  }

  void _runMigrations(sqlite.Database db) {
    try {
      try {
        db.execute(
          'ALTER TABLE ${config.DatabaseConfig.tableNotebooks} ADD COLUMN ${config.DatabaseConfig.columnOrderIndex} INTEGER NOT NULL DEFAULT 0;',
        );
      } catch (e) {
        // Ignore if column already exists
      }

      try {
        db.execute(
          'ALTER TABLE ${config.DatabaseConfig.tableNotes} ADD COLUMN ${config.DatabaseConfig.columnOrderNoteIndex} INTEGER NOT NULL DEFAULT 0;',
        );
      } catch (e) {
        // Ignore if column already exists
      }
      try {
        final result = db.select("PRAGMA table_info(bookmarks)");

        final hasDescription = result.any(
          (row) => row['name'] == 'description',
        );
        if (!hasDescription) {
          db.execute('ALTER TABLE bookmarks ADD COLUMN description TEXT;');
        }

        final hasTimestamp = result.any((row) => row['name'] == 'timestamp');
        if (!hasTimestamp) {
          db.execute(
            "ALTER TABLE bookmarks ADD COLUMN timestamp TEXT NOT NULL DEFAULT '';",
          );
        }

        final hasHidden = result.any((row) => row['name'] == 'hidden');
        if (!hasHidden) {
          db.execute(
            'ALTER TABLE bookmarks ADD COLUMN hidden INTEGER NOT NULL DEFAULT 0;',
          );
        }

        final hasTagIds = result.any((row) => row['name'] == 'tag_ids');
        if (!hasTagIds) {
          db.execute(
            "ALTER TABLE bookmarks ADD COLUMN tag_ids TEXT DEFAULT '[]';",
          );
        }
      } catch (e) {
        // Ignore if columns already exist
      }

      try {
        db.execute(
          'ALTER TABLE ${config.DatabaseConfig.tableNotebooks} ADD COLUMN ${config.DatabaseConfig.columnDeletedAt} INTEGER;',
        );
      } catch (e) {
        // Ignore if column already exists
      }

      try {
        db.execute(
          'ALTER TABLE ${config.DatabaseConfig.tableNotebooks} ADD COLUMN ${config.DatabaseConfig.columnIsFavorite} INTEGER NOT NULL DEFAULT 0;',
        );
      } catch (e) {
        // Ignore if column already exists
      }

      try {
        db.execute(
          'ALTER TABLE ${config.DatabaseConfig.tableNotebooks} ADD COLUMN ${config.DatabaseConfig.columnIconId} INTEGER;',
        );
      } catch (e) {
        // Ignore if column already exists
      }

      try {
        db.execute(
          'ALTER TABLE ${config.DatabaseConfig.tableNotes} ADD COLUMN ${config.DatabaseConfig.columnIsTask} INTEGER NOT NULL DEFAULT 0;',
        );
      } catch (e) {
        // Ignore if column already exists
      }

      try {
        db.execute(
          'ALTER TABLE ${config.DatabaseConfig.tableNotes} ADD COLUMN ${config.DatabaseConfig.columnIsCompleted} INTEGER NOT NULL DEFAULT 0;',
        );
      } catch (e) {
        // Ignore if column already exists
      }

      try {
        db.execute(
          'ALTER TABLE ${config.DatabaseConfig.tableNotes} ADD COLUMN ${config.DatabaseConfig.columnNoteIsPinned} INTEGER NOT NULL DEFAULT 0;',
        );
      } catch (e) {
        // Ignore if column already exists
      }

      try {
        final result = db.select('''
          PRAGMA table_info(${config.DatabaseConfig.tableTasks})
        ''');

        final hasIsPinnedColumn = result.any(
          (row) => row['name'] == 'is_pinned',
        );

        if (!hasIsPinnedColumn) {
          db.execute('''
            ALTER TABLE ${config.DatabaseConfig.tableTasks}
            ADD COLUMN ${config.DatabaseConfig.columnTaskIsPinned} INTEGER NOT NULL DEFAULT 0
          ''');
        }
      } catch (e) {
        // Ignore if column already exists
      }

      try {
        final result = db.select(
          'PRAGMA table_info(${config.DatabaseConfig.tableTaskTags})',
        );
        Map<String, Object?>? taskIdRow;
        for (final row in result) {
          if (row['name'] == config.DatabaseConfig.columnTagTaskId) {
            taskIdRow = row as Map<String, Object?>;
            break;
          }
        }

        if (taskIdRow != null) {
          final notnullValue = taskIdRow['notnull'] as int? ?? 0;
          if (notnullValue == 1) {
            db.execute(
              'ALTER TABLE ${config.DatabaseConfig.tableTaskTags} RENAME TO ${config.DatabaseConfig.tableTaskTags}_old;',
            );

            db.execute('''
            CREATE TABLE ${config.DatabaseConfig.tableTaskTags} (
              ${config.DatabaseConfig.columnId} INTEGER PRIMARY KEY AUTOINCREMENT,
              ${config.DatabaseConfig.columnTagName} TEXT NOT NULL,
              ${config.DatabaseConfig.columnTagTaskId} INTEGER,
              FOREIGN KEY (${config.DatabaseConfig.columnTagTaskId}) REFERENCES ${config.DatabaseConfig.tableTasks} (${config.DatabaseConfig.columnId}) ON DELETE CASCADE
            )
          ''');

            db.execute(
              'INSERT INTO ${config.DatabaseConfig.tableTaskTags} (${config.DatabaseConfig.columnTagName}, ${config.DatabaseConfig.columnTagTaskId}) SELECT ${config.DatabaseConfig.columnTagName}, ${config.DatabaseConfig.columnTagTaskId} FROM ${config.DatabaseConfig.tableTaskTags}_old;',
            );

            db.execute(
              'DROP TABLE ${config.DatabaseConfig.tableTaskTags}_old;',
            );
          }
        }
      } catch (e) {
        // Ignore migration errors
      }

      try {
        final result = db.select('''
          PRAGMA table_info(${config.DatabaseConfig.tableCalendarEvents})
        ''');

        final hasStatusColumn = result.any((row) => row['name'] == 'status');

        if (!hasStatusColumn) {
          db.execute('''
            ALTER TABLE ${config.DatabaseConfig.tableCalendarEvents}
            ADD COLUMN ${config.DatabaseConfig.columnCalendarEventStatus} TEXT
          ''');
        }
      } catch (e) {
        // Ignore if column already exists
      }

      try {
        final result = db.select('''
          PRAGMA table_info(${config.DatabaseConfig.tableSubtasks})
        ''');

        final hasParentIdColumn = result.any(
          (row) => row['name'] == config.DatabaseConfig.columnParentId,
        );

        if (!hasParentIdColumn) {
          db.execute('''
            ALTER TABLE ${config.DatabaseConfig.tableSubtasks}
            ADD COLUMN ${config.DatabaseConfig.columnParentId} INTEGER
          ''');
        }
      } catch (e) {
        // Ignore if column already exists
      }

      try {
        db.execute('CREATE INDEX IF NOT EXISTS idx_notes_notebook_id ON ${config.DatabaseConfig.tableNotes}(${config.DatabaseConfig.columnNotebookId});');
        db.execute('CREATE INDEX IF NOT EXISTS idx_notes_deleted_at ON ${config.DatabaseConfig.tableNotes}(${config.DatabaseConfig.columnDeletedAt});');
        db.execute('CREATE INDEX IF NOT EXISTS idx_notebooks_parent_id ON ${config.DatabaseConfig.tableNotebooks}(${config.DatabaseConfig.columnParentId});');
        db.execute('CREATE INDEX IF NOT EXISTS idx_calendar_events_date ON ${config.DatabaseConfig.tableCalendarEvents}(${config.DatabaseConfig.columnCalendarEventDate});');
        db.execute('CREATE INDEX IF NOT EXISTS idx_notes_is_favorite ON ${config.DatabaseConfig.tableNotes}(${config.DatabaseConfig.columnIsFavorite});');
        db.execute('CREATE INDEX IF NOT EXISTS idx_notes_pinned_order ON ${config.DatabaseConfig.tableNotes}(${config.DatabaseConfig.columnNoteIsPinned}, order_index);');
      } catch (e) {
        // Ignore if indexes already exist or fail
      }
    } catch (e) {
      developer.log('Error running migrations: $e', name: 'DatabaseHelper');
      rethrow;
    }
  }

  Future<void> dispose() async {
    try {
      for (final connection in _activeConnections) {
        try {
          connection.dispose();
        } catch (e) {
          developer.log(
            'Error disposing connection: $e',
            name: 'DatabaseHelper',
          );
        }
      }
      _activeConnections.clear();
      _database = null;
      _isDisposed = true;
    } catch (e) {
      developer.log('Error in dispose: $e', name: 'DatabaseHelper');
      rethrow;
    }
  }

  Future<void> resetDatabase() async {
    try {
      final db = await database;

      db.execute('PRAGMA foreign_keys = OFF;');

      db.execute('BEGIN TRANSACTION;');

      try {
        db.execute('DELETE FROM ${config.DatabaseConfig.tableNotes};');
        db.execute('DELETE FROM ${config.DatabaseConfig.tableNotebooks};');
        db.execute('DELETE FROM ${config.DatabaseConfig.tableSubtasks};');
        db.execute('DELETE FROM ${config.DatabaseConfig.tableTaskTags};');
        db.execute('DELETE FROM ${config.DatabaseConfig.tableTasks};');
        db.execute('DELETE FROM ${config.DatabaseConfig.tableThinks};');

        db.execute('DELETE FROM sqlite_sequence WHERE name = ?;', [
          config.DatabaseConfig.tableNotes,
        ]);
        db.execute('DELETE FROM sqlite_sequence WHERE name = ?;', [
          config.DatabaseConfig.tableNotebooks,
        ]);
        db.execute('DELETE FROM sqlite_sequence WHERE name = ?;', [
          config.DatabaseConfig.tableSubtasks,
        ]);
        db.execute('DELETE FROM sqlite_sequence WHERE name = ?;', [
          config.DatabaseConfig.tableTaskTags,
        ]);
        db.execute('DELETE FROM sqlite_sequence WHERE name = ?;', [
          config.DatabaseConfig.tableTasks,
        ]);
        db.execute('DELETE FROM sqlite_sequence WHERE name = ?;', [
          config.DatabaseConfig.tableThinks,
        ]);

        db.execute('COMMIT;');

        await _updateLastModified();
      } catch (e) {
        db.execute('ROLLBACK;');
        rethrow;
      } finally {
        db.execute('PRAGMA foreign_keys = ON;');
      }

      developer.log('Database reset successfully', name: 'DatabaseHelper');
    } catch (e) {
      developer.log('Error resetting database: $e', name: 'DatabaseHelper');
      rethrow;
    }
  }

  Future<void> _updateLastModified() async {
    final db = await database;
    db.execute(
      '''
      UPDATE sync_info
      SET last_modified = ?
      WHERE id = 1
    ''',
      [DateTime.now().millisecondsSinceEpoch],
    );
    notifyDatabaseChanged();
  }

  Future<DateTime> getLastModified() async {
    final db = await database;
    final result = db.select(
      'SELECT last_modified FROM sync_info WHERE id = 1',
    );
    if (result.isEmpty) {
      return DateTime.now();
    }
    return DateTime.fromMillisecondsSinceEpoch(
      result.first['last_modified'] as int,
    );
  }

  Future<void> updateLastModified() async {
    final db = await database;
    db.execute('UPDATE sync_info SET last_modified = ? WHERE id = 1', [
      DateTime.now().millisecondsSinceEpoch,
    ]);
  }

  void notifyNoteChanges() {
    notifyDatabaseChanged();
  }

  void notifyNotebookChanges() {
    notifyDatabaseChanged();
  }

  Future<void> initialize([String? dbPath]) async {
    if (dbPath != null) {
      _database = sqlite.sqlite3.open(dbPath);
      _activeConnections.add(_database!);
    } else {
      await database;
    }
  }

  Future<void> close() async {
    for (var connection in _activeConnections) {
      connection.dispose();
    }
    _activeConnections.clear();
    _database = null;
    _isDisposed = true;
  }
}
