class Like {
  final int? id;
  final int postId; // Which post was liked
  final int? aiPersonaId; // Which AI liked it (null = user)
  final bool isUser; // Whether the like was from the user
  final DateTime createdAt;

  Like({
    this.id,
    required this.postId,
    this.aiPersonaId,
    this.isUser = false,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'postId': postId,
      'aiPersonaId': aiPersonaId,
      'isUser': isUser ? 1 : 0,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory Like.fromMap(Map<String, dynamic> map) {
    return Like(
      id: map['id'] as int?,
      postId: map['postId'] as int,
      aiPersonaId: map['aiPersonaId'] as int?,
      isUser: map['isUser'] == 1,
      createdAt: DateTime.parse(map['createdAt'] as String),
    );
  }
}
