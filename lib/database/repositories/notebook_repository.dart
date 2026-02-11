import '../database_helper.dart';
import '../database_config.dart' as config;
import '../models/notebook.dart';
import '../database_service.dart';
import 'package:collection/collection.dart';

class NotebookRepository {
  final DatabaseHelper _dbHelper;

  NotebookRepository(this._dbHelper);

  Future<int> createNotebook(Notebook notebook) async {
    final db = await _dbHelper.database;

    final result = db.select('''
      SELECT MAX(order_index) as maxOrder
      FROM ${config.DatabaseConfig.tableNotebooks}
      WHERE ${config.DatabaseConfig.columnParentId} ${notebook.parentId == null ? 'IS NULL' : '= ?'}
      AND ${config.DatabaseConfig.columnDeletedAt} IS NULL
    ''', notebook.parentId == null ? [] : [notebook.parentId]);
    final int nextOrder = (result.first['maxOrder'] as int? ?? -1) + 1;
    final stmt = db.prepare('''
      INSERT INTO ${config.DatabaseConfig.tableNotebooks} (
        ${config.DatabaseConfig.columnName},
        ${config.DatabaseConfig.columnParentId},
        ${config.DatabaseConfig.columnCreatedAt},
        order_index,
        ${config.DatabaseConfig.columnDeletedAt},
        ${config.DatabaseConfig.columnIconId}
      ) VALUES (?, ?, ?, ?, ?, ?)
      ''');
    try {
      stmt.execute([
        notebook.name,
        notebook.parentId,
        notebook.createdAt.millisecondsSinceEpoch,
        notebook.orderIndex != 0 ? notebook.orderIndex : nextOrder,
        notebook.deletedAt?.millisecondsSinceEpoch,
        notebook.iconId,
      ]);
      DatabaseService().notifyDatabaseChanged();
      return db.lastInsertRowId;
    } finally {
      stmt.dispose();
    }
  }

  Future<Notebook?> getNotebook(int id) async {
    final db = await _dbHelper.database;
    final result = db.select(
      '''
      SELECT * FROM ${config.DatabaseConfig.tableNotebooks}
      WHERE ${config.DatabaseConfig.columnId} = ?
      ''',
      [id],
    );
    if (result.isEmpty) return null;
    return Notebook.fromMap(result.first);
  }

  Future<List<Notebook>> getNotebooksByParentId(int? parentId) async {
    final db = await _dbHelper.database;
    final result = db.select('''
      SELECT * FROM ${config.DatabaseConfig.tableNotebooks}
      WHERE ${config.DatabaseConfig.columnParentId} ${parentId == null ? 'IS NULL' : '= ?'}
      AND ${config.DatabaseConfig.columnDeletedAt} IS NULL
      ORDER BY order_index ASC
      ''', parentId == null ? [] : [parentId]);
    return result.map((row) => Notebook.fromMap(row)).toList();
  }

  Future<int> updateNotebook(Notebook notebook) async {
    final db = await _dbHelper.database;
    final stmt = db.prepare('''
      UPDATE ${config.DatabaseConfig.tableNotebooks}
      SET ${config.DatabaseConfig.columnName} = ?,
          ${config.DatabaseConfig.columnParentId} = CASE 
            WHEN ? IS NULL THEN NULL 
            ELSE ? 
          END,
          ${config.DatabaseConfig.columnOrderIndex} = ?,
          ${config.DatabaseConfig.columnIsFavorite} = ?,
          ${config.DatabaseConfig.columnIconId} = ?
      WHERE ${config.DatabaseConfig.columnId} = ?
      AND ${config.DatabaseConfig.columnDeletedAt} IS NULL
    ''');

    try {
      stmt.execute([
        notebook.name,
        notebook.parentId,
        notebook.parentId,
        notebook.orderIndex,
        notebook.isFavorite ? 1 : 0,
        notebook.iconId,
        notebook.id,
      ]);
      DatabaseService().notifyDatabaseChanged();
      return 1;
    } finally {
      stmt.dispose();
    }
  }

  Future<void> softDeleteNotebook(int id) async {
    final db = await _dbHelper.database;
    final now = DateTime.now().millisecondsSinceEpoch;

    final nestedNotebooks = await _getNestedNotebooks(id);

    for (final notebook in nestedNotebooks) {
      db.execute(
        '''
        UPDATE ${config.DatabaseConfig.tableNotes}
        SET ${config.DatabaseConfig.columnDeletedAt} = ?
        WHERE ${config.DatabaseConfig.columnNotebookId} = ?
        ''',
        [now, notebook.id],
      );

      db.execute(
        '''
        UPDATE ${config.DatabaseConfig.tableNotebooks}
        SET ${config.DatabaseConfig.columnDeletedAt} = ?
        WHERE ${config.DatabaseConfig.columnId} = ?
        ''',
        [now, notebook.id],
      );
    }

    db.execute(
      '''
      UPDATE ${config.DatabaseConfig.tableNotes}
      SET ${config.DatabaseConfig.columnDeletedAt} = ?
      WHERE ${config.DatabaseConfig.columnNotebookId} = ?
      ''',
      [now, id],
    );

    db.execute(
      '''
      UPDATE ${config.DatabaseConfig.tableNotebooks}
      SET ${config.DatabaseConfig.columnDeletedAt} = ?
      WHERE ${config.DatabaseConfig.columnId} = ?
      ''',
      [now, id],
    );

    DatabaseService().notifyDatabaseChanged();
  }

