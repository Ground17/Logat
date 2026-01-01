class Comment {
  final int? id;
  final int postId; // 어느 게시물에 달린 댓글인지
  final int? aiPersonaId; // 어떤 AI가 작성했는지 (null이면 사용자)
  final bool isUser; // 사용자가 작성한 댓글인지
  final String content; // 댓글 내용
  final DateTime createdAt;

  Comment({
    this.id,
    required this.postId,
    this.aiPersonaId,
    this.isUser = false,
    required this.content,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'postId': postId,
      'aiPersonaId': aiPersonaId,
      'isUser': isUser ? 1 : 0,
      'content': content,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory Comment.fromMap(Map<String, dynamic> map) {
    return Comment(
      id: map['id'] as int?,
      postId: map['postId'] as int,
      aiPersonaId: map['aiPersonaId'] as int?,
      isUser: map['isUser'] == 1,
      content: map['content'] as String,
      createdAt: DateTime.parse(map['createdAt'] as String),
    );
  }

  Comment copyWith({
    int? id,
    int? postId,
    int? aiPersonaId,
    bool? isUser,
    String? content,
    DateTime? createdAt,
  }) {
    return Comment(
      id: id ?? this.id,
      postId: postId ?? this.postId,
      aiPersonaId: aiPersonaId ?? this.aiPersonaId,
      isUser: isUser ?? this.isUser,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
