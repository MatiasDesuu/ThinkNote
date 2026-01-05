import 'package:flutter/material.dart';
import '../../database/models/notebook.dart';
import '../../database/models/note.dart';
import '../../database/repositories/notebook_repository.dart';
import '../../database/repositories/note_repository.dart';
import '../../database/database_helper.dart';
import '../../widgets/custom_snackbar.dart';

class TemplatesScreen extends StatefulWidget {
  final Function(Note) onTemplateApplied;
  final Function(Notebook)? onNotebookTemplateApplied;
  final Map<Notebook, List<Note>>? initialTemplates;
  final List<Notebook>? initialNotebookTemplates;

  const TemplatesScreen({
    super.key,
    required this.onTemplateApplied,
    this.onNotebookTemplateApplied,
    this.initialTemplates,
    this.initialNotebookTemplates,
  });

  @override
  State<TemplatesScreen> createState() => _TemplatesScreenState();
}

class _TemplatesScreenState extends State<TemplatesScreen> {
  late final NoteRepository _noteRepository;
  late final NotebookRepository _notebookRepository;
  bool _isLoading = true;
  Map<Notebook, List<Note>> _groupedTemplates = {};
  List<Notebook> _notebookTemplates = [];

  @override
  void initState() {
    super.initState();
    if (widget.initialTemplates != null) {
      _groupedTemplates = widget.initialTemplates!;
      _notebookTemplates = widget.initialNotebookTemplates ?? [];
      _isLoading = false;
    }
    final dbHelper = DatabaseHelper();
    _notebookRepository = NotebookRepository(dbHelper);
    _noteRepository = NoteRepository(dbHelper);
    _loadTemplates();
  }

  void _loadTemplates() async {
    if (!mounted) return;

    try {
      final allNotebooks = await _notebookRepository.getAllNotebooks();
      final templateNotebooks =
          allNotebooks
              .where((n) {
                final name = n.name.toLowerCase();
                return name.startsWith('#templates') ||
                    name.startsWith('#category');
              })
              .toList();

      final notebookTemplates =
          allNotebooks
              .where((n) => n.name.toLowerCase().startsWith('#template_'))
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
          _notebookTemplates = notebookTemplates;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading templates: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        CustomSnackbar.show(
          context: context,
          message: 'Error loading templates',
          type: CustomSnackbarType.error,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 40.0,
        title: const Text('Templates'),
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        backgroundColor: Theme.of(context).colorScheme.surface,
      ),
      body:
          _isLoading
              ? const SizedBox.shrink()
              : (_groupedTemplates.isEmpty && _notebookTemplates.isEmpty)
              ? _buildEmptyState()
              : _buildContent(),
    );
  }

  Widget _buildContent() {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        if (_notebookTemplates.isNotEmpty) ...[
          _buildNotebookTemplatesSection(),
          const Divider(height: 32),
        ],
        ..._groupedTemplates.entries.map((entry) {
          final notebook = entry.key;
          final notes = entry.value;
          return _buildGroup(notebook, notes);
        }),
      ],
    );
  }

  Widget _buildNotebookTemplatesSection() {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            'Notebook Templates',
            style: TextStyle(
              color: colorScheme.primary,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ),
        ..._notebookTemplates.map((notebook) => _buildNotebookTemplateItem(notebook)),
      ],
    );
  }

  Widget _buildNotebookTemplateItem(Notebook notebook) {
    final colorScheme = Theme.of(context).colorScheme;

    // Clean up name for display
    String displayName = notebook.name;
    if (displayName.toLowerCase().startsWith('#template_')) {
      displayName = displayName.substring(10).replaceAll('_', ' ');
    }

    return ListTile(
      leading: Icon(
        Icons.folder_copy_rounded,
        color: colorScheme.primary,
      ),
      title: Text(
        displayName,
        style: TextStyle(
          color: colorScheme.onSurface,
          fontWeight: FontWeight.w500,
        ),
      ),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: () {
        if (widget.onNotebookTemplateApplied != null) {
          widget.onNotebookTemplateApplied!(notebook);
          Navigator.pop(context);
        }
      },
    );
  }

  Widget _buildGroup(Notebook notebook, List<Note> notes) {
    final colorScheme = Theme.of(context).colorScheme;

    String displayName = notebook.name;
    final lowerName = displayName.toLowerCase();

    if (lowerName == '#templates' || lowerName == '#category') {
      displayName = 'General Templates';
    } else if (lowerName.startsWith('#templates_')) {
      displayName = notebook.name.substring(11).replaceAll('_', ' ');
    } else if (lowerName.startsWith('#category_')) {
      displayName = notebook.name.substring(10).replaceAll('_', ' ');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
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
    final isStack = note.title.toLowerCase().contains('#stack');

    return ListTile(
      leading: Icon(
        isStack
            ? Icons.library_books_rounded
            : note.isTask
                ? Icons.add_task_rounded
                : Icons.description_outlined,
        color: colorScheme.primary,
      ),
      title: Text(
        note.title.isEmpty ? 'Untitled Template' : note.title,
        style: TextStyle(
          color: colorScheme.onSurface,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: isStack ? const Text('Stack Template') : null,
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: () {
        widget.onTemplateApplied(note);
        Navigator.pop(context);
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
              'Create a notebook named "#templates", "#category" or starting with "#template_" to use them as templates.',
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
