import 'package:flutter/material.dart';
import 'dart:async';
import '../../database/database_service.dart';
import '../../database/models/task.dart';
import 'task_detail_screen.dart';
import '../../widgets/custom_snackbar.dart';
import '../../widgets/confirmation_dialogue.dart';
import 'package:intl/intl.dart';

class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});

  @override
  TasksScreenState createState() => TasksScreenState();
}

class TasksScreenState extends State<TasksScreen>
    with TickerProviderStateMixin {
  // Estado
  List<Task> _tasks = [];
  List<Task> _completedTasks = [];
  Task? _selectedTask;
  String? _selectedTag;
  List<String> _allTags = [];
  bool _isLoading = false;

  // Controladores
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _newSubtaskController = TextEditingController();
  final TextEditingController _editingController = TextEditingController();
  final FocusNode _editingFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  Timer? _debounceTimer;

  // Servicios
  final DatabaseService _databaseService = DatabaseService();

  @override
  void initState() {
    super.initState();
    _loadSavedSettings();
    _loadTasks();

    // Agregar listener para el título
    _nameController.addListener(_onNameChanged);

    // Suscribirse a cambios en la base de datos
    _databaseService.onDatabaseChanged.listen((_) {
      _loadTasks();
    });
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
    super.dispose();
  }

  void _onNameChanged() {
    if (_selectedTask == null) return;

    // Cancelar timer anterior si existe
    _debounceTimer?.cancel();

    // Crear nuevo timer
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
    // Implementar si es necesario
  }

  Future<void> _loadTasks() async {
    try {
      setState(() {
        _isLoading = true;
      });

      // Cargar tareas pendientes y completadas
      List<Task> pendingTasks =
          await _databaseService.taskService.getPendingTasks();
      List<Task> completedTasks =
          await _databaseService.taskService.getCompletedTasks();

      // Cargar todos los tags y filtrar solo los que tienen tareas asignadas
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

      // Aplicar filtro por etiqueta si es necesario
      if (_selectedTag != null) {
        final tasksWithTag = await _databaseService.taskService.getTasksByTag(
          _selectedTag!,
        );

        // Filtrar las tareas pendientes y completadas por la etiqueta seleccionada
        pendingTasks =
            pendingTasks
                .where((task) => tasksWithTag.any((t) => t.id == task.id))
                .toList();
        completedTasks =
            completedTasks
                .where((task) => tasksWithTag.any((t) => t.id == task.id))
                .toList();
      }

      // Cargar subtareas si hay una tarea seleccionada
      if (_selectedTask != null) {
        // Si tenemos una tarea seleccionada, actualiza la referencia
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
      // Crear tarea con valores por defecto
      final newTask = await _databaseService.taskService.createTask("Untitled");

      if (newTask != null) {
        // Recargar la lista de tareas
        await _loadTasks();

        // Seleccionar la nueva tarea
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
    // Cargar subtareas

    setState(() {
      _selectedTask = task;
      _nameController.text = task.name;
      _newSubtaskController.clear();
    });

    // Navegar a la pantalla de detalles
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
        // Recargar las tareas cuando se regrese de la pantalla de detalles
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

      // Actualizar el orden de todas las tareas en la lista
      final tasksToUpdate = <Task>[];
      for (int i = 0; i < _tasks.length; i++) {
        final task = _tasks[i];
        if (task.orderIndex != i) {
          tasksToUpdate.add(task.copyWith(orderIndex: i));
        }
      }

      // Actualizar en la base de datos
      setState(() {}); // Actualizar UI inmediatamente

      // Guardar todos los cambios
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

  // Helpers para el color de la etiqueta de estado (copiados desde la versión desktop)
  Color _getStateLabelColor(TaskState state, ColorScheme colorScheme) {
    switch (state) {
      case TaskState.pending:
        return colorScheme.surfaceContainerHighest.withAlpha(80);
      case TaskState.inProgress:
        return const Color(0xFFFFE0B2);
      case TaskState.completed:
        return colorScheme.primaryContainer.withAlpha(120);
    }
  }

  Color _getStateLabelTextColor(TaskState state, ColorScheme colorScheme) {
    switch (state) {
      case TaskState.pending:
        return colorScheme.onSurfaceVariant;
      case TaskState.inProgress:
        return const Color(0xFFB75D0A);
      case TaskState.completed:
        return colorScheme.primary;
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

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          scrolledUnderElevation: 0,
          surfaceTintColor: Colors.transparent,
          backgroundColor: Theme.of(context).colorScheme.surface,
          automaticallyImplyLeading: false,
          toolbarHeight: 0,
          bottom: PreferredSize(
            preferredSize: Size.fromHeight(_allTags.isNotEmpty ? 96 : 48),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_allTags.isNotEmpty)
                  Container(
                    height: 40,
                    margin: const EdgeInsets.only(bottom: 4),
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _allTags.length + 1,
                      itemBuilder: (context, index) {
                        if (index == 0) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: FilterChip(
                              label: const Text('All'),
                              selected: _selectedTag == null,
                              onSelected: (_) {
                                setState(() {
                                  _selectedTag = null;
                                });
                                _loadTasks();
                              },
                              selectedColor: colorScheme.primaryContainer,
                              checkmarkColor: colorScheme.onPrimaryContainer,
                              labelStyle: TextStyle(
                                color:
                                    _selectedTag == null
                                        ? colorScheme.onPrimaryContainer
                                        : colorScheme.onSurface,
                              ),
                              side: BorderSide(
                                color:
                                    _selectedTag == null
                                        ? colorScheme.primary
                                        : colorScheme.outline,
                                width: 1,
                              ),
                            ),
                          );
                        }
                        final tag = _allTags[index - 1];
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: FilterChip(
                            label: Text(tag),
                            selected: _selectedTag == tag,
                            onSelected: (selected) {
                              setState(() {
                                _selectedTag = selected ? tag : null;
                              });
                              _loadTasks();
                            },
                            selectedColor: colorScheme.primaryContainer,
                            checkmarkColor: colorScheme.onPrimaryContainer,
                            labelStyle: TextStyle(
                              color:
                                  _selectedTag == tag
                                      ? colorScheme.onPrimaryContainer
                                      : colorScheme.onSurface,
                            ),
                            side: BorderSide(
                              color:
                                  _selectedTag == tag
                                      ? colorScheme.primary
                                      : colorScheme.outline,
                              width: 1,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                TabBar(
                  labelColor: colorScheme.primary,
                  unselectedLabelColor: colorScheme.onSurfaceVariant,
                  indicatorColor: colorScheme.primary,
                  labelStyle: const TextStyle(fontSize: 13),
                  unselectedLabelStyle: const TextStyle(fontSize: 13),
                  tabs: [
                    Tab(
                      height: 40,
                      child: Text(
                        'Pending (${_tasks.length})',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Tab(
                      height: 40,
                      child: Text(
                        'Completed (${_completedTasks.length})',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        body:
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                  children: [
                    RefreshIndicator(
                      onRefresh: () async {
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
                                padding: const EdgeInsets.only(top: 4),
                                itemCount: _tasks.length,
                                onReorder: _reorderTasks,
                                itemBuilder: (context, index) {
                                  return _buildTaskItem(_tasks[index]);
                                },
                              ),
                    ),
                    RefreshIndicator(
                      onRefresh: () async {
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
                                padding: const EdgeInsets.only(top: 4),
                                itemCount: _completedTasks.length,
                                itemBuilder: (context, index) {
                                  return _buildTaskItem(_completedTasks[index]);
                                },
                              ),
                    ),
                  ],
                ),
        floatingActionButton: null,
      ),
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
        child: Card(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: colorScheme.outlineVariant.withAlpha(127),
            width: 0.5,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _selectTask(task),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                    // Leading: state icon (no overlay pin badge)
                GestureDetector(
                  onTap: () => _updateTaskState(
                    task,
                    task.state == TaskState.completed
                        ? TaskState.pending
                        : TaskState.completed,
                  ),
                  child: Icon(
                    task.state == TaskState.completed
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked_rounded,
                    color: task.state == TaskState.completed
                        ? colorScheme.primary
                        : colorScheme.onSurfaceVariant,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                // Title and chips — fixed-height container so title is vertically
                // centered when chips are absent.
                Expanded(
                  child: SizedBox(
                    height: 56,
                    child: FutureBuilder<List<String>>(
                      future: _databaseService.taskService.getTagsByTaskId(task.id!),
                      builder: (context, snapshot) {
                        final hasTags = snapshot.hasData && snapshot.data!.isNotEmpty;
                        final tags = snapshot.data ?? <String>[];
                        if (!hasTags) {
                          // No tags: center the title vertically
                          return Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              task.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: colorScheme.onSurface,
                                fontSize: 16,
                                decoration: task.state == TaskState.completed
                                    ? TextDecoration.lineThrough
                                    : null,
                              ),
                            ),
                          );
                        }

                        // Has tags: title on top, chips below with spacing
                        return Column(
                          mainAxisAlignment: MainAxisAlignment.start,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(top: 6.0),
                              child: Text(
                                task.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: colorScheme.onSurface,
                                  fontSize: 16,
                                  decoration: task.state == TaskState.completed
                                      ? TextDecoration.lineThrough
                                      : null,
                                ),
                              ),
                            ),
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                if (task.date != null)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: colorScheme.surfaceContainerHighest.withAlpha(80),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.calendar_today_rounded, size: 14, color: colorScheme.primary),
                                        const SizedBox(width: 4),
                                        Text(
                                          DateFormat('dd/MM/yyyy').format(task.date!),
                                          style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant, fontWeight: FontWeight.w500),
                                        ),
                                      ],
                                    ),
                                  ),
                                ...tags.map((tag) => Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: colorScheme.primaryContainer.withAlpha(80),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text('#$tag', style: TextStyle(fontSize: 11, color: colorScheme.primary, fontWeight: FontWeight.w500)),
                                    )),
                              ],
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // State label (hidden for Habits-tagged tasks)
                FutureBuilder<List<String>>(
                  future: _databaseService.taskService.getTagsByTaskId(task.id!),
                  builder: (context, snapshot) {
                    final hasHabitsTag = snapshot.data?.contains('Habits') ?? false;
                    if (hasHabitsTag) return const SizedBox.shrink();
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getStateLabelColor(task.state, colorScheme),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _getStateText(task.state),
                        style: TextStyle(
                          fontSize: 11,
                          color: _getStateLabelTextColor(task.state, colorScheme),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(width: 4),
                // Pin indicator/button: only visible when pinned (tap to unpin)
                task.isPinned
                    ? IconButton(
                        icon: Icon(
                          Icons.push_pin_rounded,
                          size: 16,
                          color: colorScheme.primary,
                        ),
                        onPressed: () async {
                          await _databaseService.taskService.updateTaskPinnedState(task.id!, false);
                          await _loadTasks();
                        },
                        tooltip: 'Unpin',
                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                        padding: EdgeInsets.zero,
                      )
                    : const SizedBox.shrink(),
              ],
            ),
          ),
        ),
      ),
    );
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

  // Hacer público el método
  Future<void> createNewTask() async {
    await _createNewTask();
  }
}
