import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../main.dart';
import '../database/app_database.dart';
import '../models/diary_notification_settings.dart';
import '../models/hundred_days_notif_settings.dart';
import '../models/notification_history_entry.dart';
import '../providers/diary_providers.dart';
import '../screens/event_detail_screen.dart';
import '../screens/manual_record_screen.dart';
import 'hundred_days_notification_service.dart';
import 'notification_history_service.dart';
import 'notification_tz_init.dart';

// Background tap handler — must be a top-level function
@pragma('vm:entry-point')
void diaryNotificationTapBackground(NotificationResponse response) {
  SharedPreferences.getInstance().then((prefs) {
    prefs.setString('pending_diary_notification_tap', response.payload ?? '');
  });
}

class DiaryNotificationManager {
  DiaryNotificationManager._();

  static final DiaryNotificationManager instance = DiaryNotificationManager._();

  static const String channelId = 'diary_reminders';

  // On This Day: 200001–200020
  static const int onThisDayBaseId = 200001;

  // Periodic rule i: 200100 + i*30 (200100–200249)
  static int periodicBaseId(int idx) => 200100 + idx * 30;

  // N*100일 기념일: 201000–201049
  static const int hundredDaysBaseId = 201000;

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  final _historyService = NotificationHistoryService();

  FlutterLocalNotificationsPlugin get plugin => _plugin;

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
    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (r) =>
          handleNotificationTap(r.payload),
      onDidReceiveBackgroundNotificationResponse: diaryNotificationTapBackground,
    );
    _initialized = true;
  }

  Future<Set<int>> getPendingIds() async {
    final pending = await _plugin.pendingNotificationRequests();
    return pending.map((r) => r.id).toSet();
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
    await _historyService.replaceEntriesOfType('onThisDay');
    if (!s.enabled) return;

    final title = (s.useAi && aiTitle != null) ? aiTitle : 'N년 전 오늘';
    final body = (s.useAi && aiBody != null)
        ? aiBody
        : 'See the event from N years ago';
    final details = _buildDetails();
    final now = tz.TZDateTime.now(tz.local);

    Future<void> schedule(int notifId, tz.TZDateTime date,
        {DateTimeComponents? matchComponents}) async {
      final entryId =
          'onThisDay_${notifId}_${date.millisecondsSinceEpoch}';
      final payload = jsonEncode({'type': 'onThisDay', 'entryId': entryId});
      await _plugin.zonedSchedule(
        notifId,
        title,
        body,
        date,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: matchComponents,
        payload: payload,
      );
      await _historyService.addEntry(NotificationHistoryEntry(
        id: entryId,
        notificationId: notifId,
        type: 'onThisDay',
        title: title,
        body: body,
        scheduledAt: date.toLocal(),
        payload: payload,
      ));
    }

    switch (s.scheduleType) {
      case NotificationScheduleType.daily:
        var date = tz.TZDateTime(
            tz.local, now.year, now.month, now.day, s.hour, s.minute);
        if (date.isBefore(now)) date = date.add(const Duration(days: 1));
        await schedule(onThisDayBaseId, date,
            matchComponents: DateTimeComponents.time);

      case NotificationScheduleType.everyNDays:
        final n = s.intervalDays.clamp(1, 30);
        var date = tz.TZDateTime(
            tz.local, now.year, now.month, now.day, s.hour, s.minute);
        if (date.isBefore(now)) date = date.add(Duration(days: n));
        for (var i = 0; i < 20; i++) {
          await schedule(onThisDayBaseId + i, date);
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
          await schedule(onThisDayBaseId + slot, date,
              matchComponents: DateTimeComponents.dayOfWeekAndTime);
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
    await _historyService.replaceEntriesOfType('periodic_$idx');
    if (!rule.enabled) return;

    final baseId = periodicBaseId(idx);
    final title = (rule.useAi && aiTitle != null) ? aiTitle : rule.label;
    final body = (rule.useAi && aiBody != null) ? aiBody : '';
    final details = _buildDetails();
    final now = tz.TZDateTime.now(tz.local);

    Future<void> schedule(int notifId, tz.TZDateTime date,
        {DateTimeComponents? matchComponents}) async {
      final entryId =
          'periodic_${notifId}_${date.millisecondsSinceEpoch}';
      final payload =
          jsonEncode({'type': 'periodic', 'ruleIdx': idx, 'entryId': entryId});
      await _plugin.zonedSchedule(
        notifId,
        title,
        body,
        date,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: matchComponents,
        payload: payload,
      );
      await _historyService.addEntry(NotificationHistoryEntry(
        id: entryId,
        notificationId: notifId,
        type: 'periodic',
        title: title,
        body: body,
        scheduledAt: date.toLocal(),
        payload: payload,
      ));
    }

    switch (rule.scheduleType) {
      case NotificationScheduleType.daily:
        var date = tz.TZDateTime(
            tz.local, now.year, now.month, now.day, rule.hour, rule.minute);
        if (date.isBefore(now)) date = date.add(const Duration(days: 1));
        await schedule(baseId, date,
            matchComponents: DateTimeComponents.time);

      case NotificationScheduleType.everyNDays:
        final n = rule.intervalDays.clamp(1, 30);
        var date = tz.TZDateTime(
            tz.local, now.year, now.month, now.day, rule.hour, rule.minute);
        if (date.isBefore(now)) date = date.add(Duration(days: n));
        for (var i = 0; i < 8; i++) {
          await schedule(baseId + i, date);
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
          await schedule(baseId + slot, date,
              matchComponents: DateTimeComponents.dayOfWeekAndTime);
          slot++;
        }
    }
  }

  // ── N*100일 기념일 ────────────────────────────────────────────────────────

  Future<void> scheduleHundredDays(
    HundredDaysNotifSettings s,
    List<HundredDaysMilestone> milestones,
  ) async {
    await cancelHundredDays();
    await _historyService.replaceEntriesOfType('hundredDays');
    if (!s.enabled) return;

    final details = _buildDetails();

    for (var i = 0; i < milestones.length && i < 50; i++) {
      final m = milestones[i];
      final notifId = hundredDaysBaseId + i;
      final scheduledTz = tz.TZDateTime.from(m.scheduledAt, tz.local);
      final entryId =
          'hundredDays_${notifId}_${scheduledTz.millisecondsSinceEpoch}';
      final title = '${m.milestoneN}일 기념일';
      final body = m.eventTitle != null
          ? '"${m.eventTitle}" ${m.milestoneN}일째를 기념합니다 🎉'
          : '오늘로 ${m.milestoneN}일이 되었어요 🎉';
      final payload = jsonEncode({
        'type': 'hundredDays',
        'eventId': m.eventId,
        'eventStartMs': m.eventStartAt.millisecondsSinceEpoch,
        'milestone': m.milestoneN,
        'entryId': entryId,
      });

      await _plugin.zonedSchedule(
        notifId,
        title,
        body,
        scheduledTz,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: payload,
      );
      await _historyService.addEntry(NotificationHistoryEntry(
        id: entryId,
        notificationId: notifId,
        type: 'hundredDays',
        title: title,
        body: body,
        scheduledAt: m.scheduledAt,
        payload: payload,
      ));
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

  Future<void> cancelHundredDays() async {
    for (var i = 0; i < 50; i++) {
      await _plugin.cancel(hundredDaysBaseId + i);
    }
  }

  // ── Reschedule all ────────────────────────────────────────────────────────

  Future<void> rescheduleAll(
    DiaryNotificationSettings settings, {
    String? otdAiTitle,
    String? otdAiBody,
    Map<int, ({String title, String body})>? periodicAiContent,
    List<HundredDaysMilestone>? hundredDaysMilestones,
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
    if (hundredDaysMilestones != null) {
      await scheduleHundredDays(settings.hundredDays, hundredDaysMilestones);
    }
  }

  // ── Notification tap handler ──────────────────────────────────────────────

  static Future<void> handleNotificationTap(String? payloadStr) async {
    if (payloadStr == null || payloadStr.isEmpty) return;
    try {
      final data = jsonDecode(payloadStr) as Map<String, dynamic>;
      final type = data['type'] as String?;
      final entryId = data['entryId'] as String?;

      // delivered 마킹
      if (entryId != null) {
        await NotificationHistoryService().markDelivered(entryId);
      }

      switch (type) {
        case 'onThisDay':
          await _navigateOnThisDay();
        case 'hundredDays':
          final eventId = data['eventId'] as String?;
          if (eventId != null) await _navigateHundredDays(eventId);
        case 'periodic':
          _navigatePeriodic();
      }
    } catch (_) {}
  }

  static Future<void> _navigateOnThisDay() async {
    final nav = navigatorKey.currentState;
    if (nav == null) return;
    // Capture context before any async gap
    final context = nav.context;

    final db = AppDatabase();
    try {
      final now = DateTime.now();
      final events = await db.queryEventsOnThisDay(
        month: now.month,
        day: now.day,
        windowDays: 0,
        currentYear: now.year,
      );
      if (events.isNotEmpty) {
        nav.push(MaterialPageRoute(
          builder: (_) => EventDetailScreen(event: events.first),
        ));
      } else {
        // 이벤트 없으면 List 탭으로 전환
        ProviderScope.containerOf(context) // ignore: use_build_context_synchronously
            .read(pendingTabProvider.notifier)
            .state = 1;
      }
    } finally {
      await db.close();
    }
  }

  static Future<void> _navigateHundredDays(String eventId) async {
    final nav = navigatorKey.currentState;
    if (nav == null) return;

    final db = AppDatabase();
    try {
      final event = await db.getEventById(eventId);
      if (event != null) {
        nav.push(MaterialPageRoute(
          builder: (_) => EventDetailScreen(event: event),
        ));
      }
    } finally {
      await db.close();
    }
  }

  static void _navigatePeriodic() {
    navigatorKey.currentState?.push(
      MaterialPageRoute(builder: (_) => const ManualRecordScreen()),
    );
  }
}
