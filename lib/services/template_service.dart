import '../database/models/notebook.dart';
import '../database/repositories/notebook_repository.dart';
import '../database/repositories/note_repository.dart';
import 'template_variable_processor.dart';

class TemplateService {
  final NotebookRepository notebookRepository;
  final NoteRepository noteRepository;

  TemplateService({
    required this.notebookRepository,
    required this.noteRepository,
  });

  Future<void> applyNotebookTemplate({
    required Notebook template,
    required int targetParentId,
    String? targetNotebookName,
  }) async {
    String newNotebookName = template.name;
    if (newNotebookName.toLowerCase().startsWith('#template_')) {
      newNotebookName = newNotebookName.substring(10);
    }

    final processedName = TemplateVariableProcessor.process(
      newNotebookName,
      notebookName: targetNotebookName,
    );

    await copyNotebookRecursive(
      sourceNotebookId: template.id!,
      targetParentId: targetParentId,
      newName: processedName,
      targetNotebookName: targetNotebookName,
    );
  }

  Future<void> copyNotebookRecursive({
    required int sourceNotebookId,
    required int targetParentId,
    required String newName,
    String? targetNotebookName,
  }) async {
    final newNotebook = Notebook(
      name: newName,
      parentId: targetParentId,
      createdAt: DateTime.now(),
      orderIndex: 0,
    );

    final newNotebookId = await notebookRepository.createNotebook(newNotebook);

    final notes = await noteRepository.getNotesByNotebookId(sourceNotebookId);
    for (final note in notes) {
      final processedTitle = TemplateVariableProcessor.process(
        note.title,
        notebookName: targetNotebookName,
      );
      final processedContent = TemplateVariableProcessor.process(
        note.content,
        notebookName: targetNotebookName,
      );

      final newNote = note.copyWith(
        id: null,
        notebookId: newNotebookId,
        title: processedTitle,
        content: processedContent,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await noteRepository.createNote(newNote);
    }

    final subNotebooks = await notebookRepository.getNotebooksByParentId(
      sourceNotebookId,
    );
    for (final sub in subNotebooks) {
      final processedSubName = TemplateVariableProcessor.process(
        sub.name,
        notebookName: targetNotebookName,
      );
      await copyNotebookRecursive(
        sourceNotebookId: sub.id!,
        targetParentId: newNotebookId,
        newName: processedSubName,
        targetNotebookName: targetNotebookName,
      );
    }
  }
}
