class Think {
  final int? id;
  final String title;
  final String content;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isFavorite;
  final int orderIndex;
  final String tags;
  final DateTime? deletedAt;

  Think({
    this.id,
    required this.title,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
    this.isFavorite = false,
    this.orderIndex = 0,
    this.tags = '',
    this.deletedAt,
  });

  factory Think.fromMap(Map<String, dynamic> map) {
    return Think(
      id: map['id'] as int,
      title: map['title'] as String,
      content: map['content'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      isFavorite: (map['is_favorite'] as int) == 1,
      orderIndex: map['order_index'] as int? ?? 0,
      tags: map['tags'] as String? ?? '',
      deletedAt:
          map['deleted_at'] != null
              ? DateTime.fromMillisecondsSinceEpoch(map['deleted_at'] as int)
              : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'is_favorite': isFavorite ? 1 : 0,
      'order_index': orderIndex,
      'tags': tags,
      'deleted_at': deletedAt?.millisecondsSinceEpoch,
    };
  }

  Think copyWith({
    int? id,
    String? title,
    String? content,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isFavorite,
    int? orderIndex,
    String? tags,
    DateTime? deletedAt,
  }) {
    return Think(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isFavorite: isFavorite ?? this.isFavorite,
      orderIndex: orderIndex ?? this.orderIndex,
      tags: tags ?? this.tags,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }
}
