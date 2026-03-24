import 'package:shared_preferences/shared_preferences.dart';

class HundredDaysNotifSettings {
  const HundredDaysNotifSettings({
    this.enabled = true,
    this.hour = 9,
    this.minute = 0,
  });

  final bool enabled;
  final int hour;
  final int minute;

  HundredDaysNotifSettings copyWith({
    bool? enabled,
    int? hour,
    int? minute,
  }) {
    return HundredDaysNotifSettings(
      enabled: enabled ?? this.enabled,
      hour: hour ?? this.hour,
      minute: minute ?? this.minute,
    );
  }

  static const _kEnabled = 'notif_hd_enabled';
  static const _kHour = 'notif_hd_hour';
  static const _kMinute = 'notif_hd_minute';

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kEnabled, enabled);
    await prefs.setInt(_kHour, hour);
    await prefs.setInt(_kMinute, minute);
  }

  static Future<HundredDaysNotifSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    return HundredDaysNotifSettings(
      enabled: prefs.getBool(_kEnabled) ?? true,
      hour: prefs.getInt(_kHour) ?? 9,
      minute: prefs.getInt(_kMinute) ?? 0,
    );
  }
}
