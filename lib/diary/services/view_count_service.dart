import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Stores and retrieves event view counts in SharedPreferences.
class ViewCountService {
  static const _key = 'event_view_counts';

  static Future<Map<String, int>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final str = prefs.getString(_key);
    if (str == null) return {};
    try {
      final map = jsonDecode(str) as Map<String, dynamic>;
      return map.map((k, v) => MapEntry(k, (v as num).toInt()));
    } catch (_) {
      return {};
    }
  }

  static Future<void> increment(String eventId) async {
    final prefs = await SharedPreferences.getInstance();
    final str = prefs.getString(_key);
    Map<String, int> map = {};
    if (str != null) {
      try {
        final decoded = jsonDecode(str) as Map<String, dynamic>;
        map = decoded.map((k, v) => MapEntry(k, (v as num).toInt()));
      } catch (_) {
        map = {};
      }
    }
    map[eventId] = (map[eventId] ?? 0) + 1;
    await prefs.setString(_key, jsonEncode(map));
  }

  static Future<int> getCount(String eventId) async {
    final all = await loadAll();
    return all[eventId] ?? 0;
  }
}
