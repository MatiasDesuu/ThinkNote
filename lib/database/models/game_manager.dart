class GameManager {
  final int? id;
  final String type; // 'bugs' o 'text'
  final String name;
  final String gameId;

  GameManager({
    this.id,
    required this.type,
    required this.name,
    required this.gameId,
  });

  factory GameManager.fromMap(Map<String, dynamic> map) {
    return GameManager(
      id: map['id'] as int?,
      type: map['type'] as String,
      name: map['name'] as String,
      gameId: map['game_id'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {'id': id, 'type': type, 'name': name, 'game_id': gameId};
  }

  GameManager copyWith({int? id, String? type, String? name, String? gameId}) {
    return GameManager(
      id: id ?? this.id,
      type: type ?? this.type,
      name: name ?? this.name,
      gameId: gameId ?? this.gameId,
    );
  }
}
