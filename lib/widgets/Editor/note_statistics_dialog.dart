import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../database/models/note.dart';
import '../../database/repositories/notebook_repository.dart';
import '../../database/database_helper.dart';
import '../custom_dialog.dart';

class NoteStatisticsDialog extends StatefulWidget {
  final Note note;

  const NoteStatisticsDialog({super.key, required this.note});

  @override
  State<NoteStatisticsDialog> createState() => _NoteStatisticsDialogState();
}

class _NoteStatisticsDialogState extends State<NoteStatisticsDialog> {
  String _location = 'Loading...';

  @override
  void initState() {
    super.initState();
    _loadLocation();
  }

  Future<void> _loadLocation() async {
    final dbHelper = DatabaseHelper();
    final notebookRepo = NotebookRepository(dbHelper);

    List<String> pathNames = [];
    int? currentNotebookId = widget.note.notebookId;

    // Safety break to prevent infinite loops if DB has circular references
    int depth = 0;
    while (currentNotebookId != null && depth < 20) {
      final notebook = await notebookRepo.getNotebook(currentNotebookId);
      if (notebook != null) {
        pathNames.insert(0, notebook.name);
        currentNotebookId = notebook.parentId;
      } else {
        break;
      }
      depth++;
    }

    if (mounted) {
      setState(() {
        _location = pathNames.isEmpty ? 'Root' : pathNames.join(' > ');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final wordCount = _calculateWordCount(widget.note.content);
    final charCount = widget.note.content.length;
    final dateFormat = DateFormat('MMM dd, yyyy HH:mm');

    return CustomDialog(
      title: 'Note Statistics',
      icon: Icons.analytics_outlined,
      width: 420,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildStatCard(
              context,
              icon: Icons.title_rounded,
              label: 'Name',
              value: widget.note.title.isEmpty ? 'Untitled' : widget.note.title,
            ),
            const SizedBox(height: 12),
            _buildStatCard(
              context,
              icon: Icons.folder_open_rounded,
              label: 'Location',
              value: _location,
            ),
            const SizedBox(height: 12),
            _buildStatCard(
              context,
              icon: Icons.event_note_rounded,
              label: 'Created',
              value: dateFormat.format(widget.note.createdAt),
            ),
            const SizedBox(height: 12),
            _buildStatCard(
              context,
              icon: Icons.edit_calendar_rounded,
              label: 'Updated',
              value: dateFormat.format(widget.note.updatedAt),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    context,
                    icon: Icons.text_fields_rounded,
                    label: 'Characters',
                    value: charCount.toString(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    context,
                    icon: Icons.short_text_rounded,
                    label: 'Words',
                    value: wordCount.toString(),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh.withAlpha(150),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: colorScheme.primary.withAlpha(25),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: colorScheme.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    color: colorScheme.onSurface,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  int _calculateWordCount(String text) {
    if (text.trim().isEmpty) return 0;
    // Split by whitespace and filter out empty strings to get accurate word count
    return text.trim().split(RegExp(r'\s+')).where((s) => s.isNotEmpty).length;
  }
}
