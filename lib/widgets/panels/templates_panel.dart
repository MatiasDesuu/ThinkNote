import 'package:flutter/material.dart';
import 'dart:async';
import '../../database/models/notebook.dart';
import '../../database/models/note.dart';
import '../../database/repositories/notebook_repository.dart';
import '../../database/repositories/note_repository.dart';
import '../../database/database_helper.dart';
import '../../database/database_service.dart';
import '../../services/template_variable_processor.dart';
import '../custom_snackbar.dart';

class TemplatesPanel extends StatefulWidget {
  final int? selectedNotebookId;
  final Function(Note) onTemplateApplied;
  final VoidCallback? onClose;
  final FocusNode appFocusNode;

  const TemplatesPanel({
    super.key,
    this.selectedNotebookId,
    required this.onTemplateApplied,
    required this.appFocusNode,
    this.onClose,
  });

  @override
  State<TemplatesPanel> createState() => TemplatesPanelState();
}

class TemplatesPanelState extends State<TemplatesPanel> {
  late final NoteRepository _noteRepository;
  late final NotebookRepository _notebookRepository;
  bool _isLoading = true;
  Map<Notebook, List<Note>> _groupedTemplates = {};
  late StreamSubscription<void> _databaseChangeSubscription;

  @override
  void initState() {
    super.initState();
    _initializeRepositories();

    _databaseChangeSubscription = DatabaseService().onDatabaseChanged.listen((
      _,
    ) {
      reloadTemplates();
    });
  }

  @override
  void dispose() {
    _databaseChangeSubscription.cancel();
    super.dispose();
  }

  Future<void> _initializeRepositories() async {
    final dbHelper = DatabaseHelper();
    await dbHelper.database;
    _notebookRepository = NotebookRepository(dbHelper);
    _noteRepository = NoteRepository(dbHelper);
    _loadTemplates();
  }

  void _loadTemplates() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final allNotebooks = await _notebookRepository.getAllNotebooks();
      final templateNotebooks =
          allNotebooks
              .where((n) => n.name.toLowerCase().startsWith('#templates'))
              .toList();

      Map<Notebook, List<Note>> grouped = {};

      for (final notebook in templateNotebooks) {
        final notes = await _noteRepository.getNotesByNotebookId(notebook.id!);
        if (notes.isNotEmpty) {
          grouped[notebook] = notes;
        }
      }

