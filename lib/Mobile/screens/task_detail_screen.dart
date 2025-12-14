import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import '../../database/database_service.dart';
import '../../database/models/task.dart';
import '../../database/models/subtask.dart';
import 'tags_screen.dart' as tasks;
import '../../widgets/custom_snackbar.dart';
import '../../widgets/confirmation_dialogue.dart';
import '../../Tasks/habits_widget.dart';

class TaskDetailScreen extends StatefulWidget {
  final Task task;
  final DatabaseService databaseService;

  const TaskDetailScreen({
    super.key,
    required this.task,
    required this.databaseService,
  });

  @override
  State<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends State<TaskDetailScreen>
    with SingleTickerProviderStateMixin {
  late Task _task;
  bool _isHabits = false;
  List<Subtask>? _cachedSubtasks;
  Map<int, List<String>>? _cachedHabitCompletions;
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _newSubtaskController = TextEditingController();
  DateTime? _selectedDate;
  bool _taskChanged = false;
  bool _isExiting = false;
  Timer? _debounceTimer;
  String? _editingSubtaskId;
  final TextEditingController _editingController = TextEditingController();
  int _habitsWeekOffset = 0;
  // _habitsWeekHover and _habitsWeekPressed removed: we use a plain button now.
  StreamSubscription<void>? _dbChangeSubscription;
  final Set<String> _expandedSubtasks = <String>{};
  late TabController _subtasksTabController;

  @override
  void initState() {
    super.initState();
    _subtasksTabController = TabController(length: 2, vsync: this);
    _task = widget.task;
    _nameController.text = _task.name;
    _selectedDate = _task.date;

    _nameController.addListener(() {
      if (_nameController.text != _task.name) {
        setState(() {
          _taskChanged = true;
          _task = _task.copyWith(name: _nameController.text);
        });
      }
    });

    // Guardar inmediatamente al inicio
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _saveTask();
    });
    // load whether this task is a Habits task and prefetch subtasks
    _loadIsHabits();
    _prefetchSubtasks();

