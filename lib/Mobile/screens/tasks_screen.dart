import 'package:flutter/material.dart';
import 'dart:async';
import '../../database/database_service.dart';
import '../../database/models/task.dart';
import 'task_detail_screen.dart';
import '../../widgets/custom_snackbar.dart';
import '../../widgets/confirmation_dialogue.dart';
import 'package:intl/intl.dart';
import '../../database/sync_service.dart';
import '../theme_handler.dart';

class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});

  @override
  TasksScreenState createState() => TasksScreenState();
}

class TasksScreenState extends State<TasksScreen>
    with TickerProviderStateMixin {
  List<Task> _tasks = [];
  List<Task> _completedTasks = [];
  Task? _selectedTask;
  String? _selectedTag;
  List<String> _allTags = [];
  bool _isLoading = false;
  bool _isEInkMode = false;
  late TabController _tabController;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _newSubtaskController = TextEditingController();
  final TextEditingController _editingController = TextEditingController();
  final FocusNode _editingFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  Timer? _debounceTimer;

  final DatabaseService _databaseService = DatabaseService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadSavedSettings();
    _loadTasks();

    _nameController.addListener(_onNameChanged);

    _databaseService.onDatabaseChanged.listen((_) {
      _loadTasks();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadSavedSettings();
  }

  @override
  void dispose() {
    _nameController.removeListener(_onNameChanged);
    _nameController.dispose();
    _newSubtaskController.dispose();
    _scrollController.dispose();
    _editingController.dispose();
    _editingFocusNode.dispose();
    _debounceTimer?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  void _onNameChanged() {
    if (_selectedTask == null) return;

    _debounceTimer?.cancel();

    _debounceTimer = Timer(const Duration(seconds: 1), () async {
      if (_selectedTask != null) {
        final updatedTask = _selectedTask!.copyWith(
          name: _nameController.text.trim(),
        );
        await _databaseService.taskService.updateTask(updatedTask);
        if (mounted) {
          await _loadTasks();
        }
      }
    });
  }

  Future<void> _loadSavedSettings() async {
    final einkEnabled = await ThemeManager.getEInkEnabled();
    if (mounted) {
      setState(() {
        _isEInkMode = einkEnabled;
      });
    }
  }

  Future<void> _loadTasks() async {
    try {
      setState(() {
        _isLoading = true;
      });

      List<Task> pendingTasks =
          await _databaseService.taskService.getPendingTasks();
      List<Task> completedTasks =
          await _databaseService.taskService.getCompletedTasks();

      final allTags = await _databaseService.taskService.getAllTags();
      final tagsWithTasks = <String>[];

      for (final tag in allTags) {
        final tasksWithTag = await _databaseService.taskService.getTasksByTag(
          tag,
        );
        if (tasksWithTag.isNotEmpty) {
          tagsWithTasks.add(tag);
        }
      }

      if (_selectedTag != null) {
        final tasksWithTag = await _databaseService.taskService.getTasksByTag(
          _selectedTag!,
        );

        pendingTasks =
            pendingTasks
                .where((task) => tasksWithTag.any((t) => t.id == task.id))
                .toList();
        completedTasks =
            completedTasks
                .where((task) => tasksWithTag.any((t) => t.id == task.id))
                .toList();
      }

      if (_selectedTask != null) {
        final updatedTask = pendingTasks.firstWhere(
          (t) => t.id == _selectedTask!.id,
          orElse:
              () => completedTasks.firstWhere(
                (t) => t.id == _selectedTask!.id,
                orElse: () => _selectedTask!,
              ),
        );

        _selectedTask = updatedTask;
      }

      if (mounted) {
        setState(() {
          _tasks = pendingTasks;
          _completedTasks = completedTasks;
          _allTags = tagsWithTasks;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading tasks: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        CustomSnackbar.show(
          context: context,
          message: 'Error loading tasks: ${e.toString()}',
          type: CustomSnackbarType.error,
        );
      }
    }
  }

  Future<void> _createNewTask() async {
    try {
      final newTask = await _databaseService.taskService.createTask("Untitled");

      if (newTask != null) {
        await _loadTasks();

        await _selectTask(newTask);
      }
    } catch (e) {
      print('Error creating task: $e');
      if (mounted) {
        CustomSnackbar.show(
          context: context,
          message: 'Error creating task: ${e.toString()}',
          type: CustomSnackbarType.error,
        );
      }
    }
  }

  Future<void> _selectTask(Task task) async {
    setState(() {
      _selectedTask = task;
      _nameController.text = task.name;
      _newSubtaskController.clear();
    });

    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder:
              (context) => TaskDetailScreen(
                task: task,
                databaseService: _databaseService,
              ),
        ),
      ).then((_) {
        _loadTasks();
      });
    }
  }

  Future<void> _updateTaskState(Task task, TaskState state) async {
    try {
      await _databaseService.taskService.updateTaskState(task.id!, state);

      if (mounted) {
        if (_selectedTask?.id == task.id) {
          setState(() {
            _selectedTask = _selectedTask!.copyWith(
              state: state,
              completed: state == TaskState.completed,
            );
          });
        }
        await _loadTasks();
      }
    } catch (e) {
      if (mounted) {
        CustomSnackbar.show(
          context: context,
          message: 'Error updating task state: ${e.toString()}',
          type: CustomSnackbarType.error,
        );
      }
    }
  }

  Future<void> _reorderTasks(int oldIndex, int newIndex) async {
    try {
      if (newIndex > oldIndex) {
        newIndex -= 1;
      }

      final item = _tasks.removeAt(oldIndex);
      _tasks.insert(newIndex, item);

      final tasksToUpdate = <Task>[];
      for (int i = 0; i < _tasks.length; i++) {
        final task = _tasks[i];
        if (task.orderIndex != i) {
          tasksToUpdate.add(task.copyWith(orderIndex: i));
        }
      }

      setState(() {}); // Actualizar UI inmediatamente

      for (final updatedTask in tasksToUpdate) {
        await _databaseService.taskService.updateTask(updatedTask);
      }
    } catch (e) {
      if (mounted) {
        CustomSnackbar.show(
          context: context,
          message: 'Error reordering tasks: ${e.toString()}',
          type: CustomSnackbarType.error,
        );
      }
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

  Widget _buildTagChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    required ColorScheme colorScheme,
  }) {
    return Material(
      color:
          isSelected
              ? colorScheme.primary.withAlpha(25)
              : colorScheme.surfaceContainerHighest,

      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side:
            _isEInkMode
                ? BorderSide(color: colorScheme.onSurface, width: 1)
                : BorderSide.none,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        hoverColor: colorScheme.primary.withAlpha(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isSelected ? Icons.label_rounded : Icons.label_outline_rounded,
                size: 20,
                color: colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  height: 1.0,
                  color:
                      isSelected ? colorScheme.primary : colorScheme.onSurface,
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

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        backgroundColor: Theme.of(context).colorScheme.surface,
        automaticallyImplyLeading: false,
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(_allTags.isNotEmpty ? 88 : 48),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_allTags.isNotEmpty)
                Container(
                  height: 36,
                  margin: const EdgeInsets.only(bottom: 4),
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    itemCount: _allTags.length + 1,
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: _buildTagChip(
                            label: 'All',
                            isSelected: _selectedTag == null,
                            onTap: () {
                              setState(() {
                                _selectedTag = null;
                              });
                              _loadTasks();
                            },
                            colorScheme: colorScheme,
                          ),
                        );
                      }
                      final tag = _allTags[index - 1];
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: _buildTagChip(
                          label: tag,
                          isSelected: _selectedTag == tag,
                          onTap: () {
                            setState(() {
                              _selectedTag = _selectedTag == tag ? null : tag;
                            });
                            _loadTasks();
                          },
                          colorScheme: colorScheme,
                        ),
                      );
                    },
                  ),
                ),

              Container(
                margin: EdgeInsets.symmetric(horizontal: _isEInkMode ? 8 : 4),
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border:
                      _isEInkMode
                          ? Border.all(color: colorScheme.onSurface, width: 1)
                          : null,
                ),
                child: SizedBox(
                  height: 36,
                  child: TabBar(
                    controller: _tabController,
                    tabAlignment: TabAlignment.fill,
                    labelPadding: EdgeInsets.zero,
                    indicatorSize: TabBarIndicatorSize.tab,
                    dividerColor: Colors.transparent,
                    splashFactory: NoSplash.splashFactory,
                    overlayColor: WidgetStateProperty.all(Colors.transparent),
                    indicator: BoxDecoration(
                      color:
                          _isEInkMode
                              ? Colors.transparent
                              : colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    tabs: [
                      Tab(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.pending_actions_rounded, size: 16),
                            const SizedBox(width: 6),
                            Text('Pending', overflow: TextOverflow.ellipsis),
                            const SizedBox(width: 4),
                            Text(
                              '(${_tasks.length})',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: colorScheme.primary,
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
                            Text('Completed', overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : TabBarView(
                controller: _tabController,
                children: [
                  RefreshIndicator(
                    onRefresh: () async {
                      try {
                        await SyncService().forceSync(isManual: true);
                      } catch (e) {
                        // Ignore sync errors on refresh
                      }
                      await _loadTasks();
                    },
                    child:
                        _tasks.isEmpty
                            ? SingleChildScrollView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              controller: _scrollController,
                              child: SizedBox(
                                height:
                                    MediaQuery.of(context).size.height - 200,
                                child: _buildEmptyTasksList(),
                              ),
                            )
                            : ReorderableListView.builder(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 0,
                                vertical: 4,
                              ),
                              itemCount: _tasks.length,
                              onReorder: _reorderTasks,
                              itemBuilder: (context, index) {
                                return _buildTaskItem(_tasks[index]);
                              },
                            ),
                  ),
                  RefreshIndicator(
                    onRefresh: () async {
                      try {
                        await SyncService().forceSync(isManual: true);
                      } catch (e) {
                        // Ignore sync errors on refresh
                      }
                      await _loadTasks();
                    },
                    child:
                        _completedTasks.isEmpty
                            ? SingleChildScrollView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              controller: _scrollController,
                              child: SizedBox(
                                height:
                                    MediaQuery.of(context).size.height - 200,
                                child: Center(
                                  child: Text(
                                    'No completed tasks',
                                    style: TextStyle(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                              ),
                            )
                            : ListView.builder(
                              physics: const AlwaysScrollableScrollPhysics(),
                              controller: _scrollController,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 0,
                                vertical: 4,
                              ),
                              itemCount: _completedTasks.length,
                              itemBuilder: (context, index) {
                                return _buildTaskItem(_completedTasks[index]);
                              },
                            ),
                  ),
                ],
              ),
      floatingActionButton: null,
    );
  }

  Widget _buildTaskItem(Task task) {
    final colorScheme = Theme.of(context).colorScheme;

    return Dismissible(
      key: Key(task.id.toString()),
      direction: DismissDirection.horizontal,
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.endToStart) {
          final confirmed = await showDeleteConfirmationDialog(
            context: context,
            title: 'Delete Task',
            message: 'Are you sure you want to delete this task?\n${task.name}',
            confirmText: 'Delete',
            confirmColor: colorScheme.error,
          );
          return confirmed ?? false;
        } else {
          return true;
        }
      },
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
      onDismissed: (direction) async {
        if (direction == DismissDirection.endToStart) {
          try {
            await _databaseService.taskService.deleteTask(task.id!);
            if (mounted) {
              setState(() {
                if (_selectedTask?.id == task.id) {
                  _selectedTask = null;
                  _nameController.clear();
                  _newSubtaskController.clear();
                }
              });
              await _loadTasks();
            }
          } catch (e) {
            if (mounted) {
              CustomSnackbar.show(
                context: context,
                message: 'Error deleting task: ${e.toString()}',
                type: CustomSnackbarType.error,
              );
            }
          }
        } else {
          _updateTaskState(
            task,
            task.state == TaskState.completed
                ? TaskState.pending
                : TaskState.completed,
          );
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 4, left: 8, right: 8),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(10),
          border:
              _isEInkMode
                  ? Border.all(color: colorScheme.onSurface, width: 1)
                  : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => _selectTask(task),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap:
                        () => _updateTaskState(
                          task,
                          task.state == TaskState.completed
                              ? TaskState.pending
                              : TaskState.completed,
                        ),
                    child: Icon(
                      task.state == TaskState.completed
                          ? Icons.check_box_rounded
                          : Icons.check_box_outline_blank_rounded,
                      size: 22,
                      color:
                          task.state == TaskState.completed
                              ? colorScheme.primary
                              : colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 14),

                  Expanded(
                    child: FutureBuilder<List<String>>(
                      future: _databaseService.taskService.getTagsByTaskId(
                        task.id!,
                      ),
                      builder: (context, snapshot) {
                        final tags = snapshot.data ?? <String>[];
                        final hasMetadata =
                            task.date != null ||
                            tags.isNotEmpty ||
                            task.isPinned;

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              task.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                color:
                                    task.state == TaskState.completed
                                        ? colorScheme.onSurfaceVariant
                                            .withAlpha(150)
                                        : colorScheme.onSurface,
                                fontSize: 15,
                                decoration:
                                    task.state == TaskState.completed
                                        ? TextDecoration.lineThrough
                                        : null,
                                decorationColor: colorScheme.onSurfaceVariant
                                    .withAlpha(150),
                              ),
                            ),

                            if (hasMetadata) ...[
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 6,
                                runSpacing: 4,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  if (task.isPinned)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.push_pin_rounded,
                                            size: 12,
                                            color: colorScheme.primary,
                                          ),
                                        ],
                                      ),
                                    ),

                                  if (task.date != null)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color:
                                            _isDateOverdue(task.date!)
                                                ? colorScheme.error.withAlpha(
                                                  20,
                                                )
                                                : colorScheme
                                                    .surfaceContainerHighest
                                                    .withAlpha(150),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.schedule_rounded,
                                            size: 12,
                                            color:
                                                _isDateOverdue(task.date!)
                                                    ? colorScheme.error
                                                    : colorScheme
                                                        .onSurfaceVariant,
                                          ),
                                          const SizedBox(width: 3),
                                          Text(
                                            _formatTaskDate(task.date!),
                                            style: TextStyle(
                                              fontSize: 11,
                                              color:
                                                  _isDateOverdue(task.date!)
                                                      ? colorScheme.error
                                                      : colorScheme
                                                          .onSurfaceVariant,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),

                                  ...tags
                                      .take(2)
                                      .map(
                                        (tag) => Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: colorScheme.primary
                                                .withAlpha(20),
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                          ),
                                          child: Text(
                                            tag,
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: colorScheme.primary,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                      ),
                                  if (tags.length > 2)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: colorScheme
                                            .surfaceContainerHighest
                                            .withAlpha(100),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        '+${tags.length - 2}',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: colorScheme.onSurfaceVariant,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ],
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 8),

                  if (task.state != TaskState.none &&
                      task.state != TaskState.completed)
                    FutureBuilder<List<String>>(
                      future: _databaseService.taskService.getTagsByTaskId(
                        task.id!,
                      ),
                      builder: (context, snapshot) {
                        final hasHabitsTag =
                            snapshot.data?.contains('Habits') ?? false;
                        if (hasHabitsTag) return const SizedBox.shrink();
                        return _buildStateIndicator(task.state, colorScheme);
                      },
                    ),

                  Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: colorScheme.onSurfaceVariant.withAlpha(100),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStateIndicator(TaskState state, ColorScheme colorScheme) {
    final color = _getStateIndicatorColor(state, colorScheme);
    final icon = _getStateIndicatorIcon(state);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withAlpha(50), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            _getStateText(state),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Color _getStateIndicatorColor(TaskState state, ColorScheme colorScheme) {
    switch (state) {
      case TaskState.pending:
        return colorScheme.onSurfaceVariant;
      case TaskState.inProgress:
        return const Color(0xFFE67E22);
      case TaskState.completed:
        return colorScheme.primary;
      case TaskState.none:
        return colorScheme.onSurfaceVariant;
    }
  }

  IconData _getStateIndicatorIcon(TaskState state) {
    switch (state) {
      case TaskState.pending:
        return Icons.schedule_rounded;
      case TaskState.inProgress:
        return Icons.trending_up_rounded;
      case TaskState.completed:
        return Icons.check_circle_rounded;
      case TaskState.none:
        return Icons.remove_rounded;
    }
  }

  String _formatTaskDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final taskDate = DateTime(date.year, date.month, date.day);

    if (taskDate == today) {
      return 'Today';
    } else if (taskDate == tomorrow) {
      return 'Tomorrow';
    } else if (taskDate.isBefore(today)) {
      return 'Overdue';
    } else {
      return DateFormat('MMM d').format(date);
    }
  }

  bool _isDateOverdue(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final taskDate = DateTime(date.year, date.month, date.day);
    return taskDate.isBefore(today);
  }

  Widget _buildEmptyTasksList() {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.task_alt_rounded,
            size: 60,
            color: colorScheme.primary.withAlpha(127),
          ),
          const SizedBox(height: 16),
          Text(
            'No pending tasks',
            style: TextStyle(
              fontSize: 16,
              color: colorScheme.onSurface.withAlpha(178),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> createNewTask() async {
    await _createNewTask();
  }

  void toggleTabs() {
    if (_tabController.index == 0) {
      _tabController.animateTo(1);
    } else {
      _tabController.animateTo(0);
    }
  }
}
