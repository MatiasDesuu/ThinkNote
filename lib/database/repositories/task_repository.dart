import '../database_helper.dart';
import '../database_config.dart' as config;
import '../models/task.dart';
import '../models/subtask.dart';
import '../models/task_tag.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

class TaskRepository {
  final DatabaseHelper _dbHelper;

  TaskRepository(this._dbHelper);

  Future<int> createTask(Task task) async {
    final db = await _dbHelper.database;

    final result = db.select('''
      SELECT MAX(order_index) as maxOrder
      FROM ${config.DatabaseConfig.tableTasks}
      WHERE ${config.DatabaseConfig.columnDeletedAt} IS NULL
    ''');
    final int nextOrder = (result.first['maxOrder'] as int? ?? -1) + 1;

    final stmt = db.prepare('''
      INSERT INTO ${config.DatabaseConfig.tableTasks} (
        ${config.DatabaseConfig.columnTaskName},
        ${config.DatabaseConfig.columnTaskDate},
        ${config.DatabaseConfig.columnTaskCompleted},
        ${config.DatabaseConfig.columnTaskState},
        ${config.DatabaseConfig.columnCreatedAt},
        ${config.DatabaseConfig.columnUpdatedAt},
        ${config.DatabaseConfig.columnOrderIndex},
        ${config.DatabaseConfig.columnTaskSortByPriority}
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
      ''');

    try {
      stmt.execute([
        task.name,
        task.date?.toIso8601String(),
        task.completed ? 1 : 0,
        task.state.index,
        task.createdAt.toIso8601String(),
        task.updatedAt.toIso8601String(),
        task.orderIndex != 0 ? task.orderIndex : nextOrder,
        task.sortByPriority ? 1 : 0,
      ]);
      DatabaseHelper.notifyDatabaseChanged();
      return db.lastInsertRowId;
    } finally {
      stmt.dispose();
    }
  }

  Future<Task?> getTask(int id) async {
    final db = await _dbHelper.database;
    final result = db.select(
      '''
      SELECT * FROM ${config.DatabaseConfig.tableTasks}
      WHERE ${config.DatabaseConfig.columnId} = ?
      ''',
      [id],
    );
    if (result.isEmpty) return null;

    return Task.fromMap(result.first);
  }

  Future<List<Task>> getAllTasks() async {
    final db = await _dbHelper.database;
    final result = db.select('''
      SELECT * FROM ${config.DatabaseConfig.tableTasks}
      WHERE ${config.DatabaseConfig.columnDeletedAt} IS NULL
      ORDER BY ${config.DatabaseConfig.columnOrderIndex} ASC
      ''');
    return result.map((row) => Task.fromMap(row)).toList();
  }

  Future<List<Task>> getCompletedTasks() async {
    final db = await _dbHelper.database;
    final result = db.select('''
      SELECT * FROM ${config.DatabaseConfig.tableTasks}
      WHERE ${config.DatabaseConfig.columnTaskCompleted} = 1
      AND ${config.DatabaseConfig.columnDeletedAt} IS NULL
      ORDER BY ${config.DatabaseConfig.columnTaskIsPinned} DESC,
               ${config.DatabaseConfig.columnOrderIndex} ASC
      ''');
    return result.map((row) => Task.fromMap(row)).toList();
  }

  Future<List<Task>> getPendingTasks() async {
    final db = await _dbHelper.database;
    final result = db.select('''
      SELECT * FROM ${config.DatabaseConfig.tableTasks}
      WHERE ${config.DatabaseConfig.columnTaskCompleted} = 0
      AND ${config.DatabaseConfig.columnDeletedAt} IS NULL
      ORDER BY ${config.DatabaseConfig.columnTaskIsPinned} DESC,
               ${config.DatabaseConfig.columnOrderIndex} ASC
      ''');

    return result.map((row) => Task.fromMap(row)).toList();
  }