  Future<List<Notebook>> _getNestedNotebooks(int parentId) async {
    final db = await _dbHelper.database;
    final notebooks = <Notebook>[];

    Future<void> getChildren(int parentId) async {
      final result = db.select(
        '''
        SELECT * FROM ${config.DatabaseConfig.tableNotebooks}
        WHERE ${config.DatabaseConfig.columnParentId} = ?
        AND ${config.DatabaseConfig.columnDeletedAt} IS NULL
        ''',
        [parentId],
      );

      for (final row in result) {
        final notebook = Notebook.fromMap(row);
        notebooks.add(notebook);
        await getChildren(notebook.id!);
      }
    }

    await getChildren(parentId);
    return notebooks;
  }

  Future<void> restoreNotebook(int id) async {
    final db = await _dbHelper.database;

    final nestedNotebooks = await _getDeletedNestedNotebooks(id);

    for (final notebook in nestedNotebooks) {
      db.execute(
        '''
        UPDATE ${config.DatabaseConfig.tableNotes}
        SET ${config.DatabaseConfig.columnDeletedAt} = NULL
        WHERE ${config.DatabaseConfig.columnNotebookId} = ?
        ''',
        [notebook.id],
      );

      db.execute(
        '''
        UPDATE ${config.DatabaseConfig.tableNotebooks}
        SET ${config.DatabaseConfig.columnDeletedAt} = NULL
        WHERE ${config.DatabaseConfig.columnId} = ?
        ''',
        [notebook.id],
      );
    }

    db.execute(
      '''
      UPDATE ${config.DatabaseConfig.tableNotes}
      SET ${config.DatabaseConfig.columnDeletedAt} = NULL
      WHERE ${config.DatabaseConfig.columnNotebookId} = ?
      ''',
      [id],
    );

    db.execute(
      '''
      UPDATE ${config.DatabaseConfig.tableNotebooks}
      SET ${config.DatabaseConfig.columnDeletedAt} = NULL
      WHERE ${config.DatabaseConfig.columnId} = ?
      ''',
      [id],
    );
  }

  Future<List<Notebook>> _getDeletedNestedNotebooks(int parentId) async {
    final db = await _dbHelper.database;
    final notebooks = <Notebook>[];

    Future<void> getChildren(int parentId) async {
      final result = db.select(
        '''
        SELECT * FROM ${config.DatabaseConfig.tableNotebooks}
        WHERE ${config.DatabaseConfig.columnParentId} = ?
        AND ${config.DatabaseConfig.columnDeletedAt} IS NOT NULL
        ''',
        [parentId],
      );

      for (final row in result) {
        final notebook = Notebook.fromMap(row);
        notebooks.add(notebook);
        await getChildren(notebook.id!);
      }
    }

    await getChildren(parentId);
    return notebooks;
  }

  Future<List<Notebook>> _getDeletedNestedNotebooksForHardDelete(
    int parentId,
  ) async {
    final db = await _dbHelper.database;
    final notebooks = <Notebook>[];

    Future<void> getChildren(int parentId) async {
      final result = db.select(
        '''
        SELECT * FROM ${config.DatabaseConfig.tableNotebooks}
        WHERE ${config.DatabaseConfig.columnParentId} = ?
        ''',
        [parentId],
      );

      for (final row in result) {
        final notebook = Notebook.fromMap(row);
        notebooks.add(notebook);
        await getChildren(notebook.id!);
      }
    }

    await getChildren(parentId);
    return notebooks;
  }

