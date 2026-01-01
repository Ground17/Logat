class Like {
  final int? id;
  final int postId; // 어느 게시물에 좋아요를 눌렀는지
  final int? aiPersonaId; // 어떤 AI가 좋아요를 눌렀는지 (null이면 사용자)
  final bool isUser; // 사용자가 누른 좋아요인지
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
