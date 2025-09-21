enum TaskState { pending, inProgress, completed }

class Task {
  final int? id;
  final String name;
  final DateTime? date;
  final bool completed;
  final TaskState state;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final int orderIndex;
  final bool sortByPriority;
  final bool isPinned;
  final List<int> tagIds;

  Task({
    this.id,
    required this.name,
    this.date,
    this.completed = false,
    this.state = TaskState.pending,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    this.orderIndex = 0,
    this.sortByPriority = false,
    this.isPinned = false,
    List<int>? tagIds,
  }) : tagIds = tagIds ?? [];

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'date': date?.toIso8601String(),
      'completed': completed ? 1 : 0,
      'state': state.index,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'deleted_at': deletedAt?.toIso8601String(),
      'order_index': orderIndex,
      'sort_by_priority': sortByPriority ? 1 : 0,
      'is_pinned': isPinned ? 1 : 0,
    };
  }

  factory Task.fromMap(Map<String, dynamic> map) {
    return Task(
      id: map['id'] as int?,
      name: map['name'] as String,
      date: map['date'] != null ? DateTime.parse(map['date'] as String) : null,
      completed: map['completed'] == 1,
      state: TaskState.values[map['state'] as int],
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      deletedAt:
          map['deleted_at'] != null
              ? DateTime.parse(map['deleted_at'] as String)
              : null,
      orderIndex: map['order_index'] as int? ?? 0,
      sortByPriority: map['sort_by_priority'] == 1,
      isPinned: map['is_pinned'] == 1,
    );
  }

  Task copyWith({
    int? id,
    String? name,
    DateTime? date,
    bool? completed,
    TaskState? state,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? deletedAt,
    int? orderIndex,
    bool? sortByPriority,
    bool? isPinned,
    List<int>? tagIds,
  }) {
    return Task(
      id: id ?? this.id,
      name: name ?? this.name,
      date:
          date ??
          this.date, // Volver a usar ?? para mantener valor original si no se pasa
      completed: completed ?? this.completed,
      state: state ?? this.state,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt:
          deletedAt ??
          this.deletedAt, // Volver a usar ?? para mantener valor original si no se pasa
      orderIndex: orderIndex ?? this.orderIndex,
      sortByPriority: sortByPriority ?? this.sortByPriority,
      isPinned: isPinned ?? this.isPinned,
      tagIds: tagIds ?? List.from(this.tagIds),
    );
  }
}