  Future<void> hardDeleteNotebook(int id) async {
    final db = await _dbHelper.database;

    final nestedNotebooks = await _getDeletedNestedNotebooksForHardDelete(id);

    nestedNotebooks.sort((a, b) {
      int depthA = 0;
      int depthB = 0;
      Notebook? currentA = a;
      Notebook? currentB = b;

      while (currentA?.parentId != null) {
        depthA++;
        currentA = nestedNotebooks.firstWhereOrNull(
          (n) => n.id == currentA?.parentId,
        );
        if (currentA == null) break;
      }

      while (currentB?.parentId != null) {
        depthB++;
        currentB = nestedNotebooks.firstWhereOrNull(
          (n) => n.id == currentB?.parentId,
        );
        if (currentB == null) break;
      }

      return depthB.compareTo(depthA);
    });

    for (final notebook in nestedNotebooks) {
      db.execute(
        '''
        DELETE FROM ${config.DatabaseConfig.tableNotes}
        WHERE ${config.DatabaseConfig.columnNotebookId} = ?
        ''',
        [notebook.id],
      );

      db.execute(
        '''
        DELETE FROM ${config.DatabaseConfig.tableNotebooks}
        WHERE ${config.DatabaseConfig.columnId} = ?
        ''',
        [notebook.id],
      );
    }

    db.execute(
      '''
      DELETE FROM ${config.DatabaseConfig.tableNotes}
      WHERE ${config.DatabaseConfig.columnNotebookId} = ?
      ''',
      [id],
    );

    db.execute(
      '''
      DELETE FROM ${config.DatabaseConfig.tableNotebooks}
      WHERE ${config.DatabaseConfig.columnId} = ?
      ''',
      [id],
    );
  }

  Future<List<Notebook>> getAllNotebooks() async {
    final db = await _dbHelper.database;
    final result = db.select('''
      SELECT * FROM ${config.DatabaseConfig.tableNotebooks}
      WHERE ${config.DatabaseConfig.columnDeletedAt} IS NULL
      ORDER BY ${config.DatabaseConfig.columnName}
      ''');
    return result.map((row) => Notebook.fromMap(row)).toList();
  }

  Future<List<Notebook>> getDeletedNotebooks() async {
    final db = await _dbHelper.database;
    final result = db.select('''
      SELECT n.* FROM ${config.DatabaseConfig.tableNotebooks} n
      LEFT JOIN ${config.DatabaseConfig.tableNotebooks} p ON n.${config.DatabaseConfig.columnParentId} = p.${config.DatabaseConfig.columnId}
      WHERE n.${config.DatabaseConfig.columnDeletedAt} IS NOT NULL
      AND (p.${config.DatabaseConfig.columnDeletedAt} IS NULL OR p.${config.DatabaseConfig.columnId} IS NULL)
      ORDER BY n.${config.DatabaseConfig.columnDeletedAt} DESC
    ''');
    return result.map((row) => Notebook.fromMap(row)).toList();
  }

  Future<int> updateNotebookOrder(int notebookId, int newOrder) async {
    final db = await _dbHelper.database;
    final stmt = db.prepare('''
      UPDATE ${config.DatabaseConfig.tableNotebooks}
      SET ${config.DatabaseConfig.columnOrderIndex} = ?
      WHERE ${config.DatabaseConfig.columnId} = ?
      AND ${config.DatabaseConfig.columnDeletedAt} IS NULL
    ''');

    try {
      stmt.execute([newOrder, notebookId]);
      DatabaseService().notifyDatabaseChanged();
      return 1;
    } finally {
      stmt.dispose();
    }
  }

  Future<List<Notebook>> getFavoriteNotebooks() async {
    final db = await _dbHelper.database;
    final result = db.select('''
      SELECT * FROM ${config.DatabaseConfig.tableNotebooks}
      WHERE ${config.DatabaseConfig.columnIsFavorite} = 1
      AND ${config.DatabaseConfig.columnDeletedAt} IS NULL
      ORDER BY ${config.DatabaseConfig.columnName}
      ''');
    return result.map((row) => Notebook.fromMap(row)).toList();
  }

  Future<List<Notebook>> searchNotebooks(String query) async {
    final db = await _dbHelper.database;
    final searchQuery = '%$query%';
    final result = db.select(
      '''
      SELECT * FROM ${config.DatabaseConfig.tableNotebooks}
      WHERE ${config.DatabaseConfig.columnName} LIKE ?
      AND ${config.DatabaseConfig.columnDeletedAt} IS NULL
      ORDER BY ${config.DatabaseConfig.columnName}
    ''',
      [searchQuery],
    );
    return result.map((row) => Notebook.fromMap(row)).toList();
  }

  Future<void> reorderNotebooks(List<Notebook> notebooks) async {
    final db = await _dbHelper.database;
    db.execute('BEGIN TRANSACTION');

    try {
      final stmt = db.prepare('''
        UPDATE ${config.DatabaseConfig.tableNotebooks}
        SET ${config.DatabaseConfig.columnOrderIndex} = ?
        WHERE ${config.DatabaseConfig.columnId} = ?
        AND ${config.DatabaseConfig.columnDeletedAt} IS NULL
      ''');

      for (int i = 0; i < notebooks.length; i++) {
        stmt.execute([i, notebooks[i].id]);
      }

      stmt.dispose();
      db.execute('COMMIT');
      DatabaseService().notifyDatabaseChanged();
    } catch (e) {
      db.execute('ROLLBACK');
      rethrow;
    }
  }
}
