import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import '../models/diary_notification_settings.dart';
import 'notification_tz_init.dart';

class DiaryNotificationManager {
  DiaryNotificationManager._();

  static final DiaryNotificationManager instance = DiaryNotificationManager._();

  static const String channelId = 'diary_reminders';

  // On This Day: 200001–200020
  static const int onThisDayBaseId = 200001;

  // Periodic rule i: 200100 + i*30 (200100–200249)
  static int periodicBaseId(int idx) => 200100 + idx * 30;

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    await initNotificationTimezone();

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      defaultPresentAlert: true,
      defaultPresentSound: true,
      defaultPresentBadge: false,
    );
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    await _plugin.initialize(initSettings);
    _initialized = true;
  }

  NotificationDetails _buildDetails() {
    return const NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        'Diary Reminders',
        channelDescription: 'Scheduled diary reminders',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: false,
        presentSound: true,
      ),
    );
  }

  // ── On This Day ───────────────────────────────────────────────────────────

  Future<void> scheduleOnThisDay(
    OnThisDayNotifSettings s, {
    String? aiTitle,
    String? aiBody,
  }) async {
    await cancelOnThisDay();
    if (!s.enabled) return;

    final title = (s.useAi && aiTitle != null) ? aiTitle : 'N년 전 오늘';
    final body = (s.useAi && aiBody != null)
        ? aiBody
        : 'See the event from N years ago';
    final details = _buildDetails();
    final now = tz.TZDateTime.now(tz.local);

    switch (s.scheduleType) {
      case NotificationScheduleType.daily:
        var date = tz.TZDateTime(
            tz.local, now.year, now.month, now.day, s.hour, s.minute);
        if (date.isBefore(now)) date = date.add(const Duration(days: 1));
        await _plugin.zonedSchedule(
          onThisDayBaseId,
          title,
          body,
          date,
          details,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          matchDateTimeComponents: DateTimeComponents.time,
        );

      case NotificationScheduleType.everyNDays:
        final n = s.intervalDays.clamp(1, 30);
        var date = tz.TZDateTime(
            tz.local, now.year, now.month, now.day, s.hour, s.minute);
        if (date.isBefore(now)) date = date.add(Duration(days: n));
        for (var i = 0; i < 20; i++) {
          await _plugin.zonedSchedule(
            onThisDayBaseId + i,
            title,
            body,
            date,
            details,
            androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          );
          date = date.add(Duration(days: n));
        }

      case NotificationScheduleType.weekdays:
        var slot = 0;
        for (final weekday in (s.weekdays.toList()..sort())) {
          if (slot >= 7) break;
          var date = tz.TZDateTime(
              tz.local, now.year, now.month, now.day, s.hour, s.minute);
          while (date.weekday != weekday || date.isBefore(now)) {
            date = date.add(const Duration(days: 1));
          }
          await _plugin.zonedSchedule(
            onThisDayBaseId + slot,
            title,
            body,
            date,
            details,
            androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
            matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
          );
          slot++;
        }
    }
  }

  // ── Periodic rule ─────────────────────────────────────────────────────────

  Future<void> schedulePeriodicRule(
    int idx,
    PeriodicNotifRule rule, {
    String? aiTitle,
    String? aiBody,
  }) async {
    await cancelPeriodicRule(idx);
    if (!rule.enabled) return;

    final baseId = periodicBaseId(idx);
    final title = (rule.useAi && aiTitle != null) ? aiTitle : rule.label;
    final body = (rule.useAi && aiBody != null) ? aiBody : '';
    final details = _buildDetails();
    final now = tz.TZDateTime.now(tz.local);

    switch (rule.scheduleType) {
      case NotificationScheduleType.daily:
        var date = tz.TZDateTime(
            tz.local, now.year, now.month, now.day, rule.hour, rule.minute);
        if (date.isBefore(now)) date = date.add(const Duration(days: 1));
        await _plugin.zonedSchedule(
          baseId,
          title,
          body,
          date,
          details,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          matchDateTimeComponents: DateTimeComponents.time,
        );

      case NotificationScheduleType.everyNDays:
        final n = rule.intervalDays.clamp(1, 30);
        var date = tz.TZDateTime(
            tz.local, now.year, now.month, now.day, rule.hour, rule.minute);
        if (date.isBefore(now)) date = date.add(Duration(days: n));
        for (var i = 0; i < 8; i++) {
          await _plugin.zonedSchedule(
            baseId + i,
            title,
            body,
            date,
            details,
            androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          );
          date = date.add(Duration(days: n));
        }

      case NotificationScheduleType.weekdays:
        var slot = 0;
        for (final weekday in (rule.weekdays.toList()..sort())) {
          if (slot >= 7) break;
          var date = tz.TZDateTime(
              tz.local, now.year, now.month, now.day, rule.hour, rule.minute);
          while (date.weekday != weekday || date.isBefore(now)) {
            date = date.add(const Duration(days: 1));
          }
          await _plugin.zonedSchedule(
            baseId + slot,
            title,
            body,
            date,
            details,
            androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
            matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
          );
          slot++;
        }
    }
  }

  // ── Cancel ────────────────────────────────────────────────────────────────

  Future<void> cancelOnThisDay() async {
    for (var i = 0; i < 20; i++) {
      await _plugin.cancel(onThisDayBaseId + i);
    }
  }

  Future<void> cancelPeriodicRule(int idx) async {
    final baseId = periodicBaseId(idx);
    for (var i = 0; i < 30; i++) {
      await _plugin.cancel(baseId + i);
    }
  }

  Future<void> rescheduleAll(
    DiaryNotificationSettings settings, {
    String? otdAiTitle,
    String? otdAiBody,
    Map<int, ({String title, String body})>? periodicAiContent,
  }) async {
    await scheduleOnThisDay(
      settings.onThisDay,
      aiTitle: otdAiTitle,
      aiBody: otdAiBody,
    );
    for (var i = 0; i < settings.periodicRules.length; i++) {
      final ai = periodicAiContent?[i];
      await schedulePeriodicRule(
        i,
        settings.periodicRules[i],
        aiTitle: ai?.title,
        aiBody: ai?.body,
      );
    }
  }
}
