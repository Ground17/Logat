class Like {
  final int? id;
  final int postId; // 어느 게시물에 좋아요를 눌렀는지
  final int aiPersonaId; // 어떤 AI가 좋아요를 눌렀는지
  final DateTime createdAt;

  Like({
    this.id,
    required this.postId,
    required this.aiPersonaId,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'postId': postId,
      'aiPersonaId': aiPersonaId,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory Like.fromMap(Map<String, dynamic> map) {
    return Like(
      id: map['id'] as int?,
      postId: map['postId'] as int,
      aiPersonaId: map['aiPersonaId'] as int,
      createdAt: DateTime.parse(map['createdAt'] as String),
    );
  }
}
