import '../database_helper.dart';
import '../models/think.dart';
import '../database_config.dart' as config;
import '../database_service.dart';

class ThinkRepository {
  final DatabaseHelper _databaseHelper;

  ThinkRepository(this._databaseHelper);

  Future<int> createThink(Think think) async {
    final db = await _databaseHelper.database;

    // Obtener el siguiente orden
    final result = db.select('''
      SELECT MAX(${config.DatabaseConfig.columnOrderIndex}) as maxOrder
      FROM ${config.DatabaseConfig.tableThinks}
      WHERE ${config.DatabaseConfig.columnDeletedAt} IS NULL
    ''');
    final int nextOrder = (result.first['maxOrder'] as int? ?? -1) + 1;

    final stmt = db.prepare('''
      INSERT INTO ${config.DatabaseConfig.tableThinks} (
        ${config.DatabaseConfig.columnTitle},
        ${config.DatabaseConfig.columnContent},
        ${config.DatabaseConfig.columnCreatedAt},
        ${config.DatabaseConfig.columnUpdatedAt},
        ${config.DatabaseConfig.columnIsFavorite},
        ${config.DatabaseConfig.columnOrderIndex},
        ${config.DatabaseConfig.columnTags}
      ) VALUES (?, ?, ?, ?, ?, ?, ?)
    ''');

    try {
      stmt.execute([
        think.title,
        think.content,
        think.createdAt.millisecondsSinceEpoch,
        think.updatedAt.millisecondsSinceEpoch,
        think.isFavorite ? 1 : 0,
        think.orderIndex != 0 ? think.orderIndex : nextOrder,
        think.tags,
      ]);
      DatabaseService().notifyDatabaseChanged();
      return db.lastInsertRowId;
    } finally {
      stmt.dispose();
    }
  }

  Future<Think?> getThink(int id) async {
    final db = await _databaseHelper.database;
    final result = db.select(
      '''
      SELECT * FROM ${config.DatabaseConfig.tableThinks}
      WHERE ${config.DatabaseConfig.columnId} = ?
      AND ${config.DatabaseConfig.columnDeletedAt} IS NULL
      ''',
      [id],
    );

    if (result.isEmpty) {
      return null;
    }

    return Think.fromMap(_convertResultToMap(result.first));
  }

  Future<List<Think>> getAllThinks({bool orderByIndex = true}) async {
    final db = await _databaseHelper.database;

    final orderBy =
        orderByIndex
            ? '${config.DatabaseConfig.columnOrderIndex} ASC'
            : '${config.DatabaseConfig.columnUpdatedAt} DESC';

    final result = db.select('''
      SELECT * FROM ${config.DatabaseConfig.tableThinks}
      WHERE ${config.DatabaseConfig.columnDeletedAt} IS NULL
      ORDER BY $orderBy
      ''');

    return result
        .map((row) => Think.fromMap(_convertResultToMap(row)))
        .toList();
  }

  Future<int> updateThink(Think think) async {
    final db = await _databaseHelper.database;
    final stmt = db.prepare('''
      UPDATE ${config.DatabaseConfig.tableThinks}
      SET ${config.DatabaseConfig.columnTitle} = ?,
          ${config.DatabaseConfig.columnContent} = ?,
          ${config.DatabaseConfig.columnUpdatedAt} = ?,
          ${config.DatabaseConfig.columnIsFavorite} = ?,
          ${config.DatabaseConfig.columnTags} = ?,
          ${config.DatabaseConfig.columnOrderIndex} = ?
      WHERE ${config.DatabaseConfig.columnId} = ?
      AND ${config.DatabaseConfig.columnDeletedAt} IS NULL
    ''');

    try {
      stmt.execute([
        think.title,
        think.content,
        think.updatedAt.millisecondsSinceEpoch,
        think.isFavorite ? 1 : 0,
        think.tags,
        think.orderIndex,
        think.id,
      ]);
      DatabaseService().notifyDatabaseChanged();
      return 1;
    } finally {
      stmt.dispose();
    }
  }

  Future<int> deleteThink(int id) async {
    final db = await _databaseHelper.database;
    final now = DateTime.now().millisecondsSinceEpoch;
    final stmt = db.prepare('''
      UPDATE ${config.DatabaseConfig.tableThinks}
      SET ${config.DatabaseConfig.columnDeletedAt} = ?
      WHERE ${config.DatabaseConfig.columnId} = ?
    ''');

    try {
      stmt.execute([now, id]);
      DatabaseService().notifyDatabaseChanged();
      return 1;
    } finally {
      stmt.dispose();
    }
  }

  Future<int> updateThinkOrder(int id, int newOrderIndex) async {
    final db = await _databaseHelper.database;
    final stmt = db.prepare('''
      UPDATE ${config.DatabaseConfig.tableThinks}
      SET ${config.DatabaseConfig.columnOrderIndex} = ?
      WHERE ${config.DatabaseConfig.columnId} = ?
      AND ${config.DatabaseConfig.columnDeletedAt} IS NULL
    ''');

    try {
      stmt.execute([newOrderIndex, id]);
      DatabaseService().notifyDatabaseChanged();
      return 1;
    } finally {
      stmt.dispose();
    }
  }