      if (mounted) {
        setState(() {
          _groupedTemplates = grouped;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading templates: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void reloadTemplates() {
    _loadTemplates();
  }

  Future<void> _applyTemplate(Note template) async {
    if (widget.selectedNotebookId == null) {
      CustomSnackbar.show(
        context: context,
        message:
            'Please select a notebook first to create a note from a template',
        type: CustomSnackbarType.error,
      );
      return;
    }

    try {
      // Check if this is a stack template
      if (template.title.toLowerCase().contains('#stack')) {
        await _applyStackTemplate(template);
      } else {
        await _applySingleTemplate(template);
      }
    } catch (e) {
      debugPrint('Error applying template: $e');
      if (mounted) {
        CustomSnackbar.show(
          context: context,
          message: 'Error creating note from template: ${e.toString()}',
          type: CustomSnackbarType.error,
        );
      }
    }
  }

  Future<void> _applySingleTemplate(Note template) async {
    String? notebookName;
    List<String> existingTitles = [];
    if (widget.selectedNotebookId != null) {
      final notebook = await _notebookRepository.getNotebook(
        widget.selectedNotebookId!,
      );
      notebookName = notebook?.name;
      final existingNotes = await _noteRepository.getNotesByNotebookId(widget.selectedNotebookId!);
      existingTitles = existingNotes.map((note) => note.title).toList();
    }

    final processedTitle = TemplateVariableProcessor.process(
      template.title,
      notebookName: notebookName,
      existingTitles: existingTitles,
    );
    final processedContent = TemplateVariableProcessor.process(
      template.content,
      notebookName: notebookName,
    );

    final newNote = Note(
      title: processedTitle,
      content: processedContent,
      notebookId: widget.selectedNotebookId!,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      isFavorite: false,
      tags: template.tags,
      isTask: template.isTask,
      isCompleted: false,
    );

    final noteId = await _noteRepository.createNote(newNote);
    final createdNote = await _noteRepository.getNote(noteId);

    if (createdNote != null) {
      widget.onTemplateApplied(createdNote);
      widget.onClose?.call();
    }
  }

  Future<void> _applyStackTemplate(Note template) async {
    // Parse the content for {{note1, note2, ...}}
    final regExp = RegExp(r'\{\{([^}]+)\}\}');
    final match = regExp.firstMatch(template.content);
    if (match == null) {
      throw Exception('Stack template must contain {{note1, note2, ...}} in content');
    }

    final noteNamesString = match.group(1)!;
    final noteNames = noteNamesString.split(',').map((name) => name.trim()).toList();

    // Get all notes from the template's notebook
    final templateNotes = await _noteRepository.getNotesByNotebookId(template.notebookId);
    final templateNoteMap = {for (var note in templateNotes) note.title: note};

    // Check if all specified notes exist
    final missingNotes = noteNames.where((name) => !templateNoteMap.containsKey(name)).toList();
    if (missingNotes.isNotEmpty) {
      throw Exception('The following notes are missing in the template notebook: ${missingNotes.join(', ')}');
    }

    // Get target notebook info
    String? notebookName;
    List<String> existingTitles = [];
    if (widget.selectedNotebookId != null) {
      final notebook = await _notebookRepository.getNotebook(
        widget.selectedNotebookId!,
      );
      notebookName = notebook?.name;
      final existingNotes = await _noteRepository.getNotesByNotebookId(widget.selectedNotebookId!);
      existingTitles = existingNotes.map((note) => note.title).toList();
    }

    // Create each note
    for (final noteName in noteNames) {
      final sourceNote = templateNoteMap[noteName]!;
      
      final processedTitle = TemplateVariableProcessor.process(
        sourceNote.title,
        notebookName: notebookName,
        existingTitles: existingTitles,
      );
      final processedContent = TemplateVariableProcessor.process(
        sourceNote.content,
        notebookName: notebookName,
      );

      final newNote = Note(
        title: processedTitle,
        content: processedContent,
        notebookId: widget.selectedNotebookId!,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        isFavorite: false,
        tags: sourceNote.tags,
        isTask: sourceNote.isTask,
        isCompleted: false,
      );

      await _noteRepository.createNote(newNote);
      // Update existingTitles for numbering
      existingTitles.add(processedTitle);
    }

    // Close the panel after applying stack template
    widget.onClose?.call();

    if (mounted) {
      CustomSnackbar.show(
        context: context,
        message: 'Created ${noteNames.length} notes from stack template',
        type: CustomSnackbarType.success,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        return SizedBox(
          width: constraints.maxWidth,
          child: Container(
            decoration: BoxDecoration(color: colorScheme.surfaceContainerLow),
            child: Column(
              children: [
                _buildHeader(),
                Expanded(
                  child:
                      _isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : _buildContent(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader() {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(
                Icons.auto_awesome_motion_rounded,
                size: 20,
                color: colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'Templates',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          IconButton(
            icon: Icon(Icons.close_rounded, color: colorScheme.primary),
            onPressed: widget.onClose,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            padding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_groupedTemplates.isEmpty) {
      return _buildEmptyState();
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children:
          _groupedTemplates.entries.map((entry) {
            final notebook = entry.key;
            final notes = entry.value;
            return _buildGroup(notebook, notes);
          }).toList(),
    );
  }

  Widget _buildGroup(Notebook notebook, List<Note> notes) {
    final colorScheme = Theme.of(context).colorScheme;

    // Clean up notebook name for display (remove #templates or #templates_)
    String displayName = notebook.name;
    if (displayName.toLowerCase() == '#templates') {
      displayName = 'General Templates';
    } else if (displayName.toLowerCase().startsWith('#templates_')) {
      displayName = notebook.name.substring(11).replaceAll('_', ' ');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            displayName,
            style: TextStyle(
              color: colorScheme.primary,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ),
        ...notes.map((note) => _buildTemplateItem(note)),
      ],
    );
  }

  Widget _buildTemplateItem(Note note) {
    final colorScheme = Theme.of(context).colorScheme;

    return MouseRegionHoverItem(
      builder: (context, isHovering) {
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          color: colorScheme.surfaceContainerHighest,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => _applyTemplate(note),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    Icon(
                      note.title.toLowerCase().contains('#stack')
                          ? Icons.library_add_rounded
                          : note.isTask
                              ? Icons.add_task_rounded
                              : Icons.description_outlined,
                      color: colorScheme.primary,
                      size: 18,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        note.title.isEmpty ? 'Untitled Template' : note.title,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurface,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isHovering)
                      Icon(
                        Icons.add_rounded,
                        size: 18,
                        color: colorScheme.primary,
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.auto_awesome_motion_rounded,
              size: 64,
              color: colorScheme.onSurfaceVariant.withAlpha(127),
            ),
            const SizedBox(height: 16),
            Text(
              'No templates found',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Create a notebook named "#templates" and add notes to use them as templates.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colorScheme.onSurfaceVariant.withAlpha(179),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MouseRegionHoverItem extends StatefulWidget {
  final Widget Function(BuildContext, bool) builder;

  const MouseRegionHoverItem({super.key, required this.builder});

  @override
  State<MouseRegionHoverItem> createState() => _MouseRegionHoverItemState();
}

class _MouseRegionHoverItemState extends State<MouseRegionHoverItem> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: widget.builder(context, _isHovering),
    );
  }
}
