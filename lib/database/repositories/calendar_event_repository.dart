import '../database_helper.dart';
import '../models/calendar_event.dart';
import '../database_config.dart' as config;
import 'note_repository.dart';

class CalendarEventRepository {
  final DatabaseHelper _dbHelper;
  late final NoteRepository _noteRepository;

  CalendarEventRepository(this._dbHelper) {
    _noteRepository = NoteRepository(_dbHelper);
  }

  Future<int> createCalendarEvent(CalendarEvent event) async {
    final db = await _dbHelper.database;
    final stmt = db.prepare('''
      INSERT INTO ${config.DatabaseConfig.tableCalendarEvents} (
        ${config.DatabaseConfig.columnCalendarEventNoteId},
        ${config.DatabaseConfig.columnCalendarEventDate},
        ${config.DatabaseConfig.columnCalendarEventOrderIndex},
        ${config.DatabaseConfig.columnCalendarEventStatus}
      ) VALUES (?, ?, ?, ?)
    ''');

    try {
      stmt.execute([
        event.noteId,
        event.date.millisecondsSinceEpoch,
        event.orderIndex,
        event.status,
      ]);
      await _dbHelper.updateLastModified();
      DatabaseHelper.notifyDatabaseChanged();
      return db.lastInsertRowId;
    } finally {
      stmt.dispose();
    }
  }

  Future<CalendarEvent?> getCalendarEvent(int id) async {
    final db = await _dbHelper.database;
    final result = db.select(
      '''
      SELECT * FROM ${config.DatabaseConfig.tableCalendarEvents}
      WHERE ${config.DatabaseConfig.columnCalendarEventId} = ?
    ''',
      [id],
    );

    if (result.isEmpty) return null;
    final event = CalendarEvent.fromMap(result.first);
    final note = await _noteRepository.getNote(event.noteId);
    return event.copyWith(note: note);
  }

  Future<List<CalendarEvent>> getCalendarEventsByDate(DateTime date) async {
    final db = await _dbHelper.database;
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    final result = db.select(
      '''
      SELECT * FROM ${config.DatabaseConfig.tableCalendarEvents}
      WHERE ${config.DatabaseConfig.columnCalendarEventDate} >= ?
      AND ${config.DatabaseConfig.columnCalendarEventDate} < ?
      ORDER BY ${config.DatabaseConfig.columnCalendarEventOrderIndex} ASC
    ''',
      [startOfDay.millisecondsSinceEpoch, endOfDay.millisecondsSinceEpoch],
    );

    final events = result.map((row) => CalendarEvent.fromMap(row)).toList();

    // Cargar las notas asociadas
    for (var i = 0; i < events.length; i++) {
      final note = await _noteRepository.getNote(events[i].noteId);
      events[i] = events[i].copyWith(note: note);
    }

    return events;
  }

  Future<List<CalendarEvent>> getCalendarEventsByMonth(DateTime month) async {
    final db = await _dbHelper.database;
    final startOfMonth = DateTime(month.year, month.month, 1);
    final endOfMonth = DateTime(month.year, month.month + 1, 0);

    final result = db.select(
      '''
      SELECT * FROM ${config.DatabaseConfig.tableCalendarEvents}
      WHERE ${config.DatabaseConfig.columnCalendarEventDate} >= ?
      AND ${config.DatabaseConfig.columnCalendarEventDate} <= ?
      ORDER BY ${config.DatabaseConfig.columnCalendarEventOrderIndex} ASC
    ''',
      [startOfMonth.millisecondsSinceEpoch, endOfMonth.millisecondsSinceEpoch],
    );

    final events = result.map((row) => CalendarEvent.fromMap(row)).toList();

    // Cargar las notas asociadas
    for (var i = 0; i < events.length; i++) {
      final note = await _noteRepository.getNote(events[i].noteId);
      events[i] = events[i].copyWith(note: note);
    }

    return events;
  }

  Future<int> deleteCalendarEvent(int id) async {
    final db = await _dbHelper.database;
    final stmt = db.prepare('''
      DELETE FROM ${config.DatabaseConfig.tableCalendarEvents}
      WHERE ${config.DatabaseConfig.columnCalendarEventId} = ?
    ''');

    try {
      stmt.execute([id]);
      await _dbHelper.updateLastModified();
      DatabaseHelper.notifyDatabaseChanged();
      return 1;
    } finally {
      stmt.dispose();
    }
  }

  Future<int> getNextOrderIndex() async {
    final db = await _dbHelper.database;
    final result = db.select('''
      SELECT MAX(${config.DatabaseConfig.columnCalendarEventOrderIndex}) as max_order
      FROM ${config.DatabaseConfig.tableCalendarEvents}
    ''');

    if (result.isEmpty || result.first['max_order'] == null) {
      return 0;
    }
    return (result.first['max_order'] as int) + 1;
  }

  Future<int> updateCalendarEvent(CalendarEvent event) async {
    final db = await _dbHelper.database;
    final stmt = db.prepare('''
      UPDATE ${config.DatabaseConfig.tableCalendarEvents}
      SET ${config.DatabaseConfig.columnCalendarEventNoteId} = ?,
          ${config.DatabaseConfig.columnCalendarEventDate} = ?,
          ${config.DatabaseConfig.columnCalendarEventOrderIndex} = ?,
          ${config.DatabaseConfig.columnCalendarEventStatus} = ?
      WHERE ${config.DatabaseConfig.columnCalendarEventId} = ?
    ''');

    try {
      stmt.execute([
        event.noteId,
        event.date.millisecondsSinceEpoch,
        event.orderIndex,
        event.status,
        event.id,
      ]);
      await _dbHelper.updateLastModified();
      DatabaseHelper.notifyDatabaseChanged();
      return 1;
    } finally {
      stmt.dispose();
    }
  }
}
