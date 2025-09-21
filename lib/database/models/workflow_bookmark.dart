class WorkflowBookmark {
  final int? id;
  final String title;
  final String url;
  final int order;

  WorkflowBookmark({
    this.id,
    required this.title,
    required this.url,
    this.order = 0,
  });

  factory WorkflowBookmark.fromMap(Map<String, dynamic> map) {
    return WorkflowBookmark(
      id: map['id'] as int?,
      title: map['title'] as String,
      url: map['url'] as String,
      order: map['order_index'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {'id': id, 'title': title, 'url': url, 'order_index': order};
  }

  WorkflowBookmark copyWith({int? id, String? title, String? url, int? order}) {
    return WorkflowBookmark(
      id: id ?? this.id,
      title: title ?? this.title,
      url: url ?? this.url,
      order: order ?? this.order,
    );
  }
}
