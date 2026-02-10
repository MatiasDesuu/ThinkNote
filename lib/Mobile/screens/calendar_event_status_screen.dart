import 'package:flutter/material.dart';
import '../../database/models/calendar_event_status.dart';
import '../../database/repositories/calendar_event_status_repository.dart';
import '../../database/database_helper.dart';
import '../../widgets/custom_snackbar.dart';
import '../../widgets/confirmation_dialogue.dart';

class CalendarEventStatusScreen extends StatefulWidget {
  const CalendarEventStatusScreen({super.key});

  @override
  State<CalendarEventStatusScreen> createState() =>
      _CalendarEventStatusScreenState();
}

class _CalendarEventStatusScreenState extends State<CalendarEventStatusScreen> {
  final TextEditingController _newStatusController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
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

  @override
  void dispose() {
    _newStatusController.dispose();
    super.dispose();
  }

  Future<void> _loadStatuses() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final statuses = await _statusRepository.getAllStatuses();
      if (mounted) {
        setState(() {
          _statuses = statuses;
          _isLoading = false;
        });
      }

      if (statuses.isEmpty) {
        await _initializeDefaultStatuses();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        CustomSnackbar.show(
          context: context,
          message: 'Error loading labels: ${e.toString()}',
          type: CustomSnackbarType.error,
        );
      }
    }
  }

  Future<void> _initializeDefaultStatuses() async {
    final defaultStatuses = [
      CalendarEventStatus(
        id: 0,
        name: 'To Write',
        color: '#FFB77D', // Orange pastel
        orderIndex: 0,
      ),
      CalendarEventStatus(
        id: 0,
        name: 'To Record',
        color: '#90CAF9', // Blue pastel
        orderIndex: 1,
      ),
      CalendarEventStatus(
        id: 0,
        name: 'In Progress',
        color: '#CE93D8', // Purple pastel
        orderIndex: 2,
      ),
      CalendarEventStatus(
        id: 0,
        name: 'Completed',
        color: '#A5D6A7', // Green pastel
        orderIndex: 3,
      ),
    ];

    for (final status in defaultStatuses) {
      try {
        await _statusRepository.createStatus(status);
      } catch (e) {
        // Ignore if status already exists
      }
    }

    await _loadStatuses();
  }

  Future<void> _addNewStatus(String selectedColor) async {
    if (!_formKey.currentState!.validate()) return;

    final newStatusName = _newStatusController.text.trim();
    if (newStatusName.isEmpty) return;

    if (_statuses.any(
      (status) => status.name.toLowerCase() == newStatusName.toLowerCase(),
    )) {
      if (mounted) {
        CustomSnackbar.show(
          context: context,
          message: 'This label already exists',
          type: CustomSnackbarType.error,
        );
      }
      return;
    }

    try {
      final nextOrderIndex =
          _statuses.isEmpty
              ? 0
              : _statuses
                      .map((s) => s.orderIndex)
                      .reduce((a, b) => a > b ? a : b) +
                  1;
      final newStatus = CalendarEventStatus(
        id: 0,
        name: newStatusName,
        color: selectedColor,
        orderIndex: nextOrderIndex,
      );

      await _statusRepository.createStatus(newStatus);
      DatabaseHelper.notifyDatabaseChanged();
      _newStatusController.clear();
      await _loadStatuses();

      if (mounted) {
        CustomSnackbar.show(
          context: context,
          message: 'Label added successfully',
          type: CustomSnackbarType.success,
        );
      }
    } catch (e) {
      if (mounted) {
        CustomSnackbar.show(
          context: context,
          message: 'Error adding label: ${e.toString()}',
          type: CustomSnackbarType.error,
        );
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
        CustomSnackbar.show(
          context: context,
          message: 'Error updating label order: ${e.toString()}',
          type: CustomSnackbarType.error,
        );
      }
    }
  }

  Future<void> _deleteStatus(CalendarEventStatus status) async {
    try {
      await _statusRepository.deleteStatus(status.id);
      DatabaseHelper.notifyDatabaseChanged();
      await _loadStatuses();
    } catch (e) {
      if (mounted) {
        CustomSnackbar.show(
          context: context,
          message: 'Error deleting label: ${e.toString()}',
          type: CustomSnackbarType.error,
        );
      }
    }
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

  void _showAddStatusDialog() {
    _newStatusController.clear();
    String selectedColor = _predefinedColors.first['hex'];

    showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        final bottomPadding = MediaQuery.of(context).padding.bottom;
        final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
        final colorScheme = Theme.of(context).colorScheme;

        return StatefulBuilder(
          builder:
              (context, setState) => Padding(
                padding: EdgeInsets.only(
                  bottom: keyboardHeight + bottomPadding,
                  left: 16,
                  right: 16,
                  top: 16,
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SingleChildScrollView(
                        physics: const ClampingScrollPhysics(),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TextFormField(
                              controller: _newStatusController,
                              decoration: InputDecoration(
                                labelText: 'Label name',
                                hintText: 'Enter the label name',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                filled: true,
                                fillColor: colorScheme.surfaceContainerHighest
                                    .withAlpha(76),
                                prefixIcon: Icon(
                                  Icons.label_rounded,
                                  color: colorScheme.primary,
                                ),
                              ),
                              validator:
                                  (value) =>
                                      value?.isEmpty ?? true
                                          ? 'Required'
                                          : null,
                              autofocus: true,
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Text(
                                  'Select Color:',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w500,
                                    color: colorScheme.onSurface,
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
                                                    ? colorScheme.primary
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
                            const SizedBox(height: 20),
                          ],
                        ),
                      ),
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.only(bottom: bottomPadding),
                        child: ElevatedButton(
                          onPressed: () async {
                            if (_formKey.currentState!.validate()) {
                              await _addNewStatus(selectedColor);
                              if (context.mounted) {
                                Navigator.pop(context, true);
                              }
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: colorScheme.primary,
                            foregroundColor: colorScheme.onPrimary,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Add',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
        );
      },
    ).then((result) {
      if (result == true && mounted) {
        _loadStatuses();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, bool? result) {
        if (!didPop) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          toolbarHeight: 40.0,
          scrolledUnderElevation: 0,
          surfaceTintColor: Colors.transparent,
          backgroundColor: Theme.of(context).colorScheme.surface,
          title: const Text('Event Labels'),
          actions: [
            IconButton(
              icon: Icon(Icons.new_label_rounded, color: colorScheme.primary),
              onPressed: _showAddStatusDialog,
            ),
          ],
        ),
        body:
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _statuses.isEmpty
                ? Center(
                  child: Text(
                    'No labels created yet',
                    style: TextStyle(color: colorScheme.onSurfaceVariant),
                  ),
                )
                : ReorderableListView.builder(
                  itemCount: _statuses.length,
                  onReorder: _onReorder,
                  buildDefaultDragHandles: false,
                  itemBuilder: (context, index) {
                    final status = _statuses[index];
                    return ReorderableDragStartListener(
                      key: ValueKey(status.id),
                      index: index,
                      child: Dismissible(
                        key: Key(status.id.toString()),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          color: colorScheme.error,
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          child: Icon(
                            Icons.delete_rounded,
                            color: colorScheme.onError,
                            size: 28,
                          ),
                        ),
                        confirmDismiss: (direction) async {
                          final result = await showDeleteConfirmationDialog(
                            context: context,
                            title: 'Delete Label',
                            message:
                                'Are you sure you want to delete this label?\n${status.name}',
                            confirmText: 'Delete',
                            confirmColor: colorScheme.error,
                          );
                          return result ?? false;
                        },
                        onDismissed: (_) {
                          _deleteStatus(status);
                        },
                        child: ListTile(
                          leading: Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: _parseColor(status.color),
                              shape: BoxShape.circle,
                            ),
                          ),
                          title: Text(status.name),
                        ),
                      ),
                    );
                  },
                ),
      ),
    );
  }
}
