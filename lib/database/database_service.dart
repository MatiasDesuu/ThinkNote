import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:archive/archive.dart';
import 'database_helper.dart';
import 'database_config.dart' as config;
import 'package:sqlite3/sqlite3.dart' as sqlite;
import 'dart:async';
import 'repositories/task_repository.dart';
import 'services/task_service.dart';
import 'dart:convert';
import 'models/task.dart';
import 'models/subtask.dart';
import 'bookmark_service.dart';
import 'repositories/think_repository.dart';
import 'services/think_service.dart';
import 'dart:developer' as developer;
import 'html_generator.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;

  late final TaskRepository _taskRepository;
  late final TaskService _taskService;
  late final BookmarkService _bookmarkService;
  late final ThinkRepository _thinkRepository;
  late final ThinkService _thinkService;
  bool _isInitialized = false;

  bool get isInitialized => _isInitialized;

  DatabaseService._internal() {
    final dbHelper = DatabaseHelper();
    _taskRepository = TaskRepository(dbHelper);
    _taskService = TaskService(_taskRepository);
    _bookmarkService = BookmarkService(dbHelper);
    _thinkRepository = ThinkRepository(dbHelper);
    _thinkService = ThinkService(_thinkRepository);

    DatabaseHelper.onDatabaseChanged.listen((_) {
      _databaseChangeController.add(null);
    });
  }

  final _databaseChangeController = StreamController<void>.broadcast();
  Stream<void> get onDatabaseChanged => _databaseChangeController.stream;

  TaskService get taskService => _taskService;

  BookmarkService get bookmarkService => _bookmarkService;

  ThinkService get thinkService => _thinkService;

  void notifyDatabaseChanged() {
    _databaseChangeController.add(null);

    DatabaseHelper.notifyDatabaseChanged();
  }

  Future<int> _countEntities(Directory dir) async {
    final entities = await dir.list(recursive: true).toList();
    return entities.length;
  }

  Future<void> importFromZip(
    String zipPath, {
    void Function(double)? onProgress,
  }) async {
    final tempDir = await Directory.systemTemp.createTemp('thinknote_import_');
    try {
      final bytes = await File(zipPath).readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);

      final totalEntries = archive.length;
      int extractedCount = 0;

      for (final file in archive) {
        final outFile = File(path.join(tempDir.path, file.name));
        if (file.isFile) {
          await outFile.create(recursive: true);
          await outFile.writeAsBytes(file.content as List<int>);
        }
        extractedCount++;
        onProgress?.call((extractedCount / totalEntries) * 0.5);
      }

      final dbHelper = DatabaseHelper();
      final db = await dbHelper.database;

      final totalToProcess = await _countEntities(tempDir);
      int processedCount = 0;

      await _processDirectory(tempDir, db, null, (processed) {
        processedCount += processed;
        onProgress?.call(0.5 + ((processedCount / totalToProcess) * 0.5));
      });

      notifyDatabaseChanged();
    } finally {
      await tempDir.delete(recursive: true);
    }
  }

  Future<void> importFromFolder(
    String folderPath, {
    void Function(double)? onProgress,
  }) async {
    try {
      final sourceDir = Directory(folderPath);
      if (!await sourceDir.exists()) {
        throw Exception('Source folder does not exist');
      }

      final dbHelper = DatabaseHelper();
      final db = await dbHelper.database;

      final totalEntities = await _countEntities(sourceDir);
      int processedCount = 0;

      await _processDirectoryFromFolder(sourceDir, db, null, (processed) {
        processedCount += processed;
        onProgress?.call(processedCount / totalEntities);
      });

      final thinksDir = Directory(path.join(folderPath, 'Thinks'));
      if (await thinksDir.exists()) {
        await _importThinksFromFolder(thinksDir, db, (processed) {
          processedCount += processed;
          onProgress?.call(processedCount / totalEntities);
        });
      }

      notifyDatabaseChanged();
    } catch (e) {
      developer.log('Error importing from folder: $e', name: 'DatabaseService');
      throw Exception('Error importing from folder: $e');
    }
  }

  Future<void> _processDirectory(
    Directory dir,
    sqlite.Database db,
    int? parentId,
    void Function(int) onItemProcessed,
  ) async {
    final entities = await dir.list().toList();

    for (final entity in entities) {
      if (entity is Directory) {
        db.execute(
          '''
          INSERT INTO ${config.DatabaseConfig.tableNotebooks} (
            ${config.DatabaseConfig.columnName},
            ${config.DatabaseConfig.columnParentId},
            ${config.DatabaseConfig.columnCreatedAt}
          ) VALUES (?, ?, ?)
        ''',
          [
            path.basename(entity.path),
            parentId,
            DateTime.now().millisecondsSinceEpoch,
          ],
        );

        final result = db.select('SELECT last_insert_rowid() as id');
        final notebookId = result.first['id'] as int;

        onItemProcessed(1);

        await _processDirectory(entity, db, notebookId, onItemProcessed);
      }
    }

    for (final entity in entities) {
      if (entity is File && path.extension(entity.path) == '.md') {
        final content = await entity.readAsString();
        final title = path.basenameWithoutExtension(entity.path);

        db.execute(
          '''
          INSERT INTO ${config.DatabaseConfig.tableNotes} (
            ${config.DatabaseConfig.columnTitle},
            ${config.DatabaseConfig.columnContent},
            ${config.DatabaseConfig.columnNotebookId},
            ${config.DatabaseConfig.columnCreatedAt},
            ${config.DatabaseConfig.columnUpdatedAt},
            ${config.DatabaseConfig.columnIsFavorite}
          ) VALUES (?, ?, ?, ?, ?, ?)
        ''',
          [
            title,
            content,
            parentId,
            DateTime.now().millisecondsSinceEpoch,
            DateTime.now().millisecondsSinceEpoch,
            0,
          ],
        );
        onItemProcessed(1);
      }
    }
  }

  Future<void> _processDirectoryFromFolder(
    Directory dir,
    sqlite.Database db,
    int? parentId,
    void Function(int) onItemProcessed,
  ) async {
    final entities = await dir.list().toList();

    final folders =
        entities
            .where(
              (entity) =>
                  entity is Directory && path.basename(entity.path) != 'Thinks',
            )
            .toList();

    for (final entity in folders) {
      if (entity is Directory) {
        db.execute(
          '''
          INSERT INTO ${config.DatabaseConfig.tableNotebooks} (
            ${config.DatabaseConfig.columnName},
            ${config.DatabaseConfig.columnParentId},
            ${config.DatabaseConfig.columnCreatedAt}
          ) VALUES (?, ?, ?)
        ''',
          [
            path.basename(entity.path),
            parentId,
            DateTime.now().millisecondsSinceEpoch,
          ],
        );

        final result = db.select('SELECT last_insert_rowid() as id');
        final notebookId = result.first['id'] as int;

        onItemProcessed(1);

        await _processDirectoryFromFolder(
          entity,
          db,
          notebookId,
          onItemProcessed,
        );
      }
    }

    final files =
        entities
            .where(
              (entity) =>
                  entity is File &&
                  (path.extension(entity.path) == '.txt' ||
                      path.extension(entity.path) == '.md'),
            )
            .toList();

    int? effectiveParentId = parentId;
    if (parentId == null && files.isNotEmpty) {
      db.execute(
        '''
        INSERT INTO ${config.DatabaseConfig.tableNotebooks} (
          ${config.DatabaseConfig.columnName},
          ${config.DatabaseConfig.columnParentId},
          ${config.DatabaseConfig.columnCreatedAt}
        ) VALUES (?, ?, ?)
      ''',
        ['Imported Notes', null, DateTime.now().millisecondsSinceEpoch],
      );

      final result = db.select('SELECT last_insert_rowid() as id');
      effectiveParentId = result.first['id'] as int;
    }

    for (final entity in entities) {
      if (entity is File &&
          (path.extension(entity.path) == '.txt' ||
              path.extension(entity.path) == '.md')) {
        final content = await entity.readAsString(encoding: utf8);
        final title = path.basenameWithoutExtension(entity.path);

        db.execute(
          '''
          INSERT INTO ${config.DatabaseConfig.tableNotes} (
            ${config.DatabaseConfig.columnTitle},
            ${config.DatabaseConfig.columnContent},
            ${config.DatabaseConfig.columnNotebookId},
            ${config.DatabaseConfig.columnCreatedAt},
            ${config.DatabaseConfig.columnUpdatedAt},
            ${config.DatabaseConfig.columnIsFavorite}
          ) VALUES (?, ?, ?, ?, ?, ?)
        ''',
          [
            title,
            content,
            effectiveParentId,
            DateTime.now().millisecondsSinceEpoch,
            DateTime.now().millisecondsSinceEpoch,
            0,
          ],
        );
        onItemProcessed(1);
      }
    }
  }

  Future<void> _importThinksFromFolder(
    Directory thinksDir,
    sqlite.Database db,
    void Function(int) onItemProcessed,
  ) async {
    final entities = await thinksDir.list().toList();

    for (final entity in entities) {
      if (entity is File &&
          (path.extension(entity.path) == '.txt' ||
              path.extension(entity.path) == '.md')) {
        final content = await entity.readAsString(encoding: utf8);
        final title = path.basenameWithoutExtension(entity.path);

        db.execute(
          '''
          INSERT INTO ${config.DatabaseConfig.tableThinks} (
            ${config.DatabaseConfig.columnTitle},
            ${config.DatabaseConfig.columnContent},
            ${config.DatabaseConfig.columnCreatedAt},
            ${config.DatabaseConfig.columnUpdatedAt}
          ) VALUES (?, ?, ?, ?)
        ''',
          [
            title,
            content,
            DateTime.now().millisecondsSinceEpoch,
            DateTime.now().millisecondsSinceEpoch,
          ],
        );
        onItemProcessed(1);
      }
    }
  }

  Future<void> deleteDatabase() async {
    try {
      final dbHelper = DatabaseHelper();
      await dbHelper.resetDatabase();

      notifyDatabaseChanged();
    } catch (e) {
      throw Exception('Error deleting database: $e');
    }
  }

  Future<void> optimizeDatabase() async {
    try {
      final dbHelper = DatabaseHelper();
      final db = await dbHelper.database;
      db.execute('VACUUM');
      notifyDatabaseChanged();
    } catch (e) {
      throw Exception('Error optimizing database: $e');
    }
  }

  Future<void> migrateTasksFromJson(Directory rootDir) async {
    final tasksDir = Directory(path.join(rootDir.path, '.todos'));
    if (!await tasksDir.exists()) return;

    final files =
        await tasksDir
            .list()
            .where(
              (entity) =>
                  entity is File &&
                  path.extension(entity.path) == '.json' &&
                  path.basename(entity.path) != 'tags.json',
            )
            .toList();

    final tagsFile = File(path.join(tasksDir.path, 'tags.json'));
    List<String> allTags = [];
    if (await tagsFile.exists()) {
      try {
        final tagsContent = await tagsFile.readAsString();
        final tagsJson = await json.decode(tagsContent);
        if (tagsJson is List) {
          allTags = tagsJson.map((tag) => tag.toString()).toList();
        }
      } catch (e) {
        print('Error loading tags: $e');
      }
    }

    for (final tag in allTags) {
      await _taskService.addTag(tag);
    }

    for (final file in files) {
      if (file is File) {
        try {
          final content = await file.readAsString();
          final todoJson = await json.decode(content);

          final now = DateTime.now();
          final task = Task(
            name: todoJson['nombre'] ?? 'Untitled',
            date:
                todoJson['fecha'] != null
                    ? DateTime.parse(todoJson['fecha'])
                    : null,
            completed: todoJson['completado'] ?? false,
            state: TaskState.values[todoJson['estado'] ?? 0],
            createdAt: now,
            updatedAt: now,
            orderIndex: todoJson['orden'] ?? 0,
            sortByPriority: todoJson['ordenarPorPrioridad'] ?? false,
          );

          final taskId = await _taskRepository.createTask(task);

          if (todoJson['tags'] is List) {
            for (final tag in todoJson['tags']) {
              await _taskService.assignTagToTask(tag.toString(), taskId);
            }
          }

          if (todoJson['subtareas'] is List) {
            for (final subtareaJson in todoJson['subtareas']) {
              final subtask = Subtask(
                taskId: taskId,
                text: subtareaJson['texto'] ?? '',
                completed: subtareaJson['completada'] ?? false,
                orderIndex: subtareaJson['orden'] ?? 0,
                priority:
                    SubtaskPriority.values[subtareaJson['prioridad'] ?? 1],
              );

              await _taskRepository.createSubtask(subtask);
            }
          }
        } catch (e) {
          print('Error migrating task ${file.path}: $e');
        }
      }
    }

    notifyDatabaseChanged();
  }

  Future<void> initializeDatabase() async {
    try {
      if (Platform.isAndroid) {
        final dbPath = await config.DatabaseConfig.databasePath;
        final dbDir = dbPath.substring(0, dbPath.lastIndexOf('/'));
        await Directory(dbDir).create(recursive: true);
      }

      final dbHelper = DatabaseHelper();
      await dbHelper.database;

      _isInitialized = true;
    } catch (e) {
      developer.log('Error initializing database: $e', name: 'DatabaseService');
      rethrow;
    }
  }

  Future<void> exportDatabase(String destinationPath) async {
    try {
      final dbPath = await config.DatabaseConfig.databasePath;
      final sourceFile = File(dbPath);

      if (!await sourceFile.exists()) {
        throw Exception('Database file not found');
      }

      final destinationFile = File(destinationPath);

      final destinationDir = destinationFile.parent;
      if (!await destinationDir.exists()) {
        await destinationDir.create(recursive: true);
      }

      await sourceFile.copy(destinationPath);
    } catch (e) {
      developer.log('Error exporting database: $e', name: 'DatabaseService');
      throw Exception('Error exporting database: $e');
    }
  }

  Future<void> exportToFiles(String destinationPath) async {
    try {
      final dbHelper = DatabaseHelper();
      final db = await dbHelper.database;

      final destinationDir = Directory(destinationPath);
      if (!await destinationDir.exists()) {
        await destinationDir.create(recursive: true);
      }

      final notebooks = db.select('''
        SELECT * FROM ${config.DatabaseConfig.tableNotebooks}
        WHERE ${config.DatabaseConfig.columnDeletedAt} IS NULL
        ORDER BY ${config.DatabaseConfig.columnOrderIndex}, ${config.DatabaseConfig.columnName}
      ''');

      final Map<int, Map<String, dynamic>> notebooksMap = {};
      for (final notebook in notebooks) {
        notebooksMap[notebook['id'] as int] = notebook;
      }

      await _exportNotebookStructure(
        db,
        notebooks,
        notebooksMap,
        destinationPath,
        null,
      );

      await _exportThinks(db, destinationPath);
    } catch (e) {
      developer.log(
        'Error exporting database to files: $e',
        name: 'DatabaseService',
      );
      throw Exception('Error exporting database to files: $e');
    }
  }

  Future<void> _exportNotebookStructure(
    sqlite.Database db,
    List<Map<String, dynamic>> notebooks,
    Map<int, Map<String, dynamic>> notebooksMap,
    String basePath,
    int? parentId,
  ) async {
    final currentNotebooks =
        notebooks
            .where((notebook) => notebook['parent_id'] == parentId)
            .toList();

    for (final notebook in currentNotebooks) {
      final notebookId = notebook['id'] as int;
      final notebookName = notebook['name'] as String;

      final safeFolderName = _sanitizeFileName(notebookName);
      final notebookPath = path.join(basePath, safeFolderName);

      final notebookDir = Directory(notebookPath);
      if (!await notebookDir.exists()) {
        await notebookDir.create(recursive: true);
      }

      await _exportNotesFromNotebook(db, notebookId, notebookPath);

      await _exportNotebookStructure(
        db,
        notebooks,
        notebooksMap,
        notebookPath,
        notebookId,
      );
    }
  }

  Future<void> _exportNotesFromNotebook(
    sqlite.Database db,
    int notebookId,
    String notebookPath,
  ) async {
    final notes = db.select(
      '''
      SELECT * FROM ${config.DatabaseConfig.tableNotes}
      WHERE ${config.DatabaseConfig.columnNotebookId} = ?
      AND ${config.DatabaseConfig.columnDeletedAt} IS NULL
      ORDER BY ${config.DatabaseConfig.columnOrderNoteIndex}, ${config.DatabaseConfig.columnTitle}
    ''',
      [notebookId],
    );

    for (final note in notes) {
      final title = note['title'] as String;
      final content = note['content'] as String;

      final safeFileName = _sanitizeFileName(title);
      final filePath = path.join(notebookPath, '$safeFileName.txt');

      final noteFile = File(filePath);
      await noteFile.writeAsString(content, encoding: utf8);
    }
  }

  String _sanitizeFileName(String fileName) {
    return fileName
        .replaceAll(RegExp(r'[<>:"/\\|?*]'), '_')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  Future<void> _exportThinks(sqlite.Database db, String basePath) async {
    final thinksPath = path.join(basePath, 'Thinks');
    final thinksDir = Directory(thinksPath);
    if (!await thinksDir.exists()) {
      await thinksDir.create(recursive: true);
    }

    final thinks = db.select('''
      SELECT * FROM ${config.DatabaseConfig.tableThinks}
      WHERE ${config.DatabaseConfig.columnDeletedAt} IS NULL
      ORDER BY ${config.DatabaseConfig.columnCreatedAt}
    ''');

    for (final think in thinks) {
      final title = think['title'] as String;
      final content = think['content'] as String;

      final safeFileName = _sanitizeFileName(title);
      final filePath = path.join(thinksPath, '$safeFileName.txt');

      final thinkFile = File(filePath);
      await thinkFile.writeAsString(content, encoding: utf8);
    }
  }

  Future<void> exportBookmarksToHtml(String destinationPath) async {
    try {
      final bookmarks = await _bookmarkService.getAllBookmarksWithTags();

      final htmlContent = await HtmlGenerator.generateBookmarksHtml(
        bookmarks,
        _bookmarkService,
      );

      final htmlFile = File(destinationPath);
      await htmlFile.writeAsString(htmlContent, encoding: utf8);
    } catch (e) {
      developer.log(
        'Error exporting bookmarks to HTML: $e',
        name: 'DatabaseService',
      );
      throw Exception('Error exporting bookmarks to HTML: $e');
    }
  }

  void dispose() {
    _databaseChangeController.close();
    _thinkService.dispose();
  }
}
