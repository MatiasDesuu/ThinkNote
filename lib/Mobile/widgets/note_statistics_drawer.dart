import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../database/models/note.dart';
import '../../database/models/think.dart';
import '../../database/repositories/notebook_repository.dart';
import '../../database/database_helper.dart';

class NoteStatisticsDrawer extends StatefulWidget {
  final Note? note;
  final Think? think;
  final String currentContent;
  final String currentTitle;

  const NoteStatisticsDrawer({
    super.key,
    this.note,
    this.think,
    required this.currentContent,
    required this.currentTitle,
  }) : assert(note != null || think != null);

  @override
  State<NoteStatisticsDrawer> createState() => _NoteStatisticsDrawerState();
}

class _NoteStatisticsDrawerState extends State<NoteStatisticsDrawer> {
  String _location = 'Loading...';

  @override
  void initState() {
    super.initState();
    _loadLocation();
  }

  Future<void> _loadLocation() async {
    if (widget.think != null) {
      if (mounted) {
        setState(() {
          _location = 'Thinks';
        });
      }
      return;
    }

    if (widget.note != null) {
      final dbHelper = DatabaseHelper();
      final notebookRepo = NotebookRepository(dbHelper);

      List<String> pathNames = [];
      int? currentNotebookId = widget.note!.notebookId;

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
  }

  @override
  Widget build(BuildContext context) {
    final wordCount = _calculateWordCount(widget.currentContent);
    final charCount = widget.currentContent.length;
    final dateFormat = DateFormat('MMM dd, yyyy HH:mm');
    final colorScheme = Theme.of(context).colorScheme;

    final createdAt = widget.note?.createdAt ?? widget.think?.createdAt;
    final updatedAt = widget.note?.updatedAt ?? widget.think?.updatedAt;

    return Drawer(
      width: MediaQuery.of(context).size.width * 0.8,
      backgroundColor: colorScheme.surface,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Icon(
                    Icons.analytics_outlined,
                    color: colorScheme.primary,
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Note Statistics',
                    style: TextStyle(
                      color: colorScheme.onSurface,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  _buildStatCard(
                    context,
                    icon: Icons.title_rounded,
                    label: 'Name',
                    value:
                        widget.currentTitle.isEmpty
                            ? 'Untitled'
                            : widget.currentTitle,
                  ),
                  const SizedBox(height: 4),
                  _buildStatCard(
                    context,
                    icon: Icons.folder_open_rounded,
                    label: 'Location',
                    value: _location,
                  ),
                  const SizedBox(height: 4),
                  if (createdAt != null)
                    _buildStatCard(
                      context,
                      icon: Icons.event_note_rounded,
                      label: 'Created',
                      value: dateFormat.format(createdAt),
                    ),
                  const SizedBox(height: 4),
                  if (updatedAt != null)
                    _buildStatCard(
                      context,
                      icon: Icons.edit_calendar_rounded,
                      label: 'Updated',
                      value: dateFormat.format(updatedAt),
                    ),
                  const SizedBox(height: 4),
                  _buildStatCard(
                    context,
                    icon: Icons.text_fields_rounded,
                    label: 'Characters',
                    value: charCount.toString(),
                  ),
                  const SizedBox(height: 4),
                  _buildStatCard(
                    context,
                    icon: Icons.short_text_rounded,
                    label: 'Words',
                    value: wordCount.toString(),
                  ),
                ],
              ),
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
    return text.trim().split(RegExp(r'\s+')).where((s) => s.isNotEmpty).length;
  }
}
