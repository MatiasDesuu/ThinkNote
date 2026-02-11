enum SubtaskPriority { low, medium, high }

class Subtask {
  final int? id;
  final int taskId;
  final String text;
  final bool completed;
  final int orderIndex;
  final SubtaskPriority priority;
  final int? parentId;

  Subtask({
    this.id,
    required this.taskId,
    required this.text,
    this.completed = false,
    this.orderIndex = 0,
    this.priority = SubtaskPriority.medium,
    this.parentId,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'task_id': taskId,
      'text': text,
      'completed': completed ? 1 : 0,
      'order_index': orderIndex,
      'priority': priority.index,
      'parent_id': parentId,
    };
  }

  factory Subtask.fromMap(Map<String, dynamic> map) {
    return Subtask(
      id: map['id'] as int?,
      taskId: map['task_id'] as int,
      text: map['text'] as String,
      completed: map['completed'] == 1,
      orderIndex: map['order_index'] as int? ?? 0,
      priority: SubtaskPriority.values[map['priority'] as int? ?? 1],
      parentId: map['parent_id'] as int?,
    );
  }

  Subtask copyWith({
    int? id,
    int? taskId,
    String? text,
    bool? completed,
    int? orderIndex,
    SubtaskPriority? priority,
    int? parentId,
  }) {
    return Subtask(
      id: id ?? this.id,
      taskId: taskId ?? this.taskId,
      text: text ?? this.text,
      completed: completed ?? this.completed,
      orderIndex: orderIndex ?? this.orderIndex,
      priority: priority ?? this.priority,
      parentId: parentId ?? this.parentId,
    );
  }
}
