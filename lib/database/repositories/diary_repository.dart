import '../database_helper.dart';
import '../database_config.dart' as config;
import '../models/diary_entry.dart';
import '../database_service.dart';

class DiaryRepository {
  final DatabaseHelper _dbHelper;

  DiaryRepository(this._dbHelper);

  Future<int> createDiaryEntry(DiaryEntry entry) async {
    final db = await _dbHelper.database;
    final stmt = db.prepare('''
      INSERT INTO ${config.DatabaseConfig.tableDiary} (
        ${config.DatabaseConfig.columnContent},
        ${config.DatabaseConfig.columnDate},
        ${config.DatabaseConfig.columnCreatedAt},
        ${config.DatabaseConfig.columnUpdatedAt},
        ${config.DatabaseConfig.columnIsFavorite},
        ${config.DatabaseConfig.columnTags}
      ) VALUES (?, ?, ?, ?, ?, ?)
    ''');

    try {
      stmt.execute([
        entry.content,
        entry.date.millisecondsSinceEpoch,
        entry.createdAt.millisecondsSinceEpoch,
        entry.updatedAt.millisecondsSinceEpoch,
        entry.isFavorite ? 1 : 0,
        entry.tags,
      ]);

      // Update last_modified
      db.execute(
        '''
        UPDATE sync_info
        SET last_modified = ?
        WHERE id = 1
      ''',
        [DateTime.now().millisecondsSinceEpoch],
      );

      DatabaseService().notifyDatabaseChanged();
      return db.lastInsertRowId;
    } finally {
      stmt.dispose();
    }
  }

  Future<DiaryEntry?> getDiaryEntry(int id) async {
    final db = await _dbHelper.database;
    final result = db.select(
      '''
      SELECT * FROM ${config.DatabaseConfig.tableDiary}
      WHERE ${config.DatabaseConfig.columnId} = ?
      AND ${config.DatabaseConfig.columnDeletedAt} IS NULL
      ''',
      [id],
    );

    if (result.isEmpty) return null;
    return DiaryEntry.fromMap(result.first);
  }

  Future<DiaryEntry?> getDiaryEntryByDate(DateTime date) async {
    final db = await _dbHelper.database;
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    final result = db.select(
      '''
      SELECT * FROM ${config.DatabaseConfig.tableDiary}
      WHERE ${config.DatabaseConfig.columnDate} >= ? 
      AND ${config.DatabaseConfig.columnDate} < ?
      AND ${config.DatabaseConfig.columnDeletedAt} IS NULL
      ''',
      [startOfDay.millisecondsSinceEpoch, endOfDay.millisecondsSinceEpoch],
    );

    if (result.isEmpty) return null;
    return DiaryEntry.fromMap(result.first);
  }

  Future<List<DiaryEntry>> getAllDiaryEntries() async {
    final db = await _dbHelper.database;
    final result = db.select('''
      SELECT * FROM ${config.DatabaseConfig.tableDiary}
      WHERE ${config.DatabaseConfig.columnDeletedAt} IS NULL
      ORDER BY ${config.DatabaseConfig.columnDate} DESC
      ''');

    return result.map((row) => DiaryEntry.fromMap(row)).toList();
  }

  Future<List<DiaryEntry>> getDiaryEntriesByMonth(int year, int month) async {
    final db = await _dbHelper.database;
    final startOfMonth = DateTime(year, month, 1);
    final endOfMonth = DateTime(year, month + 1, 1);

    final result = db.select(
      '''
      SELECT * FROM ${config.DatabaseConfig.tableDiary}
      WHERE ${config.DatabaseConfig.columnDate} >= ? 
      AND ${config.DatabaseConfig.columnDate} < ?
      AND ${config.DatabaseConfig.columnDeletedAt} IS NULL
      ORDER BY ${config.DatabaseConfig.columnDate} DESC
      ''',
      [startOfMonth.millisecondsSinceEpoch, endOfMonth.millisecondsSinceEpoch],
    );

    return result.map((row) => DiaryEntry.fromMap(row)).toList();
  }

