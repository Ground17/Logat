import 'dart:convert';

class NotificationHistoryEntry {
  const NotificationHistoryEntry({
    required this.id,
    required this.notificationId,
    required this.type,
    required this.title,
    required this.body,
    required this.scheduledAt,
    this.payload,
    this.delivered = false,
  });

  final String id;           // "${type}_${notifId}_${scheduledMs}"
  final int notificationId;  // flutter_local_notifications ID (for cross-checking pending notifications)
  final String type;         // 'onThisDay' | 'hundredDays' | 'periodic'
  final String title;
  final String body;
  final DateTime scheduledAt;
  final String? payload;     // raw JSON string (for navigation)
  final bool delivered;

  NotificationHistoryEntry copyWith({
    bool? delivered,
  }) {
    return NotificationHistoryEntry(
      id: id,
      notificationId: notificationId,
      type: type,
      title: title,
      body: body,
      scheduledAt: scheduledAt,
      payload: payload,
      delivered: delivered ?? this.delivered,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'notificationId': notificationId,
        'type': type,
        'title': title,
        'body': body,
        'scheduledAt': scheduledAt.millisecondsSinceEpoch,
        'payload': payload,
        'delivered': delivered,
      };

  factory NotificationHistoryEntry.fromJson(Map<String, dynamic> json) {
    return NotificationHistoryEntry(
      id: json['id'] as String,
      notificationId: json['notificationId'] as int,
      type: json['type'] as String,
      title: json['title'] as String,
      body: json['body'] as String,
      scheduledAt: DateTime.fromMillisecondsSinceEpoch(
        json['scheduledAt'] as int,
      ),
      payload: json['payload'] as String?,
      delivered: json['delivered'] as bool? ?? false,
    );
  }

  static NotificationHistoryEntry? tryFromJsonString(String jsonStr) {
    try {
      return NotificationHistoryEntry.fromJson(
          jsonDecode(jsonStr) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }
}