  Future<List<Task>> getTasksWithDeadlines() async {
    final db = await _dbHelper.database;
    final result = db.select('''
      SELECT * FROM ${config.DatabaseConfig.tableTasks}
      WHERE ${config.DatabaseConfig.columnTaskDate} IS NOT NULL
      AND ${config.DatabaseConfig.columnDeletedAt} IS NULL
      ORDER BY ${config.DatabaseConfig.columnTaskDate} ASC
      ''');
    return result.map((row) => Task.fromMap(row)).toList();
  }

  Future<int> updateTask(Task task) async {
    final db = await _dbHelper.database;
    final stmt = db.prepare('''
      UPDATE ${config.DatabaseConfig.tableTasks}
      SET ${config.DatabaseConfig.columnTaskName} = ?,
          ${config.DatabaseConfig.columnTaskDate} = ?,
          ${config.DatabaseConfig.columnTaskCompleted} = ?,
          ${config.DatabaseConfig.columnTaskState} = ?,
          ${config.DatabaseConfig.columnUpdatedAt} = ?,
          ${config.DatabaseConfig.columnOrderIndex} = ?,
          ${config.DatabaseConfig.columnTaskSortByPriority} = ?,
          ${config.DatabaseConfig.columnTaskIsPinned} = ?
      WHERE ${config.DatabaseConfig.columnId} = ?
    ''');

    try {
      final params = [
        task.name,
        task.date?.toIso8601String(),
        task.completed ? 1 : 0,
        task.state.index,
        task.updatedAt.toIso8601String(),
        task.orderIndex,
        task.sortByPriority ? 1 : 0,
        task.isPinned ? 1 : 0,
        task.id,
      ];

      stmt.execute(params);
      DatabaseHelper.notifyDatabaseChanged();

      return 1;
    } finally {
      stmt.dispose();
    }
  }

  Future<void> updateTaskPinnedState(int id, bool isPinned) async {
    final db = await _dbHelper.database;
    final stmt = db.prepare('''
      UPDATE ${config.DatabaseConfig.tableTasks}
      SET ${config.DatabaseConfig.columnTaskIsPinned} = ?,
          ${config.DatabaseConfig.columnUpdatedAt} = ?
      WHERE ${config.DatabaseConfig.columnId} = ?
    ''');

    try {
      stmt.execute([isPinned ? 1 : 0, DateTime.now().toIso8601String(), id]);
      DatabaseHelper.notifyDatabaseChanged();
    } finally {
      stmt.dispose();
    }
  }

  Future<int> deleteTask(int id) async {
    final db = await _dbHelper.database;

    final stmtSubtasks = db.prepare('''
      DELETE FROM ${config.DatabaseConfig.tableSubtasks}
      WHERE ${config.DatabaseConfig.columnTaskId} = ?
    ''');

    final stmtTags = db.prepare('''
      DELETE FROM ${config.DatabaseConfig.tableTaskTags}
      WHERE ${config.DatabaseConfig.columnTagTaskId} = ?
    ''');

    final stmtTask = db.prepare('''
      DELETE FROM ${config.DatabaseConfig.tableTasks}
      WHERE ${config.DatabaseConfig.columnId} = ?
    ''');

    try {
      stmtSubtasks.execute([id]);

      stmtTags.execute([id]);

      stmtTask.execute([id]);

      await _updateSyncTimestamp(db);
      DatabaseHelper.notifyDatabaseChanged();
      return 1;
    } finally {
      stmtSubtasks.dispose();
      stmtTags.dispose();
      stmtTask.dispose();
    }
  }

  Future<void> softDeleteTask(int id) async {
    final db = await _dbHelper.database;
    db.execute(
      '''
      UPDATE ${config.DatabaseConfig.tableTasks}
      SET ${config.DatabaseConfig.columnDeletedAt} = ?
      WHERE ${config.DatabaseConfig.columnId} = ?
      ''',
      [DateTime.now().toIso8601String(), id],
    );
    DatabaseHelper.notifyDatabaseChanged();
  }

