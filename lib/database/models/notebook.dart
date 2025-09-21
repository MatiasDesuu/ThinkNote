class Notebook {
  final int? id;
  final String name;
  final int? parentId;
  final DateTime createdAt;
  final int orderIndex;
  final DateTime? deletedAt;
  final bool isFavorite;
  final int? iconId;

  Notebook({
    this.id,
    required this.name,
    this.parentId,
    required this.createdAt,
    this.orderIndex = 0,
    this.deletedAt,
    this.isFavorite = false,
    this.iconId,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'parent_id': parentId,
      'created_at': createdAt.millisecondsSinceEpoch,
      'order_index': orderIndex,
      'deleted_at': deletedAt?.millisecondsSinceEpoch,
      'is_favorite': isFavorite ? 1 : 0,
      'icon_id': iconId,
    };
  }

  factory Notebook.fromMap(Map<String, dynamic> map) {
    return Notebook(
      id: map['id'] as int?,
      name: map['name'] as String,
      parentId: map['parent_id'] as int?,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      orderIndex: map['order_index'] as int? ?? 0,
      deletedAt:
          map['deleted_at'] != null
              ? DateTime.fromMillisecondsSinceEpoch(map['deleted_at'] as int)
              : null,
      isFavorite: map['is_favorite'] == 1,
      iconId: map['icon_id'] as int?,
    );
  }

  Notebook copyWith({
    int? id,
    String? name,
    int? parentId,
    DateTime? createdAt,
    int? orderIndex,
    DateTime? deletedAt,
    bool? isFavorite,
    int? iconId,
  }) {
    return Notebook(
      id: id ?? this.id,
      name: name ?? this.name,
      parentId: parentId ?? this.parentId,
      createdAt: createdAt ?? this.createdAt,
      orderIndex: orderIndex ?? this.orderIndex,
      deletedAt: deletedAt ?? this.deletedAt,
      isFavorite: isFavorite ?? this.isFavorite,
      iconId: iconId ?? this.iconId,
    );
  }
}
