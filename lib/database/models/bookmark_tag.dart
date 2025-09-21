class BookmarkTag {
  final int? id;
  final String tag;

  BookmarkTag({this.id, required this.tag});

  Map<String, dynamic> toMap() {
    return {'id': id, 'tag': tag};
  }

  factory BookmarkTag.fromMap(Map<String, dynamic> map) {
    return BookmarkTag(id: map['id'], tag: map['tag'] ?? '');
  }
}

class BookmarkTagMapping {
  final int? id;
  final int bookmarkId;
  final int tagId;

  BookmarkTagMapping({this.id, required this.bookmarkId, required this.tagId});

  Map<String, dynamic> toMap() {
    return {'id': id, 'bookmark_id': bookmarkId, 'tag_id': tagId};
  }

  factory BookmarkTagMapping.fromMap(Map<String, dynamic> map) {
    return BookmarkTagMapping(
      id: map['id'],
      bookmarkId: map['bookmark_id'],
      tagId: map['tag_id'],
    );
  }
}

class TagUrlPattern {
  final int? id;
  final String urlPattern;
  final String tag;

  TagUrlPattern({this.id, required this.urlPattern, required this.tag});

  Map<String, dynamic> toMap() {
    return {'id': id, 'url_pattern': urlPattern, 'tag': tag};
  }

  factory TagUrlPattern.fromMap(Map<String, dynamic> map) {
    return TagUrlPattern(
      id: map['id'],
      urlPattern: map['url_pattern'] ?? '',
      tag: map['tag'] ?? '',
    );
  }
}
