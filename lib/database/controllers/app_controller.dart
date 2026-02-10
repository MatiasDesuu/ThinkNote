import '../database_helper.dart';
import '../models/notebook.dart';
import '../models/notebook_icons.dart';
import '../models/note.dart';
import '../repositories/notebook_repository.dart';
import '../repositories/note_repository.dart';

class AppController {
  final NotebookRepository _notebookRepository;
  final NoteRepository _noteRepository;

  AppController(DatabaseHelper dbHelper)
    : _notebookRepository = NotebookRepository(dbHelper),
      _noteRepository = NoteRepository(dbHelper);

  Future<int> createNotebook(String name, {int? parentId}) async {
    final notebook = Notebook(
      name: name,
      parentId: parentId,
      createdAt: DateTime.now(),
      iconId: NotebookIconsRepository.getDefaultIcon().id,
    );
    return await _notebookRepository.createNotebook(notebook);
  }

  Future<List<Notebook>> getNotebooks({int? parentId}) async {
    return await _notebookRepository.getNotebooksByParentId(parentId);
  }

  Future<void> updateNotebook(int id, String name, {int? parentId}) async {
    final notebook = Notebook(
      id: id,
      name: name,
      parentId: parentId,
      createdAt: DateTime.now(),
      iconId: NotebookIconsRepository.getDefaultIcon().id,
    );
    await _notebookRepository.updateNotebook(notebook);
  }

  Future<void> softDeleteNotebook(int id) async {
    await _notebookRepository.softDeleteNotebook(id);
  }

  Future<void> restoreNotebook(int id) async {
    await _notebookRepository.restoreNotebook(id);
  }

  Future<void> hardDeleteNotebook(int id) async {
    await _notebookRepository.hardDeleteNotebook(id);
  }

  Future<List<Notebook>> getDeletedNotebooks() async {
    return await _notebookRepository.getDeletedNotebooks();
  }

  Future<void> toggleNotebookFavorite(int notebookId) async {
    final notebook = await _notebookRepository.getNotebook(notebookId);
    if (notebook != null) {
      final updatedNotebook = notebook.copyWith(
        isFavorite: !notebook.isFavorite,
      );
      await _notebookRepository.updateNotebook(updatedNotebook);
    }
  }

  Future<List<Notebook>> getFavoriteNotebooks() async {
    return await _notebookRepository.getFavoriteNotebooks();
  }

  Future<int> createNote(String title, String content, int notebookId) async {
    final now = DateTime.now();
    final note = Note(
      title: title,
      content: content,
      notebookId: notebookId,
      createdAt: now,
      updatedAt: now,
    );
    return await _noteRepository.createNote(note);
  }

  Future<List<Note>> getNotesByNotebook(int notebookId) async {
    return await _noteRepository.getNotesByNotebookId(notebookId);
  }

  Future<void> updateNote(
    int id,
    String title,
    String content,
    int notebookId,
  ) async {
    final note = Note(
      id: id,
      title: title,
      content: content,
      notebookId: notebookId,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    await _noteRepository.updateNote(note);
  }

  Future<void> moveNote(int noteId, int newNotebookId) async {
    final note = await _noteRepository.getNote(noteId);
    if (note != null) {
      final updatedNote = note.copyWith(
        notebookId: newNotebookId,
        updatedAt: DateTime.now(),
      );
      await _noteRepository.updateNote(updatedNote);
    }
  }

  Future<void> toggleFavorite(int noteId) async {
    final note = await _noteRepository.getNote(noteId);
    if (note != null) {
      final updatedNote = note.copyWith(
        isFavorite: !note.isFavorite,
        updatedAt: DateTime.now(),
      );
      await _noteRepository.updateNote(updatedNote);
    }
  }

  Future<List<Note>> getFavoriteNotes() async {
    return await _noteRepository.getFavoriteNotes();
  }

  Future<void> softDeleteNote(int noteId) async {
    await _noteRepository.deleteNote(noteId);
  }

  Future<void> restoreNote(int noteId) async {
    await _noteRepository.restoreNote(noteId);
  }

  Future<void> hardDeleteNote(int noteId) async {
    await _noteRepository.hardDeleteNote(noteId);
  }

  Future<List<Note>> getDeletedNotes() async {
    return await _noteRepository.getDeletedNotes();
  }

  Future<void> updateNoteTags(int noteId, String? tags) async {
    final note = await _noteRepository.getNote(noteId);
    if (note != null) {
      final updatedNote = note.copyWith(tags: tags, updatedAt: DateTime.now());
      await _noteRepository.updateNote(updatedNote);
    }
  }
}
