import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import '../models/notification_settings.dart';
import 'notification_tz_init.dart';

class MemoriesNotificationService {
  static const int notificationId = 200001;
  static const String channelId = 'diary_memories';

  static bool _tzInitialized = false;

  static Future<void> _ensureTzInitialized() async {
    if (_tzInitialized) return;
    await initNotificationTimezone();
    _tzInitialized = true;
  }

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  NotificationDetails _buildDetails(
      {required String title, required String body}) {
    return NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        '다이어리 추억',
        channelDescription: '오늘 같은 날의 과거 기억을 알려드립니다',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: false,
        presentSound: true,
      ),
    );
  }

  Future<void> scheduleDaily({
    required int hour,
    required int minute,
  }) async {
    await _ensureTzInitialized();
    await _notifications.cancel(notificationId);

    final now = tz.TZDateTime.now(tz.local);
    var scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    await _notifications.zonedSchedule(
      notificationId,
      'N년 전 오늘의 기억',
      '오늘 같은 날의 추억이 있어요',
      scheduledDate,
      _buildDetails(title: 'N년 전 오늘의 기억', body: '오늘 같은 날의 추억이 있어요'),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  Future<void> schedule(MemoriesNotificationSettings settings) async {
    await _ensureTzInitialized();
    // Cancel all previously scheduled notifications
    await cancelAll();

    if (!settings.enabled) return;

    final title = settings.notificationTitle;
    final body = settings.notificationBody;
    final details = _buildDetails(title: title, body: body);
    final now = tz.TZDateTime.now(tz.local);

    switch (settings.scheduleType) {
      case NotificationScheduleType.daily:
        var scheduledDate = tz.TZDateTime(
          tz.local,
          now.year,
          now.month,
          now.day,
          settings.hour,
          settings.minute,
        );
        if (scheduledDate.isBefore(now)) {
          scheduledDate = scheduledDate.add(const Duration(days: 1));
        }
        await _notifications.zonedSchedule(
          notificationId,
          title,
          body,
          scheduledDate,
          details,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          matchDateTimeComponents: DateTimeComponents.time,
        );

      case NotificationScheduleType.everyNDays:
        // Schedule up to 32 notifications ahead
        final n = settings.intervalDays.clamp(1, 30);
        var date = tz.TZDateTime(
          tz.local,
          now.year,
          now.month,
          now.day,
          settings.hour,
          settings.minute,
        );
        if (date.isBefore(now)) {
          date = date.add(Duration(days: n));
        }
        for (var i = 0; i < 32; i++) {
          await _notifications.zonedSchedule(
            notificationId + i,
            title,
            body,
            date,
            details,
            androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          );
          date = date.add(Duration(days: n));
        }

      case NotificationScheduleType.weekdays:
        for (final weekday in settings.weekdays) {
          // flutter_local_notifications weekday: 1=Mon..7=Sun
          final id = notificationId + weekday;
          var date = tz.TZDateTime(
            tz.local,
            now.year,
            now.month,
            now.day,
            settings.hour,
            settings.minute,
          );
          // Advance to the next occurrence of this weekday
          while (date.weekday != weekday || date.isBefore(now)) {
            date = date.add(const Duration(days: 1));
          }
          await _notifications.zonedSchedule(
            id,
            title,
            body,
            date,
            details,
            androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
            matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
          );
        }
    }
  }

  Future<void> cancelDaily() async {
    await _notifications.cancel(notificationId);
  }

  Future<void> cancelAll() async {
    // Cancel the repeating daily notification
    await _notifications.cancel(notificationId);
    // Cancel everyNDays batch (up to 32)
    for (var i = 0; i < 32; i++) {
      await _notifications.cancel(notificationId + i);
    }
    // Cancel weekday notifications (weekday IDs: notificationId+1 .. +7)
    for (var d = 1; d <= 7; d++) {
      await _notifications.cancel(notificationId + d);
    }
  }
}