  Future<int> updateTaskOrder(int taskId, int newOrder) async {
    final db = await _dbHelper.database;
    db.execute(
      '''
      UPDATE ${config.DatabaseConfig.tableTasks}
      SET ${config.DatabaseConfig.columnOrderIndex} = ?
      WHERE ${config.DatabaseConfig.columnId} = ?
      ''',
      [newOrder, taskId],
    );
    DatabaseHelper.notifyDatabaseChanged();
    return 1;
  }

  Future<void> _updateSyncTimestamp(sqlite.Database db) async {
    db.execute('UPDATE sync_info SET last_modified = ? WHERE id = 1', [
      DateTime.now().millisecondsSinceEpoch,
    ]);
  }

  Future<int> createSubtask(Subtask subtask) async {
    final db = await _dbHelper.database;

    final result = db.select(
      '''
      SELECT MAX(order_index) as maxOrder
      FROM ${config.DatabaseConfig.tableSubtasks}
      WHERE ${config.DatabaseConfig.columnTaskId} = ?
    ''',
      [subtask.taskId],
    );
    final int nextOrder = (result.first['maxOrder'] as int? ?? -1) + 1;

    final stmt = db.prepare('''
      INSERT INTO ${config.DatabaseConfig.tableSubtasks} (
        ${config.DatabaseConfig.columnTaskId},
        ${config.DatabaseConfig.columnSubtaskText},
        ${config.DatabaseConfig.columnSubtaskCompleted},
        ${config.DatabaseConfig.columnOrderIndex},
        ${config.DatabaseConfig.columnSubtaskPriority},
        ${config.DatabaseConfig.columnParentId}
      ) VALUES (?, ?, ?, ?, ?, ?)
      ''');

    try {
      stmt.execute([
        subtask.taskId,
        subtask.text,
        subtask.completed ? 1 : 0,
        subtask.orderIndex != 0 ? subtask.orderIndex : nextOrder,
        subtask.priority.index,
        subtask.parentId,
      ]);
      await _updateSyncTimestamp(db);
      DatabaseHelper.notifyDatabaseChanged();
      return db.lastInsertRowId;
    } finally {
      stmt.dispose();
    }
  }

  Future<List<Subtask>> getSubtasksByTaskId(int taskId) async {
    final db = await _dbHelper.database;
    final result = db.select(
      '''
      SELECT * FROM ${config.DatabaseConfig.tableSubtasks}
      WHERE ${config.DatabaseConfig.columnTaskId} = ?
      ORDER BY ${config.DatabaseConfig.columnSubtaskCompleted}, ${config.DatabaseConfig.columnOrderIndex}
      ''',
      [taskId],
    );
    return result.map((row) => Subtask.fromMap(row)).toList();
  }

  Future<List<Subtask>> getSubtasksByTaskIdWithPrioritySort(int taskId) async {
    final db = await _dbHelper.database;
    final result = db.select(
      '''
      SELECT * FROM ${config.DatabaseConfig.tableSubtasks}
      WHERE ${config.DatabaseConfig.columnTaskId} = ?
      ORDER BY ${config.DatabaseConfig.columnSubtaskCompleted}, ${config.DatabaseConfig.columnSubtaskPriority} DESC, ${config.DatabaseConfig.columnOrderIndex}
      ''',
      [taskId],
    );
    return result.map((row) => Subtask.fromMap(row)).toList();
  }

  Future<int> updateSubtask(Subtask subtask) async {
    final db = await _dbHelper.database;
    final stmt = db.prepare('''
      UPDATE ${config.DatabaseConfig.tableSubtasks}
      SET ${config.DatabaseConfig.columnSubtaskText} = ?,
          ${config.DatabaseConfig.columnSubtaskCompleted} = ?,
          ${config.DatabaseConfig.columnOrderIndex} = ?,
          ${config.DatabaseConfig.columnSubtaskPriority} = ?,
          ${config.DatabaseConfig.columnParentId} = ?
      WHERE ${config.DatabaseConfig.columnId} = ?
    ''');

    try {
      stmt.execute([
        subtask.text,
        subtask.completed ? 1 : 0,
        subtask.orderIndex,
        subtask.priority.index,
        subtask.parentId,
        subtask.id,
      ]);
      await _updateSyncTimestamp(db);
      DatabaseHelper.notifyDatabaseChanged();
      return 1;
    } finally {
      stmt.dispose();
    }
  }

