class DiaryEntry {
  final int? id;
  final String content;
  final DateTime date;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final bool isFavorite;
  final String? tags;

  DiaryEntry({
    this.id,
    required this.content,
    required this.date,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    this.isFavorite = false,
    this.tags,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'content': content,
      'date': date.millisecondsSinceEpoch,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
      'deleted_at': deletedAt?.millisecondsSinceEpoch,
      'is_favorite': isFavorite ? 1 : 0,
      'tags': tags,
    };
  }

  factory DiaryEntry.fromMap(Map<String, dynamic> map) {
    return DiaryEntry(
      id: map['id'] as int?,
      content: map['content'] as String,
      date: DateTime.fromMillisecondsSinceEpoch(map['date'] as int),
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at'] as int),
      deletedAt:
          map['deleted_at'] != null
              ? DateTime.fromMillisecondsSinceEpoch(map['deleted_at'] as int)
              : null,
      isFavorite: map['is_favorite'] == 1,
      tags: map['tags'] as String?,
    );
  }

  DiaryEntry copyWith({
    int? id,
    String? content,
    DateTime? date,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? deletedAt,
    bool? isFavorite,
    String? tags,
  }) {
    return DiaryEntry(
      id: id ?? this.id,
      content: content ?? this.content,
      date: date ?? this.date,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      isFavorite: isFavorite ?? this.isFavorite,
      tags: tags ?? this.tags,
    );
  }
}
