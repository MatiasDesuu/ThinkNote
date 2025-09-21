class ContentItem {
  final String id;
  final String name;
  final String screenshotUrl;
  final bool isDone;
  final int order;
  final int removed;
  final int hidden;
  final DateTime createdAt;
  final DateTime updatedAt;

  ContentItem({
    required this.id,
    required this.name,
    this.screenshotUrl = '',
    this.isDone = false,
    this.order = 0,
    this.removed = 0,
    this.hidden = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ContentItem.fromMap(Map<String, dynamic> map) {
    return ContentItem(
      id: map['id'] as String,
      name: map['name'] as String,
      screenshotUrl: map['screenshot_url'] as String? ?? '',
      isDone: map['is_done'] == 1,
      order: map['order_index'] as int? ?? 0,
      removed: map['removed'] as int? ?? 0,
      hidden: map['hidden'] as int? ?? 0,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at'] as int),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'screenshot_url': screenshotUrl,
      'is_done': isDone ? 1 : 0,
      'order_index': order,
      'removed': removed,
      'hidden': hidden,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
    };
  }

  ContentItem copyWith({
    String? name,
    String? screenshotUrl,
    bool? isDone,
    int? order,
    int? removed,
    int? hidden,
    DateTime? updatedAt,
  }) {
    return ContentItem(
      id: id,
      name: name ?? this.name,
      screenshotUrl: screenshotUrl ?? this.screenshotUrl,
      isDone: isDone ?? this.isDone,
      order: order ?? this.order,
      removed: removed ?? this.removed,
      hidden: hidden ?? this.hidden,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
