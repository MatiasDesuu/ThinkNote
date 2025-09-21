class Game {
  final String id;
  final String name;
  final DateTime? deadline;
  final String reportsUrl;
  final String changelogUrl;
  final String url;
  final String notes;
  final bool isDone;
  final int order;
  final String folderPath;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Método estático para formatear fechas en YYYY-MM-DD
  static String? formatDateOnly(DateTime? date) {
    if (date == null) return null;
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  Game({
    required this.id,
    required this.name,
    this.deadline,
    this.reportsUrl = '',
    this.changelogUrl = '',
    this.url = '',
    this.notes = '',
    this.isDone = false,
    this.order = 0,
    this.folderPath = '',
    required this.createdAt,
    required this.updatedAt,
  });

  factory Game.fromMap(Map<String, dynamic> map) {
    return Game(
      id: map['id'] as String,
      name: map['name'] as String,
      deadline:
          map['deadline'] != null
              ? map['deadline'] is int
                  ? DateTime.fromMillisecondsSinceEpoch(map['deadline'] as int)
                  : DateTime.parse(map['deadline'] as String)
              : null,
      reportsUrl: map['reports_url'] as String? ?? '',
      changelogUrl: map['changelog_url'] as String? ?? '',
      url: map['url'] as String? ?? '',
      notes: map['notes'] as String? ?? '',
      isDone: (map['is_done'] as int) == 1,
      order: map['order_index'] as int? ?? 0,
      folderPath: map['folder_path'] as String? ?? '',
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at'] as int),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'deadline': Game.formatDateOnly(deadline),
      'reports_url': reportsUrl,
      'changelog_url': changelogUrl,
      'url': url,
      'notes': notes,
      'is_done': isDone ? 1 : 0,
      'order_index': order,
      'folder_path': folderPath,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
    };
  }

  Game copyWith({
    String? name,
    DateTime? deadline,
    String? reportsUrl,
    String? changelogUrl,
    String? url,
    String? notes,
    bool? isDone,
    int? order,
    String? folderPath,
    DateTime? updatedAt,
  }) {
    return Game(
      id: id,
      name: name ?? this.name,
      deadline: deadline ?? this.deadline,
      reportsUrl: reportsUrl ?? this.reportsUrl,
      changelogUrl: changelogUrl ?? this.changelogUrl,
      url: url ?? this.url,
      notes: notes ?? this.notes,
      isDone: isDone ?? this.isDone,
      order: order ?? this.order,
      folderPath: folderPath ?? this.folderPath,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  String getRemainingTime() {
    if (deadline == null) return '-';
    final now = DateTime.now();
    final diff = deadline!.difference(DateTime(now.year, now.month, now.day));
    if (diff.inDays > 0) {
      return '${diff.inDays} days remaining';
    } else if (diff.inDays == 0) {
      return 'Due today';
    } else {
      return '${-diff.inDays} days overdue';
    }
  }
}
