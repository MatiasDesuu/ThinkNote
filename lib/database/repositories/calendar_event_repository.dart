import '../database_helper.dart';
import '../models/calendar_event.dart';
import '../models/note.dart';
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
      SELECT e.*, n.title, n.content, n.notebook_id, n.created_at, n.updated_at, 
             n.is_favorite, n.tags, n.order_index as n_order_index, n.is_task, n.is_completed, n.is_pinned
      FROM ${config.DatabaseConfig.tableCalendarEvents} e
      JOIN ${config.DatabaseConfig.tableNotes} n ON e.${config.DatabaseConfig.columnCalendarEventNoteId} = n.id
      WHERE e.${config.DatabaseConfig.columnCalendarEventDate} >= ?
      AND e.${config.DatabaseConfig.columnCalendarEventDate} < ?
      AND n.${config.DatabaseConfig.columnDeletedAt} IS NULL
      ORDER BY e.${config.DatabaseConfig.columnCalendarEventOrderIndex} ASC
    ''',
      [startOfDay.millisecondsSinceEpoch, endOfDay.millisecondsSinceEpoch],
    );

    return result.map((row) {
      final event = CalendarEvent.fromMap(row);
      final note = Note(
        id: row['note_id'] as int,
        title: row['title'] as String? ?? '',
        content: row['content'] as String? ?? '',
        notebookId: row['notebook_id'] as int,
        createdAt: DateTime.fromMillisecondsSinceEpoch(row['created_at'] as int),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(row['updated_at'] as int),
        isFavorite: row['is_favorite'] == 1,
        tags: row['tags'] as String? ?? '',
        orderIndex: row['n_order_index'] as int? ?? 0,
        isTask: row['is_task'] == 1,
        isCompleted: row['is_completed'] == 1,
        isPinned: row['is_pinned'] == 1,
      );
      return event.copyWith(note: note);
    }).toList();
  }

  Future<List<CalendarEvent>> getCalendarEventsByMonth(DateTime month) async {
    final db = await _dbHelper.database;
    final startOfMonth = DateTime(month.year, month.month, 1);
    final endOfMonth = DateTime(month.year, month.month + 1, 0);

    final result = db.select(
      '''
      SELECT e.*, n.title, n.content, n.notebook_id, n.created_at, n.updated_at, 
             n.is_favorite, n.tags, n.order_index as n_order_index, n.is_task, n.is_completed, n.is_pinned
      FROM ${config.DatabaseConfig.tableCalendarEvents} e
      JOIN ${config.DatabaseConfig.tableNotes} n ON e.${config.DatabaseConfig.columnCalendarEventNoteId} = n.id
      WHERE e.${config.DatabaseConfig.columnCalendarEventDate} >= ?
      AND e.${config.DatabaseConfig.columnCalendarEventDate} <= ?
      AND n.${config.DatabaseConfig.columnDeletedAt} IS NULL
      ORDER BY e.${config.DatabaseConfig.columnCalendarEventOrderIndex} ASC
    ''',
      [startOfMonth.millisecondsSinceEpoch, endOfMonth.millisecondsSinceEpoch],
    );

    return result.map((row) {
      final event = CalendarEvent.fromMap(row);
      final note = Note(
        id: row['note_id'] as int,
        title: row['title'] as String? ?? '',
        content: row['content'] as String? ?? '',
        notebookId: row['notebook_id'] as int,
        createdAt: DateTime.fromMillisecondsSinceEpoch(row['created_at'] as int),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(row['updated_at'] as int),
        isFavorite: row['is_favorite'] == 1,
        tags: row['tags'] as String? ?? '',
        orderIndex: row['n_order_index'] as int? ?? 0,
        isTask: row['is_task'] == 1,
        isCompleted: row['is_completed'] == 1,
        isPinned: row['is_pinned'] == 1,
      );
      return event.copyWith(note: note);
    }).toList();
  }

  Future<CalendarEvent?> getCalendarEventByNoteId(int noteId) async {
    final db = await _dbHelper.database;
    final result = db.select(
      '''
      SELECT * FROM ${config.DatabaseConfig.tableCalendarEvents}
      WHERE ${config.DatabaseConfig.columnCalendarEventNoteId} = ?
      ORDER BY ${config.DatabaseConfig.columnCalendarEventDate} DESC
      LIMIT 1
    ''',
      [noteId],
    );

    if (result.isEmpty) return null;
    return CalendarEvent.fromMap(result.first);
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

  Future<List<CalendarEvent>> getUnassignedCalendarEvents() async {
    final db = await _dbHelper.database;
    final result = db.select('''
      SELECT e.*, n.title, n.content, n.notebook_id, n.created_at, n.updated_at, 
             n.is_favorite, n.tags, n.order_index as n_order_index, n.is_task, n.is_completed, n.is_pinned
      FROM ${config.DatabaseConfig.tableCalendarEvents} e
      JOIN ${config.DatabaseConfig.tableNotes} n ON e.${config.DatabaseConfig.columnCalendarEventNoteId} = n.id
      WHERE e.${config.DatabaseConfig.columnCalendarEventStatus} IS NULL
      AND n.${config.DatabaseConfig.columnDeletedAt} IS NULL
      ORDER BY e.${config.DatabaseConfig.columnCalendarEventOrderIndex} ASC
    ''');

    return result.map((row) {
      final event = CalendarEvent.fromMap(row);
      final note = Note(
        id: row['note_id'] as int,
        title: row['title'] as String? ?? '',
        content: row['content'] as String? ?? '',
        notebookId: row['notebook_id'] as int,
        createdAt: DateTime.fromMillisecondsSinceEpoch(row['created_at'] as int),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(row['updated_at'] as int),
        isFavorite: row['is_favorite'] == 1,
        tags: row['tags'] as String? ?? '',
        orderIndex: row['n_order_index'] as int? ?? 0,
        isTask: row['is_task'] == 1,
        isCompleted: row['is_completed'] == 1,
        isPinned: row['is_pinned'] == 1,
      );
      return event.copyWith(note: note);
    }).toList();
  }
}
