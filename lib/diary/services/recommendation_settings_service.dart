import 'package:shared_preferences/shared_preferences.dart';

import '../models/recommendation_settings.dart';

class RecommendationSettingsService {
  static const _prefix = 'diary_rec_';

  Future<RecommendationSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    final map = <String, dynamic>{};
    for (final key in _keys) {
      final fullKey = _prefix + key;
      final val = prefs.get(fullKey);
      if (val != null) map[key] = val;
    }
    return RecommendationSettings.fromPrefsMap(map);
  }

  Future<void> save(RecommendationSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    final map = settings.toPrefsMap();
    for (final entry in map.entries) {
      final fullKey = _prefix + entry.key;
      final val = entry.value;
      if (val is bool) {
        await prefs.setBool(fullKey, val);
      } else if (val is int) {
        await prefs.setInt(fullKey, val);
      } else if (val is String) {
        await prefs.setString(fullKey, val);
      }
    }
  }

  static const _keys = [
    'rec_enabled',
    'rec_model',
    'rec_format',
    'rec_prompt_style',
    'rec_notif_enabled',
    'rec_notif_hour',
    'rec_notif_minute',
    'rec_bg_indexing',
  ];
}
