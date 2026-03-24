class Comment {
  final int? id;
  final int postId; // Which post this comment belongs to
  final int? aiPersonaId; // Which AI wrote it (null = user)
  final bool isUser; // Whether the comment was written by the user
  final String content; // Comment content
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
