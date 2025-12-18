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
  static const String tableWorkflowsGames = 'workflows_games';
  static const String tableWorkflowsGameTasks = 'workflows_game_tasks';
  static const String tableWorkflowsGameManagers = 'workflows_game_managers';
  static const String tableWorkflowsGameImages = 'workflows_game_images';
  static const String tableWorkflowsBookmarks = 'workflows_bookmarks';
  static const String tableCalendarEvents = 'calendar_events';
  static const String tableCalendarEventStatuses = 'calendar_event_statuses';
  static const String tableDiary = 'diary';

  // Columnas para la tabla notebooks
  static const String columnId = 'id';
  static const String columnName = 'name';
  static const String columnParentId = 'parent_id';
  static const String columnCreatedAt = 'created_at';
  static const String columnOrder = 'order';
  static const String columnOrderIndex = 'order_index';
  static const String columnIconId = 'icon_id';

  // Columnas para la tabla notes
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

  // Columnas para la tabla tasks
  static const String columnTaskName = 'name';
  static const String columnTaskDate = 'date';
  static const String columnTaskCompleted = 'completed';
  static const String columnTaskState = 'state';
  static const String columnTaskSortByPriority = 'sort_by_priority';
  static const String columnTaskIsPinned = 'is_pinned';

  // Columnas para la tabla subtasks
  static const String columnSubtaskText = 'text';
  static const String columnSubtaskCompleted = 'completed';
  static const String columnSubtaskPriority = 'priority';
  static const String columnTaskId = 'task_id';

  // Columnas para la tabla task_tags
  static const String columnTagName = 'name';
  static const String columnTagTaskId = 'task_id';

  // Columnas para las tablas de workflows
  static const String columnGameId = 'id';
  static const String columnGameName = 'name';
  static const String columnGameDeadline = 'deadline';
  static const String columnGameReportsUrl = 'reports_url';
  static const String columnGameChangelogUrl = 'changelog_url';
  static const String columnGameUrl = 'url';
  static const String columnGameNotes = 'notes';
  static const String columnGameIsDone = 'is_done';
  static const String columnGameOrder = 'order_index';
  static const String columnGameFolderPath = 'folder_path';

  // Columnas para la tabla de tareas de juegos
  static const String columnGameTaskId = 'id';
  static const String columnGameTaskName = 'name';
  static const String columnGameTaskStatus = 'status';
  static const String columnGameTaskGameId = 'game_id';

  // Columnas para la tabla de managers de juegos
  static const String columnGameManagerId = 'id';
  static const String columnGameManagerType = 'type';
  static const String columnGameManagerName = 'name';
  static const String columnGameManagerGameId = 'game_id';

  // Columnas para la tabla de bookmarks
  static const String columnBookmarkId = 'id';
  static const String columnBookmarkTitle = 'title';
  static const String columnBookmarkUrl = 'url';
  static const String columnBookmarkOrder = 'order_index';

  // Tablas para Content Moderation
  static const String tableContentItems = 'content_items';
  static const String tableContentReportConfig = 'content_report_config';

  // Columnas para la tabla de Content Items
  static const String columnContentItemId = 'id';
  static const String columnContentItemName = 'name';
  static const String columnContentItemScreenshotUrl = 'screenshot_url';
  static const String columnContentItemIsDone = 'is_done';
  static const String columnContentItemOrder = 'order_index';
  static const String columnContentItemRemoved = 'removed';
  static const String columnContentItemHidden = 'hidden';

  // Columnas para la tabla de Content Report Config
  static const String columnContentReportConfigId = 'id';
  static const String columnContentReportConfigUrl = 'url';
  static const String columnContentReportConfigHammerText = 'hammer_text';
  static const String columnContentReportConfigIsScrollSyncEnabled =
      'is_scroll_sync_enabled';

  // Columnas para la tabla de imágenes de juegos
  static const String columnGameImageId = 'id';
  static const String columnGameImagePath = 'image_path';
  static const String columnGameImageGameId = 'game_id';
  static const String columnGameImageOrder = 'order_index';

  // Columnas para la tabla calendar_events
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

  // Columnas para la tabla calendar_event_statuses
  static const String columnCalendarEventStatusId = 'id';
  static const String columnCalendarEventStatusName = 'name';
  static const String columnCalendarEventStatusColor = 'color';
  static const String columnCalendarEventStatusOrderIndex = 'order_index';

  // Columnas para la tabla diary
  static const String columnDate = 'date';
}
