import '../database_helper.dart';
import '../database_config.dart' as config;
import '../models/note.dart';
import '../database_service.dart';
import '../../services/notification_service.dart';

class NoteRepository {
  final DatabaseHelper _dbHelper;

  NoteRepository(this._dbHelper);

  Future<int> createNote(Note note) async {
    final db = await _dbHelper.database;

    final targetOrderIndex = note.orderIndex != 0 ? note.orderIndex : 0;

    if (targetOrderIndex == 0) {
      db.execute(
        '''
        UPDATE ${config.DatabaseConfig.tableNotes}
        SET order_index = order_index + 1
        WHERE ${config.DatabaseConfig.columnNotebookId} = ?
        AND ${config.DatabaseConfig.columnDeletedAt} IS NULL
        ''',
        [note.notebookId],
      );
    }

    final stmt = db.prepare('''
      INSERT INTO ${config.DatabaseConfig.tableNotes} (
        ${config.DatabaseConfig.columnTitle},
        ${config.DatabaseConfig.columnContent},
        ${config.DatabaseConfig.columnNotebookId},
        ${config.DatabaseConfig.columnCreatedAt},
        ${config.DatabaseConfig.columnUpdatedAt},
        ${config.DatabaseConfig.columnIsFavorite},
        ${config.DatabaseConfig.columnTags},
        order_index,
        ${config.DatabaseConfig.columnIsTask},
        ${config.DatabaseConfig.columnIsCompleted},
        ${config.DatabaseConfig.columnNoteIsPinned}
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ''');
    try {
      stmt.execute([
        note.title,
        note.content,
        note.notebookId,
        note.createdAt.millisecondsSinceEpoch,
        note.updatedAt.millisecondsSinceEpoch,
        note.isFavorite ? 1 : 0,
        note.tags,
        targetOrderIndex,
        note.isTask ? 1 : 0,
        note.isCompleted ? 1 : 0,
        note.isPinned ? 1 : 0,
      ]);

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

  Future<Note?> getNote(int id) async {
    final db = await _dbHelper.database;
    final result = db.select(
      '''
      SELECT * FROM ${config.DatabaseConfig.tableNotes}
      WHERE id = ? AND ${config.DatabaseConfig.columnDeletedAt} IS NULL
    ''',
      [id],
    );

    if (result.isEmpty) return null;

    final row = result.first;
    final isTask = row[config.DatabaseConfig.columnIsTask] == 1;
    final isCompleted = row[config.DatabaseConfig.columnIsCompleted] == 1;

    return Note(
      id: row['id'] as int,
      title: row[config.DatabaseConfig.columnTitle] as String? ?? '',
      content: row[config.DatabaseConfig.columnContent] as String? ?? '',
      notebookId: row[config.DatabaseConfig.columnNotebookId] as int,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        row[config.DatabaseConfig.columnCreatedAt] as int,
      ),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
        row[config.DatabaseConfig.columnUpdatedAt] as int,
      ),
      isFavorite: row[config.DatabaseConfig.columnIsFavorite] == 1,
      tags: row[config.DatabaseConfig.columnTags] as String? ?? '',
      orderIndex: row['order_index'] as int? ?? 0,
      isTask: isTask,
      isCompleted: isCompleted,
      isPinned: row[config.DatabaseConfig.columnNoteIsPinned] == 1,
    );
  }

  Future<List<Note>> getNotesByNotebookId(int notebookId) async {
    final db = await _dbHelper.database;
    final result = db.select(
      '''
      SELECT * FROM ${config.DatabaseConfig.tableNotes}
      WHERE ${config.DatabaseConfig.columnNotebookId} = ?
      AND ${config.DatabaseConfig.columnDeletedAt} IS NULL
      ORDER BY ${config.DatabaseConfig.columnNoteIsPinned} DESC, order_index ASC
    ''',
      [notebookId],
    );

    return result.map((row) => Note.fromMap(row)).toList();
  }

  Future<List<Note>> getAllNotes() async {
    final db = await _dbHelper.database;
    final result = db.select('''
      SELECT * FROM ${config.DatabaseConfig.tableNotes}
      WHERE ${config.DatabaseConfig.columnDeletedAt} IS NULL
      ORDER BY ${config.DatabaseConfig.columnTitle} ASC
    ''');

    return result.map((row) => Note.fromMap(row)).toList();
  }

