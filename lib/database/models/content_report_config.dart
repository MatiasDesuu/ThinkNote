class ContentReportConfig {
  final int? id;
  final String url;
  final String hammerText;
  final bool isScrollSyncEnabled;
  final DateTime createdAt;
  final DateTime updatedAt;

  ContentReportConfig({
    this.id,
    this.url = '',
    this.hammerText = '',
    this.isScrollSyncEnabled = true,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ContentReportConfig.fromMap(Map<String, dynamic> map) {
    return ContentReportConfig(
      id: map['id'] as int?,
      url: map['url'] as String? ?? '',
      hammerText: map['hammer_text'] as String? ?? '',
      isScrollSyncEnabled: (map['is_scroll_sync_enabled'] as int?) == 1,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at'] as int),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'url': url,
      'hammer_text': hammerText,
      'is_scroll_sync_enabled': isScrollSyncEnabled ? 1 : 0,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
    };
  }

  ContentReportConfig copyWith({
    String? url,
    String? hammerText,
    bool? isScrollSyncEnabled,
    DateTime? updatedAt,
  }) {
    return ContentReportConfig(
      id: id,
      url: url ?? this.url,
      hammerText: hammerText ?? this.hammerText,
      isScrollSyncEnabled: isScrollSyncEnabled ?? this.isScrollSyncEnabled,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
