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
import '../models/diary_filter.dart';
import '../providers/diary_providers.dart';
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

  // N×100 day milestones: 201000–201049
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

  NotificationDetails _buildDetails({String? subtitle}) {
    return NotificationDetails(
      android: const AndroidNotificationDetails(
        channelId,
        'Diary Reminders',
        channelDescription: 'Scheduled diary reminders',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
      ),
      iOS: DarwinNotificationDetails(
        subtitle: subtitle?.isEmpty ?? true ? null : subtitle,
        presentAlert: true,
        presentBadge: false,
        presentSound: true,
      ),
    );
  }

  // ── On This Day ───────────────────────────────────────────────────────────

  /// Schedules On This Day notifications for the next [lookAheadDays] days
  /// that have at least one event from a past year on that calendar date.
  Future<void> scheduleOnThisDay(
    OnThisDayNotifSettings s, {
    String? aiTitle,
    String? aiBody,
    AppDatabase? db,
  }) async {
    await cancelOnThisDay();
    await _historyService.replaceEntriesOfType('onThisDay');
    if (!s.enabled) return;

    final title = (s.useAi && aiTitle != null) ? aiTitle : 'On This Day';
    final body = (s.useAi && aiBody != null)
        ? aiBody
        : 'See memories from this day in past years';
    final details = _buildDetails();
    final now = tz.TZDateTime.now(tz.local);

    // Collect calendar days (month, day) that have events from past years
    final ownDb = db == null;
    final database = db ?? AppDatabase();
    Set<String> daysWithMemories = {};
    try {
      daysWithMemories = await database.getCalendarDaysWithPastEvents(now.year);
    } finally {
      if (ownDb) await database.close();
    }

    // Schedule for next 30 days that have past-year memories
    var slot = 0;
    for (var offset = 1; offset <= 30 && slot < 20; offset++) {
      final candidate = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day + offset,
        s.hour,
        s.minute,
      );
      final key =
          '${candidate.month.toString().padLeft(2, '0')}-${candidate.day.toString().padLeft(2, '0')}';
      if (!daysWithMemories.contains(key)) continue;

      final notifId = onThisDayBaseId + slot;
      final entryId = 'onThisDay_${notifId}_${candidate.millisecondsSinceEpoch}';
      final payload = jsonEncode({'type': 'onThisDay', 'entryId': entryId});
      await _plugin.zonedSchedule(
        notifId,
        title,
        body,
        candidate,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: payload,
      );
      await _historyService.addEntry(NotificationHistoryEntry(
        id: entryId,
        notificationId: notifId,
        type: 'onThisDay',
        title: title,
        body: body,
        scheduledAt: candidate.toLocal(),
        payload: payload,
      ));
      slot++;
    }
  }

  // ── Periodic rule ─────────────────────────────────────────────────────────

  Future<void> schedulePeriodicRule(
    int idx,
    PeriodicNotifRule rule, {
    String? aiTitle,
    String? aiBody,
    String? aiSubtitle,
  }) async {
    await cancelPeriodicRule(idx);
    await _historyService.replaceEntriesOfType('periodic_$idx');
    if (!rule.enabled) return;

    final baseId = periodicBaseId(idx);
    final title = (rule.useAi && aiTitle != null) ? aiTitle : rule.label;
    final body = (rule.useAi && aiBody != null) ? aiBody : '';
    final subtitle = rule.useAi && aiSubtitle != null
        ? aiSubtitle
        : rule.subtitle;
    final details = _buildDetails(subtitle: subtitle);
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

  // ── N×100 Day Milestones ──────────────────────────────────────────────────

  Future<void> scheduleHundredDays(
    HundredDaysNotifSettings s,
    List<HundredDaysMilestone> milestones, {
    String? aiTitle,
    String? aiBody,
  }) async {
    await cancelHundredDays();
    await _historyService.replaceEntriesOfType('hundredDays');
    if (!s.enabled) return;

    final details = _buildDetails();

    // Group milestones by date (yyyy-MM-dd)
    final byDate = <String, List<HundredDaysMilestone>>{};
    for (final m in milestones) {
      final local = m.scheduledAt.toLocal();
      final key =
          '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
      byDate.putIfAbsent(key, () => []).add(m);
    }

    final sortedKeys = byDate.keys.toList()..sort();
    var idx = 0;
    for (final dateKey in sortedKeys) {
      if (idx >= 50) break;
      final group = byDate[dateKey]!;
      final notifId = hundredDaysBaseId + idx;
      final first = group.first;
      final scheduledTz = tz.TZDateTime.from(first.scheduledAt, tz.local);
      final entryId =
          'hundredDays_${notifId}_${scheduledTz.millisecondsSinceEpoch}';

      final title = (s.useAi && aiTitle != null)
          ? aiTitle
          : '${group.length} ${group.length == 1 ? 'Milestone' : 'Milestones'} Today';
      final body = (s.useAi && aiBody != null)
          ? aiBody
          : 'See memories that have reached a milestone today';

      final payload = jsonEncode({
        'type': 'hundredDays',
        'eventIds': group.map((m) => m.eventId).toList(),
        'milestones': group.map((m) => m.milestoneN).toList(),
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
        scheduledAt: first.scheduledAt,
        payload: payload,
      ));
      idx++;
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
    Map<int, ({String title, String subtitle, String body})>? periodicAiContent,
    List<HundredDaysMilestone>? hundredDaysMilestones,
    String? hdAiTitle,
    String? hdAiBody,
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
        aiSubtitle: ai?.subtitle,
      );
    }
    if (hundredDaysMilestones != null) {
      await scheduleHundredDays(
        settings.hundredDays,
        hundredDaysMilestones,
        aiTitle: hdAiTitle,
        aiBody: hdAiBody,
      );
    }
  }

  // ── Notification tap handler ──────────────────────────────────────────────

  static Future<void> handleNotificationTap(String? payloadStr) async {
    if (payloadStr == null || payloadStr.isEmpty) return;
    try {
      final data = jsonDecode(payloadStr) as Map<String, dynamic>;
      final type = data['type'] as String?;
      final entryId = data['entryId'] as String?;

      // Mark as delivered
      if (entryId != null) {
        await NotificationHistoryService().markDelivered(entryId);
      }

      switch (type) {
        case 'onThisDay':
          await _navigateOnThisDay();
        case 'hundredDays':
          final eventIds = (data['eventIds'] as List?)?.cast<String>() ??
              (data['eventId'] != null ? [data['eventId'] as String] : []);
          if (eventIds.isNotEmpty) await _navigateHundredDays(eventIds);
        case 'periodic':
          _navigatePeriodic();
      }
    } catch (_) {}
  }

  static Future<void> _navigateOnThisDay() async {
    final nav = navigatorKey.currentState;
    if (nav == null) return;
    final context = nav.context;

    // Apply similarDate filter + set selected date to today → go to List tab
    final container = ProviderScope.containerOf(context); // ignore: use_build_context_synchronously
    final now = DateTime.now().toUtc();
    container.read(selectedDateProvider.notifier).state =
        DateTime.utc(now.year, now.month, now.day);
    container.read(diaryFilterProvider.notifier).update(
          const DiaryFilter(similarDate: true),
        );
    container.read(pendingTabProvider.notifier).state = 1;
  }

  static Future<void> _navigateHundredDays(List<String> eventIds) async {
    final nav = navigatorKey.currentState;
    if (nav == null) return;
    final context = nav.context;

    // Apply isMilestoneDay filter → go to List tab
    final container = ProviderScope.containerOf(context); // ignore: use_build_context_synchronously
    container.read(diaryFilterProvider.notifier).update(
          const DiaryFilter(isMilestoneDay: true),
        );
    container.read(pendingTabProvider.notifier).state = 1;
  }

  static void _navigatePeriodic() {
    navigatorKey.currentState?.push(
      MaterialPageRoute(builder: (_) => const ManualRecordScreen()),
    );
  }
}
