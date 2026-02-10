import 'package:flutter/material.dart';
import '../database/models/calendar_event_status.dart';
import '../database/repositories/calendar_event_status_repository.dart';
import '../database/database_helper.dart';
import 'confirmation_dialogue.dart';
import 'custom_dialog.dart';

class CalendarEventStatusManager extends StatefulWidget {
  final Function(CalendarEventStatus) onStatusSelected;
  final CalendarEventStatus? currentStatus;

  const CalendarEventStatusManager({
    super.key,
    required this.onStatusSelected,
    this.currentStatus,
  });

  @override
  State<CalendarEventStatusManager> createState() =>
      _CalendarEventStatusManagerState();
}

class _CalendarEventStatusManagerState
    extends State<CalendarEventStatusManager> {
  late CalendarEventStatusRepository _statusRepository;
  List<CalendarEventStatus> _statuses = [];
  bool _isLoading = true;

  static const List<Map<String, dynamic>> _predefinedColors = [
    {'name': 'Coral', 'hex': '#FFB4AB'},
    {'name': 'Peach', 'hex': '#FFB4A1'},
    {'name': 'Orange', 'hex': '#FFB77D'},
    {'name': 'Yellow', 'hex': '#FFD54F'},
    {'name': 'Lime', 'hex': '#C8E6C9'},
    {'name': 'Green', 'hex': '#A5D6A7'},
    {'name': 'Teal', 'hex': '#80CBC4'},
    {'name': 'Cyan', 'hex': '#80DEEA'},
    {'name': 'Blue', 'hex': '#90CAF9'},
    {'name': 'Indigo', 'hex': '#9FA8DA'},
    {'name': 'Purple', 'hex': '#CE93D8'},
    {'name': 'Pink', 'hex': '#F8BBD9'},
    {'name': 'Rose', 'hex': '#F48FB1'},
    {'name': 'Red', 'hex': '#EF9A9A'},
    {'name': 'Brown', 'hex': '#BCAAA4'},
    {'name': 'Gray', 'hex': '#E0E0E0'},
  ];

  @override
  void initState() {
    super.initState();
    _statusRepository = CalendarEventStatusRepository(DatabaseHelper());
    _loadStatuses();
  }

  Future<void> _loadStatuses() async {
    try {
      final statuses = await _statusRepository.getAllStatuses();
      if (mounted) {
        setState(() {
          _statuses = statuses;
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

  Future<void> _addNewStatus() async {
    final TextEditingController nameController = TextEditingController();
    String selectedColor = _predefinedColors.first['hex'];

    final result = await showDialog<bool>(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setState) => CustomDialog(
                  title: 'Add New Label',
                  icon: Icons.new_label_rounded,
                  width: 400,
                  bottomBar: Container(
                    height: 56,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () => Navigator.of(context).pop(false),
                            style: TextButton.styleFrom(
                              backgroundColor:
                                  Theme.of(
                                    context,
                                  ).colorScheme.surfaceContainerHigh,
                              foregroundColor:
                                  Theme.of(context).colorScheme.onSurface,
                              minimumSize: const Size(0, 44),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text(
                              'Cancel',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.normal,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => Navigator.of(context).pop(true),
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  Theme.of(context).colorScheme.primary,
                              foregroundColor:
                                  Theme.of(context).colorScheme.onPrimary,
                              minimumSize: const Size(0, 44),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text(
                              'Add',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextFormField(
                          controller: nameController,
                          decoration: InputDecoration(
                            labelText: 'Label Name*',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            filled: true,
                            fillColor: Theme.of(
                              context,
                            ).colorScheme.surfaceContainerHighest.withAlpha(76),
                            prefixIcon: const Icon(Icons.label_rounded),
                          ),
                          validator:
                              (value) =>
                                  value?.isEmpty ?? true ? 'Required' : null,
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Text(
                              'Select Color:',
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          alignment: WrapAlignment.start,
                          children:
                              _predefinedColors.map((color) {
                                final isSelected =
                                    selectedColor == color['hex'];
                                return GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      selectedColor = color['hex'];
                                    });
                                  },
                                  child: Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: _parseColor(color['hex']),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color:
                                            isSelected
                                                ? Theme.of(
                                                  context,
                                                ).colorScheme.primary
                                                : _parseColor(
                                                      color['hex'],
                                                    ).computeLuminance() >
                                                    0.8
                                                ? Colors.grey.withAlpha(127)
                                                : Colors.transparent,
                                        width: isSelected ? 3 : 1,
                                      ),
                                    ),
                                    child:
                                        isSelected
                                            ? Icon(
                                              Icons.check_rounded,
                                              color:
                                                  _parseColor(
                                                            color['hex'],
                                                          ).computeLuminance() >
                                                          0.5
                                                      ? Colors.black
                                                      : Colors.white,
                                              size: 20,
                                            )
                                            : null,
                                  ),
                                );
                              }).toList(),
                        ),
                      ],
                    ),
                  ),
                ),
          ),
    );

    if (result == true && nameController.text.isNotEmpty) {
      try {
        final newStatus = CalendarEventStatus(
          id: 0,
          name: nameController.text.trim(),
          color: selectedColor,
          orderIndex: 0,
        );
        await _statusRepository.createStatus(newStatus);
        DatabaseHelper.notifyDatabaseChanged();
        await _loadStatuses();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error adding label: $e')));
        }
      }
    }
  }

  Future<void> _onReorder(int oldIndex, int newIndex) async {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }

    final List<CalendarEventStatus> reorderedStatuses = List.from(_statuses);
    final CalendarEventStatus item = reorderedStatuses.removeAt(oldIndex);
    reorderedStatuses.insert(newIndex, item);

    try {
      for (int i = 0; i < reorderedStatuses.length; i++) {
        final updatedStatus = reorderedStatuses[i].copyWith(orderIndex: i);
        await _statusRepository.updateStatus(updatedStatus);
      }

      DatabaseHelper.notifyDatabaseChanged();
      await _loadStatuses();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating label order: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _deleteStatus(CalendarEventStatus status) async {
    final result = await showDeleteConfirmationDialog(
      context: context,
      title: 'Delete Label',
      message:
          'Are you sure you want to delete "${status.name}"?\nThis action cannot be undone.',
      confirmText: 'Delete',
      confirmColor: Theme.of(context).colorScheme.error,
    );

    if (result == true) {
      try {
        await _statusRepository.deleteStatus(status.id);
        DatabaseHelper.notifyDatabaseChanged();
        await _loadStatuses();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error deleting label: $e')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return CustomDialog(
      title: 'Event Labels',
      icon: Icons.label_rounded,
      width: 400,
      height: 300,
      headerActions: [
        IconButton(
          icon: Icon(Icons.new_label_rounded, color: colorScheme.primary),
          onPressed: _addNewStatus,
        ),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child:
            _statuses.isEmpty
                ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.label_outline_rounded,
                        size: 48,
                        color: colorScheme.onSurfaceVariant.withAlpha(127),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No labels defined',
                        style: TextStyle(
                          color: colorScheme.onSurfaceVariant,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Add your first label to get started',
                        style: TextStyle(
                          color: colorScheme.onSurfaceVariant.withAlpha(150),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                )
                : ReorderableListView.builder(
                  itemCount: _statuses.length,
                  onReorder: _onReorder,
                  buildDefaultDragHandles: false,
                  itemBuilder: (context, index) {
                    final status = _statuses[index];
                    final isSelected = widget.currentStatus?.id == status.id;

                    return ReorderableDragStartListener(
                      key: ValueKey(status.id),
                      index: index,
                      child: MouseRegionHoverItem(
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
                                onTap: () {
                                  widget.onStatusSelected(status);
                                  Navigator.of(context).pop();
                                },
                                borderRadius: BorderRadius.circular(12),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 12,
                                        height: 12,
                                        decoration: BoxDecoration(
                                          color: _parseColor(status.color),
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          status.name,
                                          style: Theme.of(
                                            context,
                                          ).textTheme.bodyMedium?.copyWith(
                                            color:
                                                isSelected
                                                    ? colorScheme.primary
                                                    : colorScheme.onSurface,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                      if (isSelected)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            right: 8,
                                          ),
                                          child: Icon(
                                            Icons.check_rounded,
                                            color: colorScheme.primary,
                                            size: 18,
                                          ),
                                        ),

                                      Opacity(
                                        opacity: isHovering ? 1.0 : 0.0,
                                        child: IgnorePointer(
                                          ignoring: !isHovering,
                                          child: MouseRegion(
                                            cursor: SystemMouseCursors.click,
                                            child: GestureDetector(
                                              onTap:
                                                  () => _deleteStatus(status),
                                              child: Container(
                                                padding: const EdgeInsets.all(
                                                  4,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: colorScheme.error
                                                      .withAlpha(20),
                                                  borderRadius:
                                                      BorderRadius.circular(6),
                                                ),
                                                child: Icon(
                                                  Icons.close_rounded,
                                                  size: 14,
                                                  color: colorScheme.error,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
      ),
    );
  }

  Color _parseColor(String colorString) {
    try {
      if (colorString.startsWith('#')) {
        return Color(
          int.parse(colorString.substring(1), radix: 16) + 0xFF000000,
        );
      }
      return Colors.blue;
    } catch (e) {
      return Colors.blue;
    }
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
