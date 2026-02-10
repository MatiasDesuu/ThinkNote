import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

class DatabaseConfig {
  static const String databaseName = 'thinknote.db';
  static const int databaseVersion = 1;

  static Future<String> get databasePath async {
    final Directory appDir = await getApplicationDocumentsDirectory();
    final Directory dbDir = Directory(join(appDir.path, 'ThinkDatabases'));

    if (!await dbDir.exists()) {
      await dbDir.create(recursive: true);
    }

    return join(dbDir.path, databaseName);
  }

  static const String tableNotebooks = 'notebooks';
  static const String tableNotes = 'notes';
  static const String tableTasks = 'tasks';
  static const String tableSubtasks = 'subtasks';
  static const String tableTags = 'tags';
  static const String tableTaskTags = 'task_tags';
  static const String tableThinks = 'thinks';
  static const String tableCalendarEvents = 'calendar_events';
  static const String tableCalendarEventStatuses = 'calendar_event_statuses';

  static const String columnId = 'id';
  static const String columnName = 'name';
  static const String columnParentId = 'parent_id';
  static const String columnCreatedAt = 'created_at';
  static const String columnOrder = 'order';
  static const String columnOrderIndex = 'order_index';
  static const String columnIconId = 'icon_id';

  static const String columnTitle = 'title';
  static const String columnContent = 'content';
  static const String columnNotebookId = 'notebook_id';
  static const String columnUpdatedAt = 'updated_at';
  static const String columnDeletedAt = 'deleted_at';
  static const String columnIsFavorite = 'is_favorite';
  static const String columnTags = 'tags';
  static const String columnOrderNote = 'order';
  static const String columnOrderNoteIndex = 'order_index';
  static const String columnIsTask = 'is_task';
  static const String columnIsCompleted = 'is_completed';
  static const String columnNoteIsPinned = 'is_pinned';

  static const String columnTaskName = 'name';
  static const String columnTaskDate = 'date';
  static const String columnTaskCompleted = 'completed';
  static const String columnTaskState = 'state';
  static const String columnTaskSortByPriority = 'sort_by_priority';
  static const String columnTaskIsPinned = 'is_pinned';

  static const String columnSubtaskText = 'text';
  static const String columnSubtaskCompleted = 'completed';
  static const String columnSubtaskPriority = 'priority';
  static const String columnTaskId = 'task_id';

  static const String columnTagName = 'name';
  static const String columnTagTaskId = 'task_id';

  static const String columnCalendarEventId = 'id';
  static const String columnCalendarEventTitle = 'title';
  static const String columnCalendarEventDescription = 'description';
  static const String columnCalendarEventDate = 'date';
  static const String columnCalendarEventNoteId = 'note_id';
  static const String columnCalendarEventCreatedAt = 'created_at';
  static const String columnCalendarEventUpdatedAt = 'updated_at';
  static const String columnCalendarEventDeletedAt = 'deleted_at';
  static const String columnCalendarEventColor = 'color';
  static const String columnCalendarEventOrderIndex = 'order_index';
  static const String columnCalendarEventStatus = 'status';

  static const String columnCalendarEventStatusId = 'id';
  static const String columnCalendarEventStatusName = 'name';
  static const String columnCalendarEventStatusColor = 'color';
  static const String columnCalendarEventStatusOrderIndex = 'order_index';
}
