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

class _TaskDetailScreenState extends State<TaskDetailScreen> {
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
  bool _showCompletedSubtasks = false;
  String? _editingSubtaskId;
  final TextEditingController _editingController = TextEditingController();
  int _habitsWeekOffset = 0;
  // _habitsWeekHover and _habitsWeekPressed removed: we use a plain button now.
  StreamSubscription<void>? _dbChangeSubscription;

  @override
  void initState() {
    super.initState();
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
      _dbChangeSubscription = widget.databaseService.onDatabaseChanged.listen((_) async {
        // reload tags and subtasks when DB changes
        await _loadIsHabits();
        await _refreshCachedSubtasks();
      });
    } catch (_) {}
  }

  Future<void> _prefetchSubtasks() async {
    if (_task.id == null) return;
    try {
      final subs = _task.sortByPriority
          ? await widget.databaseService.taskService.getSubtasksByTaskIdWithPrioritySort(_task.id!)
          : await widget.databaseService.taskService.getSubtasksByTaskId(_task.id!);
      // Also prefetch habit completions for instant rendering in HabitsTracker
      try {
        _cachedHabitCompletions = await widget.databaseService.taskService.getHabitCompletionsForTask(_task.id!);
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
      final tags = await widget.databaseService.taskService.getTagsByTaskId(_task.id!);
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

  Widget _buildSubtaskItem(
    Subtask subtask,
    bool isEditing,
    ColorScheme colorScheme,
  ) {
    return Dismissible(
      key: Key(subtask.id.toString()),
      direction: DismissDirection.horizontal,
      background: Container(
        color: colorScheme.tertiary,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20),
        child: Icon(Icons.check_rounded, color: colorScheme.onTertiary),
      ),
      secondaryBackground: Container(
        color: colorScheme.error,
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
                    content: Text('Error deleting subtask: ${e.toString()}'),
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
              'Are you sure you want to delete this subtask?\n${subtask.text}',
          confirmText: 'Delete',
          confirmColor: colorScheme.error,
        );
        return result ?? false;
      },
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: colorScheme.outlineVariant.withAlpha(127),
            width: 0.5,
          ),
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
          leading: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!_task.sortByPriority)
                Icon(
                  Icons.drag_indicator_rounded,
                  color: colorScheme.onSurfaceVariant.withAlpha(127),
                  size: 20,
                ),
              const SizedBox(width: 8),
              Checkbox(
                value: subtask.completed,
                onChanged: (_) => _toggleSubtask(subtask),
                activeColor: colorScheme.primary,
                checkColor: colorScheme.onPrimary,
              ),
            ],
          ),
          title:
              isEditing
                  ? TextField(
                    controller: _editingController,
                    autofocus: true,
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 8),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      filled: true,
                      fillColor: colorScheme.surfaceContainerHighest.withAlpha(
                        127,
                      ),
                      prefixIcon: Icon(
                        Icons.edit_rounded,
                        color: colorScheme.primary,
                      ),
                    ),
                    style: TextStyle(
                      decoration:
                          subtask.completed ? TextDecoration.lineThrough : null,
                      color:
                          subtask.completed
                              ? colorScheme.onSurfaceVariant
                              : colorScheme.onSurface,
                    ),
                    onSubmitted: (_) => _saveSubtaskEditing(subtask),
                    onEditingComplete: () => _saveSubtaskEditing(subtask),
                    onTapOutside: (_) => _cancelSubtaskEditing(),
                  )
                  : GestureDetector(
                    onDoubleTap: () => _editSubtask(subtask),
                    child: Text(
                      subtask.text,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        decoration:
                            subtask.completed
                                ? TextDecoration.lineThrough
                                : null,
                        color:
                            subtask.completed
                                ? colorScheme.onSurfaceVariant
                                : colorScheme.onSurface,
                      ),
                    ),
                  ),
          trailing: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            child: InkWell(
              onTap: () => _showPrioritySelector(subtask),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.all(8),
                child: Icon(
                  _getPriorityIcon(subtask.priority),
                  color: _getPriorityColor(subtask.priority),
                  size: 20,
                ),
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
          title: _isHabits
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
        body: ListView(
          padding: EdgeInsets.zero,
          children: [
            // Título
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _nameController,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: 'Title',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  filled: true,
                  fillColor: colorScheme.surfaceContainerHighest.withAlpha(127),
                  prefixIcon: Icon(
                    Icons.title_rounded,
                    color: colorScheme.primary,
                  ),
                ),
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),

            if (!_isHabits)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(child: _buildDateSelector()),
                    const SizedBox(width: 8),
                    Expanded(child: _buildStateSelector()),
                    const SizedBox(width: 8),
                    _buildPinButton(),
                  ],
                ),
              )
            else
              // For Habits mode show Tag and Pin controls below the title,
              // horizontally aligned and taking full width.
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildTagSelector(compact: true),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildPinButton(compact: true),
                    ),
                  ],
                ),
              ),
            SizedBox(height: _isHabits ? 8 : 16),

            // Tags (only show the standalone tag row when NOT Habits; Habits shows tag in header)
            if (!_isHabits)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _buildTagSelector(),
              ),
            SizedBox(height: _isHabits ? 0 : 8),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: !_isHabits
                  ? Text(
                      'Subtasks',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
            SizedBox(height: _isHabits ? 0 : 8),

            // For Habits mode show week navigation and add row here (we hide internals in the widget)
            if (_isHabits) ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_rounded),
                      onPressed: () => setState(() => _habitsWeekOffset--),
                    ),
                    const SizedBox(width: 8),
                          Expanded(
                            child: SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: () {
                                  if (_habitsWeekOffset != 0) setState(() => _habitsWeekOffset = 0);
                                },
                                icon: Icon(Icons.date_range_rounded, size: 18, color: colorScheme.onSurfaceVariant),
                                label: Text(
                                  '${DateFormat('MMM d').format(DateTime.now().add(Duration(days: _habitsWeekOffset * 7 - DateTime.now().weekday + 1)))} - ${DateFormat('MMM d').format(DateTime.now().add(Duration(days: _habitsWeekOffset * 7 - DateTime.now().weekday + 7)))}',
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context).textTheme.bodyLarge,
                                ),
                                style: OutlinedButton.styleFrom(
                                  minimumSize: const Size.fromHeight(48),
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  backgroundColor: colorScheme.surface,
                                  side: BorderSide(color: Colors.transparent),
                                ),
                              ),
                            ),
                          ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.arrow_forward_rounded),
                      onPressed: () => setState(() => _habitsWeekOffset++),
                    ),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _newSubtaskController,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: InputDecoration(
                          hintText: 'Add new habit',
                          prefixIcon: Icon(
                            Icons.add_task_rounded,
                            color: colorScheme.primary,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          filled: true,
                          fillColor: colorScheme.surfaceContainerHighest
                              .withAlpha(127),
                          hintStyle: TextStyle(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        style: TextStyle(color: colorScheme.onSurface),
                        onSubmitted: (_) => _addSubtask(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.add_circle_rounded),
                      onPressed: _addSubtask,
                      color: colorScheme.primary,
                    ),
                  ],
                ),
              ),
            ]
            else
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _newSubtaskController,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: InputDecoration(
                          hintText: 'Add new subtask',
                          prefixIcon: Icon(
                            Icons.add_task_rounded,
                            color: colorScheme.primary,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          filled: true,
                          fillColor: colorScheme.surfaceContainerHighest
                              .withAlpha(127),
                          hintStyle: TextStyle(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        style: TextStyle(color: colorScheme.onSurface),
                        onSubmitted: (_) => _addSubtask(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.add_circle_rounded),
                      onPressed: _addSubtask,
                      color: colorScheme.primary,
                    ),
                    IconButton(
                      icon: Icon(
                        _task.sortByPriority
                            ? Icons.sort_by_alpha_rounded
                            : Icons.drag_indicator_rounded,
                        color:
                            _task.sortByPriority
                                ? colorScheme.primary
                                : colorScheme.onSurfaceVariant,
                      ),
                      onPressed: () async {
                        setState(() {
                          _task = _task.copyWith(
                            sortByPriority: !_task.sortByPriority,
                          );
                          _taskChanged = true;
                        });
                        await _saveTask();
                      },
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 8),

            StreamBuilder<void>(
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
                  // Render the HabitsTracker inline so it participates in the
                  // parent ListView's scroll (matching subtasks behaviour).
                  return HabitsTracker(
                    databaseService: widget.databaseService,
                    subtasks: subtasks,
                    taskId: _task.id!,
                    initialCompletions: _cachedHabitCompletions,
                    hideControls: true,
                    weekOffset: _habitsWeekOffset,
                    showEmptyMessage: false,
                  );
                }
                final pendingSubtasks =
                    subtasks.where((s) => !s.completed).toList();
                final completedSubtasks =
                    subtasks.where((s) => s.completed).toList();

                if (subtasks.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        'No subtasks',
                        style: TextStyle(color: colorScheme.onSurfaceVariant),
                      ),
                    ),
                  );
                }

                return Column(
                  children: [
                    // Sección de subtareas pendientes
                    if (pendingSubtasks.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: Text(
                          'Pending',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      _task.sortByPriority
                          ? ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            padding: EdgeInsets.zero,
                            itemCount: pendingSubtasks.length,
                            itemBuilder: (context, index) {
                              final subtask = pendingSubtasks[index];
                              final isEditing =
                                  _editingSubtaskId == subtask.id.toString();
                              return _buildSubtaskItem(
                                subtask,
                                isEditing,
                                colorScheme,
                              );
                            },
                          )
                          : ReorderableListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            padding: EdgeInsets.zero,
                            itemCount: pendingSubtasks.length,
                            onReorder: _reorderSubtasks,
                            itemBuilder: (context, index) {
                              final subtask = pendingSubtasks[index];
                              final isEditing =
                                  _editingSubtaskId == subtask.id.toString();
                              return _buildSubtaskItem(
                                subtask,
                                isEditing,
                                colorScheme,
                              );
                            },
                          ),
                    ],

                    if (completedSubtasks.isNotEmpty) ...[
                      InkWell(
                        onTap: () {
                          setState(() {
                            _showCompletedSubtasks = !_showCompletedSubtasks;
                          });
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Row(
                            children: [
                              Text(
                                'Completed',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const Spacer(),
                              Icon(
                                _showCompletedSubtasks
                                    ? Icons.expand_less_rounded
                                    : Icons.expand_more_rounded,
                                color: colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${completedSubtasks.length}',
                                style: TextStyle(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (_showCompletedSubtasks)
                        Container(
                          height: 200,
                          decoration: BoxDecoration(color: colorScheme.surface),
                          child: ListView.builder(
                            itemCount: completedSubtasks.length,
                            itemBuilder: (context, index) {
                              final subtask = completedSubtasks[index];
                              final isEditing =
                                  _editingSubtaskId == subtask.id.toString();
                              return Dismissible(
                                key: Key(subtask.id.toString()),
                                direction: DismissDirection.horizontal,
                                background: Container(
                                  color: colorScheme.primary,
                                  alignment: Alignment.centerLeft,
                                  padding: const EdgeInsets.only(left: 20),
                                  child: Icon(
                                    Icons.check_rounded,
                                    color: colorScheme.onPrimary,
                                  ),
                                ),
                                secondaryBackground: Container(
                                  color: colorScheme.error,
                                  alignment: Alignment.centerRight,
                                  padding: const EdgeInsets.only(right: 20),
                                  child: Icon(
                                    Icons.delete_rounded,
                                    color: colorScheme.onError,
                                  ),
                                ),
                                onDismissed: (direction) {
                                  if (direction ==
                                      DismissDirection.endToStart) {
                                    final scaffoldMessenger =
                                        ScaffoldMessenger.of(context);
                                    widget.databaseService.taskService
                                        .deleteSubtask(subtask.id!)
                                        .then((_) {
                                          if (!mounted) return;
                                          setState(() {
                                            _taskChanged = true;
                                          });
                                          _saveTask();
                                        })
                                        .catchError((e) {
                                          if (!mounted) return;
                                          scaffoldMessenger.showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                'Error deleting subtask: ${e.toString()}',
                                              ),
                                              backgroundColor:
                                                  colorScheme.error,
                                            ),
                                          );
                                        });
                                  } else {
                                    _toggleSubtask(subtask);
                                  }
                                },
                                confirmDismiss: (direction) async {
                                  if (direction ==
                                      DismissDirection.startToEnd) {
                                    _toggleSubtask(subtask);
                                    return false;
                                  }
                                  final result = await showDeleteConfirmationDialog(
                                    context: context,
                                    title: 'Delete Subtask',
                                    message:
                                        'Are you sure you want to delete this subtask?\n${subtask.text}',
                                    confirmText: 'Delete',
                                    confirmColor: colorScheme.error,
                                  );
                                  return result ?? false;
                                },
                                child: Card(
                                  margin: const EdgeInsets.symmetric(
                                    vertical: 4,
                                    horizontal: 16,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    side: BorderSide(
                                      color: colorScheme.outlineVariant
                                          .withAlpha(127),
                                      width: 0.5,
                                    ),
                                  ),
                                  child: ListTile(
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                    ),
                                    leading: Checkbox(
                                      value: subtask.completed,
                                      onChanged: (_) => _toggleSubtask(subtask),
                                      activeColor: colorScheme.primary,
                                      checkColor: colorScheme.onPrimary,
                                    ),
                                    title:
                                        isEditing
                                            ? TextField(
                                              controller: _editingController,
                                              autofocus: true,
                                              decoration: InputDecoration(
                                                isDense: true,
                                                contentPadding:
                                                    const EdgeInsets.symmetric(
                                                      vertical: 8,
                                                    ),
                                                border: OutlineInputBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(16),
                                                ),
                                                filled: true,
                                                fillColor: colorScheme
                                                    .surfaceContainerHighest
                                                    .withAlpha(127),
                                                prefixIcon: Icon(
                                                  Icons.edit_rounded,
                                                  color: colorScheme.primary,
                                                ),
                                              ),
                                              style: TextStyle(
                                                decoration:
                                                    TextDecoration.lineThrough,
                                                color:
                                                    colorScheme
                                                        .onSurfaceVariant,
                                              ),
                                              onSubmitted:
                                                  (_) => _saveSubtaskEditing(
                                                    subtask,
                                                  ),
                                              onEditingComplete:
                                                  () => _saveSubtaskEditing(
                                                    subtask,
                                                  ),
                                              onTapOutside:
                                                  (_) =>
                                                      _cancelSubtaskEditing(),
                                            )
                                            : GestureDetector(
                                              onDoubleTap:
                                                  () => _editSubtask(subtask),
                                              child: Text(
                                                subtask.text,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  decoration:
                                                      TextDecoration
                                                          .lineThrough,
                                                  color:
                                                      colorScheme
                                                          .onSurfaceVariant,
                                                ),
                                              ),
                                            ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                    ],
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPinButton({bool compact = false}) {
    final colorScheme = Theme.of(context).colorScheme;
    if (compact) {
      return Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: () => _toggleTaskPinned(),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withAlpha(127),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colorScheme.outline, width: 1),
            ),
            child: Icon(
              _task.isPinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
              color: _task.isPinned ? colorScheme.primary : colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: () => _toggleTaskPinned(),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest.withAlpha(127),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colorScheme.outline, width: 1),
          ),
          child: Icon(
            _task.isPinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
            color:
                _task.isPinned
                    ? colorScheme.primary
                    : colorScheme.onSurfaceVariant,
          ),
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

  Widget _buildDateSelector() {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: () async {
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
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest.withAlpha(127),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colorScheme.outline, width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Icon(Icons.calendar_today_rounded, color: colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                _task.date == null
                    ? 'No date'
                    : DateFormat('dd/MM/yyyy').format(_task.date!),
                style: TextStyle(fontSize: 13, color: colorScheme.onSurface),
              ),
              if (_task.date != null) ...[
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () async {
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
                  },
                  child: Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStateSelector() {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: () => _showStateSelector(),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest.withAlpha(127),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colorScheme.outline, width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _getStateIconData(_task.state),
                color: _getStateColor(_task.state),
              ),
              const SizedBox(width: 8),
              Text(
                _getStateText(_task.state),
                style: TextStyle(
                  fontSize: 14,
                  color: _getStateColor(_task.state),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getStateIconData(TaskState state) {
    switch (state) {
      case TaskState.pending:
        return Icons.circle_outlined;
      case TaskState.inProgress:
        return Icons.pending;
      case TaskState.completed:
        return Icons.check_circle;
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
                    ...TaskState.values.map(
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

  Widget _buildTagSelector({bool compact = false}) {
    final colorScheme = Theme.of(context).colorScheme;
    if (compact) {
      return Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: () => _showTagSelector(),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withAlpha(127),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colorScheme.outline, width: 1),
            ),
            child: Icon(Icons.label_rounded, color: colorScheme.primary),
          ),
        ),
      );
    }

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: () => _showTagSelector(),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest.withAlpha(127),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colorScheme.outline, width: 1),
          ),
          child: FutureBuilder<List<String>>(
            future: widget.databaseService.taskService.getTagsByTaskId(
              _task.id!,
            ),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.label_rounded, color: colorScheme.primary),
                    const SizedBox(width: 8),
                    Text(
                      'Tags',
                      style: TextStyle(
                        fontSize: 14,
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ],
                );
              }

              final tags = snapshot.data!;
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.label_rounded, color: colorScheme.primary),
                  const SizedBox(width: 8),
                  if (tags.isEmpty)
                    Text(
                      'Tags',
                      style: TextStyle(
                        fontSize: 14,
                        color: colorScheme.onSurface,
                      ),
                    )
                  else
                    Flexible(
                      child: Text(
                        tags.join(', '),
                        style: TextStyle(
                          fontSize: 14,
                          color: colorScheme.onSurface,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
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
                                    padding: const EdgeInsets.all(16),
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
                                            widget.databaseService.notifyDatabaseChanged();
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
                                horizontal: 16,
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
}
