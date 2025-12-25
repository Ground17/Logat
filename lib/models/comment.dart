class Comment {
  final int? id;
  final int postId; // 어느 게시물에 달린 댓글인지
  final int aiPersonaId; // 어떤 AI가 작성했는지
  final String content; // 댓글 내용
  final DateTime createdAt;

  Comment({
    this.id,
    required this.postId,
    required this.aiPersonaId,
    required this.content,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'postId': postId,
      'aiPersonaId': aiPersonaId,
      'content': content,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory Comment.fromMap(Map<String, dynamic> map) {
    return Comment(
      id: map['id'] as int?,
      postId: map['postId'] as int,
      aiPersonaId: map['aiPersonaId'] as int,
      content: map['content'] as String,
      createdAt: DateTime.parse(map['createdAt'] as String),
    );
  }
}
