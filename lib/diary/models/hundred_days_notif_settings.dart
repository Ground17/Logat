import 'package:shared_preferences/shared_preferences.dart';

import 'diary_notification_settings.dart';

class HundredDaysNotifSettings {
  const HundredDaysNotifSettings({
    this.enabled = true,
    this.hour = 9,
    this.minute = 0,
    this.useAi = false,
    this.aiFormat = NotificationAiFormat.brief,
    this.aiPromptStyle =
        'In a warm and celebratory tone, mark this milestone occasion.',
  });

  final bool enabled;
  final int hour;
  final int minute;
  final bool useAi;
  final NotificationAiFormat aiFormat;
  final String aiPromptStyle;

  HundredDaysNotifSettings copyWith({
    bool? enabled,
    int? hour,
    int? minute,
    bool? useAi,
    NotificationAiFormat? aiFormat,
    String? aiPromptStyle,
  }) {
    return HundredDaysNotifSettings(
      enabled: enabled ?? this.enabled,
      hour: hour ?? this.hour,
      minute: minute ?? this.minute,
      useAi: useAi ?? this.useAi,
      aiFormat: aiFormat ?? this.aiFormat,
      aiPromptStyle: aiPromptStyle ?? this.aiPromptStyle,
    );
  }

  static const _kEnabled = 'notif_hd_enabled';
  static const _kHour = 'notif_hd_hour';
  static const _kMinute = 'notif_hd_minute';
  static const _kUseAi = 'notif_hd_use_ai';
  static const _kAiFormat = 'notif_hd_ai_format';
  static const _kAiPrompt = 'notif_hd_ai_prompt';

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kEnabled, enabled);
    await prefs.setInt(_kHour, hour);
    await prefs.setInt(_kMinute, minute);
    await prefs.setBool(_kUseAi, useAi);
    await prefs.setString(_kAiFormat, aiFormat.name);
    await prefs.setString(_kAiPrompt, aiPromptStyle);
  }

  static Future<HundredDaysNotifSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    return HundredDaysNotifSettings(
      enabled: prefs.getBool(_kEnabled) ?? true,
      hour: prefs.getInt(_kHour) ?? 9,
      minute: prefs.getInt(_kMinute) ?? 0,
      useAi: prefs.getBool(_kUseAi) ?? false,
      aiFormat: NotificationAiFormat.values.firstWhere(
        (e) => e.name == prefs.getString(_kAiFormat),
        orElse: () => NotificationAiFormat.brief,
      ),
      aiPromptStyle: prefs.getString(_kAiPrompt) ??
          'In a warm and celebratory tone, mark this milestone occasion.',
    );
  }
}
