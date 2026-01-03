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

    // Listen to DatabaseHelper changes and propagate them
    DatabaseHelper.onDatabaseChanged.listen((_) {
      _databaseChangeController.add(null);
    });
  }

  // Stream controller para notificar cambios en la base de datos
  final _databaseChangeController = StreamController<void>.broadcast();
  Stream<void> get onDatabaseChanged => _databaseChangeController.stream;

  // Accessor for task service
  TaskService get taskService => _taskService;

  // Accessor for bookmark service
  BookmarkService get bookmarkService => _bookmarkService;

  // Accessor for think service
  ThinkService get thinkService => _thinkService;

  // Method to notify database changes
  void notifyDatabaseChanged() {
    _databaseChangeController.add(null);
    // Also notify through DatabaseHelper for synchronization
    DatabaseHelper.notifyDatabaseChanged();
  }

  Future<void> importFromZip(String zipPath) async {
    // 1. Descomprimir el archivo en una carpeta temporal
    final tempDir = await Directory.systemTemp.createTemp('thinknote_import_');
    try {
      final bytes = await File(zipPath).readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);

      for (final file in archive) {
        final outFile = File(path.join(tempDir.path, file.name));
        if (file.isFile) {
          await outFile.create(recursive: true);
          await outFile.writeAsBytes(file.content as List<int>);
        }
      }

      // 2. Obtener la base de datos
      final dbHelper = DatabaseHelper();
      final db = await dbHelper.database;

      // 3. Recorrer la estructura de carpetas y archivos
      await _processDirectory(tempDir, db, null);

      // 4. Notificar que la base de datos ha cambiado
      notifyDatabaseChanged();
    } finally {
      // 5. Limpiar archivos temporales
      await tempDir.delete(recursive: true);
    }
  }

  Future<void> importFromFolder(String folderPath) async {
    try {
      final sourceDir = Directory(folderPath);
      if (!await sourceDir.exists()) {
        throw Exception('Source folder does not exist');
      }

      // Obtener la base de datos
      final dbHelper = DatabaseHelper();
      final db = await dbHelper.database;

      // Procesar la estructura de carpetas y archivos (notebooks y notas)
      await _processDirectoryFromFolder(sourceDir, db, null);

      // Procesar la carpeta Thinks si existe
      final thinksDir = Directory(path.join(folderPath, 'Thinks'));
      if (await thinksDir.exists()) {
        await _importThinksFromFolder(thinksDir, db);
      }

      // Notificar que la base de datos ha cambiado
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
  ) async {
    final entities = await dir.list().toList();

    // Primero procesar las carpetas
    for (final entity in entities) {
      if (entity is Directory) {
        // Crear notebook en la base de datos
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

        // Obtener el ID del notebook recién creado
        final result = db.select('SELECT last_insert_rowid() as id');
        final notebookId = result.first['id'] as int;

        // Procesar recursivamente el contenido de la carpeta
        await _processDirectory(entity, db, notebookId);
      }
    }

    // Luego procesar los archivos
    for (final entity in entities) {
      if (entity is File && path.extension(entity.path) == '.md') {
        final content = await entity.readAsString();
        final title = path.basenameWithoutExtension(entity.path);

        // Crear nota en la base de datos
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
      }
    }
  }

  Future<void> _processDirectoryFromFolder(
    Directory dir,
    sqlite.Database db,
    int? parentId,
  ) async {
    final entities = await dir.list().toList();

    // Filtrar solo carpetas que no sean "Thinks" (ya que se procesa por separado)
    final folders =
        entities
            .where(
              (entity) =>
                  entity is Directory && path.basename(entity.path) != 'Thinks',
            )
            .toList();

    // Primero procesar las carpetas
    for (final entity in folders) {
      if (entity is Directory) {
        // Crear notebook en la base de datos
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

        // Obtener el ID del notebook recién creado
        final result = db.select('SELECT last_insert_rowid() as id');
        final notebookId = result.first['id'] as int;

        // Procesar recursivamente el contenido de la carpeta
        await _processDirectoryFromFolder(entity, db, notebookId);
      }
    }

    // Verificar si hay archivos sueltos en el directorio raíz
    final files = entities.where((entity) =>
        entity is File &&
        (path.extension(entity.path) == '.txt' ||
            path.extension(entity.path) == '.md')).toList();

    int? effectiveParentId = parentId;
    if (parentId == null && files.isNotEmpty) {
      // Crear un notebook por defecto para archivos sueltos
      db.execute(
        '''
        INSERT INTO ${config.DatabaseConfig.tableNotebooks} (
          ${config.DatabaseConfig.columnName},
          ${config.DatabaseConfig.columnParentId},
          ${config.DatabaseConfig.columnCreatedAt}
        ) VALUES (?, ?, ?)
      ''',
        [
          'Imported Notes',
          null,
          DateTime.now().millisecondsSinceEpoch,
        ],
      );

      // Obtener el ID del notebook recién creado
      final result = db.select('SELECT last_insert_rowid() as id');
      effectiveParentId = result.first['id'] as int;
    }

    // Luego procesar los archivos (.txt y .md)
    for (final entity in entities) {
      if (entity is File &&
          (path.extension(entity.path) == '.txt' ||
              path.extension(entity.path) == '.md')) {
        final content = await entity.readAsString(encoding: utf8);
        final title = path.basenameWithoutExtension(entity.path);

        // Crear nota en la base de datos
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
      }
    }
  }

  Future<void> _importThinksFromFolder(
    Directory thinksDir,
    sqlite.Database db,
  ) async {
    final entities = await thinksDir.list().toList();

    for (final entity in entities) {
      if (entity is File &&
          (path.extension(entity.path) == '.txt' ||
              path.extension(entity.path) == '.md')) {
        final content = await entity.readAsString(encoding: utf8);
        final title = path.basenameWithoutExtension(entity.path);

        // Crear think en la base de datos
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
      }
    }
  }

  Future<void> deleteDatabase() async {
    try {
      final dbHelper = DatabaseHelper();
      await dbHelper.resetDatabase();

      // Notificar que la base de datos ha cambiado
      notifyDatabaseChanged();
    } catch (e) {
      throw Exception('Error deleting database: $e');
    }
  }

  // Método para migrar tareas desde JSON a la base de datos
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

    // Obtener tags.json si existe
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

    // Crear los tags globales en la base de datos
    for (final tag in allTags) {
      await _taskService.addTag(tag);
    }

    // Procesar cada archivo JSON de tareas
    for (final file in files) {
      if (file is File) {
        try {
          final content = await file.readAsString();
          final todoJson = await json.decode(content);

          // Crear la tarea en la base de datos
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

          // Agregar tags a la tarea
          if (todoJson['tags'] is List) {
            for (final tag in todoJson['tags']) {
              await _taskService.assignTagToTask(tag.toString(), taskId);
            }
          }

          // Procesar subtareas
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

    // Notificar que la base de datos ha cambiado
    notifyDatabaseChanged();
  }

  Future<void> initializeDatabase() async {
    try {
      if (Platform.isAndroid) {
        // Asegurarse de que el directorio de la base de datos existe
        final dbPath = await config.DatabaseConfig.databasePath;
        final dbDir = dbPath.substring(0, dbPath.lastIndexOf('/'));
        await Directory(dbDir).create(recursive: true);
      }

      // Inicializar la base de datos
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

      // Crear el directorio de destino si no existe
      final destinationDir = destinationFile.parent;
      if (!await destinationDir.exists()) {
        await destinationDir.create(recursive: true);
      }

      // Copiar el archivo de la base de datos
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

      // Crear el directorio de destino si no existe
      final destinationDir = Directory(destinationPath);
      if (!await destinationDir.exists()) {
        await destinationDir.create(recursive: true);
      }

      // Obtener todos los notebooks
      final notebooks = db.select('''
        SELECT * FROM ${config.DatabaseConfig.tableNotebooks}
        WHERE ${config.DatabaseConfig.columnDeletedAt} IS NULL
        ORDER BY ${config.DatabaseConfig.columnOrderIndex}, ${config.DatabaseConfig.columnName}
      ''');

      // Crear un mapa de notebooks por ID para facilitar la búsqueda de padres
      final Map<int, Map<String, dynamic>> notebooksMap = {};
      for (final notebook in notebooks) {
        notebooksMap[notebook['id'] as int] = notebook;
      }

      // Función recursiva para crear la estructura de carpetas y archivos
      await _exportNotebookStructure(
        db,
        notebooks,
        notebooksMap,
        destinationPath,
        null,
      );

      // Exportar thinks a una carpeta separada
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
    // Filtrar notebooks que pertenecen al padre actual
    final currentNotebooks =
        notebooks
            .where((notebook) => notebook['parent_id'] == parentId)
            .toList();

    for (final notebook in currentNotebooks) {
      final notebookId = notebook['id'] as int;
      final notebookName = notebook['name'] as String;

      // Crear nombre de carpeta seguro (sin caracteres especiales)
      final safeFolderName = _sanitizeFileName(notebookName);
      final notebookPath = path.join(basePath, safeFolderName);

      // Crear la carpeta del notebook
      final notebookDir = Directory(notebookPath);
      if (!await notebookDir.exists()) {
        await notebookDir.create(recursive: true);
      }

      // Obtener y exportar las notas de este notebook
      await _exportNotesFromNotebook(db, notebookId, notebookPath);

      // Procesar recursivamente los sub-notebooks
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
    // Obtener todas las notas del notebook que no estén eliminadas
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

      // Crear nombre de archivo seguro
      final safeFileName = _sanitizeFileName(title);
      final filePath = path.join(notebookPath, '$safeFileName.txt');

      // Crear el archivo de texto
      final noteFile = File(filePath);
      await noteFile.writeAsString(content, encoding: utf8);
    }
  }

  String _sanitizeFileName(String fileName) {
    // Reemplazar caracteres no permitidos en nombres de archivo
    return fileName
        .replaceAll(RegExp(r'[<>:"/\\|?*]'), '_')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  Future<void> _exportThinks(sqlite.Database db, String basePath) async {
    // Crear la carpeta Thinks
    final thinksPath = path.join(basePath, 'Thinks');
    final thinksDir = Directory(thinksPath);
    if (!await thinksDir.exists()) {
      await thinksDir.create(recursive: true);
    }

    // Obtener todos los thinks que no estén eliminados
    final thinks = db.select('''
      SELECT * FROM ${config.DatabaseConfig.tableThinks}
      WHERE ${config.DatabaseConfig.columnDeletedAt} IS NULL
      ORDER BY ${config.DatabaseConfig.columnCreatedAt}
    ''');

    for (final think in thinks) {
      final title = think['title'] as String;
      final content = think['content'] as String;

      // Crear nombre de archivo seguro
      final safeFileName = _sanitizeFileName(title);
      final filePath = path.join(thinksPath, '$safeFileName.txt');

      // Crear el archivo de texto
      final thinkFile = File(filePath);
      await thinkFile.writeAsString(content, encoding: utf8);
    }
  }

  Future<void> exportBookmarksToHtml(String destinationPath) async {
    try {
      // Obtener todos los bookmarks con sus tags
      final bookmarks = await _bookmarkService.getAllBookmarksWithTags();

      // Generar el contenido HTML usando HtmlGenerator
      final htmlContent = await HtmlGenerator.generateBookmarksHtml(
        bookmarks,
        _bookmarkService,
      );

      // Crear el archivo HTML
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