  Future<int> updateNote(Note note) async {
    final db = await _dbHelper.database;
    final stmt = db.prepare('''
      UPDATE ${config.DatabaseConfig.tableNotes}
      SET ${config.DatabaseConfig.columnTitle} = ?,
          ${config.DatabaseConfig.columnContent} = ?,
          ${config.DatabaseConfig.columnNotebookId} = ?,
          ${config.DatabaseConfig.columnUpdatedAt} = ?,
          ${config.DatabaseConfig.columnIsFavorite} = ?,
          ${config.DatabaseConfig.columnTags} = ?,
          order_index = ?,
          ${config.DatabaseConfig.columnIsTask} = ?,
          ${config.DatabaseConfig.columnIsCompleted} = ?,
          ${config.DatabaseConfig.columnNoteIsPinned} = ?
      WHERE id = ?
    ''');

    try {
      stmt.execute([
        note.title,
        note.content,
        note.notebookId,
        note.updatedAt.millisecondsSinceEpoch,
        note.isFavorite ? 1 : 0,
        note.tags,
        note.orderIndex,
        note.isTask ? 1 : 0,
        note.isCompleted ? 1 : 0,
        note.isPinned ? 1 : 0,
        note.id,
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
      NotificationService().notifyNoteUpdate(note);
      return 1;
    } finally {
      stmt.dispose();
    }
  }

  Future<int> deleteNote(int id) async {
    final db = await _dbHelper.database;
    final stmt = db.prepare('''
      UPDATE ${config.DatabaseConfig.tableNotes}
      SET ${config.DatabaseConfig.columnDeletedAt} = ?
      WHERE id = ?
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
      return 1;
    } finally {
      stmt.dispose();
    }
  }

  Future<void> restoreNote(int id) async {
    final db = await _dbHelper.database;
    db.execute(
      '''
      UPDATE ${config.DatabaseConfig.tableNotes}
      SET ${config.DatabaseConfig.columnDeletedAt} = NULL
      WHERE ${config.DatabaseConfig.columnId} = ?
      ''',
      [id],
    );
    DatabaseService().notifyDatabaseChanged();
  }

  Future<void> hardDeleteNote(int id) async {
    final db = await _dbHelper.database;
    db.execute(
      '''
      DELETE FROM ${config.DatabaseConfig.tableNotes}
      WHERE ${config.DatabaseConfig.columnId} = ?
      ''',
      [id],
    );
    DatabaseService().notifyDatabaseChanged();
  }

  Future<List<Note>> getDeletedNotes() async {
    final db = await _dbHelper.database;
    final result = db.select('''
      SELECT n.* FROM ${config.DatabaseConfig.tableNotes} n
      LEFT JOIN ${config.DatabaseConfig.tableNotebooks} nb ON n.${config.DatabaseConfig.columnNotebookId} = nb.${config.DatabaseConfig.columnId}
      WHERE n.${config.DatabaseConfig.columnDeletedAt} IS NOT NULL
      AND (nb.${config.DatabaseConfig.columnDeletedAt} IS NULL OR nb.${config.DatabaseConfig.columnId} IS NULL)
      ORDER BY n.${config.DatabaseConfig.columnDeletedAt} DESC
    ''');
    return result.map((row) => Note.fromMap(row)).toList();
  }

  Future<List<Note>> getFavoriteNotes() async {
    final db = await _dbHelper.database;
    final result = db.select('''
      SELECT * FROM ${config.DatabaseConfig.tableNotes}
      WHERE ${config.DatabaseConfig.columnIsFavorite} = 1
      AND ${config.DatabaseConfig.columnDeletedAt} IS NULL
      ORDER BY ${config.DatabaseConfig.columnTitle}
      ''');
    return result.map((row) => Note.fromMap(row)).toList();
  }

  Future<void> updateNoteOrder(int noteId, int newOrder) async {
    final db = await _dbHelper.database;
    db.execute(
      '''
      UPDATE ${config.DatabaseConfig.tableNotes}
      SET order_index = ?
      WHERE id = ?
    ''',
      [newOrder, noteId],
    );

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
  }

  Future<List<Note>> searchNotes(String query) async {
    final db = await _dbHelper.database;
    final searchQuery = '%$query%';
    final result = db.select(
      '''
      SELECT * FROM ${config.DatabaseConfig.tableNotes}
      WHERE (${config.DatabaseConfig.columnTitle} LIKE ? OR ${config.DatabaseConfig.columnContent} LIKE ?)
      AND ${config.DatabaseConfig.columnDeletedAt} IS NULL
      ORDER BY ${config.DatabaseConfig.columnTitle}
    ''',
      [searchQuery, searchQuery],
    );
    return result.map((row) => Note.fromMap(row)).toList();
  }

  Future<List<Note>> searchNotesByTitle(String query) async {
    final db = await _dbHelper.database;
    final searchQuery = '%$query%';
    final result = db.select(
      '''
      SELECT * FROM ${config.DatabaseConfig.tableNotes}
      WHERE ${config.DatabaseConfig.columnTitle} LIKE ?
      AND ${config.DatabaseConfig.columnDeletedAt} IS NULL
      ORDER BY ${config.DatabaseConfig.columnTitle}
    ''',
      [searchQuery],
    );
    return result.map((row) => Note.fromMap(row)).toList();
  }

  Future<void> toggleNoteCompletion(int noteId, bool isCompleted) async {
    final db = await _dbHelper.database;
    final stmt = db.prepare('''
      UPDATE ${config.DatabaseConfig.tableNotes}
      SET ${config.DatabaseConfig.columnIsCompleted} = ?,
          ${config.DatabaseConfig.columnUpdatedAt} = ?
      WHERE id = ?
    ''');

    try {
      stmt.execute([
        isCompleted ? 1 : 0,
        DateTime.now().millisecondsSinceEpoch,
        noteId,
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
    } finally {
      stmt.dispose();
    }
  }

  Future<void> updateNoteTitleAndContent(
    int noteId,
    String title,
    String content,
  ) async {
    final db = await _dbHelper.database;
    final stmt = db.prepare('''
      UPDATE ${config.DatabaseConfig.tableNotes}
      SET ${config.DatabaseConfig.columnTitle} = ?,
          ${config.DatabaseConfig.columnContent} = ?,
          ${config.DatabaseConfig.columnUpdatedAt} = ?
      WHERE id = ?
    ''');

    try {
      stmt.execute([
        title,
        content,
        DateTime.now().millisecondsSinceEpoch,
        noteId,
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
    } finally {
      stmt.dispose();
    }
  }
}
