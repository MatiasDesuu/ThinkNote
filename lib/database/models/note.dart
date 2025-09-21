class Note {
  final int? id;
  final String title;
  final String content;
  final int notebookId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final bool isFavorite;
  final String? tags;
  final int orderIndex;
  final bool isTask;
  final bool isCompleted;

  Note({
    this.id,
    required this.title,
    required this.content,
    required this.notebookId,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    this.isFavorite = false,
    this.tags,
    this.orderIndex = 0,
    this.isTask = false,
    this.isCompleted = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'notebook_id': notebookId,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
      'deleted_at': deletedAt?.millisecondsSinceEpoch,
      'is_favorite': isFavorite ? 1 : 0,
      'tags': tags,
      'order_index': orderIndex,
      'is_task': isTask ? 1 : 0,
      'is_completed': isCompleted ? 1 : 0,
    };
  }

  factory Note.fromMap(Map<String, dynamic> map) {
    return Note(
      id: map['id'] as int?,
      title: map['title'] as String,
      content: map['content'] as String,
      notebookId: map['notebook_id'] as int,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at'] as int),
      deletedAt:
          map['deleted_at'] != null
              ? DateTime.fromMillisecondsSinceEpoch(map['deleted_at'] as int)
              : null,
      isFavorite: map['is_favorite'] == 1,
      tags: map['tags'] as String?,
      orderIndex: map['order_index'] as int? ?? 0,
      isTask: map['is_task'] == 1,
      isCompleted: map['is_completed'] == 1,
    );
  }

  Note copyWith({
    int? id,
    String? title,
    String? content,
    int? notebookId,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? deletedAt,
    bool? isFavorite,
    String? tags,
    int? orderIndex,
    bool? isTask,
    bool? isCompleted,
  }) {
    return Note(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      notebookId: notebookId ?? this.notebookId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      isFavorite: isFavorite ?? this.isFavorite,
      tags: tags ?? this.tags,
      orderIndex: orderIndex ?? this.orderIndex,
      isTask: isTask ?? this.isTask,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }
}
