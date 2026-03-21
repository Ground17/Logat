import 'package:shared_preferences/shared_preferences.dart';

class DateRangeFilter {
  const DateRangeFilter({
    required this.start,
    required this.end,
  });

  final DateTime start;
  final DateTime end;

  static const _keyStart = 'drf_start';
  static const _keyEnd = 'drf_end';

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyStart, start.millisecondsSinceEpoch);
    await prefs.setInt(_keyEnd, end.millisecondsSinceEpoch);
  }

  static Future<DateRangeFilter> load() async {
    final prefs = await SharedPreferences.getInstance();
    final startMs = prefs.getInt(_keyStart);
    final endMs = prefs.getInt(_keyEnd);
    if (startMs == null || endMs == null) return _defaultRange();
    return DateRangeFilter(
      start: DateTime.fromMillisecondsSinceEpoch(startMs, isUtc: true),
      end: DateTime.fromMillisecondsSinceEpoch(endMs, isUtc: true),
    );
  }

  static DateRangeFilter _defaultRange() {
    final now = DateTime.now().toUtc();
    return DateRangeFilter(
      start: DateTime.utc(now.year, now.month - 1, now.day),
      end: DateTime.utc(now.year, now.month, now.day + 1),
    );
  }
}
