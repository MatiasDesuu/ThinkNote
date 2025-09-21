class GameImage {
  final int? id;
  final String imagePath;
  final String gameId;
  final int orderIndex;

  GameImage({
    this.id,
    required this.imagePath,
    required this.gameId,
    this.orderIndex = 0,
  });

  factory GameImage.fromMap(Map<String, dynamic> map) {
    return GameImage(
      id: map['id'] as int?,
      imagePath: map['image_path'] as String,
      gameId: map['game_id'] as String,
      orderIndex: map['order_index'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'image_path': imagePath,
      'game_id': gameId,
      'order_index': orderIndex,
    };
  }

  GameImage copyWith({
    int? id,
    String? imagePath,
    String? gameId,
    int? orderIndex,
  }) {
    return GameImage(
      id: id ?? this.id,
      imagePath: imagePath ?? this.imagePath,
      gameId: gameId ?? this.gameId,
      orderIndex: orderIndex ?? this.orderIndex,
    );
  }
}