  Future<int> deleteSubtask(int id) async {
    final db = await _dbHelper.database;
    final stmt = db.prepare('''
      DELETE FROM ${config.DatabaseConfig.tableSubtasks}
      WHERE ${config.DatabaseConfig.columnId} = ?
    ''');

    try {
      stmt.execute([id]);
      await _updateSyncTimestamp(db);
      DatabaseHelper.notifyDatabaseChanged();
      return 1;
    } finally {
      stmt.dispose();
    }
  }

  Future<void> setHabitCompletion(
    int subtaskId,
    String isoDate,
    bool completed,
  ) async {
    final db = await _dbHelper.database;
    if (completed) {
      final stmt = db.prepare(
        'INSERT OR IGNORE INTO habit_completions (subtask_id, date) VALUES (?, ?)',
      );
      try {
        stmt.execute([subtaskId, isoDate]);
      } finally {
        stmt.dispose();
      }
    } else {
      final stmt = db.prepare(
        'DELETE FROM habit_completions WHERE subtask_id = ? AND date = ?',
      );
      try {
        stmt.execute([subtaskId, isoDate]);
      } finally {
        stmt.dispose();
      }
    }

    await _updateSyncTimestamp(db);
    DatabaseHelper.notifyDatabaseChanged();
  }

  Future<List<String>> getHabitCompletionsForSubtask(int subtaskId) async {
    final db = await _dbHelper.database;
    final result = db.select(
      'SELECT date FROM habit_completions WHERE subtask_id = ?',
      [subtaskId],
    );
    return result.map((r) => r['date'] as String).toList();
  }

  Future<Map<int, List<String>>> getHabitCompletionsForTask(int taskId) async {
    final db = await _dbHelper.database;
    final result = db.select(
      '''
      SELECT hc.subtask_id as subtask_id, hc.date as date
      FROM habit_completions hc
      JOIN ${config.DatabaseConfig.tableSubtasks} s ON hc.subtask_id = s.${config.DatabaseConfig.columnId}
      WHERE s.${config.DatabaseConfig.columnTaskId} = ?
    ''',
      [taskId],
    );

    final Map<int, List<String>> map = {};
    for (final row in result) {
      final subId = row['subtask_id'] as int;
      final date = row['date'] as String;
      map.putIfAbsent(subId, () => []).add(date);
    }
    return map;
  }

  Future<int> updateSubtaskOrder(int subtaskId, int newOrder) async {
    final db = await _dbHelper.database;
    db.execute(
      '''
      UPDATE ${config.DatabaseConfig.tableSubtasks}
      SET ${config.DatabaseConfig.columnOrderIndex} = ?
      WHERE ${config.DatabaseConfig.columnId} = ?
      ''',
      [newOrder, subtaskId],
    );
    await _updateSyncTimestamp(db);
    DatabaseHelper.notifyDatabaseChanged();
    return 1;
  }

  Future<List<TaskTag>> getAllTags() async {
    final db = await _dbHelper.database;
    final result = db.select('''
      SELECT DISTINCT ${config.DatabaseConfig.columnTagName} as name, 
             ${config.DatabaseConfig.columnId} as id,
             NULL as task_id
      FROM ${config.DatabaseConfig.tableTaskTags}
      GROUP BY ${config.DatabaseConfig.columnTagName}
      ORDER BY ${config.DatabaseConfig.columnTagName}
      ''');
    return result.map((row) => TaskTag.fromMap(row)).toList();
  }

  Future<List<TaskTag>> getTagsByTaskId(int taskId) async {
    final db = await _dbHelper.database;
    final result = db.select(
      '''
      SELECT * FROM ${config.DatabaseConfig.tableTaskTags}
      WHERE ${config.DatabaseConfig.columnTagTaskId} = ?
      ORDER BY ${config.DatabaseConfig.columnTagName}
      ''',
      [taskId],
    );
    return result.map((row) => TaskTag.fromMap(row)).toList();
  }

