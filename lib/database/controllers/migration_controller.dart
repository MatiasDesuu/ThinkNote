import 'dart:io';
import 'package:path/path.dart' as path;
import '../database_helper.dart';
import '../models/notebook.dart';
import '../models/note.dart';
import '../repositories/notebook_repository.dart';
import '../repositories/note_repository.dart';

class MigrationController {
  final NotebookRepository _notebookRepository;
  final NoteRepository _noteRepository;

  MigrationController(DatabaseHelper dbHelper)
    : _notebookRepository = NotebookRepository(dbHelper),
      _noteRepository = NoteRepository(dbHelper);

  Future<void> migrateFromFileSystem(String rootPath) async {
    final rootDir = Directory(rootPath);
    if (!await rootDir.exists()) {
      throw Exception('El directorio raíz no existe');
    }

    await _processDirectory(rootDir);
  }

  Future<void> _processDirectory(Directory dir, {int? parentNotebookId}) async {
    final entities = await dir.list().toList();

    // Primero procesamos las carpetas
    for (final entity in entities) {
      if (entity is Directory) {
        final notebook = Notebook(
          name: path.basename(entity.path),
          parentId: parentNotebookId,
          createdAt: DateTime.now(),
        );
        final notebookId = await _notebookRepository.createNotebook(notebook);
        await _processDirectory(entity, parentNotebookId: notebookId);
      }
    }

    // Luego procesamos los archivos
    for (final entity in entities) {
      if (entity is File && path.extension(entity.path) == '.md') {
        final content = await entity.readAsString();
        final title = path.basenameWithoutExtension(entity.path);

        final note = Note(
          title: title,
          content: content,
          notebookId: parentNotebookId!,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        await _noteRepository.createNote(note);
      }
    }
  }

  Future<void> exportToFileSystem(String rootPath) async {
    final rootDir = Directory(rootPath);
    if (!await rootDir.exists()) {
      await rootDir.create(recursive: true);
    }

    final notebooks = await _notebookRepository.getAllNotebooks();
    final notes = await _noteRepository.getNotesByNotebookId(
      0,
    ); // Obtener todas las notas

    // Crear la estructura de directorios
    for (final notebook in notebooks) {
      final notebookPath = _getNotebookPath(notebook, notebooks);
      final dir = Directory(path.join(rootPath, notebookPath));
      await dir.create(recursive: true);
    }

    // Crear los archivos de notas
    for (final note in notes) {
      final notebook = notebooks.firstWhere((n) => n.id == note.notebookId);
      final notebookPath = _getNotebookPath(notebook, notebooks);
      final noteFile = File(
        path.join(rootPath, notebookPath, '${note.title}.md'),
      );
      await noteFile.writeAsString(note.content);
    }
  }

  String _getNotebookPath(Notebook notebook, List<Notebook> allNotebooks) {
    final pathParts = <String>[notebook.name];
    var currentNotebook = notebook;

    while (currentNotebook.parentId != null) {
      currentNotebook = allNotebooks.firstWhere(
        (n) => n.id == currentNotebook.parentId,
      );
      pathParts.insert(0, currentNotebook.name);
    }

    return path.joinAll(pathParts);
  }
}
