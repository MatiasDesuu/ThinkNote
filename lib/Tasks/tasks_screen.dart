import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'package:intl/intl.dart';
import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../animations/animations_handler.dart';
import 'dart:async';
import '../database/database_service.dart';
import '../database/models/task.dart';
import '../database/models/subtask.dart';
import '../widgets/custom_snackbar.dart';
import '../widgets/context_menu.dart';
import '../widgets/confirmation_dialogue.dart';
import '../widgets/resizable_icon_sidebar.dart';
import '../Settings/settings_screen.dart';
import 'package:flutter/gestures.dart';
import 'tasks_screen_details.dart';

class _ToggleSidebarIntent extends Intent {
  const _ToggleSidebarIntent();
}

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
  List<Task> _allCompletedTasks =
      []; // Todas las tareas completadas sin filtrar
  Task? _selectedTask;
  List<Subtask> _subtasks = [];
  String? _selectedTag;
  List<String> _filteredTagsForCurrentTab = [];
  List<String> _selectedTaskTags = [];
  final Set<String> _expandedSubtasks = <String>{};
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
  bool _isSidebarVisible = true;
  late AnimationController _sidebarAnimController;
  late Animation<double> _sidebarWidthAnimation;
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

    // Inicializar animación del sidebar
    _sidebarAnimController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
      value: 1.0, // Empieza visible
    );
    _sidebarWidthAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _sidebarAnimController, curve: Curves.easeInOut),
    );

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
    _sidebarAnimController.dispose();
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
        final taskTags = await _databaseService.taskService.getTagsByTaskId(
          task.id!,
        );
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
      final tasksToFilter =
          currentTabIndex == 0 ? _allPendingTasks : _allCompletedTasks;

      final tasksWithTag = await _databaseService.taskService.getTasksByTag(
        tag,
      );

      final filteredTasks =
          tasksToFilter
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
          _completedTasks =
              allCompletedTasks; // Inicialmente mostrar todas las tareas
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
          _completedTasks =
              allCompletedTasks; // Inicialmente mostrar todas las tareas
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

  Future<void> _onDateChanged(DateTime? fecha) async {
    if (_selectedTask == null) return;

    // Marcar que estamos actualizando manualmente
    _isUpdatingManually = true;

    if (fecha != null) {
      final updatedTask = _selectedTask!.copyWith(date: fecha);
      await _databaseService.taskService.updateTask(updatedTask);

      setState(() {
        _selectedDate = fecha;
        _selectedTask = updatedTask;
      });
    } else {
      await _databaseService.taskService.updateTaskDate(
        _selectedTask!.id!,
        null,
      );

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
          sortByPriority: _selectedTask!.sortByPriority,
          isPinned: _selectedTask!.isPinned,
          tagIds: _selectedTask!.tagIds,
        );
      });
    }

    // Recargar la lista de tareas para actualizar la UI
    await _updateTaskListsOnly();

    // Desmarcar la actualización manual
    _isUpdatingManually = false;
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

  void _toggleSidebar() {
    if (_isSidebarVisible) {
      _sidebarAnimController.reverse().then((_) {
        setState(() {
          _isSidebarVisible = false;
        });
      });
    } else {
      setState(() {
        _isSidebarVisible = true;
      });
      _sidebarAnimController.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Shortcuts(
      shortcuts: <LogicalKeySet, Intent>{
        LogicalKeySet(LogicalKeyboardKey.f2): const _ToggleSidebarIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          _ToggleSidebarIntent: CallbackAction<_ToggleSidebarIntent>(
            onInvoke: (intent) {
              _toggleSidebar();
              return null;
            },
          ),
        },
        child: Focus(
          focusNode: _appFocusNode,
          autofocus: true,
          child: Scaffold(
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
                      onToggleSidebar: _toggleSidebar,
                      appFocusNode: _appFocusNode,
                    ),

                    // Animated sidebar
                    AnimatedBuilder(
                      animation: _sidebarWidthAnimation,
                      builder: (context, child) {
                        final animatedWidth =
                            _sidebarWidthAnimation.value * (_sidebarWidth + 1);
                        if (animatedWidth == 0 && !_isSidebarVisible) {
                          return const SizedBox.shrink();
                        }
                        return ClipRect(
                          child: SizedBox(
                            width: animatedWidth,
                            child: OverflowBox(
                              alignment: Alignment.centerLeft,
                              minWidth: 0,
                              maxWidth: _sidebarWidth + 1,
                              child: child,
                            ),
                          ),
                        );
                      },
                      child: Row(
                        children: [
                          VerticalDivider(
                            width: 1,
                            thickness: 1,
                            color:
                                Theme.of(
                                  context,
                                ).colorScheme.surfaceContainerHighest,
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
                                    const SizedBox(height: 8),
                                    // Tabs for Pending and Completed tasks
                                    Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: colorScheme.surfaceContainerLow,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: SizedBox(
                                        height: 36,
                                        child: TabBar(
                                          controller: _tasksTabController,
                                          onTap: (index) {
                                            // Al cambiar de tab, resetear el filtro de tag y mostrar todas las tareas
                                            setState(() {
                                              _selectedTag = null;
                                              _tasks = List.from(_allPendingTasks);
                                              _completedTasks = List.from(
                                                _allCompletedTasks,
                                              );
                                            });
                                            // Actualizar tags para la nueva tab después de un pequeño delay
                                            Future.delayed(
                                              const Duration(milliseconds: 50),
                                              () {
                                                _updateFilteredTagsForCurrentTab();
                                              },
                                            );
                                          },
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
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
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
                                                    '(${_tasks.length})',
                                                    style: TextStyle(
                                                      fontWeight: FontWeight.w600,
                                                      color:
                                                          _tasksTabController
                                                                      .index ==
                                                                  0
                                                              ? colorScheme.primary
                                                              : colorScheme
                                                                  .onSurfaceVariant,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Tab(
                                              child: Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
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
                                      ),
                                    ),
                                    // Tag filters (filtered by current tab)
                                    if (_filteredTagsForCurrentTab.isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      SizedBox(
                                        height: 36,
                                        child: Listener(
                                          onPointerSignal: (pointerSignal) {
                                            if (pointerSignal
                                                is PointerScrollEvent) {
                                              _tagsScrollController.position
                                                  .moveTo(
                                                    _tagsScrollController
                                                            .position
                                                            .pixels +
                                                        pointerSignal
                                                            .scrollDelta
                                                            .dy,
                                                    curve: Curves.linear,
                                                    duration: const Duration(
                                                      milliseconds: 20,
                                                    ),
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
                                              _buildTagChip(
                                                label: 'All',
                                                isSelected: _selectedTag == null,
                                                onTap: () => _setTagFilter(null),
                                                colorScheme: colorScheme,
                                              ),
                                              ..._filteredTagsForCurrentTab.map(
                                                (tag) => Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                        left: 6,
                                                      ),
                                                  child: _buildTagChip(
                                                    label: tag,
                                                    isSelected:
                                                        _selectedTag == tag,
                                                    onTap: () =>
                                                        _setTagFilter(
                                                          _selectedTag == tag
                                                              ? null
                                                              : tag,
                                                        ),
                                                    colorScheme: colorScheme,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                    const SizedBox(height: 8),
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
                                                      Icons
                                                          .check_circle_outline_rounded,
                                                      size: 48,
                                                      color: colorScheme
                                                          .onSurfaceVariant
                                                          .withAlpha(100),
                                                    ),
                                                    const SizedBox(height: 16),
                                                    Text(
                                                      'No pending tasks',
                                                      style: TextStyle(
                                                        color: colorScheme
                                                            .onSurfaceVariant
                                                            .withAlpha(150),
                                                      ),
                                                    ),
                                                    const SizedBox(height: 8),
                                                    TextButton.icon(
                                                      onPressed: _createNewTask,
                                                      icon: Icon(
                                                        Icons.add_rounded,
                                                        size: 18,
                                                        color:
                                                            colorScheme.primary,
                                                      ),
                                                      label: Text(
                                                        'Create task',
                                                        style: TextStyle(
                                                          color:
                                                              colorScheme
                                                                  .primary,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              )
                                              : ReorderableListView.builder(
                                                padding: const EdgeInsets.only(
                                                  bottom: 8,
                                                ),
                                                itemCount: _tasks.length,
                                                buildDefaultDragHandles: false,
                                                onReorder: _reorderTasks,
                                                itemBuilder: (context, index) {
                                                  return _buildTaskItem(
                                                    _tasks[index],
                                                  );
                                                },
                                              ),
                                          // Completed tasks tab
                                          _completedTasks.isEmpty
                                              ? Center(
                                                child: Text(
                                                  'No completed tasks',
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
                                                itemCount:
                                                    _completedTasks.length,
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
                                      onPanStart:
                                          (_) => setState(
                                            () => _isDragging = true,
                                          ),
                                      onPanEnd: (details) {
                                        setState(() => _isDragging = false);
                                        _onDragEnd(details);
                                      },
                                      child: Container(
                                        width: 6,
                                        decoration: BoxDecoration(
                                          color:
                                              _isDragging
                                                  ? colorScheme.primary
                                                      .withAlpha(50)
                                                  : Colors.transparent,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Right content panel (editor)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(
                          left: 16.0,
                          right: 16.0,
                          top: 44.0,
                        ),
                        child: TaskDetailsPanel(
                          selectedTask: _selectedTask,
                          subtasks: _subtasks,
                          selectedTaskTags: _selectedTaskTags,
                          selectedDate: _selectedDate,
                          nameController: _nameController,
                          newSubtaskController: _newSubtaskController,
                          editingController: _editingController,
                          editingFocusNode: _editingFocusNode,
                          editingSubtaskId: _editingSubtaskId,
                          expandedSubtasks: _expandedSubtasks,
                          subtasksTabController: _subtasksTabController,
                          databaseService: _databaseService,
                          onAddSubtask: _addSubtask,
                          onToggleSubtask: _toggleSubtask,
                          onDeleteSubtask: _deleteSubtask,
                          onEditSubtask: _editSubtask,
                          onSaveSubtaskEditing: _saveSubtaskEditing,
                          onCancelSubtaskEditing: _cancelSubtaskEditing,
                          onReorderSubtasks: _reorderSubtasks,
                          onUpdateSubtaskPriority: _updateSubtaskPriority,
                          onToggleSortByPriority: _toggleSortByPriority,
                          onToggleSubtaskExpansion: _toggleSubtaskExpansion,
                          onDateChanged: _onDateChanged,
                          onStateChanged:
                              (state) =>
                                  _updateTaskState(_selectedTask!, state),
                          onTogglePinned:
                              () => _toggleTaskPinned(_selectedTask!),
                          onTagsChanged: () => _loadTasks(),
                          onShowManageTags: _showManageTagsDialog,
                          getPendingSubtasks: _getPendingSubtasks,
                          getCompletedSubtasks: _getCompletedSubtasks,
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
                  left:
                      60 +
                      (_isSidebarVisible
                          ? _sidebarWidth
                          : 0), // Skip left sidebar + central task sidebar
                  right: 138, // Control buttons width
                  height: 40,
                  child: MoveWindow(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTagChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    required ColorScheme colorScheme,
  }) {
    return Material(
      color: isSelected ? colorScheme.primary.withAlpha(25) : colorScheme.surfaceContainerHighest,
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
                isSelected ? Icons.label_rounded : Icons.label_outline_rounded,
                size: 20,
                color: colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: isSelected ? colorScheme.primary : colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
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
          return Container(
            margin: const EdgeInsets.only(bottom: 4, left: 8, right: 8),
            decoration: BoxDecoration(
              color: isSelected
                  ? colorScheme.primary.withAlpha(25)
                  : isHovering
                      ? colorScheme.surfaceContainerHighest
                      : colorScheme.surface,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => _selectTask(task),
                onSecondaryTapDown: (details) {
                  _showTaskContextMenu(task, details.globalPosition);
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 10,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Checkbox minimalista
                      MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: GestureDetector(
                          onTap: () => _updateTaskState(
                            task,
                            task.state == TaskState.completed
                                ? TaskState.pending
                                : TaskState.completed,
                          ),
                          child: Icon(
                            task.state == TaskState.completed ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                            size: 20,
                            color: task.state == TaskState.completed ? colorScheme.primary : colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Contenido principal
                      Expanded(
                        child: FutureBuilder<List<String>>(
                          future: _databaseService.taskService.getTagsByTaskId(
                            task.id!,
                          ),
                          builder: (context, snapshot) {
                            final tags = snapshot.data ?? <String>[];
                            final hasMetadata = task.date != null || tags.isNotEmpty || task.isPinned;

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Task name
                                Text(
                                  task.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w500,
                                    color: task.state == TaskState.completed
                                        ? colorScheme.onSurfaceVariant.withAlpha(150)
                                        : colorScheme.onSurface,
                                    fontSize: 14,
                                    decoration: task.state == TaskState.completed
                                        ? TextDecoration.lineThrough
                                        : null,
                                    decorationColor: colorScheme.onSurfaceVariant.withAlpha(150),
                                  ),
                                ),
                                // Metadata row (date, tags, pin)
                                if (hasMetadata) ...[
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      // Pin indicator
                                      if (task.isPinned) ...[
                                        Icon(
                                          Icons.push_pin_rounded,
                                          size: 12,
                                          color: colorScheme.primary,
                                        ),
                                        const SizedBox(width: 6),
                                      ],
                                      // Date
                                      if (task.date != null) ...[
                                        Icon(
                                          Icons.schedule_rounded,
                                          size: 12,
                                          color: _isDateOverdue(task.date!)
                                              ? colorScheme.error
                                              : colorScheme.onSurfaceVariant.withAlpha(180),
                                        ),
                                        const SizedBox(width: 3),
                                        Text(
                                          _formatTaskDate(task.date!),
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: _isDateOverdue(task.date!)
                                                ? colorScheme.error
                                                : colorScheme.onSurfaceVariant.withAlpha(180),
                                          ),
                                        ),
                                        if (tags.isNotEmpty)
                                          const SizedBox(width: 8),
                                      ],
                                      // Tags (show first 2 max)
                                      ...tags.take(2).map(
                                        (tag) => Padding(
                                          padding: const EdgeInsets.only(right: 4),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 1,
                                            ),
                                            decoration: BoxDecoration(
                                              color: colorScheme.primary.withAlpha(20),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              tag,
                                              style: TextStyle(
                                                fontSize: 10,
                                                color: colorScheme.primary,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      if (tags.length > 2)
                                        Text(
                                          '+${tags.length - 2}',
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: colorScheme.onSurfaceVariant.withAlpha(150),
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
                      // Estado (solo si no es none y no completed)
                      if (task.state != TaskState.none && 
                          task.state != TaskState.completed)
                        FutureBuilder<List<String>>(
                          future: _databaseService.taskService.getTagsByTaskId(task.id!),
                          builder: (context, snapshot) {
                            final hasHabitsTag = snapshot.data?.contains('Habits') ?? false;
                            if (hasHabitsTag) return const SizedBox.shrink();
                            return Opacity(
                              opacity: (isHovering || isSelected) ? 1.0 : 0.0,
                              child: Padding(
                                padding: const EdgeInsets.only(left: 8),
                                child: _buildStateIndicator(task.state, colorScheme),
                              ),
                            );
                          },
                        ),
                      // Delete button (siempre presente, opacity controla visibilidad)
                      Opacity(
                        opacity: isHovering ? 1.0 : 0.0,
                        child: IgnorePointer(
                          ignoring: !isHovering,
                          child: Padding(
                            padding: const EdgeInsets.only(left: 4),
                            child: MouseRegion(
                              cursor: SystemMouseCursors.click,
                              child: GestureDetector(
                                onTap: () => _deleteTask(task),
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: colorScheme.error.withAlpha(20),
                                    borderRadius: BorderRadius.circular(6),
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

  Widget _buildStateIndicator(TaskState state, ColorScheme colorScheme) {
    final color = _getStateIndicatorColor(state, colorScheme);
    final icon = _getStateIndicatorIcon(state);
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: color.withAlpha(60),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            _getStateText(state),
            style: TextStyle(
              fontSize: 10,
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

  void _showManageTagsDialog() {
    showDialog(
      context: context,
      builder:
          (context) => TagsManagerDialog(
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

  void _toggleSubtaskExpansion(String id) {
    setState(() {
      if (_expandedSubtasks.contains(id)) {
        _expandedSubtasks.remove(id);
      } else {
        _expandedSubtasks.add(id);
      }
    });
  }
}