  Future<int> createTag(TaskTag tag) async {
    final db = await _dbHelper.database;
    final stmt = db.prepare('''
      INSERT INTO ${config.DatabaseConfig.tableTaskTags} (
        ${config.DatabaseConfig.columnTagName},
        ${config.DatabaseConfig.columnTagTaskId}
      ) VALUES (?, ?)
      ''');

    try {
      stmt.execute([tag.name, tag.taskId]);
      DatabaseHelper.notifyDatabaseChanged();
      return db.lastInsertRowId;
    } finally {
      stmt.dispose();
    }
  }

  Future<int> deleteTag(int id) async {
    final db = await _dbHelper.database;
    final stmt = db.prepare('''
      DELETE FROM ${config.DatabaseConfig.tableTaskTags}
      WHERE ${config.DatabaseConfig.columnId} = ?
    ''');

    try {
      stmt.execute([id]);
      DatabaseHelper.notifyDatabaseChanged();
      return 1;
    } finally {
      stmt.dispose();
    }
  }

  Future<void> deleteTagByNameAndTaskId(String name, int taskId) async {
    final db = await _dbHelper.database;
    db.execute(
      '''
      DELETE FROM ${config.DatabaseConfig.tableTaskTags}
      WHERE ${config.DatabaseConfig.columnTagName} = ? AND ${config.DatabaseConfig.columnTagTaskId} = ?
      ''',
      [name, taskId],
    );
  }

  Future<void> assignTagToTask(String tagName, int taskId) async {
    final db = await _dbHelper.database;

    final stmt = db.prepare('''
      INSERT OR IGNORE INTO ${config.DatabaseConfig.tableTaskTags} (
        ${config.DatabaseConfig.columnTagName},
        ${config.DatabaseConfig.columnTagTaskId}
      ) VALUES (?, ?)
    ''');

    try {
      stmt.execute([tagName, taskId]);
      DatabaseHelper.notifyDatabaseChanged();
    } finally {
      stmt.dispose();
    }
  }

  Future<void> removeTagFromTask(String tagName, int taskId) async {
    final db = await _dbHelper.database;

    final stmt = db.prepare('''
      DELETE FROM ${config.DatabaseConfig.tableTaskTags}
      WHERE ${config.DatabaseConfig.columnTagName} = ?
      AND ${config.DatabaseConfig.columnTagTaskId} = ?
    ''');

    try {
      stmt.execute([tagName, taskId]);
      DatabaseHelper.notifyDatabaseChanged();
    } finally {
      stmt.dispose();
    }
  }

  Future<List<Task>> getTasksByTag(String tagName) async {
    final db = await _dbHelper.database;
    final result = db.select(
      '''
      SELECT t.* FROM ${config.DatabaseConfig.tableTasks} t
      JOIN ${config.DatabaseConfig.tableTaskTags} tt ON t.${config.DatabaseConfig.columnId} = tt.${config.DatabaseConfig.columnTagTaskId}
      WHERE tt.${config.DatabaseConfig.columnTagName} = ?
      AND t.${config.DatabaseConfig.columnDeletedAt} IS NULL
      ORDER BY t.${config.DatabaseConfig.columnOrderIndex}
      ''',
      [tagName],
    );
    return result.map((row) => Task.fromMap(row)).toList();
  }

  Future<List<Task>> getUnassignedTasks() async {
    final db = await _dbHelper.database;
    final result = db.select('''
      SELECT * FROM ${config.DatabaseConfig.tableTasks}
      WHERE ${config.DatabaseConfig.columnTaskDate} IS NOT NULL
      AND ${config.DatabaseConfig.columnTaskState} = 3
      AND ${config.DatabaseConfig.columnDeletedAt} IS NULL
      ORDER BY ${config.DatabaseConfig.columnTaskDate} ASC
      ''');
    return result.map((row) => Task.fromMap(row)).toList();
  }
}
