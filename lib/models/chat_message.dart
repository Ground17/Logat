class ChatMessage {
  final int? id;
  final int aiPersonaId; // 어떤 AI와의 대화인지
  final bool isUser; // true면 사용자 메시지, false면 AI 메시지
  final String content; // 메시지 내용
  final DateTime createdAt;

  ChatMessage({
    this.id,
    required this.aiPersonaId,
    required this.isUser,
    required this.content,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'aiPersonaId': aiPersonaId,
      'isUser': isUser ? 1 : 0,
      'content': content,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory ChatMessage.fromMap(Map<String, dynamic> map) {
    return ChatMessage(
      id: map['id'] as int?,
      aiPersonaId: map['aiPersonaId'] as int,
      isUser: map['isUser'] == 1,
      content: map['content'] as String,
      createdAt: DateTime.parse(map['createdAt'] as String),
    );
  }
}
