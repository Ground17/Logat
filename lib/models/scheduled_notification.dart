class ScheduledNotification {
  final int? id;
  final int postId;
  final int? aiPersonaId;
  final String notificationType; // 'like' or 'comment'
  final String? commentContent; // Only for comment notifications
  final DateTime scheduledTime;
  final bool isDelivered;
  final bool isRead;
  final DateTime createdAt;

  ScheduledNotification({
    this.id,
    required this.postId,
    this.aiPersonaId,
    required this.notificationType,
    this.commentContent,
    required this.scheduledTime,
    this.isDelivered = false,
    this.isRead = false,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'postId': postId,
      'aiPersonaId': aiPersonaId,
      'notificationType': notificationType,
      'commentContent': commentContent,
      'scheduledTime': scheduledTime.toIso8601String(),
      'isDelivered': isDelivered ? 1 : 0,
      'isRead': isRead ? 1 : 0,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory ScheduledNotification.fromMap(Map<String, dynamic> map) {
    return ScheduledNotification(
      id: map['id'] as int?,
      postId: map['postId'] as int,
      aiPersonaId: map['aiPersonaId'] as int?,
      notificationType: map['notificationType'] as String,
      commentContent: map['commentContent'] as String?,
      scheduledTime: DateTime.parse(map['scheduledTime'] as String),
      isDelivered: map['isDelivered'] == 1,
      isRead: map['isRead'] == 1,
      createdAt: DateTime.parse(map['createdAt'] as String),
    );
  }

  ScheduledNotification copyWith({
    int? id,
    int? postId,
    int? aiPersonaId,
    String? notificationType,
    String? commentContent,
    DateTime? scheduledTime,
    bool? isDelivered,
    bool? isRead,
    DateTime? createdAt,
  }) {
    return ScheduledNotification(
      id: id ?? this.id,
      postId: postId ?? this.postId,
      aiPersonaId: aiPersonaId ?? this.aiPersonaId,
      notificationType: notificationType ?? this.notificationType,
      commentContent: commentContent ?? this.commentContent,
      scheduledTime: scheduledTime ?? this.scheduledTime,
      isDelivered: isDelivered ?? this.isDelivered,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
