import 'package:shared_preferences/shared_preferences.dart';

enum RelativeDateUnit { days, months, years }

extension RelativeDateUnitExt on RelativeDateUnit {
  String get label {
    switch (this) {
      case RelativeDateUnit.days:
        return 'days';
      case RelativeDateUnit.months:
        return 'months';
      case RelativeDateUnit.years:
        return 'years';
    }
  }

  String labelFor(int n) {
    switch (this) {
      case RelativeDateUnit.days:
        return n == 1 ? '1 day ago' : '$n days ago';
      case RelativeDateUnit.months:
        return n == 1 ? '1 month ago' : '$n months ago';
      case RelativeDateUnit.years:
        return n == 1 ? '1 year ago' : '$n years ago';
    }
  }

  static RelativeDateUnit fromString(String s) {
    switch (s) {
      case 'days':
        return RelativeDateUnit.days;
      case 'years':
        return RelativeDateUnit.years;
      default:
        return RelativeDateUnit.months;
    }
  }

  /// Compute start DateTime from today.
  DateTime startFromToday() {
    final now = DateTime.now().toUtc();
    switch (this) {
      case RelativeDateUnit.days:
        return DateTime.utc(now.year, now.month, now.day);
      case RelativeDateUnit.months:
        return DateTime.utc(now.year, now.month, now.day);
      case RelativeDateUnit.years:
        return DateTime.utc(now.year, now.month, now.day);
    }
  }
}

DateTime _computeRelativeStart(int amount, RelativeDateUnit unit) {
  final now = DateTime.now().toUtc();
  switch (unit) {
    case RelativeDateUnit.days:
      return DateTime.utc(now.year, now.month, now.day - amount);
    case RelativeDateUnit.months:
      return DateTime.utc(now.year, now.month - amount, now.day);
    case RelativeDateUnit.years:
      return DateTime.utc(now.year - amount, now.month, now.day);
  }
}

class DateRangeFilter {
  const DateRangeFilter({
    required this.start,
    required this.end,
    this.isRelative = true,
    this.isAllTime = false,
    this.relativeAmount = 1,
    this.relativeUnit = RelativeDateUnit.months,
  });

  /// Absolute start (used for DB queries).
  final DateTime start;

  /// Absolute end, exclusive (used for DB queries).
  final DateTime end;

  /// If true, shows all records with no date constraint.
  final bool isAllTime;

  /// If true, start is recomputed from today on every load.
  final bool isRelative;

  /// N in "n days/months/years ago". Only meaningful when [isRelative] = true.
  final int relativeAmount;

  /// Unit for relative mode.
  final RelativeDateUnit relativeUnit;

  // ─── Keys ───────────────────────────────────────────────────────────────

  static const _keyStart = 'drf_start';
  static const _keyEnd = 'drf_end';
  static const _keyIsRelative = 'drf_is_relative';
  static const _keyIsAllTime = 'drf_is_all_time';
  static const _keyRelAmount = 'drf_rel_amount';
  static const _keyRelUnit = 'drf_rel_unit';

  // Default preference keys (user-configured default for relative mode)
  static const _keyDefAmount = 'drf_def_amount';
  static const _keyDefUnit = 'drf_def_unit';

  // ─── Computed helpers ────────────────────────────────────────────────────

  String get relativeLabel => relativeUnit.labelFor(relativeAmount);

  // ─── Factories ──────────────────────────────────────────────────────────

  /// Creates a relative filter recomputed from today.
  factory DateRangeFilter.relative(int amount, RelativeDateUnit unit) {
    final now = DateTime.now().toUtc();
    return DateRangeFilter(
      isRelative: true,
      relativeAmount: amount,
      relativeUnit: unit,
      start: _computeRelativeStart(amount, unit),
      end: DateTime.utc(now.year, now.month, now.day + 1),
    );
  }

  /// Creates an absolute (fixed-date) filter.
  factory DateRangeFilter.absolute(DateTime start, DateTime end) {
    return DateRangeFilter(
      isRelative: false,
      relativeAmount: 1,
      relativeUnit: RelativeDateUnit.months,
      start: start,
      end: end,
    );
  }

  /// Creates an all-time filter (no date constraint).
  factory DateRangeFilter.allTime() {
    return DateRangeFilter(
      isAllTime: true,
      isRelative: false,
      relativeAmount: 1,
      relativeUnit: RelativeDateUnit.months,
      start: DateTime.utc(2000),
      end: DateTime.utc(2100),
    );
  }

  static DateRangeFilter _defaultRange() {
    return DateRangeFilter.relative(1, RelativeDateUnit.months);
  }

  // ─── Persistence ─────────────────────────────────────────────────────────

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyIsAllTime, isAllTime);
    await prefs.setBool(_keyIsRelative, isRelative);
    await prefs.setInt(_keyRelAmount, relativeAmount);
    await prefs.setString(_keyRelUnit, relativeUnit.label);
    if (!isRelative && !isAllTime) {
      await prefs.setInt(_keyStart, start.millisecondsSinceEpoch);
      await prefs.setInt(_keyEnd, end.millisecondsSinceEpoch);
    }
  }

  static Future<DateRangeFilter> load() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_keyIsAllTime) ?? false) {
      return DateRangeFilter.allTime();
    }
    final isRelative = prefs.getBool(_keyIsRelative) ?? true;

    if (isRelative) {
      final amount = prefs.getInt(_keyRelAmount) ?? 1;
      final unit = RelativeDateUnitExt.fromString(
          prefs.getString(_keyRelUnit) ?? 'months');
      // Always recompute from today
      return DateRangeFilter.relative(amount, unit);
    } else {
      final startMs = prefs.getInt(_keyStart);
      final endMs = prefs.getInt(_keyEnd);
      if (startMs == null || endMs == null) return _defaultRange();
      return DateRangeFilter.absolute(
        DateTime.fromMillisecondsSinceEpoch(startMs, isUtc: true),
        DateTime.fromMillisecondsSinceEpoch(endMs, isUtc: true),
      );
    }
  }

  // ─── User default (separate from active filter) ──────────────────────────

  /// Saves the current relative preset as the user's preferred default.
  Future<void> saveAsDefault() async {
    assert(isRelative, 'Only relative filters can be saved as default.');
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyDefAmount, relativeAmount);
    await prefs.setString(_keyDefUnit, relativeUnit.label);
  }

  /// Loads the user's saved default (falls back to 1 month).
  static Future<DateRangeFilter> loadDefault() async {
    final prefs = await SharedPreferences.getInstance();
    final amount = prefs.getInt(_keyDefAmount) ?? 1;
    final unit = RelativeDateUnitExt.fromString(
        prefs.getString(_keyDefUnit) ?? 'months');
    return DateRangeFilter.relative(amount, unit);
  }
}
