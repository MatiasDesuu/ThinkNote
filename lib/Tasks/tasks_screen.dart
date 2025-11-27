import 'package:flutter/material.dart';
import 'dart:io';
import 'package:intl/intl.dart';
import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../animations/animations_handler.dart';
import 'dart:async';
import '../database/database_service.dart';
import '../database/models/task.dart';
import '../database/models/subtask.dart';
import 'habits_widget.dart';
import '../widgets/custom_snackbar.dart';
import '../widgets/context_menu.dart';
import '../widgets/confirmation_dialogue.dart';
import '../widgets/resizable_icon_sidebar.dart';
import '../Settings/settings_screen.dart';
import 'package:flutter/gestures.dart';

class TodoScreenDB extends StatefulWidget {
  final Directory rootDir;
  final VoidCallback onDirectorySet;
  final VoidCallback? onThemeUpdated;

  const TodoScreenDB({
    super.key,
    required this.rootDir,
    required this.onDirectorySet,
    this.onThemeUpdated,
  });

  @override
  State<TodoScreenDB> createState() => _TodoScreenDBState();
}

class _TodoScreenDBState extends State<TodoScreenDB>
    with TickerProviderStateMixin {
  // Estado
  List<Task> _tasks = [];
  List<Task> _completedTasks = [];
  List<Task> _allPendingTasks = []; // Todas las tareas pendientes sin filtrar
  List<Task> _allCompletedTasks = []; // Todas las tareas completadas sin filtrar
  Task? _selectedTask;
  List<Subtask> _subtasks = [];
  String? _selectedTag;
  List<String> _filteredTagsForCurrentTab = [];
  List<String> _selectedTaskTags = [];

  // Controladores
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _newSubtaskController = TextEditingController();
  final TextEditingController _editingController = TextEditingController();
  final FocusNode _editingFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  final ScrollController _tagsScrollController = ScrollController();
  late SyncAnimationController _syncController;
  late TabController _tasksTabController;
  late TabController _subtasksTabController;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _appFocusNode = FocusNode();

  // Interfaz
  double _sidebarWidth = 240;
  bool _isDragging = false;
  DateTime? _selectedDate;
  String? _editingSubtaskId;
  Timer? _debounceTimer;
  bool _isUpdatingManually = false;

  // Servicios
  final DatabaseService _databaseService = DatabaseService();

  @override
  void initState() {
    super.initState();
    _syncController = SyncAnimationController(vsync: this);
    _tasksTabController = TabController(length: 2, vsync: this);
    _subtasksTabController = TabController(length: 2, vsync: this);

    _loadSavedSettings();
    _loadTasks();

    // Agregar listener para el título
    _nameController.addListener(_onNameChanged);

    // Suscribirse a cambios en la base de datos
    _databaseService.onDatabaseChanged.listen((_) {
      // Solo actualizar si no estamos actualizando manualmente
      if (!_isUpdatingManually) {
        _loadTasks();
      }
    });
  }

  @override
  void dispose() {
    _nameController.removeListener(_onNameChanged);
    _nameController.dispose();
    _newSubtaskController.dispose();
    _scrollController.dispose();
    _tagsScrollController.dispose();
    _editingController.dispose();
    _editingFocusNode.dispose();
    _debounceTimer?.cancel();
    _syncController.dispose();
    _tasksTabController.dispose();
    _subtasksTabController.dispose();
    _searchController.dispose();
    _appFocusNode.dispose();
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
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _sidebarWidth = prefs.getDouble('todo_sidebar_width') ?? 240;
    });
  }

  Future<void> _saveWidth(double width) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('todo_sidebar_width', width);
  }

  Future<void> _updateFilteredTagsForCurrentTab() async {
    // Usar las listas de tareas sin filtrar para obtener todos los tags disponibles
    final tasksForCurrentTab =
        _tasksTabController.index == 0 ? _allPendingTasks : _allCompletedTasks;
    
    if (tasksForCurrentTab.isEmpty) {
      setState(() {
        _filteredTagsForCurrentTab = [];
      });
      return;
    }

    final tagsSet = <String>{};
    
    // Obtener tags que están presentes en las tareas de la tab actual (sin filtrar por tag)
    for (final task in tasksForCurrentTab) {
      if (task.id != null) {
        final taskTags = await _databaseService.taskService.getTagsByTaskId(task.id!);
        tagsSet.addAll(taskTags);
      }
    }

    if (mounted) {
      setState(() {
        _filteredTagsForCurrentTab = tagsSet.toList()..sort();
      });
    }
  }

  Future<void> _filterTasksByTag(String? tag) async {
    if (tag == null) {
      // Sin filtro - mostrar todas las tareas de cada tab
      setState(() {
        _tasks = List.from(_allPendingTasks);
        _completedTasks = List.from(_allCompletedTasks);
      });
    } else {
      // Filtrar solo la tab actual
      final currentTabIndex = _tasksTabController.index;
      final tasksToFilter = currentTabIndex == 0 ? _allPendingTasks : _allCompletedTasks;
      
      final tasksWithTag = await _databaseService.taskService.getTasksByTag(tag);
      
      final filteredTasks = tasksToFilter
          .where((task) => tasksWithTag.any((t) => t.id == task.id))
          .toList();
      
      setState(() {
        if (currentTabIndex == 0) {
          _tasks = filteredTasks;
        } else {
          _completedTasks = filteredTasks;
        }
      });
    }
    
    // Actualizar tags filtrados para la tab actual
    await _updateFilteredTagsForCurrentTab();
  }

  Future<void> _updateTaskListsOnly() async {
    try {
      // Cargar tareas pendientes y completadas
      List<Task> pendingTasks =
          await _databaseService.taskService.getPendingTasks();
      List<Task> completedTasks =
          await _databaseService.taskService.getCompletedTasks();

      // Guardar todas las tareas sin filtrar
      final allPendingTasks = List<Task>.from(pendingTasks);
      final allCompletedTasks = List<Task>.from(completedTasks);

      // Cargar todos los tags

      if (mounted) {
        setState(() {
          _tasks = allPendingTasks; // Inicialmente mostrar todas las tareas
          _completedTasks = allCompletedTasks; // Inicialmente mostrar todas las tareas
          _allPendingTasks = allPendingTasks;
          _allCompletedTasks = allCompletedTasks;
        });
        // Aplicar filtro actual si existe
        await _filterTasksByTag(_selectedTag);
      }
    } catch (e) {
      print('Error updating task lists: $e');
      if (mounted) {
        CustomSnackbar.show(
          context: context,
          message: 'Error updating task lists: $e',
          type: CustomSnackbarType.error,
        );
      }
    }
  }

  Future<void> _loadTasks() async {
    try {
      // Cargar tareas pendientes y completadas
      List<Task> pendingTasks =
          await _databaseService.taskService.getPendingTasks();
      List<Task> completedTasks =
          await _databaseService.taskService.getCompletedTasks();

      // Guardar todas las tareas sin filtrar
      final allPendingTasks = List<Task>.from(pendingTasks);
      final allCompletedTasks = List<Task>.from(completedTasks);

      // Cargar todos los tags

      // Cargar subtareas si hay una tarea seleccionada
      List<Subtask> subtasks = [];
      if (_selectedTask != null) {
        subtasks = await _databaseService.taskService.getSubtasksByTaskId(
          _selectedTask!.id!,
        );

        // Obtener la tarea directamente de la base de datos para asegurar que esté actualizada
        final updatedTask = await _databaseService.taskService.getTask(
          _selectedTask!.id!,
        );

        if (updatedTask != null) {
          _selectedTask = updatedTask;
          _selectedDate = updatedTask.date;
          // Load selected task tags
          await _loadSelectedTaskTags(updatedTask.id!);
        }
      }

      if (mounted) {
        setState(() {
          _tasks = allPendingTasks; // Inicialmente mostrar todas las tareas
          _completedTasks = allCompletedTasks; // Inicialmente mostrar todas las tareas
          _allPendingTasks = allPendingTasks;
          _allCompletedTasks = allCompletedTasks;
          _subtasks = subtasks;
        });
        // Aplicar filtro actual si existe
        await _filterTasksByTag(_selectedTag);
      }
    } catch (e) {
      print('Error loading tasks: $e');
      if (mounted) {
        CustomSnackbar.show(
          context: context,
          message: 'Error loading tasks: $e',
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
          message: 'Error creating task: $e',
          type: CustomSnackbarType.error,
        );
      }
    }
  }

  Future<void> _selectTask(Task task) async {
    // Cargar subtareas
    final subtasks = await _databaseService.taskService.getSubtasksByTaskId(
      task.id!,
    );

    setState(() {
      _selectedTask = task;
      _nameController.text = task.name;
      _newSubtaskController.clear();
      _selectedDate = task.date;
      _subtasks = subtasks;
    });
    // Load tags for selected task
    await _loadSelectedTaskTags(task.id!);
  }

  Future<void> _loadSelectedTaskTags(int taskId) async {
    try {
      final tags = await _databaseService.taskService.getTagsByTaskId(taskId);
      if (mounted) {
        setState(() {
          _selectedTaskTags = tags;
        });
      }
    } catch (e) {
      print('Error loading selected task tags: $e');
    }
  }

  Future<void> _deleteTask(Task task) async {
    final colorScheme = Theme.of(context).colorScheme;
    final confirmed = await showDeleteConfirmationDialog(
      context: context,
      title: 'Delete Task',
      message:
          'Are you sure you want to delete "${task.name}"? This action cannot be undone.',
      confirmText: 'Delete',
      confirmColor: colorScheme.error,
    );

    if (confirmed == true) {
      await _databaseService.taskService.deleteTask(task.id!);

      // Actualizar estado
      setState(() {
        if (_selectedTask?.id == task.id) {
          _selectedTask = null;
          _nameController.clear();
          _newSubtaskController.clear();
          _selectedDate = null;
          _subtasks = [];
        }
      });

      await _loadTasks();
    }
  }

  Future<void> _updateTaskState(Task task, TaskState state) async {
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
  }

  Future<void> _reorderTasks(int oldIndex, int newIndex) async {
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
  }

  Future<void> _addSubtask() async {
    if (_selectedTask == null || _newSubtaskController.text.trim().isEmpty) {
      return;
    }

    final newSubtask = await _databaseService.taskService.createSubtask(
      _selectedTask!.id!,
      _newSubtaskController.text.trim(),
    );

    if (newSubtask != null) {
      setState(() {
        _subtasks.add(newSubtask);
        _newSubtaskController.clear();
      });
    }
  }

  Future<void> _toggleSubtask(Subtask subtask) async {
    await _databaseService.taskService.toggleSubtaskCompleted(
      subtask,
      !subtask.completed,
    );

    // Recargar subtareas
    if (_selectedTask != null) {
      final subtasks = await _databaseService.taskService.getSubtasksByTaskId(
        _selectedTask!.id!,
      );
      setState(() {
        _subtasks = subtasks;
      });
    }
  }

  Future<void> _deleteSubtask(Subtask subtask) async {
    await _databaseService.taskService.deleteSubtask(subtask.id!);

    setState(() {
      _subtasks.removeWhere((s) => s.id == subtask.id);
    });
  }

  Future<void> _editSubtask(Subtask subtask) async {
    setState(() {
      _editingSubtaskId = subtask.id.toString();
      _editingController.text = subtask.text;
    });
  }

  Future<void> _saveSubtaskEditing(Subtask subtask) async {
    final newText = _editingController.text.trim();
    if (newText.isNotEmpty && newText != subtask.text) {
      final updatedSubtask = subtask.copyWith(text: newText);
      await _databaseService.taskService.updateSubtask(updatedSubtask);

      setState(() {
        final index = _subtasks.indexWhere((s) => s.id == subtask.id);
        if (index != -1) {
          _subtasks[index] = updatedSubtask;
        }
        _editingSubtaskId = null;
      });
    } else {
      setState(() {
        _editingSubtaskId = null;
      });
    }
  }

  Future<void> _cancelSubtaskEditing() async {
    setState(() {
      _editingSubtaskId = null;
    });
  }

  Future<void> _reorderSubtasks(int oldIndex, int newIndex) async {
    // Obtener solo las subtareas pendientes
    final pendingSubtasks = _getPendingSubtasks();

    if (newIndex > oldIndex) {
      newIndex -= 1;
    }

    final item = pendingSubtasks.removeAt(oldIndex);
    pendingSubtasks.insert(newIndex, item);

    // Actualizar el orden de todas las subtareas pendientes
    final subtasksToUpdate = <Subtask>[];
    for (int i = 0; i < pendingSubtasks.length; i++) {
      final subtask = pendingSubtasks[i];
      if (subtask.orderIndex != i) {
        subtasksToUpdate.add(subtask.copyWith(orderIndex: i));
      }
    }

    // Actualizar la lista completa manteniendo el orden
    final completedSubtasks = _getCompletedSubtasks();
    setState(() {
      _subtasks = [...pendingSubtasks, ...completedSubtasks];
    });

    // Guardar todos los cambios
    for (final updatedSubtask in subtasksToUpdate) {
      await _databaseService.taskService.updateSubtask(updatedSubtask);
    }
  }

  List<Subtask> _getPendingSubtasks() {
    return _subtasks.where((s) => !s.completed).toList();
  }

  List<Subtask> _getCompletedSubtasks() {
    return _subtasks.where((s) => s.completed).toList();
  }

  Future<void> _updateSubtaskPriority(
    Subtask subtask,
    SubtaskPriority priority,
  ) async {
    final updatedSubtask = subtask.copyWith(priority: priority);
    await _databaseService.taskService.updateSubtask(updatedSubtask);

    setState(() {
      final index = _subtasks.indexWhere((s) => s.id == subtask.id);
      if (index != -1) {
        _subtasks[index] = updatedSubtask;
      }

      if (_selectedTask!.sortByPriority) {
        _orderSubtasksByPriority();
      }
    });
  }

  void _toggleSortByPriority() {
    if (_selectedTask == null) return;

    final updatedTask = _selectedTask!.copyWith(
      sortByPriority: !_selectedTask!.sortByPriority,
    );

    _databaseService.taskService.updateTask(updatedTask);

    setState(() {
      _selectedTask = updatedTask;
      if (_selectedTask!.sortByPriority) {
        _orderSubtasksByPriority();
      } else {
        _orderSubtasksManually();
      }
    });
  }

  void _orderSubtasksByPriority() {
    final pendingSubtasks = _getPendingSubtasks();
    final completedSubtasks = _getCompletedSubtasks();

    // Ordenar por prioridad (high -> medium -> low)
    pendingSubtasks.sort((a, b) {
      final priorityComp = b.priority.index.compareTo(a.priority.index);
      if (priorityComp != 0) return priorityComp;
      return a.orderIndex.compareTo(b.orderIndex);
    });

    // Actualizar lista completa
    setState(() {
      _subtasks = [...pendingSubtasks, ...completedSubtasks];
    });

    _databaseService.taskService.reorderSubtasks(pendingSubtasks);
  }

  void _orderSubtasksManually() {
    final pendingSubtasks = _getPendingSubtasks();
    final completedSubtasks = _getCompletedSubtasks();

    // Ordenar por orden manual
    pendingSubtasks.sort((a, b) => a.orderIndex.compareTo(b.orderIndex));

    // Actualizar lista completa
    setState(() {
      _subtasks = [...pendingSubtasks, ...completedSubtasks];
    });

    _databaseService.taskService.reorderSubtasks(pendingSubtasks);
  }

  void _onDragUpdate(DragUpdateDetails details) {
    setState(() {
      _sidebarWidth = (_sidebarWidth + details.delta.dx).clamp(200.0, 400.0);
    });
  }

  void _onDragEnd(DragEndDetails details) async {
    await _saveWidth(_sidebarWidth);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: Stack(
        children: [
          // Main content
          Row(
            children: [
              // Icon sidebar
              ResizableIconSidebar(
                rootDir: widget.rootDir,
                onOpenNote: (_) {},
                onOpenFolder: (_) {},
                onNotebookSelected: null,
                onNoteSelected: null,
                onBack: () async {
                  Navigator.of(context).pop();
                },
                onDirectorySet: widget.onDirectorySet,
                onThemeUpdated: widget.onThemeUpdated,
                onFavoriteRemoved: () {},
                onNavigateToMain: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).pop();
                },
                onClose: () {},
                onCreateNewNote: null,
                onCreateNewNotebook: null,
                onCreateNewTodo: _createNewTask,
                onShowManageTags: _showManageTagsDialog,
                onCreateThink: null,
                onOpenSettings: _openSettings,
                onOpenTrash: null,
                onOpenFavorites: null,
                showBackButton: true,
                isWorkflowsScreen: false,
                isTasksScreen: true,
                isThinksScreen: false,
                isSettingsScreen: false,
                isBookmarksScreen: false,
                appFocusNode: _appFocusNode,
              ),

              VerticalDivider(
                width: 1,
                thickness: 1,
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
              ),

              // Central sidebar with task list (resizable)
              Container(
                width: _sidebarWidth,
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerLow,
                ),
                child: Stack(
                  children: [
                    Column(
                      children: [
                        // Tabs for Pending and Completed tasks
                        TabBar(
                          controller: _tasksTabController,
                          onTap: (index) {
                            // Al cambiar de tab, resetear el filtro de tag y mostrar todas las tareas
                            setState(() {
                              _selectedTag = null;
                              _tasks = List.from(_allPendingTasks);
                              _completedTasks = List.from(_allCompletedTasks);
                            });
                            // Actualizar tags para la nueva tab después de un pequeño delay
                            Future.delayed(const Duration(milliseconds: 50), () {
                              _updateFilteredTagsForCurrentTab();
                            });
                          },
                          tabAlignment: TabAlignment.fill,
                          labelPadding: EdgeInsets.zero,
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
                                  Container(
                                    width: 22,
                                    height: 22,
                                    decoration: BoxDecoration(
                                      color: _tasksTabController.index == 0
                                          ? colorScheme.primary.withAlpha(26)
                                          : colorScheme.surfaceContainerHighest.withAlpha(77),
                                      shape: BoxShape.circle,
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      '${_tasks.length}',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: _tasksTabController.index == 0
                                            ? colorScheme.primary
                                            : colorScheme.onSurfaceVariant,
                                      ),
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
                                  Icon(
                                    Icons.check_circle_rounded,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Completed',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        // Tag filters (filtered by current tab)
                        if (_filteredTagsForCurrentTab.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          SizedBox(
                            height: 40,
                            child: Listener(
                              onPointerSignal: (pointerSignal) {
                                if (pointerSignal is PointerScrollEvent) {
                                  _tagsScrollController.position.moveTo(
                                    _tagsScrollController.position.pixels +
                                        pointerSignal.scrollDelta.dy,
                                    curve: Curves.linear,
                                    duration: const Duration(milliseconds: 20),
                                  );
                                }
                              },
                              child: ListView(
                                controller: _tagsScrollController,
                                scrollDirection: Axis.horizontal,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                ),
                                children: [
                                  FilterChip(
                                    label: const Text('All'),
                                    selected: _selectedTag == null,
                                    onSelected: (_) => _setTagFilter(null),
                                    showCheckmark: false,
                                    selectedColor: colorScheme.primaryContainer,
                                    checkmarkColor:
                                        colorScheme.onPrimaryContainer,
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
                                  ..._filteredTagsForCurrentTab.map(
                                    (tag) => Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 2,
                                      ),
                                      child: FilterChip(
                                        label: Text(tag),
                                        selected: _selectedTag == tag,
                                        onSelected:
                                            (selected) => _setTagFilter(
                                              selected ? tag : null,
                                            ),
                                        showCheckmark: false,
                                        selectedColor:
                                            colorScheme.primaryContainer,
                                        checkmarkColor:
                                            colorScheme.onPrimaryContainer,
                                        labelStyle: TextStyle(
                                          color:
                                              _selectedTag == tag
                                                  ? colorScheme
                                                      .onPrimaryContainer
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
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 2),
                        // TabBarView for tasks content
                        Expanded(
                          child: TabBarView(
                            controller: _tasksTabController,
                            children: [
                              // Pending tasks tab
                              _tasks.isEmpty
                                  ? Center(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.check_circle_outline_rounded,
                                          size: 48,
                                          color: colorScheme.onSurfaceVariant
                                              .withAlpha(100),
                                        ),
                                        const SizedBox(height: 16),
                                        Text(
                                          'No pending tasks',
                                          style: TextStyle(
                                            color: colorScheme.onSurfaceVariant
                                                .withAlpha(150),
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        TextButton.icon(
                                          onPressed: _createNewTask,
                                          icon: Icon(
                                            Icons.add_rounded,
                                            size: 18,
                                            color: colorScheme.primary,
                                          ),
                                          label: Text(
                                            'Create task',
                                            style: TextStyle(
                                              color: colorScheme.primary,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                  : ReorderableListView.builder(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    itemCount: _tasks.length,
                                    buildDefaultDragHandles: false,
                                    onReorder: _reorderTasks,
                                    itemBuilder: (context, index) {
                                      return _buildTaskItem(_tasks[index]);
                                    },
                                  ),
                              // Completed tasks tab
                              _completedTasks.isEmpty
                                  ? Center(
                                    child: Text(
                                      'No completed tasks',
                                      style: TextStyle(
                                        color: colorScheme.onSurfaceVariant
                                            .withAlpha(150),
                                      ),
                                    ),
                                  )
                                  : ListView.builder(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    itemCount: _completedTasks.length,
                                    itemBuilder: (context, index) {
                                      return _buildTaskItem(
                                        _completedTasks[index],
                                      );
                                    },
                                  ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    // Resize control
                    Positioned(
                      right: 0,
                      top: 0,
                      bottom: 0,
                      child: MouseRegion(
                        cursor: SystemMouseCursors.resizeLeftRight,
                        child: GestureDetector(
                          onPanUpdate: _onDragUpdate,
                          onPanStart: (_) => setState(() => _isDragging = true),
                          onPanEnd: (details) {
                            setState(() => _isDragging = false);
                            _onDragEnd(details);
                          },
                          child: Container(
                            width: 6,
                            decoration: BoxDecoration(
                              color:
                                  _isDragging
                                      ? colorScheme.primary.withAlpha(50)
                                      : Colors.transparent,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Right content panel (editor)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(
                    left: 24.0,
                    right: 24.0,
                    top: 48.0,
                  ),
                  child:
                      _selectedTask == null
                          ? Center(
                            child: Text(
                              'Select a task or create a new one',
                              style: TextStyle(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          )
                          : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Title
                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: _nameController,
                                      decoration: InputDecoration(
                                        labelText: 'Title',
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(16),
                                        ),
                                        filled: true,
                                        fillColor: colorScheme.surfaceContainerHighest
                                            .withAlpha(127),
                                        prefixIcon: Icon(
                                          Icons.title_rounded,
                                          color: colorScheme.primary,
                                        ),
                                      ),
                                      onChanged: (_) {},
                                      style: const TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  // In habits mode, move compact tags and pin next to title
                                  if (_selectedTask != null && _selectedTaskTags.contains('Habits')) ...[
                                    _buildTagSelector(colorScheme: colorScheme, compact: true),
                                    const SizedBox(width: 8),
                                    _buildPinButton(colorScheme: colorScheme, compact: true),
                                  ],
                                ],
                              ),
                              if (!(_selectedTask != null && _selectedTaskTags.contains('Habits')))
                                const SizedBox(height: 8),

                                  // Row: Date | Status | Tags | Pin
                                  Builder(builder: (context) {
                                    final isHabits = _selectedTask != null && _selectedTaskTags.contains('Habits');
                                        return Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (!isHabits) ...[
                                          _buildDateWithDelete(
                                            colorScheme: colorScheme,
                                          ),
                                          const SizedBox(width: 8),
                                          _buildStatusSelector(
                                            colorScheme: colorScheme,
                                          ),
                                          const SizedBox(width: 8),
                                          _buildTagSelector(colorScheme: colorScheme),
                                          const SizedBox(width: 8),
                                          _buildPinButton(colorScheme: colorScheme),
                                        ],
                                      ],
                                    );
                                  }),

                              if (!(_selectedTask != null && _selectedTaskTags.contains('Habits')))
                                const SizedBox(height: 8),

                              // Subtasks section
                              if (!(_selectedTask != null && _selectedTaskTags.contains('Habits')))
                                _buildNewSubtaskSection(colorScheme: colorScheme),

                              if (!(_selectedTask != null && _selectedTaskTags.contains('Habits')))
                                const SizedBox(height: 8),

                                      // Subtasks list or Habits view if task has 'Habits' tag
                                      Expanded(
                                        child: _selectedTask != null && _selectedTaskTags.contains('Habits')
                                            ? HabitsTracker(
                                                databaseService: _databaseService,
                                                subtasks: _subtasks,
                                                taskId: _selectedTask!.id!,
                                              )
                                            : Column(
                                                children: [
                                                  // Subtasks tabs
                                                  Container(
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
                                                        overlayColor: WidgetStateProperty.all(Colors.transparent),
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
                                                                Container(
                                                                  width: 22,
                                                                  height: 22,
                                                                  decoration: BoxDecoration(
                                                                    color: _subtasksTabController.index == 0
                                                                        ? colorScheme.primary.withAlpha(26)
                                                                        : colorScheme.surfaceContainerHighest.withAlpha(77),
                                                                    shape: BoxShape.circle,
                                                                  ),
                                                                  alignment: Alignment.center,
                                                                  child: Text(
                                                                    '${_getPendingSubtasks().length}',
                                                                    style: TextStyle(
                                                                      fontSize: 10,
                                                                      fontWeight: FontWeight.w600,
                                                                      color: _subtasksTabController.index == 0
                                                                          ? colorScheme.primary
                                                                          : colorScheme.onSurfaceVariant,
                                                                    ),
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
                                                                Icon(
                                                                  Icons.check_circle_rounded,
                                                                  size: 16,
                                                                ),
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
                                                  const SizedBox(height: 2),
                                                  // Subtasks TabBarView
                                                  Expanded(
                                                    child: TabBarView(
                                                      controller: _subtasksTabController,
                                                      children: [
                                                        // Pending subtasks tab
                                                        _getPendingSubtasks().isEmpty
                                                            ? Center(
                                                                child: Text(
                                                                  'No pending subtasks',
                                                                  style: TextStyle(
                                                                    color: colorScheme
                                                                        .onSurfaceVariant
                                                                        .withAlpha(150),
                                                                  ),
                                                                ),
                                                              )
                                                            : ReorderableListView.builder(
                                                                padding: const EdgeInsets.only(
                                                                  bottom: 8,
                                                                ),
                                                                itemCount: _getPendingSubtasks().length,
                                                                buildDefaultDragHandles: false,
                                                                onReorder: _reorderSubtasks,
                                                                itemBuilder: (context, index) {
                                                                  final subtask = _getPendingSubtasks()[index];
                                                                  final isEditing = _editingSubtaskId == subtask.id.toString();
                                                                  return _buildSubtaskItem(
                                                                    subtask,
                                                                    isEditing,
                                                                    colorScheme,
                                                                  );
                                                                },
                                                              ),
                                                        // Completed subtasks tab
                                                        _getCompletedSubtasks().isEmpty
                                                            ? Center(
                                                                child: Text(
                                                                  'No completed subtasks',
                                                                  style: TextStyle(
                                                                    color: colorScheme
                                                                        .onSurfaceVariant
                                                                        .withAlpha(150),
                                                                  ),
                                                                ),
                                                              )
                                                            : ListView.builder(
                                                                padding: const EdgeInsets.only(
                                                                  bottom: 8,
                                                                ),
                                                                itemCount: _getCompletedSubtasks().length,
                                                                itemBuilder: (context, index) {
                                                                  final subtask = _getCompletedSubtasks()[index];
                                                                  final isEditing = _editingSubtaskId == subtask.id.toString();
                                                                  return _buildSubtaskItem(
                                                                    subtask,
                                                                    isEditing,
                                                                    colorScheme,
                                                                  );
                                                                },
                                                              ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                      ),
                            ],
                          ),
                ),
              ),
            ],
          ),

          // Window controls in top right corner
          Positioned(
            top: 0,
            right: 0,
            height: 40,
            child: Container(
              color: colorScheme.surface,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 46,
                    height: 40,
                    child: MinimizeWindowButton(
                      colors: WindowButtonColors(
                        iconNormal: colorScheme.onSurface,
                        mouseOver: colorScheme.surfaceContainerHighest,
                        mouseDown: colorScheme.surfaceContainerHigh,
                        iconMouseOver: colorScheme.onSurface,
                        iconMouseDown: colorScheme.onSurface,
                      ),
                      onPressed: () {
                        appWindow.minimize();
                      },
                    ),
                  ),
                  SizedBox(
                    width: 46,
                    height: 40,
                    child: MaximizeWindowButton(
                      colors: WindowButtonColors(
                        iconNormal: colorScheme.onSurface,
                        mouseOver: colorScheme.surfaceContainerHighest,
                        mouseDown: colorScheme.surfaceContainerHigh,
                        iconMouseOver: colorScheme.onSurface,
                        iconMouseDown: colorScheme.onSurface,
                      ),
                      onPressed: () {
                        appWindow.maximizeOrRestore();
                      },
                    ),
                  ),
                  SizedBox(
                    width: 46,
                    height: 40,
                    child: CloseWindowButton(
                      colors: WindowButtonColors(
                        iconNormal: colorScheme.onSurface,
                        mouseOver: colorScheme.error,
                        mouseDown: colorScheme.error.withAlpha(128),
                        iconMouseOver: colorScheme.onError,
                        iconMouseDown: colorScheme.onError,
                      ),
                      onPressed: () {
                        appWindow.close();
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Title drag area - correctly placed
          Positioned(
            top: 0,
            left: 60 + _sidebarWidth, // Skip left sidebar + central task sidebar
            right: 138, // Control buttons width
            height: 40,
            child: MoveWindow(),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskItem(Task task) {
    final colorScheme = Theme.of(context).colorScheme;
    final bool isSelected = _selectedTask?.id == task.id;

    return ReorderableDragStartListener(
      key: ValueKey(task.id!),
      index: _tasks.indexOf(task),
      child: MouseRegionHoverItem(
        builder: (context, isHovering) {
          return Card(
            margin: const EdgeInsets.only(bottom: 4, left: 8, right: 8),
            color:
                isSelected
                    ? colorScheme.surfaceContainerHighest
                    : colorScheme.surfaceContainer,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color:
                    isSelected
                        ? colorScheme.primary.withAlpha(80)
                        : colorScheme.outlineVariant.withAlpha(60),
                width: isSelected ? 1.5 : 1,
              ),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => _selectTask(task),
                onSecondaryTapDown: (details) {
                  _showTaskContextMenu(task, details.globalPosition);
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Ícono de tarea y pin
                      Stack(
                        alignment: Alignment.center,
                        clipBehavior: Clip.none,
                        children: [
                          MouseRegion(
                            cursor: SystemMouseCursors.click,
                            child: GestureDetector(
                              onTap:
                                  () => _updateTaskState(
                                    task,
                                    task.state == TaskState.completed
                                        ? TaskState.pending
                                        : TaskState.completed,
                                  ),
                              child: Icon(
                                task.state == TaskState.completed
                                    ? Icons.check_circle_rounded
                                    : Icons.radio_button_unchecked_rounded,
                                color:
                                    task.state == TaskState.completed
                                        ? colorScheme.primary
                                        : colorScheme.onSurfaceVariant,
                                size: 24,
                              ),
                            ),
                          ),
                          if (task.isPinned)
                            Positioned(
                              right: -4,
                              bottom: -4,
                              child: Container(
                                padding: const EdgeInsets.all(1),
                                decoration: BoxDecoration(
                                  color: colorScheme.surface,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.push_pin_rounded,
                                  size: 12,
                                  color: colorScheme.primary,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(width: 12),
                      // Nombre y detalles — reservar altura fija para consistencia
                      Expanded(
                        child: FutureBuilder<List<String>>(
                          future: _databaseService.taskService
                              .getTagsByTaskId(task.id!),
                          builder: (context, snapshot) {
                            final hasTags = snapshot.hasData && snapshot.data!.isNotEmpty;
                            final tags = snapshot.data ?? <String>[];

                            return SizedBox(
                              height: 50,
                              child: hasTags
                                  ? Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          task.name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontWeight: isSelected
                                                ? FontWeight.bold
                                                : FontWeight.w500,
                                            color: colorScheme.onSurface,
                                            fontSize: 16,
                                            decoration: task.state == TaskState.completed
                                                ? TextDecoration.lineThrough
                                                : null,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Wrap(
                                          spacing: 4,
                                          runSpacing: 2,
                                          children: [
                                            if (task.date != null)
                                              Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    Icons.calendar_today_rounded,
                                                    size: 14,
                                                    color: colorScheme.primary,
                                                  ),
                                                  const SizedBox(width: 2),
                                                  Text(
                                                    DateFormat('dd/MM/yyyy').format(task.date!),
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color: colorScheme.onSurfaceVariant,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            if (task.date != null && (task.tagIds.isNotEmpty))
                                              Text(
                                                '|',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: colorScheme.onSurfaceVariant,
                                                ),
                                              ),
                                          ...tags.map(
                                            (tag) => Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 6,
                                                vertical: 2,
                                              ),
                                              decoration: BoxDecoration(
                                                color: colorScheme.primaryContainer.withAlpha(80),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                '#$tag',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: colorScheme.primary,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ),
                                          ),
                                          ],
                                        ),
                                      ],
                                    )
                                  : Align(
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        task.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                          color: colorScheme.onSurface,
                                          fontSize: 16,
                                          decoration: task.state == TaskState.completed
                                              ? TextDecoration.lineThrough
                                              : null,
                                        ),
                                      ),
                                    ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Estado visual como etiqueta (hide for Habits-tagged tasks)
                      FutureBuilder<List<String>>(
                        future: _databaseService.taskService.getTagsByTaskId(task.id!),
                        builder: (context, snapshot) {
                          final hasHabitsTag = snapshot.data?.contains('Habits') ?? false;
                          if (hasHabitsTag) return const SizedBox.shrink();
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: _getStateLabelColor(task.state, colorScheme),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _getStateText(task.state),
                              style: TextStyle(
                                fontSize: 11,
                                color: _getStateLabelTextColor(
                                  task.state,
                                  colorScheme,
                                ),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(width: 4),
                      // Botón eliminar
                      IconButton(
                        icon: Icon(
                          Icons.delete_forever_rounded,
                          color: colorScheme.error,
                          size: 18,
                        ),
                        onPressed: () => _deleteTask(task),
                        tooltip: 'Delete',
                        constraints: const BoxConstraints(
                          minWidth: 32,
                          minHeight: 32,
                        ),
                        padding: EdgeInsets.zero,
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
  }

  // Helpers para el color de la etiqueta de estado
  Color _getStateLabelColor(TaskState state, ColorScheme colorScheme) {
    switch (state) {
      case TaskState.pending:
        return colorScheme.surfaceContainerHighest.withAlpha(80);
      case TaskState.inProgress:
        return const Color(0xFFFFE0B2); // Orange pastel
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

  void _showTaskContextMenu(Task task, Offset position) {
    ContextMenuOverlay.show(
      context: context,
      tapPosition: position,
      items: [
        ContextMenuItem(
          icon: Icons.edit_rounded,
          label: 'Edit task',
          onTap: () => _selectTask(task),
        ),
        ContextMenuItem(
          icon:
              task.isPinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
          label: task.isPinned ? 'Unpin task' : 'Pin task',
          onTap: () => _toggleTaskPinned(task),
        ),
        ContextMenuItem(
          icon: Icons.delete_forever_rounded,
          label: 'Delete task',
          iconColor: Theme.of(context).colorScheme.error,
          onTap: () => _deleteTask(task),
        ),
      ],
    );
  }

  Future<void> _toggleTaskPinned(Task task) async {
    await _databaseService.taskService.updateTaskPinnedState(
      task.id!,
      !task.isPinned,
    );
    await _loadTasks();
  }

  Widget _buildSubtaskItem(
    Subtask subtask,
    bool isEditing,
    ColorScheme colorScheme,
  ) {
    final isCompleted = subtask.completed;
    final list = isCompleted ? _getCompletedSubtasks() : _getPendingSubtasks();
    final index = list.indexOf(subtask);
    final ordenarPorPrioridad = _selectedTask?.sortByPriority ?? false;

    return ReorderableDragStartListener(
      key: ValueKey(subtask.id!),
      index: index,
      enabled: !ordenarPorPrioridad && !isCompleted,
      child: Card(
        elevation: 0,
        margin: const EdgeInsets.symmetric(vertical: 2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(
            color: colorScheme.outlineVariant.withAlpha(127),
            width: 0.5,
          ),
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 4,
          ),
          leading: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!ordenarPorPrioridad && !isCompleted)
                Icon(
                  Icons.drag_indicator_rounded,
                  color: colorScheme.onSurfaceVariant.withAlpha(127),
                  size: 20,
                ),
              const SizedBox(width: 8),
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: Checkbox(
                  value: subtask.completed,
                  activeColor: colorScheme.primary,
                  checkColor: colorScheme.onPrimary,
                  onChanged: (_) => _toggleSubtask(subtask),
                ),
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
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
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
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
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
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
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
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!isEditing && !subtask.completed)
                IconButton(
                  icon: Icon(
                    _getPriorityIcon(subtask.priority),
                    color: _getPriorityColor(subtask.priority),
                    size: 20,
                  ),
                  onPressed: () => _showPrioritySelectorDialog(subtask),
                ),
              if (!isEditing)
                IconButton(
                  icon: Icon(
                    Icons.edit_rounded,
                    color: colorScheme.primary,
                    size: 20,
                  ),
                  tooltip: '',
                  onPressed: () => _editSubtask(subtask),
                ),
              if (isEditing)
                IconButton(
                  icon: Icon(
                    Icons.check_rounded,
                    color: colorScheme.primary,
                    size: 20,
                  ),
                  tooltip: '',
                  onPressed: () => _saveSubtaskEditing(subtask),
                ),
              if (isEditing)
                IconButton(
                  icon: Icon(
                    Icons.close_rounded,
                    color: colorScheme.error,
                    size: 20,
                  ),
                  tooltip: '',
                  onPressed: _cancelSubtaskEditing,
                ),
              if (!isEditing)
                IconButton(
                  icon: Icon(
                    Icons.delete_forever_rounded,
                    color: colorScheme.error,
                    size: 20,
                  ),
                  tooltip: '',
                  onPressed: () => _deleteSubtask(subtask),
                ),
            ],
          ),
        ),
      ),
    );
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
        return Theme.of(context).colorScheme.error;
      case SubtaskPriority.medium:
        return Theme.of(context).colorScheme.primary;
      case SubtaskPriority.low:
        return Theme.of(context).colorScheme.tertiary;
    }
  }

  Widget _buildNewSubtaskSection({required ColorScheme colorScheme}) {
    final ordenarPorPrioridad = _selectedTask?.sortByPriority ?? false;

    return Row(
      children: [
        Container(
          height: 48,
          width: 48,
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: _addSubtask,
              child: Center(
                child: Icon(
                  Icons.add_rounded,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: TextField(
            controller: _newSubtaskController,
            decoration: InputDecoration(
              labelText: 'New subtask',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              filled: true,
              fillColor: colorScheme.surfaceContainerHighest.withAlpha(127),
              prefixIcon: Icon(
                Icons.add_task_rounded,
                color: colorScheme.primary,
              ),
            ),
            onSubmitted: (_) => _addSubtask(),
          ),
        ),
        const SizedBox(width: 12),
        IconButton(
          icon: Icon(
            ordenarPorPrioridad
                ? Icons.sort_by_alpha_rounded
                : Icons.drag_indicator_rounded,
            color:
                ordenarPorPrioridad
                    ? colorScheme.primary
                    : colorScheme.onSurfaceVariant,
          ),
          onPressed: _toggleSortByPriority,
        ),
      ],
    );
  }

  Widget _buildDateWithDelete({required ColorScheme colorScheme}) {
    return MouseRegionHoverItem(
      builder: (context, isHovering) {
        return MouseRegion(
          cursor: SystemMouseCursors.click,
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              onTap: () async {
                final fecha = await showDatePicker(
                  context: context,
                  initialDate: _selectedDate ?? DateTime.now(),
                  firstDate: DateTime.now().subtract(const Duration(days: 365)),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (fecha != null && _selectedTask != null) {
                  // Marcar que estamos actualizando manualmente
                  _isUpdatingManually = true;

                  final updatedTask = _selectedTask!.copyWith(date: fecha);
                  await _databaseService.taskService.updateTask(updatedTask);

                  setState(() {
                    _selectedDate = fecha;
                    _selectedTask = updatedTask;
                  });

                  // Recargar la lista de tareas para actualizar la UI
                  await _updateTaskListsOnly();

                  // Desmarcar la actualización manual
                  _isUpdatingManually = false;
                }
              },
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest.withAlpha(127),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: colorScheme.outline, width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.calendar_today_rounded,
                      size: 16,
                      color: colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _selectedDate == null
                          ? 'No date'
                          : DateFormat('dd/MM/yyyy').format(_selectedDate!),
                      style: TextStyle(
                        fontSize: 14,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    if (_selectedDate != null && isHovering) ...[
                      const SizedBox(width: 8),
                      MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () async {
                              if (_selectedTask != null) {
                                // Marcar que estamos actualizando manualmente
                                _isUpdatingManually = true;

                                await _databaseService.taskService
                                    .updateTaskDate(_selectedTask!.id!, null);

                                setState(() {
                                  _selectedDate = null;
                                  // Crear una nueva tarea con fecha null explícitamente
                                  _selectedTask = Task(
                                    id: _selectedTask!.id,
                                    name: _selectedTask!.name,
                                    date: null, // Fecha explícitamente null
                                    completed: _selectedTask!.completed,
                                    state: _selectedTask!.state,
                                    createdAt: _selectedTask!.createdAt,
                                    updatedAt: _selectedTask!.updatedAt,
                                    deletedAt: _selectedTask!.deletedAt,
                                    orderIndex: _selectedTask!.orderIndex,
                                    sortByPriority:
                                        _selectedTask!.sortByPriority,
                                    isPinned: _selectedTask!.isPinned,
                                    tagIds: _selectedTask!.tagIds,
                                  );
                                });

                                // Actualizar también la lista de tareas para que refleje el cambio
                                await _updateTaskListsOnly();

                                // Desmarcar la actualización manual
                                _isUpdatingManually = false;
                              }
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Padding(
                              padding: const EdgeInsets.all(2),
                              child: Icon(
                                Icons.close_rounded,
                                size: 14,
                                color: colorScheme.onSurface,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
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

  Color _getStateTextColor(TaskState state, ColorScheme colorScheme) {
    switch (state) {
      case TaskState.pending:
        return colorScheme.onSurface;
      case TaskState.inProgress:
        return const Color(0xFFB75D0A); // Darker orange for text
      case TaskState.completed:
        return colorScheme.onPrimaryContainer;
    }
  }

  Icon _getStateIcon(TaskState state, ColorScheme colorScheme) {
    switch (state) {
      case TaskState.pending:
        return Icon(
          Icons.circle_outlined,
          size: 16,
          color: colorScheme.onSurfaceVariant,
        );
      case TaskState.inProgress:
        return Icon(
          Icons.pending_rounded,
          size: 16,
          color: const Color(0xFFB75D0A), // Darker orange for icon
        );
      case TaskState.completed:
        return Icon(
          Icons.check_circle_rounded,
          size: 16,
          color: colorScheme.primary,
        );
    }
  }

  Widget _buildStatusSelector({required ColorScheme colorScheme}) {
    if (_selectedTask == null) return const SizedBox.shrink();

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () => _showStatusSelectorDialog(),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withAlpha(127),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colorScheme.outline, width: 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _getStateIcon(_selectedTask!.state, colorScheme),
                const SizedBox(width: 8),
                Text(
                  _getStateText(_selectedTask!.state),
                  style: TextStyle(
                    fontSize: 14,
                    color: _getStateTextColor(
                      _selectedTask!.state,
                      colorScheme,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.arrow_drop_down_rounded,
                  size: 18,
                  color: _getStateTextColor(_selectedTask!.state, colorScheme),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showStatusSelectorDialog() {
    showDialog(
      context: context,
      builder:
          (context) => _StatusSelectorDialog(
            selectedState: _selectedTask!.state,
            onStateSelected: (state) {
              _updateTaskState(_selectedTask!, state);
              Navigator.pop(context);
            },
          ),
    );
  }

  Widget _buildTagSelector({required ColorScheme colorScheme, bool compact = false}) {
    if (_selectedTask == null) return const SizedBox.shrink();

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () => _showTagSelectorDialog(),
          borderRadius: BorderRadius.circular(16),
          child: compact
              ? Container(
                  height: 56,
                  width: 56,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest.withAlpha(127),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: colorScheme.outline, width: 1),
                  ),
                  child: Icon(Icons.label_rounded, size: 20, color: colorScheme.primary),
                )
              : Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest.withAlpha(127),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: colorScheme.outline, width: 1),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.label_rounded, size: 16, color: colorScheme.primary),
                      const SizedBox(width: 8),
                      Text(
                        'Tags',
                        style: TextStyle(fontSize: 14, color: colorScheme.onSurface),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.arrow_drop_down_rounded,
                        size: 18,
                        color: colorScheme.onSurface,
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  void _showTagSelectorDialog() {
    showDialog(
      context: context,
      builder:
          (context) => _TagSelectorDialog(
            databaseService: _databaseService,
            selectedTask: _selectedTask!,
            onTagsChanged: () {
              setState(() {
                _loadTasks();
              });
            },
          ),
    );
  }

  Widget _buildPinButton({required ColorScheme colorScheme, bool compact = false}) {
    if (_selectedTask == null) return const SizedBox.shrink();

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () => _toggleTaskPinned(_selectedTask!),
          borderRadius: BorderRadius.circular(16),
          child: compact
              ? Container(
                  height: 56,
                  width: 56,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest.withAlpha(127),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: colorScheme.outline, width: 1),
                  ),
                  child: Icon(
                    _selectedTask!.isPinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
                    size: 20,
                    color: _selectedTask!.isPinned ? colorScheme.primary : colorScheme.onSurfaceVariant,
                  ),
                )
              : Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest.withAlpha(127),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: colorScheme.outline, width: 1),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _selectedTask!.isPinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
                        size: 16,
                        color: _selectedTask!.isPinned ? colorScheme.primary : colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _selectedTask!.isPinned ? 'Pinned' : 'Pin',
                        style: TextStyle(
                          fontSize: 14,
                          color: _selectedTask!.isPinned ? colorScheme.primary : colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  void _showManageTagsDialog() {
    showDialog(
      context: context,
      builder:
          (context) => _TagsManagerDialog(
            databaseService: _databaseService,
            onTagsChanged: () {
              setState(() {
                // Refresh tags
                _loadTasks();
              });
            },
          ),
    );
  }

  void _setTagFilter(String? tag) {
    setState(() {
      _selectedTag = tag;
    });
    _filterTasksByTag(tag); // Aplicar filtro solo a la tab actual
  }

  void _openSettings() {
    showDialog(
      context: context,
      builder:
          (context) => SettingsScreen(onThemeUpdated: widget.onThemeUpdated),
    );
  }

  void _showPrioritySelectorDialog(Subtask subtask) {
    showDialog(
      context: context,
      builder:
          (context) => _PrioritySelectorDialog(
            selectedPriority: subtask.priority,
            onPrioritySelected: (priority) {
              _updateSubtaskPriority(subtask, priority);
              Navigator.pop(context);
            },
          ),
    );
  }
}

// Widget auxiliar para gestionar el estado de hover
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

class _TagsManagerDialog extends StatefulWidget {
  final DatabaseService databaseService;
  final VoidCallback onTagsChanged;

  const _TagsManagerDialog({
    required this.databaseService,
    required this.onTagsChanged,
  });

  @override
  State<_TagsManagerDialog> createState() => _TagsManagerDialogState();
}

class _TagsManagerDialogState extends State<_TagsManagerDialog> {
  final TextEditingController _newTagController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  List<String> _tags = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTags();
  }

  @override
  void dispose() {
    _newTagController.dispose();
    super.dispose();
  }

  Future<void> _loadTags() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final tags = await widget.databaseService.taskService.getAllTags();
      setState(() {
        _tags = tags;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        CustomSnackbar.show(
          context: context,
          message: 'Error loading tags: $e',
          type: CustomSnackbarType.error,
        );
      }
    }
  }

  Future<void> _addNewTag() async {
    if (_formKey.currentState!.validate()) {
      final newTag = _newTagController.text.trim();

      if (_tags.contains(newTag)) {
        if (mounted) {
          CustomSnackbar.show(
            context: context,
            message: 'This tag already exists',
            type: CustomSnackbarType.error,
          );
        }
        return;
      }

      try {
        await widget.databaseService.taskService.addTag(newTag);
        _newTagController.clear();
        await _loadTags();
        widget.onTagsChanged();
      } catch (e) {
        if (mounted) {
          CustomSnackbar.show(
            context: context,
            message: 'Error adding tag: $e',
            type: CustomSnackbarType.error,
          );
        }
      }
    }
  }

  Future<void> _deleteTag(String tag) async {
    final colorScheme = Theme.of(context).colorScheme;
    final confirmed = await showDeleteConfirmationDialog(
      context: context,
      title: 'Delete Tag',
      message:
          'Are you sure you want to delete the tag "$tag"? This action cannot be undone.',
      confirmText: 'Delete',
      confirmColor: colorScheme.error,
    );

    if (confirmed == true) {
      try {
        await widget.databaseService.taskService.deleteTag(tag);
        await _loadTags();
        widget.onTagsChanged();
      } catch (e) {
        if (mounted) {
          CustomSnackbar.show(
            context: context,
            message: 'Error deleting tag: $e',
            type: CustomSnackbarType.error,
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Dialog(
      backgroundColor: Colors.transparent,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 500,
          height: 400,
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Container(
                height: 56,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Icon(Icons.label_rounded, color: colorScheme.primary),
                    const SizedBox(width: 12),
                    Text(
                      'Tags',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const Spacer(),
                    IconButton(
                      icon: Icon(
                        Icons.close_rounded,
                        color: colorScheme.onSurface,
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _newTagController,
                          decoration: InputDecoration(
                            labelText: 'New tag',
                            hintText: 'Enter tag name',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            filled: true,
                            fillColor: colorScheme.surfaceContainerHighest
                                .withAlpha(127),
                            prefixIcon: Icon(
                              Icons.title_rounded,
                              color: colorScheme.primary,
                            ),
                          ),
                          validator:
                              (value) =>
                                  value?.isEmpty ?? true ? 'Required' : null,
                          onFieldSubmitted: (_) => _addNewTag(),
                        ),
                      ),
                      const SizedBox(width: 16),
                      IconButton(
                        onPressed: _addNewTag,
                        icon: const Icon(Icons.add_rounded),
                        style: IconButton.styleFrom(
                          backgroundColor: colorScheme.primary,
                          foregroundColor: colorScheme.onPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child:
                    _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : _tags.isEmpty
                        ? Center(
                          child: Text(
                            'No tags available',
                            style: TextStyle(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        )
                        : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _tags.length,
                          itemBuilder: (context, index) {
                            final tag = _tags[index];
                            return Card(
                              elevation: 0,
                              margin: const EdgeInsets.only(bottom: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                                side: BorderSide(
                                  color: colorScheme.outlineVariant.withAlpha(
                                    127,
                                  ),
                                  width: 0.5,
                                ),
                              ),
                              child: ListTile(
                                leading: Icon(
                                  Icons.label_rounded,
                                  color: colorScheme.primary,
                                  size: 20,
                                ),
                                title: Text(tag),
                                trailing: IconButton(
                                  icon: Icon(
                                    Icons.delete_forever_rounded,
                                    color: colorScheme.error,
                                    size: 20,
                                  ),
                                  onPressed: () => _deleteTag(tag),
                                ),
                              ),
                            );
                          },
                        ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TagSelectorDialog extends StatefulWidget {
  final DatabaseService databaseService;
  final Task selectedTask;
  final VoidCallback onTagsChanged;

  const _TagSelectorDialog({
    required this.databaseService,
    required this.selectedTask,
    required this.onTagsChanged,
  });

  @override
  State<_TagSelectorDialog> createState() => _TagSelectorDialogState();
}

class _TagSelectorDialogState extends State<_TagSelectorDialog> {
  final TextEditingController _newTagController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  List<String> _allTags = [];
  List<String> _selectedTags = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTags();
  }

  @override
  void dispose() {
    _newTagController.dispose();
    super.dispose();
  }

  Future<void> _loadTags() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final allTags = await widget.databaseService.taskService.getAllTags();
      final taskTags = await widget.databaseService.taskService.getTagsByTaskId(
        widget.selectedTask.id!,
      );

      setState(() {
        _allTags = allTags;
        _selectedTags = taskTags;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        CustomSnackbar.show(
          context: context,
          message: 'Error loading tags: $e',
          type: CustomSnackbarType.error,
        );
      }
    }
  }

  Future<void> _addNewTag() async {
    if (_formKey.currentState!.validate()) {
      final newTag = _newTagController.text.trim();

      if (_allTags.contains(newTag)) {
        if (mounted) {
          CustomSnackbar.show(
            context: context,
            message: 'This tag already exists',
            type: CustomSnackbarType.error,
          );
        }
        return;
      }

      try {
        await widget.databaseService.taskService.addTag(newTag);
        _newTagController.clear();
        await _loadTags();
        widget.onTagsChanged();
      } catch (e) {
        if (mounted) {
          CustomSnackbar.show(
            context: context,
            message: 'Error adding tag: $e',
            type: CustomSnackbarType.error,
          );
        }
      }
    }
  }

  Future<void> _toggleTag(String tag) async {
    try {
      if (_selectedTags.contains(tag)) {
        await widget.databaseService.taskService.removeTagFromTask(
          tag,
          widget.selectedTask.id!,
        );
      } else {
        await widget.databaseService.taskService.assignTagToTask(
          tag,
          widget.selectedTask.id!,
        );
      }
      await _loadTags();
      widget.onTagsChanged();
    } catch (e) {
      if (mounted) {
        CustomSnackbar.show(
          context: context,
          message: 'Error updating tag: $e',
          type: CustomSnackbarType.error,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Dialog(
      backgroundColor: Colors.transparent,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 500,
          height: 400,
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Container(
                height: 56,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Icon(Icons.label_rounded, color: colorScheme.primary),
                    const SizedBox(width: 12),
                    Text(
                      'Select Tags',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const Spacer(),
                    IconButton(
                      icon: Icon(
                        Icons.close_rounded,
                        color: colorScheme.onSurface,
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _newTagController,
                          decoration: InputDecoration(
                            labelText: 'New tag',
                            hintText: 'Enter tag name',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            filled: true,
                            fillColor: colorScheme.surfaceContainerHighest
                                .withAlpha(127),
                            prefixIcon: Icon(
                              Icons.title_rounded,
                              color: colorScheme.primary,
                            ),
                          ),
                          validator:
                              (value) =>
                                  value?.isEmpty ?? true ? 'Required' : null,
                          onFieldSubmitted: (_) => _addNewTag(),
                        ),
                      ),
                      const SizedBox(width: 16),
                      IconButton(
                        onPressed: _addNewTag,
                        icon: const Icon(Icons.add_rounded),
                        style: IconButton.styleFrom(
                          backgroundColor: colorScheme.primary,
                          foregroundColor: colorScheme.onPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child:
                    _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : _allTags.isEmpty
                        ? Center(
                          child: Text(
                            'No tags available',
                            style: TextStyle(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        )
                        : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _allTags.length,
                          itemBuilder: (context, index) {
                            final tag = _allTags[index];
                            final isSelected = _selectedTags.contains(tag);
                            return Card(
                              elevation: 0,
                              margin: const EdgeInsets.only(bottom: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                                side: BorderSide(
                                  color: colorScheme.outlineVariant.withAlpha(
                                    127,
                                  ),
                                  width: 0.5,
                                ),
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () => _toggleTag(tag),
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    height: 48,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          isSelected
                                              ? Icons.check_circle_rounded
                                              : Icons.circle_outlined,
                                          color:
                                              isSelected
                                                  ? colorScheme.primary
                                                  : colorScheme
                                                      .onSurfaceVariant,
                                          size: 20,
                                        ),
                                        const SizedBox(width: 16),
                                        Text(
                                          tag,
                                          style:
                                              Theme.of(
                                                context,
                                              ).textTheme.bodyLarge,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusSelectorDialog extends StatelessWidget {
  final TaskState selectedState;
  final Function(TaskState) onStateSelected;

  const _StatusSelectorDialog({
    required this.selectedState,
    required this.onStateSelected,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Dialog(
      backgroundColor: Colors.transparent,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 300,
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 56,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Icon(
                      Icons.pending_actions_rounded,
                      color: colorScheme.primary,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Select Status',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const Spacer(),
                    IconButton(
                      icon: Icon(
                        Icons.close_rounded,
                        color: colorScheme.onSurface,
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildStatusOption(
                      context,
                      TaskState.pending,
                      Icons.circle_outlined,
                      colorScheme.onSurfaceVariant,
                      'Pending',
                    ),
                    const SizedBox(height: 8),
                    _buildStatusOption(
                      context,
                      TaskState.inProgress,
                      Icons.pending_rounded,
                      const Color(0xFFB75D0A),
                      'In progress',
                    ),
                    const SizedBox(height: 8),
                    _buildStatusOption(
                      context,
                      TaskState.completed,
                      Icons.check_circle_rounded,
                      colorScheme.primary,
                      'Completed',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusOption(
    BuildContext context,
    TaskState state,
    IconData icon,
    Color color,
    String text,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final isSelected = state == selectedState;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onStateSelected(state),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 16),
              Text(
                text,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color:
                      isSelected ? colorScheme.primary : colorScheme.onSurface,
                ),
              ),
              const Spacer(),
              if (isSelected)
                Icon(Icons.check_rounded, color: colorScheme.primary, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _PrioritySelectorDialog extends StatelessWidget {
  final SubtaskPriority selectedPriority;
  final Function(SubtaskPriority) onPrioritySelected;

  const _PrioritySelectorDialog({
    required this.selectedPriority,
    required this.onPrioritySelected,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Dialog(
      backgroundColor: Colors.transparent,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 300,
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 56,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Icon(
                      Icons.priority_high_rounded,
                      color: colorScheme.primary,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Select Priority',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const Spacer(),
                    IconButton(
                      icon: Icon(
                        Icons.close_rounded,
                        color: colorScheme.onSurface,
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildPriorityOption(
                      context,
                      SubtaskPriority.high,
                      Icons.arrow_upward_rounded,
                      colorScheme.error,
                      'High',
                    ),
                    const SizedBox(height: 8),
                    _buildPriorityOption(
                      context,
                      SubtaskPriority.medium,
                      Icons.remove_rounded,
                      colorScheme.primary,
                      'Medium',
                    ),
                    const SizedBox(height: 8),
                    _buildPriorityOption(
                      context,
                      SubtaskPriority.low,
                      Icons.arrow_downward_rounded,
                      colorScheme.tertiary,
                      'Low',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPriorityOption(
    BuildContext context,
    SubtaskPriority priority,
    IconData icon,
    Color color,
    String text,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final isSelected = priority == selectedPriority;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onPrioritySelected(priority),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 16),
              Text(
                text,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color:
                      isSelected ? colorScheme.primary : colorScheme.onSurface,
                ),
              ),
              const Spacer(),
              if (isSelected)
                Icon(Icons.check_rounded, color: colorScheme.primary, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
