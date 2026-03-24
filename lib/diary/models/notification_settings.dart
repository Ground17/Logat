import 'package:shared_preferences/shared_preferences.dart';

enum NotificationScheduleType { daily, everyNDays, weekdays }

class MemoriesNotificationSettings {
  final bool enabled;
  final int hour;
  final int minute;
  final NotificationScheduleType scheduleType;
  final int intervalDays; // for everyNDays
  final Set<int> weekdays; // 1=Mon ~ 7=Sun, for weekdays type
  final bool onThisDayEnabled;
  final String notificationTitle;
  final String notificationBody;

  const MemoriesNotificationSettings({
    this.enabled = true,
    this.hour = 9,
    this.minute = 0,
    this.scheduleType = NotificationScheduleType.daily,
    this.intervalDays = 2,
    this.weekdays = const {1, 2, 3, 4, 5},
    this.onThisDayEnabled = true,
    this.notificationTitle = 'On This Day',
    this.notificationBody = 'You have a memory from this day in the past',
  });

  MemoriesNotificationSettings copyWith({
    bool? enabled,
    int? hour,
    int? minute,
    NotificationScheduleType? scheduleType,
    int? intervalDays,
    Set<int>? weekdays,
    bool? onThisDayEnabled,
    String? notificationTitle,
    String? notificationBody,
  }) {
    return MemoriesNotificationSettings(
      enabled: enabled ?? this.enabled,
      hour: hour ?? this.hour,
      minute: minute ?? this.minute,
      scheduleType: scheduleType ?? this.scheduleType,
      intervalDays: intervalDays ?? this.intervalDays,
      weekdays: weekdays ?? this.weekdays,
      onThisDayEnabled: onThisDayEnabled ?? this.onThisDayEnabled,
      notificationTitle: notificationTitle ?? this.notificationTitle,
      notificationBody: notificationBody ?? this.notificationBody,
    );
  }

  static const _keyEnabled = 'mem_notif_enabled';
  static const _keyHour = 'mem_notif_hour';
  static const _keyMinute = 'mem_notif_minute';
  static const _keyScheduleType = 'mem_notif_schedule_type';
  static const _keyIntervalDays = 'mem_notif_interval_days';
  static const _keyWeekdays = 'mem_notif_weekdays';
  static const _keyOnThisDay = 'mem_notif_on_this_day';
  static const _keyTitle = 'mem_notif_title';
  static const _keyBody = 'mem_notif_body';

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyEnabled, enabled);
    await prefs.setInt(_keyHour, hour);
    await prefs.setInt(_keyMinute, minute);
    await prefs.setString(_keyScheduleType, scheduleType.name);
    await prefs.setInt(_keyIntervalDays, intervalDays);
    await prefs.setString(_keyWeekdays, weekdays.join(','));
    await prefs.setBool(_keyOnThisDay, onThisDayEnabled);
    await prefs.setString(_keyTitle, notificationTitle);
    await prefs.setString(_keyBody, notificationBody);
  }

  static Future<MemoriesNotificationSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    final weekdaysStr = prefs.getString(_keyWeekdays) ?? '1,2,3,4,5';
    final weekdays = weekdaysStr.isEmpty
        ? <int>{}
        : weekdaysStr.split(',').map(int.parse).toSet();
    final scheduleTypeName = prefs.getString(_keyScheduleType) ?? 'daily';
    final scheduleType = NotificationScheduleType.values.firstWhere(
      (e) => e.name == scheduleTypeName,
      orElse: () => NotificationScheduleType.daily,
    );
    return MemoriesNotificationSettings(
      enabled: prefs.getBool(_keyEnabled) ?? true,
      hour: prefs.getInt(_keyHour) ?? 9,
      minute: prefs.getInt(_keyMinute) ?? 0,
      scheduleType: scheduleType,
      intervalDays: prefs.getInt(_keyIntervalDays) ?? 2,
      weekdays: weekdays.isEmpty ? const {1, 2, 3, 4, 5} : weekdays,
      onThisDayEnabled: prefs.getBool(_keyOnThisDay) ?? true,
      notificationTitle: prefs.getString(_keyTitle) ?? 'On This Day',
      notificationBody: prefs.getString(_keyBody) ?? 'You have a memory from this day in the past',
    );
  }
}
