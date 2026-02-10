class Bookmark {
  final int? id;
  final String title;
  final String url;
  final String description;
  final String timestamp;
  final bool hidden;
  final List<int> tagIds;
  final List<String> tags;

  Bookmark({
    this.id,
    required this.title,
    required this.url,
    this.description = '',
    required this.timestamp,
    this.hidden = false,
    this.tagIds = const [],
    this.tags = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'url': url,
      'description': description,
      'timestamp': timestamp,
      'hidden': hidden ? 1 : 0,
      'tag_ids': tagIds,
    };
  }

  factory Bookmark.fromMap(Map<String, dynamic> map) {
    final tagsString = map['tags'] as String?;
    return Bookmark(
      id: map['id'],
      title: map['title'] ?? '',
      url: map['url'] ?? '',
      description: map['description'] ?? '',
      timestamp: map['timestamp'] ?? DateTime.now().toIso8601String(),
      hidden: map['hidden'] == 1,
      tagIds: List<int>.from(map['tag_ids'] ?? []),
      tags:
          (tagsString != null && tagsString.isNotEmpty)
              ? tagsString.split(',')
              : [],
    );
  }

  Bookmark copyWith({
    int? id,
    String? title,
    String? url,
    String? description,
    String? timestamp,
    bool? hidden,
    List<int>? tagIds,
    List<String>? tags,
  }) {
    return Bookmark(
      id: id ?? this.id,
      title: title ?? this.title,
      url: url ?? this.url,
      description: description ?? this.description,
      timestamp: timestamp ?? this.timestamp,
      hidden: hidden ?? this.hidden,
      tagIds: tagIds ?? this.tagIds,
      tags: tags ?? this.tags,
    );
  }
}
