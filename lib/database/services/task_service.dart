import '../models/task.dart';
import '../models/subtask.dart';
import '../models/task_tag.dart';
import '../repositories/task_repository.dart';

class TaskService {
  final TaskRepository _taskRepository;

  TaskService(this._taskRepository);

  // Task methods
  Future<Task?> createTask(String name) async {
    final now = DateTime.now();
    final task = Task(name: name, createdAt: now, updatedAt: now);

    final id = await _taskRepository.createTask(task);
    return getTask(id);
  }

  Future<Task?> getTask(int id) async {
    final task = await _taskRepository.getTask(id);
    if (task == null) return null;

    // Get the tags for this task
    final tags = await _taskRepository.getTagsByTaskId(id);
    final tagIds = tags.map((tag) => tag.id).whereType<int>().toList();

    return task.copyWith(tagIds: tagIds);
  }

  Future<List<Task>> getAllTasks() async {
    return await _taskRepository.getAllTasks();
  }

  Future<List<Task>> getPendingTasks() async {
    return await _taskRepository.getPendingTasks();
  }

  Future<List<Task>> getCompletedTasks() async {
    return await _taskRepository.getCompletedTasks();
  }

  Future<List<Task>> getTasksWithDeadlines() async {
    return await _taskRepository.getTasksWithDeadlines();
  }

  Future<List<Task>> getUnassignedTasks() async {
    return await _taskRepository.getUnassignedTasks();
  }

  Future<void> updateTask(Task task) async {
    // Crear una nueva tarea con todos los campos explícitamente
    final updatedTask = Task(
      id: task.id,
      name: task.name,
      date: task.date, // Mantener la fecha explícitamente
      completed: task.completed,
      state: task.state,
      createdAt: task.createdAt,
      updatedAt: DateTime.now(),
      deletedAt: task.deletedAt,
      orderIndex: task.orderIndex,
      sortByPriority: task.sortByPriority,
      isPinned: task.isPinned,
      tagIds: task.tagIds,
    );

    await _taskRepository.updateTask(updatedTask);
  }

  Future<void> updateTaskDate(int taskId, DateTime? date) async {
    final task = await _taskRepository.getTask(taskId);
    if (task == null) {
      return;
    }

    // Crear una nueva tarea con la fecha específica (puede ser null)
    final updatedTask = Task(
      id: task.id,
      name: task.name,
      date: date, // Puede ser null para borrar la fecha
      completed: task.completed,
      state: task.state,
      createdAt: task.createdAt,
      updatedAt: DateTime.now(),
      deletedAt: task.deletedAt,
      orderIndex: task.orderIndex,
      sortByPriority: task.sortByPriority,
      isPinned: task.isPinned,
      tagIds: task.tagIds,
    );

    await _taskRepository.updateTask(updatedTask);
  }

  Future<void> deleteTask(int id) async {
    await _taskRepository.deleteTask(id);
  }

  Future<void> updateTaskState(int id, TaskState state) async {
    final task = await _taskRepository.getTask(id);
    if (task == null) return;

    final updatedTask = task.copyWith(
      state: state,
      completed: state == TaskState.completed,
      updatedAt: DateTime.now(),
    );

    await _taskRepository.updateTask(updatedTask);
  }

  Future<void> updateTaskPinnedState(int id, bool isPinned) async {
    await _taskRepository.updateTaskPinnedState(id, isPinned);
  }

  Future<void> reorderTasks(List<Task> tasks) async {
    for (int i = 0; i < tasks.length; i++) {
      final task = tasks[i];
      if (task.orderIndex != i) {
        await _taskRepository.updateTaskOrder(task.id!, i);
      }
    }
  }

  // Subtask methods
  Future<Subtask?> createSubtask(int taskId, String text) async {
    final subtask = Subtask(taskId: taskId, text: text);

    final id = await _taskRepository.createSubtask(subtask);
    final subtasks = await _taskRepository.getSubtasksByTaskId(taskId);
    return subtasks.firstWhere((s) => s.id == id);
  }

  Future<List<Subtask>> getSubtasksByTaskId(int taskId) async {
    return await _taskRepository.getSubtasksByTaskId(taskId);
  }

  Future<List<Subtask>> getSubtasksByTaskIdWithPrioritySort(int taskId) async {
    return await _taskRepository.getSubtasksByTaskIdWithPrioritySort(taskId);
  }

  Future<void> updateSubtask(Subtask subtask) async {
    await _taskRepository.updateSubtask(subtask);
  }

  Future<void> deleteSubtask(int id) async {
    await _taskRepository.deleteSubtask(id);
  }

  Future<void> toggleSubtaskCompleted(Subtask subtask, bool completed) async {
    final updatedSubtask = subtask.copyWith(completed: completed);
    await _taskRepository.updateSubtask(updatedSubtask);
  }

  Future<void> reorderSubtasks(List<Subtask> subtasks) async {
    for (int i = 0; i < subtasks.length; i++) {
      final subtask = subtasks[i];
      if (subtask.orderIndex != i) {
        await _taskRepository.updateSubtaskOrder(subtask.id!, i);
      }
    }
  }

  Future<void> updateSubtaskPriority(
    Subtask subtask,
    SubtaskPriority priority,
  ) async {
    final updatedSubtask = subtask.copyWith(priority: priority);

    await _taskRepository.updateSubtask(updatedSubtask);
  }

  // Habit completion helpers
  Future<void> setHabitCompletion(
    int subtaskId,
    String isoDate,
    bool completed,
  ) async {
    await _taskRepository.setHabitCompletion(subtaskId, isoDate, completed);
  }

  Future<List<String>> getHabitCompletionsForSubtask(int subtaskId) async {
    return await _taskRepository.getHabitCompletionsForSubtask(subtaskId);
  }

  Future<Map<int, List<String>>> getHabitCompletionsForTask(int taskId) async {
    return await _taskRepository.getHabitCompletionsForTask(taskId);
  }

  // Tag methods
  Future<List<String>> getAllTags() async {
    final tags = await _taskRepository.getAllTags();
    return tags.map((tag) => tag.name).toList();
  }

  Future<List<String>> getTagsByTaskId(int taskId) async {
    final tags = await _taskRepository.getTagsByTaskId(taskId);
    return tags.map((tag) => tag.name).toList();
  }

  Future<void> addTag(String tagName) async {
    final tag = TaskTag(name: tagName);
    await _taskRepository.createTag(tag);
  }

  Future<void> assignTagToTask(String tagName, int taskId) async {
    await _taskRepository.assignTagToTask(tagName, taskId);
  }

  Future<void> removeTagFromTask(String tagName, int taskId) async {
    await _taskRepository.removeTagFromTask(tagName, taskId);
  }

  Future<void> deleteTag(String tagName) async {
    final tags = await _taskRepository.getAllTags();
    final tag = tags.firstWhere((t) => t.name == tagName);
    await _taskRepository.deleteTag(tag.id!);
  }

  Future<List<Task>> getTasksByTag(String tagName) async {
    return await _taskRepository.getTasksByTag(tagName);
  }
}