  Future<void> reorderThinks(List<Think> thinks) async {
    final db = await _databaseHelper.database;
    db.execute('BEGIN TRANSACTION');

    try {
      final stmt = db.prepare('''
        UPDATE ${config.DatabaseConfig.tableThinks}
        SET ${config.DatabaseConfig.columnOrderIndex} = ?
        WHERE ${config.DatabaseConfig.columnId} = ?
        AND ${config.DatabaseConfig.columnDeletedAt} IS NULL
      ''');

      for (int i = 0; i < thinks.length; i++) {
        stmt.execute([i, thinks[i].id]);
      }

      stmt.dispose();
      db.execute('COMMIT');
      DatabaseService().notifyDatabaseChanged();
    } catch (e) {
      db.execute('ROLLBACK');
      rethrow;
    }
  }

  Future<List<Think>> getFavoriteThinks() async {
    final db = await _databaseHelper.database;
    final result = db.select('''
      SELECT * FROM ${config.DatabaseConfig.tableThinks}
      WHERE ${config.DatabaseConfig.columnIsFavorite} = 1
      AND ${config.DatabaseConfig.columnDeletedAt} IS NULL
      ORDER BY ${config.DatabaseConfig.columnUpdatedAt} DESC
      ''');

    return result
        .map((row) => Think.fromMap(_convertResultToMap(row)))
        .toList();
  }

  Future<int> toggleFavorite(int id, bool isFavorite) async {
    final db = await _databaseHelper.database;
    final stmt = db.prepare('''
      UPDATE ${config.DatabaseConfig.tableThinks}
      SET ${config.DatabaseConfig.columnIsFavorite} = ?
      WHERE ${config.DatabaseConfig.columnId} = ?
      AND ${config.DatabaseConfig.columnDeletedAt} IS NULL
    ''');

    try {
      stmt.execute([isFavorite ? 1 : 0, id]);
      DatabaseService().notifyDatabaseChanged();
      return 1;
    } finally {
      stmt.dispose();
    }
  }

  Future<List<Think>> searchThinks(String query) async {
    final db = await _databaseHelper.database;
    final result = db.select(
      '''
      SELECT * FROM ${config.DatabaseConfig.tableThinks}
      WHERE (${config.DatabaseConfig.columnTitle} LIKE ? 
      OR ${config.DatabaseConfig.columnContent} LIKE ?)
      AND ${config.DatabaseConfig.columnDeletedAt} IS NULL
      ORDER BY ${config.DatabaseConfig.columnUpdatedAt} DESC
      ''',
      ['%$query%', '%$query%'],
    );

    return result
        .map((row) => Think.fromMap(_convertResultToMap(row)))
        .toList();
  }

  Future<List<Think>> getDeletedThinks() async {
    final db = await _databaseHelper.database;
    final result = db.select('''
      SELECT * FROM ${config.DatabaseConfig.tableThinks}
      WHERE ${config.DatabaseConfig.columnDeletedAt} IS NOT NULL
      ORDER BY ${config.DatabaseConfig.columnDeletedAt} DESC
      ''');

    return result
        .map((row) => Think.fromMap(_convertResultToMap(row)))
        .toList();
  }

  Future<int> restoreThink(int id) async {
    final db = await _databaseHelper.database;
    final stmt = db.prepare('''
      UPDATE ${config.DatabaseConfig.tableThinks}
      SET ${config.DatabaseConfig.columnDeletedAt} = NULL
      WHERE ${config.DatabaseConfig.columnId} = ?
    ''');

    try {
      stmt.execute([id]);
      DatabaseService().notifyDatabaseChanged();
      return 1;
    } finally {
      stmt.dispose();
    }
  }

  Future<int> permanentlyDeleteThink(int id) async {
    final db = await _databaseHelper.database;
    final stmt = db.prepare('''
      DELETE FROM ${config.DatabaseConfig.tableThinks}
      WHERE ${config.DatabaseConfig.columnId} = ?
    ''');

    try {
      stmt.execute([id]);
      DatabaseService().notifyDatabaseChanged();
      return 1;
    } finally {
      stmt.dispose();
    }
  }

  // Función auxiliar para convertir resultados de SQLite a Map
  Map<String, dynamic> _convertResultToMap(Map<String, Object?> row) {
    return {
      'id': row[config.DatabaseConfig.columnId],
      'title': row[config.DatabaseConfig.columnTitle],
      'content': row[config.DatabaseConfig.columnContent],
      'created_at':
          DateTime.fromMillisecondsSinceEpoch(
            row[config.DatabaseConfig.columnCreatedAt] as int,
          ).toIso8601String(),
      'updated_at':
          DateTime.fromMillisecondsSinceEpoch(
            row[config.DatabaseConfig.columnUpdatedAt] as int,
          ).toIso8601String(),
      'deleted_at': row[config.DatabaseConfig.columnDeletedAt],
      'is_favorite': row[config.DatabaseConfig.columnIsFavorite],
      'order_index': row[config.DatabaseConfig.columnOrderIndex],
      'tags': row[config.DatabaseConfig.columnTags] ?? '',
    };
  }
}
