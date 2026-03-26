import 'package:shared_preferences/shared_preferences.dart';

import 'hundred_days_notif_settings.dart';

enum NotificationScheduleType { daily, everyNDays, weekdays }

enum NotificationAiFormat {
  brief,
  detailed,
  creative;

  String get displayName {
    switch (this) {
      case brief:
        return 'Brief (1-2 sentences)';
      case detailed:
        return 'Detailed (3-5 sentences)';
      case creative:
        return 'Creative (poetic)';
    }
  }

  String get instruction {
    switch (this) {
      case brief:
        return 'briefly in 1-2 sentences';
      case detailed:
        return 'in detail with 3-5 sentences';
      case creative:
        return 'in a poetic and evocative way';
    }
  }
}

// ── On This Day settings ────────────────────────────────────────────────────

class OnThisDayNotifSettings {
  const OnThisDayNotifSettings({
    this.enabled = true,
    this.hour = 9,
    this.minute = 0,
    this.scheduleType = NotificationScheduleType.daily,
    this.intervalDays = 2,
    this.weekdays = const {1, 2, 3, 4, 5},
    this.useAi = false,
    this.aiFormat = NotificationAiFormat.brief,
    this.aiPromptStyle =
        'In a warm and nostalgic tone, remind me of a memory from the past.',
  });

  final bool enabled;
  final int hour;
  final int minute;
  final NotificationScheduleType scheduleType;
  final int intervalDays;
  final Set<int> weekdays; // 1=Mon..7=Sun
  final bool useAi;
  final NotificationAiFormat aiFormat;
  final String aiPromptStyle;

  OnThisDayNotifSettings copyWith({
    bool? enabled,
    int? hour,
    int? minute,
    NotificationScheduleType? scheduleType,
    int? intervalDays,
    Set<int>? weekdays,
    bool? useAi,
    NotificationAiFormat? aiFormat,
    String? aiPromptStyle,
  }) {
    return OnThisDayNotifSettings(
      enabled: enabled ?? this.enabled,
      hour: hour ?? this.hour,
      minute: minute ?? this.minute,
      scheduleType: scheduleType ?? this.scheduleType,
      intervalDays: intervalDays ?? this.intervalDays,
      weekdays: weekdays ?? this.weekdays,
      useAi: useAi ?? this.useAi,
      aiFormat: aiFormat ?? this.aiFormat,
      aiPromptStyle: aiPromptStyle ?? this.aiPromptStyle,
    );
  }

  static const _kEnabled = 'notif_otd_enabled';
  static const _kHour = 'notif_otd_hour';
  static const _kMinute = 'notif_otd_minute';
  static const _kScheduleType = 'notif_otd_schedule_type';
  static const _kIntervalDays = 'notif_otd_interval_days';
  static const _kWeekdays = 'notif_otd_weekdays';
  static const _kUseAi = 'notif_otd_use_ai';
  static const _kAiFormat = 'notif_otd_ai_format';
  static const _kAiPromptStyle = 'notif_otd_ai_prompt_style';

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kEnabled, enabled);
    await prefs.setInt(_kHour, hour);
    await prefs.setInt(_kMinute, minute);
    await prefs.setString(_kScheduleType, scheduleType.name);
    await prefs.setInt(_kIntervalDays, intervalDays);
    await prefs.setString(_kWeekdays, weekdays.join(','));
    await prefs.setBool(_kUseAi, useAi);
    await prefs.setString(_kAiFormat, aiFormat.name);
    await prefs.setString(_kAiPromptStyle, aiPromptStyle);
  }

  static Future<OnThisDayNotifSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    final weekdaysStr = prefs.getString(_kWeekdays) ?? '1,2,3,4,5';
    final weekdays = weekdaysStr.isEmpty
        ? <int>{}
        : weekdaysStr.split(',').map(int.parse).toSet();
    final scheduleType = NotificationScheduleType.values.firstWhere(
      (e) => e.name == (prefs.getString(_kScheduleType) ?? 'daily'),
      orElse: () => NotificationScheduleType.daily,
    );
    final aiFormat = NotificationAiFormat.values.firstWhere(
      (e) => e.name == (prefs.getString(_kAiFormat) ?? 'brief'),
      orElse: () => NotificationAiFormat.brief,
    );
    return OnThisDayNotifSettings(
      enabled: prefs.getBool(_kEnabled) ?? true,
      hour: prefs.getInt(_kHour) ?? 9,
      minute: prefs.getInt(_kMinute) ?? 0,
      scheduleType: scheduleType,
      intervalDays: prefs.getInt(_kIntervalDays) ?? 2,
      weekdays: weekdays.isEmpty ? const {1, 2, 3, 4, 5} : weekdays,
      useAi: prefs.getBool(_kUseAi) ?? false,
      aiFormat: aiFormat,
      aiPromptStyle: prefs.getString(_kAiPromptStyle) ??
          'In a warm and nostalgic tone, remind me of a memory from the past.',
    );
  }
}

// ── Periodic notification rule ──────────────────────────────────────────────