  Future<int> updateDiaryEntry(DiaryEntry entry) async {
    final db = await _dbHelper.database;
    final stmt = db.prepare('''
      UPDATE ${config.DatabaseConfig.tableDiary}
      SET ${config.DatabaseConfig.columnContent} = ?,
          ${config.DatabaseConfig.columnDate} = ?,
          ${config.DatabaseConfig.columnUpdatedAt} = ?,
          ${config.DatabaseConfig.columnIsFavorite} = ?,
          ${config.DatabaseConfig.columnTags} = ?
      WHERE ${config.DatabaseConfig.columnId} = ?
    ''');

    try {
      stmt.execute([
        entry.content,
        entry.date.millisecondsSinceEpoch,
        entry.updatedAt.millisecondsSinceEpoch,
        entry.isFavorite ? 1 : 0,
        entry.tags,
        entry.id,
      ]);

      // Update last_modified
      db.execute(
        '''
        UPDATE sync_info
        SET last_modified = ?
        WHERE id = 1
      ''',
        [DateTime.now().millisecondsSinceEpoch],
      );

      DatabaseService().notifyDatabaseChanged();
      return db.lastInsertRowId;
    } finally {
      stmt.dispose();
    }
  }

  Future<int> deleteDiaryEntry(int id) async {
    final db = await _dbHelper.database;
    final stmt = db.prepare('''
      UPDATE ${config.DatabaseConfig.tableDiary}
      SET ${config.DatabaseConfig.columnDeletedAt} = ?
      WHERE ${config.DatabaseConfig.columnId} = ?
    ''');

    try {
      stmt.execute([DateTime.now().millisecondsSinceEpoch, id]);

      // Update last_modified
      db.execute(
        '''
        UPDATE sync_info
        SET last_modified = ?
        WHERE id = 1
      ''',
        [DateTime.now().millisecondsSinceEpoch],
      );

      DatabaseService().notifyDatabaseChanged();
      return db.lastInsertRowId;
    } finally {
      stmt.dispose();
    }
  }

  Future<int> permanentlyDeleteDiaryEntry(int id) async {
    final db = await _dbHelper.database;
    final stmt = db.prepare('''
      DELETE FROM ${config.DatabaseConfig.tableDiary}
      WHERE ${config.DatabaseConfig.columnId} = ?
    ''');

    try {
      stmt.execute([id]);

      // Update last_modified
      db.execute(
        '''
        UPDATE sync_info
        SET last_modified = ?
        WHERE id = 1
      ''',
        [DateTime.now().millisecondsSinceEpoch],
      );

      DatabaseService().notifyDatabaseChanged();
      return db.lastInsertRowId;
    } finally {
      stmt.dispose();
    }
  }

  Future<List<DiaryEntry>> getDeletedDiaryEntries() async {
    final db = await _dbHelper.database;
    final result = db.select('''
      SELECT * FROM ${config.DatabaseConfig.tableDiary}
      WHERE ${config.DatabaseConfig.columnDeletedAt} IS NOT NULL
      ORDER BY ${config.DatabaseConfig.columnDeletedAt} DESC
      ''');

    return result.map((row) => DiaryEntry.fromMap(row)).toList();
  }

  Future<int> restoreDiaryEntry(int id) async {
    final db = await _dbHelper.database;
    final stmt = db.prepare('''
      UPDATE ${config.DatabaseConfig.tableDiary}
      SET ${config.DatabaseConfig.columnDeletedAt} = NULL
      WHERE ${config.DatabaseConfig.columnId} = ?
    ''');

    try {
      stmt.execute([id]);

      // Update last_modified
      db.execute(
        '''
        UPDATE sync_info
        SET last_modified = ?
        WHERE id = 1
      ''',
        [DateTime.now().millisecondsSinceEpoch],
      );

      DatabaseService().notifyDatabaseChanged();
      return db.lastInsertRowId;
    } finally {
      stmt.dispose();
    }
  }
}
