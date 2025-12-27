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

  // Stream controller para notificar cambios
  static final _onDatabaseChanged = StreamController<void>.broadcast();
  static Stream<void> get onDatabaseChanged => _onDatabaseChanged.stream;

  factory DatabaseHelper() => _instance;

  DatabaseHelper._internal();

  // Método para notificar cambios
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

      // Asegurarse de que el directorio existe
      final dbDir = path.dirname(dbPath);
      await Directory(dbDir).create(recursive: true);

      // Inicializar las bibliotecas de SQLite para Android
      if (Platform.isAndroid) {
        await applyWorkaroundToOpenSqlite3OnOldAndroidVersions();
      }

      // Abrir la base de datos
      final db = sqlite.sqlite3.open(dbPath);

      // Habilitar las restricciones de clave foránea
      db.execute('PRAGMA foreign_keys = ON;');

      // Crear tablas si no existen
      _createTables(db);

      // Ejecutar migraciones
      _runMigrations(db);

      return db;
    } catch (e) {
      developer.log('Error initializing database: $e', name: 'DatabaseHelper');
      rethrow;
    }
  }

  void _createTables(sqlite.Database db) {
    // Crear tabla sync_info si no existe
    db.execute('''
      CREATE TABLE IF NOT EXISTS sync_info (
        id INTEGER PRIMARY KEY,
        last_modified INTEGER NOT NULL
      )
    ''');

    // Insertar registro inicial en sync_info si no existe
    final syncInfoExists = db.select('SELECT 1 FROM sync_info LIMIT 1');
    if (syncInfoExists.isEmpty) {
      db.execute('INSERT INTO sync_info (id, last_modified) VALUES (1, ?)', [
        DateTime.now().millisecondsSinceEpoch,
      ]);
    }

    // Tabla notebooks
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

    // Tabla notes
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

    // Tabla thinks
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

    // Tabla tasks
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

    // Tabla subtasks
    db.execute('''
      CREATE TABLE IF NOT EXISTS ${config.DatabaseConfig.tableSubtasks} (
        ${config.DatabaseConfig.columnId} INTEGER PRIMARY KEY AUTOINCREMENT,
        ${config.DatabaseConfig.columnTaskId} INTEGER NOT NULL,
        ${config.DatabaseConfig.columnSubtaskText} TEXT NOT NULL,
        ${config.DatabaseConfig.columnSubtaskCompleted} INTEGER NOT NULL DEFAULT 0,
        ${config.DatabaseConfig.columnSubtaskPriority} INTEGER NOT NULL DEFAULT 1,
        ${config.DatabaseConfig.columnOrderIndex} INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (${config.DatabaseConfig.columnTaskId}) REFERENCES ${config.DatabaseConfig.tableTasks} (${config.DatabaseConfig.columnId}) ON DELETE CASCADE
      )
    ''');

    // Tabla habit_completions: store per-subtask completion dates
    db.execute('''
      CREATE TABLE IF NOT EXISTS habit_completions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        subtask_id INTEGER NOT NULL,
        date TEXT NOT NULL,
        UNIQUE(subtask_id, date),
        FOREIGN KEY(subtask_id) REFERENCES ${config.DatabaseConfig.tableSubtasks} (${config.DatabaseConfig.columnId}) ON DELETE CASCADE
      )
    ''');

    // Tabla task_tags
    // Allow task_id to be nullable so tags can exist globally and be assigned to tasks later.
    db.execute('''
      CREATE TABLE IF NOT EXISTS ${config.DatabaseConfig.tableTaskTags} (
        ${config.DatabaseConfig.columnId} INTEGER PRIMARY KEY AUTOINCREMENT,
        ${config.DatabaseConfig.columnTagName} TEXT NOT NULL,
        ${config.DatabaseConfig.columnTagTaskId} INTEGER,
        FOREIGN KEY (${config.DatabaseConfig.columnTagTaskId}) REFERENCES ${config.DatabaseConfig.tableTasks} (${config.DatabaseConfig.columnId}) ON DELETE CASCADE
      )
    ''');

    // Tabla calendar_event_statuses
    db.execute('''
      CREATE TABLE IF NOT EXISTS ${config.DatabaseConfig.tableCalendarEventStatuses} (
        ${config.DatabaseConfig.columnCalendarEventStatusId} INTEGER PRIMARY KEY AUTOINCREMENT,
        ${config.DatabaseConfig.columnCalendarEventStatusName} TEXT NOT NULL,
        ${config.DatabaseConfig.columnCalendarEventStatusColor} TEXT NOT NULL,
        ${config.DatabaseConfig.columnCalendarEventStatusOrderIndex} INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // Tabla calendar_events
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

    // Tabla bookmarks
    db.execute('''
      CREATE TABLE IF NOT EXISTS bookmarks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        url TEXT NOT NULL,
        order_index INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // Crear triggers para actualizar last_modified automáticamente
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

    // Triggers para notebooks
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

    // Triggers para tasks
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

    // Triggers para thinks
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

    // Triggers para bookmarks
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

    // Triggers para calendar_events
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

    // Triggers para calendar_event_statuses
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
      // Migración para notebooks - order_index
      try {
        db.execute(
          'ALTER TABLE ${config.DatabaseConfig.tableNotebooks} ADD COLUMN ${config.DatabaseConfig.columnOrderIndex} INTEGER NOT NULL DEFAULT 0;',
        );
      } catch (e) {
        // Si la columna ya existe, ignorar el error
      }

      // Migración para notes - order_index
      try {
        db.execute(
          'ALTER TABLE ${config.DatabaseConfig.tableNotes} ADD COLUMN ${config.DatabaseConfig.columnOrderNoteIndex} INTEGER NOT NULL DEFAULT 0;',
        );
      } catch (e) {
        // Si la columna ya existe, ignorar el error
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
          // Add a timestamp column with a safe default to avoid NOT NULL issues on existing rows
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
        // Ignorar si alguna columna ya existe o si la migración falla por compatibilidad
      }

      // Migración para notebooks - deleted_at
      try {
        db.execute(
          'ALTER TABLE ${config.DatabaseConfig.tableNotebooks} ADD COLUMN ${config.DatabaseConfig.columnDeletedAt} INTEGER;',
        );
      } catch (e) {
        // Si la columna ya existe, ignorar el error
      }

      // Migración para notebooks - is_favorite
      try {
        db.execute(
          'ALTER TABLE ${config.DatabaseConfig.tableNotebooks} ADD COLUMN ${config.DatabaseConfig.columnIsFavorite} INTEGER NOT NULL DEFAULT 0;',
        );
      } catch (e) {
        // Si la columna ya existe, ignorar el error
      }

      // Migración para notebooks - icon_id
      try {
        db.execute(
          'ALTER TABLE ${config.DatabaseConfig.tableNotebooks} ADD COLUMN ${config.DatabaseConfig.columnIconId} INTEGER;',
        );
      } catch (e) {
        // Si la columna ya existe, ignorar el error
      }

      // Migración para notes - is_task
      try {
        db.execute(
          'ALTER TABLE ${config.DatabaseConfig.tableNotes} ADD COLUMN ${config.DatabaseConfig.columnIsTask} INTEGER NOT NULL DEFAULT 0;',
        );
      } catch (e) {
        // Si la columna ya existe, ignorar el error
      }

      // Migración para notes - is_completed
      try {
        db.execute(
          'ALTER TABLE ${config.DatabaseConfig.tableNotes} ADD COLUMN ${config.DatabaseConfig.columnIsCompleted} INTEGER NOT NULL DEFAULT 0;',
        );
      } catch (e) {
        // Si la columna ya existe, ignorar el error
      }

      // Migración para notes - is_completed
      try {
        db.execute(
          'ALTER TABLE ${config.DatabaseConfig.tableNotes} ADD COLUMN ${config.DatabaseConfig.columnNoteIsPinned} INTEGER NOT NULL DEFAULT 0;',
        );
      } catch (e) {
        // Si la columna ya existe, ignorar el error
      }

      // Migración para tasks - is_pinned
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
        // Si la columna ya existe, ignorar el error
      }

      // Migración para task_tags - asegurarse que task_id sea nullable
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
            // La columna task_id existe pero es NOT NULL en una versión previa de la DB.
            // Recreate the table to allow NULL task_id (can't alter nullability directly).
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
        // If anything fails here, ignore to avoid blocking startup on older DBs
      }

      // Migración para calendar_events - status
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
        // Si la columna ya existe, ignorar el error
      }
    } catch (e) {
      developer.log('Error running migrations: $e', name: 'DatabaseHelper');
      rethrow;
    }
  }

  Future<void> dispose() async {
    try {
      // Cerrar todas las conexiones activas
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

      // 1. Desactivar las restricciones de clave foránea temporalmente
      db.execute('PRAGMA foreign_keys = OFF;');

      // 2. Iniciar una transacción
      db.execute('BEGIN TRANSACTION;');

      try {
        // 3. Truncar todas las tablas
        db.execute('DELETE FROM ${config.DatabaseConfig.tableNotes};');
        db.execute('DELETE FROM ${config.DatabaseConfig.tableNotebooks};');
        db.execute('DELETE FROM ${config.DatabaseConfig.tableSubtasks};');
        db.execute('DELETE FROM ${config.DatabaseConfig.tableTaskTags};');
        db.execute('DELETE FROM ${config.DatabaseConfig.tableTasks};');
        db.execute('DELETE FROM ${config.DatabaseConfig.tableThinks};');

        // 4. Reiniciar los contadores de autoincremento
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

        // 5. Confirmar la transacción
        db.execute('COMMIT;');

        // 6. Actualizar last_modified
        await _updateLastModified();
      } catch (e) {
        // 7. Si algo falla, revertir los cambios
        db.execute('ROLLBACK;');
        rethrow;
      } finally {
        // 8. Reactivar las restricciones de clave foránea
        db.execute('PRAGMA foreign_keys = ON;');
      }

      developer.log('Database reset successfully', name: 'DatabaseHelper');
    } catch (e) {
      developer.log('Error resetting database: $e', name: 'DatabaseHelper');
      rethrow;
    }
  }

  // Método para actualizar last_modified y notificar cambios
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

  // Método para obtener la última modificación
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

  // Método para actualizar la última modificación
  Future<void> updateLastModified() async {
    final db = await database;
    db.execute('UPDATE sync_info SET last_modified = ? WHERE id = 1', [
      DateTime.now().millisecondsSinceEpoch,
    ]);
  }

  // Método para notificar cambios en notas
  void notifyNoteChanges() {
    notifyDatabaseChanged();
  }

  // Método para notificar cambios en notebooks
  void notifyNotebookChanges() {
    notifyDatabaseChanged();
  }

  // Método para inicializar la base de datos con una ruta específica
  Future<void> initialize([String? dbPath]) async {
    if (dbPath != null) {
      _database = sqlite.sqlite3.open(dbPath);
      _activeConnections.add(_database!);
    } else {
      await database;
    }
  }

  // Método para cerrar la base de datos
  Future<void> close() async {
    for (var connection in _activeConnections) {
      connection.dispose();
    }
    _activeConnections.clear();
    _database = null;
    _isDisposed = true;
  }
}
