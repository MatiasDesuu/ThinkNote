import 'package:flutter/material.dart';
import '../../database/models/notebook.dart';
import '../../database/models/note.dart';
import '../../database/repositories/notebook_repository.dart';
import '../../database/repositories/note_repository.dart';
import '../../database/database_helper.dart';
import '../../widgets/custom_snackbar.dart';

class TemplatesScreen extends StatefulWidget {
  final Function(Note) onTemplateApplied;
  final Map<Notebook, List<Note>>? initialTemplates;

  const TemplatesScreen({
    super.key,
    required this.onTemplateApplied,
    this.initialTemplates,
  });

  @override
  State<TemplatesScreen> createState() => _TemplatesScreenState();
}

class _TemplatesScreenState extends State<TemplatesScreen> {
  late final NoteRepository _noteRepository;
  late final NotebookRepository _notebookRepository;
  bool _isLoading = true;
  Map<Notebook, List<Note>> _groupedTemplates = {};

  @override
  void initState() {
    super.initState();
    if (widget.initialTemplates != null) {
      _groupedTemplates = widget.initialTemplates!;
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
        title: const Text('Templates'),
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        backgroundColor: Theme.of(context).colorScheme.surface,
      ),
      body:
          _isLoading
              ? const SizedBox.shrink()
              : _groupedTemplates.isEmpty
              ? _buildEmptyState()
              : _buildContent(),
    );
  }

  Widget _buildContent() {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
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
