class TaskTag {
  final int? id;
  final String name;
  final int? taskId;

  TaskTag({this.id, required this.name, this.taskId});

  Map<String, dynamic> toMap() {
    return {'id': id, 'name': name, 'task_id': taskId};
  }

  factory TaskTag.fromMap(Map<String, dynamic> map) {
    return TaskTag(
      id: map['id'] as int?,
      name: map['name'] as String,
      taskId: map['task_id'] as int?,
    );
  }

  TaskTag copyWith({int? id, String? name, int? taskId}) {
    return TaskTag(
      id: id ?? this.id,
      name: name ?? this.name,
      taskId: taskId ?? this.taskId,
    );
  }
}
