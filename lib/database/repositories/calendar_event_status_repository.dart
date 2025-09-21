import '../database_helper.dart';
import '../models/calendar_event_status.dart';
import '../database_config.dart' as config;

class CalendarEventStatusRepository {
  final DatabaseHelper _databaseHelper;

  CalendarEventStatusRepository(this._databaseHelper);

  Future<List<CalendarEventStatus>> getAllStatuses() async {
    final db = await _databaseHelper.database;
    final results = db.select('''
      SELECT * FROM ${config.DatabaseConfig.tableCalendarEventStatuses}
      ORDER BY ${config.DatabaseConfig.columnCalendarEventStatusOrderIndex}
    ''');

    return results.map((row) => CalendarEventStatus.fromMap(row)).toList();
  }

  Future<CalendarEventStatus?> getStatusById(int id) async {
    final db = await _databaseHelper.database;
    final results = db.select(
      '''
      SELECT * FROM ${config.DatabaseConfig.tableCalendarEventStatuses}
      WHERE ${config.DatabaseConfig.columnCalendarEventStatusId} = ?
    ''',
      [id],
    );

    if (results.isEmpty) return null;
    return CalendarEventStatus.fromMap(results.first);
  }

  Future<CalendarEventStatus?> getStatusByName(String name) async {
    final db = await _databaseHelper.database;
    final results = db.select(
      '''
      SELECT * FROM ${config.DatabaseConfig.tableCalendarEventStatuses}
      WHERE ${config.DatabaseConfig.columnCalendarEventStatusName} = ?
    ''',
      [name],
    );

    if (results.isEmpty) return null;
    return CalendarEventStatus.fromMap(results.first);
  }

  Future<int> createStatus(CalendarEventStatus status) async {
    final db = await _databaseHelper.database;
    final nextOrderIndex = await _getNextOrderIndex();

    final stmt = db.prepare('''
      INSERT INTO ${config.DatabaseConfig.tableCalendarEventStatuses} (
        ${config.DatabaseConfig.columnCalendarEventStatusName},
        ${config.DatabaseConfig.columnCalendarEventStatusColor},
        ${config.DatabaseConfig.columnCalendarEventStatusOrderIndex}
      ) VALUES (?, ?, ?)
    ''');

    try {
      stmt.execute([status.name, status.color, nextOrderIndex]);
      await _databaseHelper.updateLastModified();
      DatabaseHelper.notifyDatabaseChanged();
      return db.lastInsertRowId;
    } finally {
      stmt.dispose();
    }
  }

  Future<void> updateStatus(CalendarEventStatus status) async {
    final db = await _databaseHelper.database;
    db.execute(
      '''
      UPDATE ${config.DatabaseConfig.tableCalendarEventStatuses}
      SET ${config.DatabaseConfig.columnCalendarEventStatusName} = ?,
          ${config.DatabaseConfig.columnCalendarEventStatusColor} = ?,
          ${config.DatabaseConfig.columnCalendarEventStatusOrderIndex} = ?
      WHERE ${config.DatabaseConfig.columnCalendarEventStatusId} = ?
    ''',
      [status.name, status.color, status.orderIndex, status.id],
    );

    await _databaseHelper.updateLastModified();
    DatabaseHelper.notifyDatabaseChanged();
  }

  Future<void> deleteStatus(int id) async {
    final db = await _databaseHelper.database;
    db.execute(
      '''
      DELETE FROM ${config.DatabaseConfig.tableCalendarEventStatuses}
      WHERE ${config.DatabaseConfig.columnCalendarEventStatusId} = ?
    ''',
      [id],
    );

    await _databaseHelper.updateLastModified();
    DatabaseHelper.notifyDatabaseChanged();
  }

  Future<int> _getNextOrderIndex() async {
    final db = await _databaseHelper.database;
    final result = db.select('''
      SELECT MAX(${config.DatabaseConfig.columnCalendarEventStatusOrderIndex}) as max_order
      FROM ${config.DatabaseConfig.tableCalendarEventStatuses}
    ''');

    if (result.isEmpty || result.first['max_order'] == null) {
      return 0;
    }
    return (result.first['max_order'] as int) + 1;
  }
}