    // Listen for external DB changes so tag updates (e.g., adding/removing 'Habits')
    // are reflected immediately in this screen without requiring navigation.
    try {
      _dbChangeSubscription = widget.databaseService.onDatabaseChanged.listen((
        _,
      ) async {
        // reload tags and subtasks when DB changes
        await _loadIsHabits();
        await _refreshCachedSubtasks();
      });
    } catch (_) {}
  }

  Future<void> _prefetchSubtasks() async {
    if (_task.id == null) return;
    try {
      final subs =
          _task.sortByPriority
              ? await widget.databaseService.taskService
                  .getSubtasksByTaskIdWithPrioritySort(_task.id!)
              : await widget.databaseService.taskService.getSubtasksByTaskId(
                _task.id!,
              );
      // Also prefetch habit completions for instant rendering in HabitsTracker
      try {
        _cachedHabitCompletions = await widget.databaseService.taskService
            .getHabitCompletionsForTask(_task.id!);
      } catch (_) {
        _cachedHabitCompletions = null;
      }
      if (!mounted) return;
      setState(() {
        _cachedSubtasks = subs;
      });
    } catch (_) {
      // ignore
    }
  }

  Future<void> _refreshCachedSubtasks() async {
    // refresh from DB when notified
    await _prefetchSubtasks();
  }

  Future<void> _loadIsHabits() async {
    if (_task.id == null) return;
    try {
      final tags = await widget.databaseService.taskService.getTagsByTaskId(
        _task.id!,
      );
      if (!mounted) return;
      setState(() {
        _isHabits = tags.contains('Habits');
      });
    } catch (e) {
      // ignore
    }
  }

  @override
  void dispose() {
    _dbChangeSubscription?.cancel();
    _nameController.dispose();
    _newSubtaskController.dispose();
    _editingController.dispose();
    _debounceTimer?.cancel();
    _subtasksTabController.dispose();
    if (_taskChanged && !_isExiting) {
      _saveTask();
    }
    super.dispose();
  }

  Future<void> _saveTask() async {
    try {
      if (_nameController.text.trim().isEmpty) {
        _task = _task.copyWith(name: "No title");
        _nameController.text = "No title";
      }

      _task = _task.copyWith(date: _selectedDate, updatedAt: DateTime.now());

      await widget.databaseService.taskService.updateTask(_task);
      if (!mounted) return;
      setState(() {
        _taskChanged = false;
      });
    } catch (e) {
      print('Error saving task: $e');
      if (!mounted) return;
      CustomSnackbar.show(
        context: context,
        message: 'Error saving task: ${e.toString()}',
        type: CustomSnackbarType.error,
      );
    }
  }

  Future<bool> _saveAndExit() async {
    _isExiting = true;
    if (_taskChanged || _nameController.text.trim().isEmpty) {
      if (_nameController.text.trim().isEmpty) {
        _task = _task.copyWith(name: "No title");
        _nameController.text = "No title";
      }

      try {
        await _saveTask();
      } catch (e) {
        print('Error saving before exit: $e');
      }
    }

    if (!mounted) return true;
    Navigator.of(context).pop(true);
    return true;
  }

  Future<void> _addSubtask() async {
    if (_newSubtaskController.text.trim().isEmpty) return;

    try {
      final subtask = await widget.databaseService.taskService.createSubtask(
        _task.id!,
        _newSubtaskController.text.trim(),
      );

      if (subtask != null) {
        if (!mounted) return;
        // Clear input and refresh cached subtasks immediately so the UI shows the new habit.
        _newSubtaskController.clear();
        setState(() {
          _taskChanged = true;
        });

        // Refresh the cached subtasks from DB so the HabitsTracker receives updated list.
        await _prefetchSubtasks();

        // Also notify the DatabaseService so other listeners (if any) can react.
        try {
          widget.databaseService.notifyDatabaseChanged();
        } catch (_) {}

        await _saveTask();
      }
    } catch (e) {
      print('Error adding subtask: $e');
      if (!mounted) return;
      CustomSnackbar.show(
        context: context,
        message: 'Error adding subtask: ${e.toString()}',
        type: CustomSnackbarType.error,
      );
    }
  }

  Future<void> _toggleSubtask(Subtask subtask) async {
    try {
      await widget.databaseService.taskService.toggleSubtaskCompleted(
        subtask,
        !subtask.completed,
      );
      if (!mounted) return;
      setState(() {
        _taskChanged = true;
      });
      await _saveTask();

      // Notify database changed to refresh cached subtasks
      try {
        widget.databaseService.notifyDatabaseChanged();
      } catch (_) {}
    } catch (e) {
      print('Error toggling subtask: $e');
      if (!mounted) return;
      CustomSnackbar.show(
        context: context,
        message: 'Error updating subtask: ${e.toString()}',
        type: CustomSnackbarType.error,
      );
    }
  }

  Future<void> _reorderSubtasks(int oldIndex, int newIndex) async {
    if (_task.sortByPriority) return;

    try {
      final subtasks = await widget.databaseService.taskService
          .getSubtasksByTaskId(_task.id!);
      if (newIndex > oldIndex) {
        newIndex -= 1;
      }
      final item = subtasks.removeAt(oldIndex);
      subtasks.insert(newIndex, item);

      // Actualizar el orden de todas las subtareas
      for (int i = 0; i < subtasks.length; i++) {
        final subtask = subtasks[i].copyWith(orderIndex: i);
        await widget.databaseService.taskService.updateSubtask(subtask);
      }

      if (!mounted) return;
      setState(() {
        _taskChanged = true;
      });
      await _saveTask();

      // Notify database changed to refresh cached subtasks
      try {
        widget.databaseService.notifyDatabaseChanged();
      } catch (_) {}
    } catch (e) {
      print('Error reordering subtasks: $e');
      if (!mounted) return;
      CustomSnackbar.show(
        context: context,
        message: 'Error reordering subtasks: ${e.toString()}',
        type: CustomSnackbarType.error,
      );
    }
  }

  Future<void> _updateTaskState(TaskState state) async {
    try {
      await widget.databaseService.taskService.updateTaskState(
        _task.id!,
        state,
      );
      if (!mounted) return;
      setState(() {
        _task = _task.copyWith(
          state: state,
          completed: state == TaskState.completed,
        );
        _taskChanged = true;
      });
      await _saveTask();
    } catch (e) {
      print('Error updating task state: $e');
      if (!mounted) return;
      CustomSnackbar.show(
        context: context,
        message: 'Error updating task state: ${e.toString()}',
        type: CustomSnackbarType.error,
      );
    }
  }

  String _getStateText(TaskState state) {
    switch (state) {
      case TaskState.pending:
        return 'Pending';
      case TaskState.inProgress:
        return 'In progress';
      case TaskState.completed:
        return 'Completed';
      case TaskState.none:
        return 'No status';
    }
  }

  Color _getStateColor(TaskState state) {
    final colorScheme = Theme.of(context).colorScheme;
    switch (state) {
      case TaskState.pending:
        return colorScheme.onSurfaceVariant;
      case TaskState.inProgress:
        return const Color(0xFFB75D0A);
      case TaskState.completed:
        return colorScheme.primary;
      case TaskState.none:
        return colorScheme.onSurfaceVariant;
    }
  }

  Future<void> _editSubtask(Subtask subtask) async {
    setState(() {
      _editingSubtaskId = subtask.id.toString();
      _editingController.text = subtask.text;
    });
  }

  Future<void> _saveSubtaskEditing(Subtask subtask) async {
    if (_editingController.text.trim().isEmpty) return;

    try {
      final updatedSubtask = subtask.copyWith(
        text: _editingController.text.trim(),
      );
      await widget.databaseService.taskService.updateSubtask(updatedSubtask);
      setState(() {
        _editingSubtaskId = null;
        _taskChanged = true;
      });
      await _saveTask();

      // Notify database changed to refresh cached subtasks
      try {
        widget.databaseService.notifyDatabaseChanged();
      } catch (_) {}
    } catch (e) {
      print('Error saving subtask edit: $e');
      if (!mounted) return;
      CustomSnackbar.show(
        context: context,
        message: 'Error saving subtask: ${e.toString()}',
        type: CustomSnackbarType.error,
      );
    }
  }

  void _cancelSubtaskEditing() {
    setState(() {
      _editingSubtaskId = null;
    });
  }

  Future<void> _updateSubtaskPriority(
    Subtask subtask,
    SubtaskPriority priority,
  ) async {
    try {
      await widget.databaseService.taskService.updateSubtaskPriority(
        subtask,
        priority,
      );
      setState(() {
        _taskChanged = true;
      });
      await _saveTask();

      // Notify database changed to refresh cached subtasks
      try {
        widget.databaseService.notifyDatabaseChanged();
      } catch (_) {}
    } catch (e) {
      print('Error updating subtask priority: $e');
      if (!mounted) return;
      CustomSnackbar.show(
        context: context,
        message: 'Error updating priority: ${e.toString()}',
        type: CustomSnackbarType.error,
      );
    }
  }

  IconData _getPriorityIcon(SubtaskPriority priority) {
    switch (priority) {
      case SubtaskPriority.high:
        return Icons.arrow_upward_rounded;
      case SubtaskPriority.medium:
        return Icons.remove_rounded;
      case SubtaskPriority.low:
        return Icons.arrow_downward_rounded;
    }
  }

  Color _getPriorityColor(SubtaskPriority priority) {
    switch (priority) {
      case SubtaskPriority.high:
        return Colors.red[700]!;
      case SubtaskPriority.medium:
        return Colors.orange[700]!;
      case SubtaskPriority.low:
        return Colors.green[700]!;
    }
  }

  String _getPriorityText(SubtaskPriority priority) {
    switch (priority) {
      case SubtaskPriority.high:
        return 'High';
      case SubtaskPriority.medium:
        return 'Medium';
      case SubtaskPriority.low:
        return 'Low';
    }
  }

  Widget _buildActionChip({
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
    required ColorScheme colorScheme,
    VoidCallback? onClear,
    Color? activeColor,
  }) {
    final chipColor = activeColor ?? colorScheme.primary;

    return Material(
      color: isActive ? chipColor.withAlpha(25) : colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        hoverColor: colorScheme.primary.withAlpha(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 20,
                color: colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: isActive ? chipColor : colorScheme.onSurface,
                ),
              ),
              if (onClear != null) ...[
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: onClear,
                  child: Icon(
                    Icons.close_rounded,
                    size: 16,
                    color: chipColor.withAlpha(180),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNewSubtaskInput({required ColorScheme colorScheme}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorScheme.outlineVariant.withAlpha(100),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // Add button
          Material(
            color: colorScheme.primaryContainer.withAlpha(80),
            borderRadius: BorderRadius.circular(8),
            child: InkWell(
              onTap: _addSubtask,
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 40,
                height: 40,
                child: Icon(
                  Icons.add_rounded,
                  color: colorScheme.primary,
                  size: 22,
                ),
              ),
            ),
          ),

          // Text field
          Expanded(
            child: TextField(
              controller: _newSubtaskController,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: 'Add subtask...',
                hintStyle: TextStyle(
                  color: colorScheme.onSurfaceVariant.withAlpha(150),
                  fontSize: 14,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              ),
              style: TextStyle(fontSize: 14, color: colorScheme.onSurface),
              onSubmitted: (_) => _addSubtask(),
            ),
          ),

          // Sort toggle button
          Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            child: InkWell(
              onTap: () async {
                setState(() {
                  _task = _task.copyWith(sortByPriority: !_task.sortByPriority);
                  _taskChanged = true;
                });
                await _saveTask();
              },
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 40,
                height: 40,
                child: Icon(
                  _task.sortByPriority
                      ? Icons.sort_rounded
                      : Icons.swap_vert_rounded,
                  color:
                      _task.sortByPriority
                          ? colorScheme.primary
                          : colorScheme.onSurfaceVariant,
                  size: 22,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _selectDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _task.date ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date != null) {
      try {
        final updatedTask = _task.copyWith(
          date: date,
          updatedAt: DateTime.now(),
        );
        await widget.databaseService.taskService.updateTask(updatedTask);
        if (!mounted) return;
        setState(() {
          _task = updatedTask;
          _selectedDate = date;
          _taskChanged = false;
        });
      } catch (e) {
        if (!mounted) return;
        CustomSnackbar.show(
          context: context,
          message: 'Error updating date: ${e.toString()}',
          type: CustomSnackbarType.error,
        );
      }
    }
  }

  Future<void> _clearDate() async {
    try {
      final updatedTask = _task.copyWith(
        clearDate: true,
        updatedAt: DateTime.now(),
      );
      await widget.databaseService.taskService.updateTask(updatedTask);
      if (!mounted) return;
      setState(() {
        _task = updatedTask;
        _selectedDate = null;
        _taskChanged = false;
      });
    } catch (e) {
      if (!mounted) return;
      CustomSnackbar.show(
        context: context,
        message: 'Error clearing date: ${e.toString()}',
        type: CustomSnackbarType.error,
      );
    }
  }

  Widget _buildSubtaskItem(
    Subtask subtask,
    bool isEditing,
    ColorScheme colorScheme,
    int index,
  ) {
    final isCompleted = subtask.completed;

    return Dismissible(
      key: Key(subtask.id.toString()),
      direction: DismissDirection.horizontal,
      background: Container(
        decoration: BoxDecoration(
          color: colorScheme.tertiary,
          borderRadius: BorderRadius.circular(10),
        ),
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20),
        child: Icon(Icons.check_rounded, color: colorScheme.onTertiary),
      ),
      secondaryBackground: Container(
        decoration: BoxDecoration(
          color: colorScheme.error,
          borderRadius: BorderRadius.circular(10),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: Icon(Icons.delete_rounded, color: colorScheme.onError),
      ),
      onDismissed: (direction) {
        if (direction == DismissDirection.endToStart) {
          final scaffoldMessenger = ScaffoldMessenger.of(context);
          widget.databaseService.taskService
              .deleteSubtask(subtask.id!)
              .then((_) {
                if (!mounted) return;
                setState(() {
                  _taskChanged = true;
                });
                _saveTask();

                // Notify database changed to refresh cached subtasks
                try {
                  widget.databaseService.notifyDatabaseChanged();
                } catch (_) {}
              })
              .catchError((e) {
                if (!mounted) return;
                scaffoldMessenger.showSnackBar(
                  SnackBar(
                    content: Text('Error deleting subtask: \${e.toString()}'),
                    backgroundColor: colorScheme.error,
                  ),
                );
              });
        } else {
          _toggleSubtask(subtask);
        }
      },
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          _toggleSubtask(subtask);
          return false;
        }
        final result = await showDeleteConfirmationDialog(
          context: context,
          title: 'Delete Subtask',
          message:
              'Are you sure you want to delete this subtask?\n\${subtask.text}',
          confirmText: 'Delete',
          confirmColor: colorScheme.error,
        );
        return result ?? false;
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 4, left: 8, right: 8),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              // Drag handle (only for pending and manual sort)
              if (!_task.sortByPriority && !isCompleted)
                ReorderableDragStartListener(
                  index: index,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Icon(
                      Icons.drag_indicator_rounded,
                      color: colorScheme.onSurfaceVariant.withAlpha(100),
                      size: 18,
                    ),
                  ),
                ),

              // Custom checkbox
              GestureDetector(
                onTap: () => _toggleSubtask(subtask),
                child: Icon(
                  isCompleted ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                  size: 20,
                  color: isCompleted ? colorScheme.primary : colorScheme.onSurfaceVariant,
                ),
              ),

              const SizedBox(width: 12),

              // Priority indicator (only for pending)
              if (!isCompleted && subtask.priority != SubtaskPriority.medium)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: _getPriorityColor(subtask.priority),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),

              // Title or edit field
              Expanded(
                child:
                    isEditing
                        ? TextField(
                          controller: _editingController,
                          autofocus: true,
                          decoration: InputDecoration(
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(
                                color: colorScheme.primary.withAlpha(100),
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(
                                color: colorScheme.outlineVariant.withAlpha(
                                  100,
                                ),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(
                                color: colorScheme.primary,
                              ),
                            ),
                            filled: true,
                            fillColor: colorScheme.surface,
                          ),
                          style: TextStyle(
                            fontSize: 15,
                            color: colorScheme.onSurface,
                          ),
                          onSubmitted: (_) => _saveSubtaskEditing(subtask),
                          onEditingComplete: () => _saveSubtaskEditing(subtask),
                          onTapOutside: (_) => _cancelSubtaskEditing(),
                        )
                        : GestureDetector(
                          onTap:
                              () => _toggleSubtaskExpansion(
                                subtask.id.toString(),
                              ),
                          onLongPress: () => _editSubtask(subtask),
                          child: Text(
                            subtask.text,
                            maxLines:
                                _expandedSubtasks.contains(
                                      subtask.id.toString(),
                                    )
                                    ? null
                                    : 1,
                            overflow:
                                _expandedSubtasks.contains(
                                      subtask.id.toString(),
                                    )
                                    ? TextOverflow.visible
                                    : TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 15,
                              decoration:
                                  isCompleted
                                      ? TextDecoration.lineThrough
                                      : null,
                              color:
                                  isCompleted
                                      ? colorScheme.onSurfaceVariant
                                      : colorScheme.onSurface,
                            ),
                          ),
                        ),
              ),

              // Priority button (always visible on mobile)
              if (!isCompleted)
                Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                  child: InkWell(
                    onTap: () => _showPrioritySelector(subtask),
                    borderRadius: BorderRadius.circular(6),
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: Icon(
                        _getPriorityIcon(subtask.priority),
                        color: _getPriorityColor(subtask.priority),
                        size: 18,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, bool? result) async {
        if (didPop) return;
        await _saveAndExit();
      },
      child: Scaffold(
        appBar: AppBar(
          scrolledUnderElevation: 0,
          surfaceTintColor: Colors.transparent,
          backgroundColor: Theme.of(context).colorScheme.surface,
          title:
              _isHabits
                  ? Row(
                    children: [
                      Icon(
                        Icons.self_improvement_rounded,
                        color: colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      const Text('Habits Details'),
                    ],
                  )
                  : const Text('Task Details'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: _saveAndExit,
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.delete_rounded),
              color: colorScheme.error,
              onPressed: () async {
                final confirmed = await showDeleteConfirmationDialog(
                  context: context,
                  title: 'Delete Task',
                  message:
                      'Are you sure you want to delete this task?\n${_task.name}',
                  confirmText: 'Delete',
                  confirmColor: colorScheme.error,
                );

                if (confirmed == true) {
                  try {
                    await widget.databaseService.taskService.deleteTask(
                      _task.id!,
                    );
                    if (!context.mounted) return;
                    Navigator.of(context).pop(true);
                  } catch (e) {
                    if (!context.mounted) return;
                    CustomSnackbar.show(
                      context: context,
                      message: 'Error deleting task: ${e.toString()}',
                      type: CustomSnackbarType.error,
                    );
                  }
                }
              },
            ),
          ],
        ),
        body: Column(
          children: [
            // Header section
            Container(
              margin: const EdgeInsets.only(left: 8, right: 8, bottom: 4),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(16),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title row
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _nameController,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: const InputDecoration(
                            hintText: 'Task title...',
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.zero,
                          ),
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w600,
                            color: colorScheme.onSurface,
                          ),
                        ),
                      ),
                      // Pin button
                      Material(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        child: InkWell(
                          onTap: _toggleTaskPinned,
                          borderRadius: BorderRadius.circular(8),
                          child: SizedBox(
                            width: 40,
                            height: 40,
                            child: Icon(
                              _task.isPinned
                                  ? Icons.push_pin_rounded
                                  : Icons.push_pin_outlined,
                              size: 22,
                              color:
                                  _task.isPinned
                                      ? colorScheme.primary
                                      : colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  if (!_isHabits) ...[
                    // Action chips row
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          // Date chip
                          _buildActionChip(
                            icon: Icons.calendar_today_rounded,
                            label:
                                _task.date == null
                                    ? 'Add date'
                                    : DateFormat(
                                      'MMM d, yyyy',
                                    ).format(_task.date!),
                            isActive: _task.date != null,
                            onTap: () => _selectDate(),
                            onClear:
                                _task.date != null ? () => _clearDate() : null,
                            colorScheme: colorScheme,
                          ),
                          const SizedBox(width: 4),

                          // Status chip
                          _buildActionChip(
                            icon: _getStateIconData(_task.state),
                            label: _getStateText(_task.state),
                            isActive: _task.state != TaskState.none,
                            onTap: _showStateSelector,
                            colorScheme: colorScheme,
                            activeColor: _getStateColor(_task.state),
                          ),
                          const SizedBox(width: 4),

                          // Tags chip
                          FutureBuilder<List<String>>(
                            future: widget.databaseService.taskService
                                .getTagsByTaskId(_task.id!),
                            builder: (context, snapshot) {
                              final tags = snapshot.data ?? [];
                              return _buildActionChip(
                                icon: Icons.label_outline_rounded,
                                label:
                                    tags.isEmpty
                                        ? 'Add tags'
                                        : tags.length == 1
                                        ? tags.first
                                        : '${tags.length} tags',
                                isActive: tags.isNotEmpty,
                                onTap: _showTagSelector,
                                colorScheme: colorScheme,
                              );
                            },
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 8),
                    _buildNewSubtaskInput(colorScheme: colorScheme),
                  ] else ...[

                    // Tags chip for habits
                    FutureBuilder<List<String>>(
                      future: widget.databaseService.taskService
                          .getTagsByTaskId(_task.id!),
                      builder: (context, snapshot) {
                        final tags = snapshot.data ?? [];
                        return _buildActionChip(
                          icon: Icons.label_outline_rounded,
                          label:
                              tags.isEmpty
                                  ? 'Add tags'
                                  : tags.length == 1
                                  ? tags.first
                                  : '${tags.length} tags',
                          isActive: tags.isNotEmpty,
                          onTap: _showTagSelector,
                          colorScheme: colorScheme,
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),

            // For Habits mode show week navigation and add row
            if (_isHabits) ...[
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    // Week navigation row
                    Row(
                      children: [
                        Material(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          child: InkWell(
                            onTap: () => setState(() => _habitsWeekOffset--),
                            borderRadius: BorderRadius.circular(8),
                            child: SizedBox(
                              width: 36,
                              height: 36,
                              child: Icon(
                                Icons.chevron_left_rounded,
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              if (_habitsWeekOffset != 0) {
                                setState(() => _habitsWeekOffset = 0);
                              }
                            },
                            child: Container(
                              height: 36,
                              alignment: Alignment.center,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.calendar_today_rounded,
                                    size: 14,
                                    color:
                                        _habitsWeekOffset == 0
                                            ? colorScheme.primary
                                            : colorScheme.onSurfaceVariant,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '${DateFormat('MMM d').format(DateTime.now().add(Duration(days: _habitsWeekOffset * 7 - DateTime.now().weekday + 1)))} - ${DateFormat('MMM d').format(DateTime.now().add(Duration(days: _habitsWeekOffset * 7 - DateTime.now().weekday + 7)))}',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color:
                                          _habitsWeekOffset == 0
                                              ? colorScheme.primary
                                              : colorScheme.onSurface,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Material(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          child: InkWell(
                            onTap: () => setState(() => _habitsWeekOffset++),
                            borderRadius: BorderRadius.circular(8),
                            child: SizedBox(
                              width: 36,
                              height: 36,
                              child: Icon(
                                Icons.chevron_right_rounded,
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Add habit input
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color: colorScheme.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: colorScheme.outlineVariant.withAlpha(100),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Material(
                            color: colorScheme.primaryContainer.withAlpha(80),
                            borderRadius: BorderRadius.circular(8),
                            child: InkWell(
                              onTap: _addSubtask,
                              borderRadius: BorderRadius.circular(8),
                              child: SizedBox(
                                width: 36,
                                height: 36,
                                child: Icon(
                                  Icons.add_rounded,
                                  color: colorScheme.primary,
                                  size: 20,
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: TextField(
                              controller: _newSubtaskController,
                              textCapitalization: TextCapitalization.sentences,
                              decoration: InputDecoration(
                                hintText: 'Add habit...',
                                hintStyle: TextStyle(
                                  color: colorScheme.onSurfaceVariant.withAlpha(
                                    150,
                                  ),
                                  fontSize: 14,
                                ),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                              ),
                              style: TextStyle(
                                fontSize: 14,
                                color: colorScheme.onSurface,
                              ),
                              onSubmitted: (_) => _addSubtask(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],

            Expanded(
              child: StreamBuilder<void>(
                stream: widget.databaseService.onDatabaseChanged,
                builder: (context, snapshot) {
                  // If we received a DB change event, refresh the cached subtasks.
                  if (snapshot.hasData) {
                    // fire-and-forget refresh
                    _refreshCachedSubtasks();
                  }

                  final subtasks = _cachedSubtasks ?? <Subtask>[];
                  // If this task is a Habits task, render the HabitsTracker instead of the normal subtasks list
                  if (_isHabits) {
                    // Render the HabitsTracker with scrolling enabled
                    return HabitsTracker(
                      databaseService: widget.databaseService,
                      subtasks: subtasks,
                      taskId: _task.id!,
                      initialCompletions: _cachedHabitCompletions,
                      hideControls: true,
                      weekOffset: _habitsWeekOffset,
                      showEmptyMessage: false,
                      allowScroll: true, // Enable scrolling in mobile
                    );
                  }
                  final pendingSubtasks =
                      subtasks.where((s) => !s.completed).toList();
                  final completedSubtasks =
                      subtasks.where((s) => s.completed).toList();

                  return Column(
                    children: [
                      // Subtasks tabs
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 8),
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.all(4),
                        child: SizedBox(
                          height: 36,
                          child: TabBar(
                            controller: _subtasksTabController,
                            tabAlignment: TabAlignment.fill,
                            labelPadding: EdgeInsets.zero,
                            indicatorSize: TabBarIndicatorSize.tab,
                            dividerColor: Colors.transparent,
                            splashFactory: NoSplash.splashFactory,
                            overlayColor: WidgetStateProperty.all(
                              Colors.transparent,
                            ),
                            indicator: BoxDecoration(
                              color: colorScheme.surface,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            tabs: [
                              Tab(
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.pending_actions_rounded,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Pending',
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '(${pendingSubtasks.length})',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color:
                                            _subtasksTabController.index == 0
                                                ? colorScheme.primary
                                                : colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Tab(
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.check_circle_rounded, size: 16),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Completed',
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            onTap: (index) {
                              setState(() {});
                            },
                          ),
                        ),
                      ),
                      // Subtasks TabBarView
                      Expanded(
                        child: TabBarView(
                          controller: _subtasksTabController,
                          children: [
                            _buildPendingSubtasksTab(pendingSubtasks),
                            _buildCompletedSubtasksTab(completedSubtasks),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _toggleTaskPinned() {
    setState(() {
      _task = _task.copyWith(isPinned: !_task.isPinned);
      _taskChanged = true;
    });
  }

  IconData _getStateIconData(TaskState state) {
    switch (state) {
      case TaskState.pending:
        return Icons.circle_outlined;
      case TaskState.inProgress:
        return Icons.pending;
      case TaskState.completed:
        return Icons.check_circle;
      case TaskState.none:
        return Icons.remove_circle_outline;
    }
  }

  void _showStateSelector() {
    final colorScheme = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      backgroundColor: colorScheme.surface,
      isScrollControlled: true,
      builder: (context) {
        final bottomPadding = MediaQuery.of(context).padding.bottom;
        final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;

        return Padding(
          padding: EdgeInsets.only(
            bottom: keyboardHeight + bottomPadding,
            left: 16,
            right: 16,
            top: 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: colorScheme.onSurface.withAlpha(50),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ...[
                      TaskState.none,
                      TaskState.pending,
                      TaskState.inProgress,
                      TaskState.completed,
                    ].map(
                      (state) => Card(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: colorScheme.outlineVariant.withAlpha(127),
                            width: 0.5,
                          ),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () {
                              _updateTaskState(state);
                              Navigator.pop(context);
                            },
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              leading: Icon(
                                _getStateIconData(state),
                                color: _getStateColor(state),
                              ),
                              title: Text(
                                _getStateText(state),
                                style: TextStyle(color: _getStateColor(state)),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showTagSelector() {
    final colorScheme = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      backgroundColor: colorScheme.surface,
      isScrollControlled: true,
      builder: (context) {
        final bottomPadding = MediaQuery.of(context).padding.bottom;
        final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;

        return Padding(
          padding: EdgeInsets.only(
            bottom: keyboardHeight + bottomPadding,
            left: 16,
            right: 16,
            top: 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: colorScheme.onSurface.withAlpha(50),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FutureBuilder<List<String>>(
                      future: widget.databaseService.taskService.getAllTags(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }

                        final allTags = snapshot.data!;
                        return FutureBuilder<List<String>>(
                          future: widget.databaseService.taskService
                              .getTagsByTaskId(_task.id!),
                          builder: (context, taskTagsSnapshot) {
                            if (!taskTagsSnapshot.hasData) {
                              return const Center(
                                child: CircularProgressIndicator(),
                              );
                            }

                            final taskTags = taskTagsSnapshot.data!;

                            if (allTags.isEmpty) {
                              return Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.all(8),
                                    child: Text(
                                      'No tags available',
                                      style: TextStyle(
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ),
                                  Card(
                                    margin: const EdgeInsets.symmetric(
                                      vertical: 4,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      side: BorderSide(
                                        color: colorScheme.outlineVariant
                                            .withAlpha(127),
                                        width: 0.5,
                                      ),
                                    ),
                                    color: colorScheme.primary,
                                    child: Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(12),
                                        onTap: () {
                                          Navigator.pop(context);
                                          _showManageTagsDialog();
                                        },
                                        child: ListTile(
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                horizontal: 16,
                                              ),
                                          leading: Icon(
                                            Icons.add_rounded,
                                            color: colorScheme.onPrimary,
                                          ),
                                          title: Text(
                                            'New tag',
                                            style: TextStyle(
                                              color: colorScheme.onPrimary,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                ],
                              );
                            }

                            return Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ...allTags.map(
                                  (tag) => Card(
                                    margin: const EdgeInsets.symmetric(
                                      vertical: 4,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      side: BorderSide(
                                        color: colorScheme.outlineVariant
                                            .withAlpha(127),
                                        width: 0.5,
                                      ),
                                    ),
                                    child: Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(12),
                                        onTap: () async {
                                          if (taskTags.contains(tag)) {
                                            await widget
                                                .databaseService
                                                .taskService
                                                .removeTagFromTask(
                                                  tag,
                                                  _task.id!,
                                                );
                                          } else {
                                            await widget
                                                .databaseService
                                                .taskService
                                                .assignTagToTask(
                                                  tag,
                                                  _task.id!,
                                                );
                                          }
                                          if (mounted) {
                                            setState(() {
                                              _taskChanged = true;
                                            });
                                          }
                                          // Notify database change so listeners (including this
                                          // screen) update immediately when tags change.
                                          try {
                                            widget.databaseService
                                                .notifyDatabaseChanged();
                                          } catch (_) {}
                                          Navigator.pop(context);
                                        },
                                        child: ListTile(
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                horizontal: 16,
                                              ),
                                          leading: Icon(
                                            taskTags.contains(tag)
                                                ? Icons.check_circle
                                                : Icons.circle_outlined,
                                            color:
                                                taskTags.contains(tag)
                                                    ? colorScheme.primary
                                                    : colorScheme
                                                        .onSurfaceVariant,
                                          ),
                                          title: Text(
                                            tag,
                                            style: TextStyle(
                                              color: colorScheme.onSurface,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                Card(
                                  margin: const EdgeInsets.symmetric(
                                    vertical: 4,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    side: BorderSide(
                                      color: colorScheme.outlineVariant
                                          .withAlpha(127),
                                      width: 0.5,
                                    ),
                                  ),
                                  color: colorScheme.primary,
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(12),
                                      onTap: () {
                                        Navigator.pop(context);
                                        _showManageTagsDialog();
                                      },
                                      child: ListTile(
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 16,
                                            ),
                                        leading: Icon(
                                          Icons.add_rounded,
                                          color: colorScheme.onPrimary,
                                        ),
                                        title: Text(
                                          'New tag',
                                          style: TextStyle(
                                            color: colorScheme.onPrimary,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 20),
                              ],
                            );
                          },
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showManageTagsDialog() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const tasks.TagsScreen()),
    ).then((_) {
      setState(() {
        _taskChanged = true;
      });
      _saveTask();
    });
  }

  void _showPrioritySelector(Subtask subtask) {
    final colorScheme = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      backgroundColor: colorScheme.surface,
      isScrollControlled: true,
      builder: (context) {
        final bottomPadding = MediaQuery.of(context).padding.bottom;
        final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;

        return Padding(
          padding: EdgeInsets.only(
            bottom: keyboardHeight + bottomPadding,
            left: 16,
            right: 16,
            top: 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: colorScheme.onSurface.withAlpha(50),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ...SubtaskPriority.values.reversed.map(
                      (priority) => Card(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: colorScheme.outlineVariant.withAlpha(127),
                            width: 0.5,
                          ),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () {
                              _updateSubtaskPriority(subtask, priority);
                              Navigator.pop(context);
                            },
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 8,
                              ),
                              leading: Icon(
                                _getPriorityIcon(priority),
                                color: _getPriorityColor(priority),
                              ),
                              title: Text(
                                _getPriorityText(priority),
                                style: TextStyle(
                                  color: _getPriorityColor(priority),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _toggleSubtaskExpansion(String id) {
    setState(() {
      if (_expandedSubtasks.contains(id)) {
        _expandedSubtasks.remove(id);
      } else {
        _expandedSubtasks.add(id);
      }
    });
  }

  Widget _buildPendingSubtasksTab(List<Subtask> pendingSubtasks) {
    final colorScheme = Theme.of(context).colorScheme;
    return pendingSubtasks.isEmpty
        ? Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.checklist_rounded,
                size: 48,
                color: colorScheme.onSurfaceVariant.withAlpha(80),
              ),
              const SizedBox(height: 12),
              Text(
                'No pending subtasks',
                style: TextStyle(
                  color: colorScheme.onSurfaceVariant.withAlpha(150),
                ),
              ),
            ],
          ),
        )
        : _task.sortByPriority
        ? ListView.builder(
          padding: const EdgeInsets.only(top: 4),
          itemCount: pendingSubtasks.length,
          itemBuilder: (context, index) {
            final subtask = pendingSubtasks[index];
            final isEditing = _editingSubtaskId == subtask.id.toString();
            return _buildSubtaskItem(subtask, isEditing, colorScheme, index);
          },
        )
        : ReorderableListView.builder(
          padding: const EdgeInsets.only(top: 4),
          itemCount: pendingSubtasks.length,
          onReorder: _reorderSubtasks,
          buildDefaultDragHandles: false,
          itemBuilder: (context, index) {
            final subtask = pendingSubtasks[index];
            final isEditing = _editingSubtaskId == subtask.id.toString();
            return _buildSubtaskItem(subtask, isEditing, colorScheme, index);
          },
        );
  }

  Widget _buildCompletedSubtasksTab(List<Subtask> completedSubtasks) {
    final colorScheme = Theme.of(context).colorScheme;
    return completedSubtasks.isEmpty
        ? Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.task_alt_rounded,
                size: 48,
                color: colorScheme.onSurfaceVariant.withAlpha(80),
              ),
              const SizedBox(height: 12),
              Text(
                'No completed subtasks',
                style: TextStyle(
                  color: colorScheme.onSurfaceVariant.withAlpha(150),
                ),
              ),
            ],
          ),
        )
        : ListView.builder(
          padding: const EdgeInsets.only(top: 4),
          itemCount: completedSubtasks.length,
          itemBuilder: (context, index) {
            final subtask = completedSubtasks[index];
            final isEditing = _editingSubtaskId == subtask.id.toString();
            return _buildSubtaskItem(subtask, isEditing, colorScheme, index);
          },
        );
  }
}