class PeriodicNotifRule {
  const PeriodicNotifRule({
    required this.id,
    this.label = 'Reminder',
    this.subtitle = '',
    this.enabled = true,
    this.scheduleType = NotificationScheduleType.daily,
    this.hour = 9,
    this.minute = 0,
    this.intervalDays = 1,
    this.weekdays = const {1, 2, 3, 4, 5},
    this.useAi = false,
    this.aiFormat = NotificationAiFormat.brief,
    this.aiPromptStyle = 'Write a short diary writing prompt.',
  });

  final int id; // 0-4
  final String label;
  final String subtitle;
  final bool enabled;
  final NotificationScheduleType scheduleType;
  final int hour;
  final int minute;
  final int intervalDays;
  final Set<int> weekdays;
  final bool useAi;
  final NotificationAiFormat aiFormat;
  final String aiPromptStyle;

  PeriodicNotifRule copyWith({
    String? label,
    String? subtitle,
    bool? enabled,
    NotificationScheduleType? scheduleType,
    int? hour,
    int? minute,
    int? intervalDays,
    Set<int>? weekdays,
    bool? useAi,
    NotificationAiFormat? aiFormat,
    String? aiPromptStyle,
  }) {
    return PeriodicNotifRule(
      id: id,
      label: label ?? this.label,
      subtitle: subtitle ?? this.subtitle,
      enabled: enabled ?? this.enabled,
      scheduleType: scheduleType ?? this.scheduleType,
      hour: hour ?? this.hour,
      minute: minute ?? this.minute,
      intervalDays: intervalDays ?? this.intervalDays,
      weekdays: weekdays ?? this.weekdays,
      useAi: useAi ?? this.useAi,
      aiFormat: aiFormat ?? this.aiFormat,
      aiPromptStyle: aiPromptStyle ?? this.aiPromptStyle,
    );
  }

  String _k(String field) => 'notif_rule_${id}_$field';

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_k('label'), label);
    await prefs.setString(_k('subtitle'), subtitle);
    await prefs.setBool(_k('enabled'), enabled);
    await prefs.setString(_k('schedule_type'), scheduleType.name);
    await prefs.setInt(_k('hour'), hour);
    await prefs.setInt(_k('minute'), minute);
    await prefs.setInt(_k('interval_days'), intervalDays);
    await prefs.setString(_k('weekdays'), weekdays.join(','));
    await prefs.setBool(_k('use_ai'), useAi);
    await prefs.setString(_k('ai_format'), aiFormat.name);
    await prefs.setString(_k('ai_prompt_style'), aiPromptStyle);
  }

  static Future<PeriodicNotifRule> load(int id) async {
    final prefs = await SharedPreferences.getInstance();
    String k(String field) => 'notif_rule_${id}_$field';
    final weekdaysStr = prefs.getString(k('weekdays')) ?? '1,2,3,4,5';
    final weekdays = weekdaysStr.isEmpty
        ? <int>{}
        : weekdaysStr.split(',').map(int.parse).toSet();
    final scheduleType = NotificationScheduleType.values.firstWhere(
      (e) => e.name == (prefs.getString(k('schedule_type')) ?? 'daily'),
      orElse: () => NotificationScheduleType.daily,
    );
    final aiFormat = NotificationAiFormat.values.firstWhere(
      (e) => e.name == (prefs.getString(k('ai_format')) ?? 'brief'),
      orElse: () => NotificationAiFormat.brief,
    );
    return PeriodicNotifRule(
      id: id,
      label: prefs.getString(k('label')) ?? 'Reminder',
      subtitle: prefs.getString(k('subtitle')) ?? '',
      enabled: prefs.getBool(k('enabled')) ?? true,
      scheduleType: scheduleType,
      hour: prefs.getInt(k('hour')) ?? 9,
      minute: prefs.getInt(k('minute')) ?? 0,
      intervalDays: prefs.getInt(k('interval_days')) ?? 1,
      weekdays: weekdays.isEmpty ? const {1, 2, 3, 4, 5} : weekdays,
      useAi: prefs.getBool(k('use_ai')) ?? false,
      aiFormat: aiFormat,
      aiPromptStyle: prefs.getString(k('ai_prompt_style')) ??
          'Write a short diary writing prompt.',
    );
  }

  static Future<List<PeriodicNotifRule>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final count = prefs.getInt('notif_rules_count') ?? 0;
    final rules = <PeriodicNotifRule>[];
    for (var i = 0; i < count; i++) {
      rules.add(await load(i));
    }
    return rules;
  }

  static Future<void> saveCount(int count) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('notif_rules_count', count);
  }
}

// ── Top-level settings container ─────────────────────────────────────────────

class DiaryNotificationSettings {
  const DiaryNotificationSettings({
    required this.onThisDay,
    required this.periodicRules,
    required this.hundredDays,
  });

  final OnThisDayNotifSettings onThisDay;
  final List<PeriodicNotifRule> periodicRules;
  final HundredDaysNotifSettings hundredDays;

  static Future<DiaryNotificationSettings> load() async {
    final onThisDay = await OnThisDayNotifSettings.load();
    final periodicRules = await PeriodicNotifRule.loadAll();
    final hundredDays = await HundredDaysNotifSettings.load();
    return DiaryNotificationSettings(
      onThisDay: onThisDay,
      periodicRules: periodicRules,
      hundredDays: hundredDays,
    );
  }
}
