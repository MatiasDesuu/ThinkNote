import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database/models/diary_entry.dart';
import '../database/services/diary_service.dart';
import '../database/database_helper.dart';
import '../database/repositories/diary_repository.dart';
import '../widgets/context_menu.dart';
import '../widgets/confirmation_dialogue.dart';
import '../widgets/custom_snackbar.dart';

class DiaryEntriesPanel extends StatefulWidget {
  final DiaryEntry? selectedEntry;
  final Function(DiaryEntry) onEntrySelected;
  final VoidCallback? onEntryDeleted;

  const DiaryEntriesPanel({
    super.key,
    this.selectedEntry,
    required this.onEntrySelected,
    this.onEntryDeleted,
  });

  @override
  DiaryEntriesPanelState createState() => DiaryEntriesPanelState();
}

class DiaryEntriesPanelState extends State<DiaryEntriesPanel> {
  List<DiaryEntry> _entries = [];
  bool _isLoading = true;
  late DiaryService _diaryService;

  @override
  void initState() {
    super.initState();
    _diaryService = DiaryService(DiaryRepository(DatabaseHelper()));
    _loadEntries();
  }

  Future<void> loadEntries() async {
    await _loadEntries();
  }

  Future<void> _loadEntries() async {
    try {
      final entries = await _diaryService.getAllDiaryEntries();
      if (mounted) {
        setState(() {
          _entries = entries;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showContextMenu(
    BuildContext context,
    Offset tapPosition,
    DiaryEntry entry,
  ) {
    ContextMenuOverlay.show(
      context: context,
      tapPosition: tapPosition,
      items: [
        ContextMenuItem(
          icon: Icons.delete_rounded,
          label: 'Delete Entry',
          iconColor: Theme.of(context).colorScheme.error,
          onTap: () => _showDeleteConfirmation(entry),
        ),
      ],
    );
  }

  Future<void> _showDeleteConfirmation(DiaryEntry entry) async {
    final confirmed = await showDeleteConfirmationDialog(
      context: context,
      title: 'Delete Diary Entry',
      message:
          'Are you sure you want to delete the diary entry for ${DateFormat('MMM dd, yyyy').format(entry.date)}? This action cannot be undone.',
      confirmText: 'Delete',
      confirmColor: Theme.of(context).colorScheme.error,
    );

    if (confirmed == true) {
      await _deleteEntry(entry);
    }
  }

  Future<void> _deleteEntry(DiaryEntry entry) async {
    if (entry.id == null) {
      if (mounted) {
        CustomSnackbar.show(
          context: context,
          message: 'Cannot delete entry: Invalid entry ID',
          type: CustomSnackbarType.error,
        );
      }
      return;
    }

    try {
      await _diaryService.deleteDiaryEntry(entry.id!);
      await _loadEntries();

      if (mounted) {
        CustomSnackbar.show(
          context: context,
          message: 'Diary entry deleted successfully',
          type: CustomSnackbarType.success,
        );
      }

      if (widget.onEntryDeleted != null) {
        widget.onEntryDeleted!();
      }
    } catch (e) {
      if (mounted) {
        CustomSnackbar.show(
          context: context,
          message: 'Error deleting diary entry: ${e.toString()}',
          type: CustomSnackbarType.error,
        );
      }
    }
  }

  Widget _buildEntryItem(DiaryEntry entry) {
    final colorScheme = Theme.of(context).colorScheme;
    final bool isSelected = widget.selectedEntry?.id == entry.id;

    // Format the date
    final monthFormat = DateFormat('MMM');
    final dateFormat = DateFormat('dd');
    final month = monthFormat.format(entry.date);
    final date = dateFormat.format(entry.date);

    // Get content preview (first line or first 50 characters)
    final contentPreview =
        entry.content.isNotEmpty
            ? entry.content.split('\n').first
            : 'No content';
    final displayContent =
        contentPreview.length > 120
            ? '${contentPreview.substring(0, 120)}...'
            : contentPreview;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => widget.onEntrySelected(entry),
          hoverColor: colorScheme.surfaceContainerHigh,
          splashColor: colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(12),
          mouseCursor: SystemMouseCursors.click,
          child: GestureDetector(
            onSecondaryTapDown: (details) {
              _showContextMenu(context, details.globalPosition, entry);
            },
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color:
                    isSelected
                        ? colorScheme.surfaceContainerHigh
                        : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Month and Date column with background
                  Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 8,
                      horizontal: 20,
                    ),
                    decoration: BoxDecoration(
                      color:
                          isSelected
                              ? colorScheme.primaryContainer.withAlpha(200)
                              : colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          month,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color:
                                isSelected
                                    ? colorScheme.onPrimaryContainer
                                    : colorScheme.primary,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          date,
                          style: TextStyle(
                            fontWeight:
                                isSelected ? FontWeight.bold : FontWeight.w500,
                            color:
                                isSelected
                                    ? colorScheme.onPrimaryContainer
                                    : colorScheme.onSurface,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Content column
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          displayContent,
                          style: TextStyle(
                            color:
                                isSelected
                                    ? colorScheme.onSurface
                                    : colorScheme.onSurface,
                            fontWeight:
                                isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                            fontSize: 14,
                            height: 1.3,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (entry.isFavorite)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Icon(
                              Icons.favorite_rounded,
                              size: 12,
                              color: colorScheme.primary,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.book_rounded, size: 20, color: colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                'Diary Entries (${_entries.length})',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child:
                _isLoading
                    ? Center(
                      child: CircularProgressIndicator(
                        color: colorScheme.primary,
                      ),
                    )
                    : _entries.isEmpty
                    ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.calendar_today_rounded,
                            size: 48,
                            color: colorScheme.onSurfaceVariant.withAlpha(100),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No diary entries',
                            style: TextStyle(
                              color: colorScheme.onSurfaceVariant.withAlpha(
                                150,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                    : ListView.builder(
                      itemCount: _entries.length,
                      itemBuilder: (context, index) {
                        return _buildEntryItem(_entries[index]);
                      },
                    ),
          ),
        ],
      ),
    );
  }
}
