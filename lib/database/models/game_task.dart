class GameTask {
  final int? id;
  final String name;
  final String status; // 'notStarted' o 'done'
  final String gameId;
  final int orderIndex;

  GameTask({
    this.id,
    required this.name,
    required this.status,
    required this.gameId,
    this.orderIndex = 0,
  });

  factory GameTask.fromMap(Map<String, dynamic> map) {
    return GameTask(
      id: map['id'] as int?,
      name: map['name'] as String,
      status: map['status'] as String,
      gameId: map['game_id'] as String,
      orderIndex: map['order_index'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'status': status,
      'game_id': gameId,
      'order_index': orderIndex,
    };
  }

  GameTask copyWith({
    int? id,
    String? name,
    String? status,
    String? gameId,
    int? orderIndex,
  }) {
    return GameTask(
      id: id ?? this.id,
      name: name ?? this.name,
      status: status ?? this.status,
      gameId: gameId ?? this.gameId,
      orderIndex: orderIndex ?? this.orderIndex,
    );
  }
}
