import 'package:shared_preferences/shared_preferences.dart';

enum LoopViewCountMode {
  ignore,
  boostUnwatched, // Prioritize less-viewed posts
  boostWatched,   // Prioritize most-viewed posts
}

extension LoopViewCountModeLabel on LoopViewCountMode {
  String get label {
    switch (this) {
      case LoopViewCountMode.ignore:
        return 'Ignore View Count';
      case LoopViewCountMode.boostUnwatched:
        return 'Boost Unwatched';
      case LoopViewCountMode.boostWatched:
        return 'Boost Most Watched';
    }
  }

  String get description {
    switch (this) {
      case LoopViewCountMode.ignore:
        return 'View count does not affect Loop order';
      case LoopViewCountMode.boostUnwatched:
        return 'Posts with fewer views appear more often';
      case LoopViewCountMode.boostWatched:
        return 'Posts with more views appear more often';
    }
  }
}

class LoopAlgorithmSettings {
  const LoopAlgorithmSettings({
    this.favoriteWeight = 3,
    this.onThisDayWeight = 3,
    this.recentWeight = 2,
    this.baseWeight = 1,
    this.viewCountMode = LoopViewCountMode.boostUnwatched,
  });

  /// Extra weight for favorited events (0–10)
  final int favoriteWeight;
  /// Extra weight for on-this-day / N×100 day events (0–10)
  final int onThisDayWeight;
  /// Extra weight for events within the last 30 days (0–10)
  final int recentWeight;
  /// Base weight for all events (1–10)
  final int baseWeight;
  /// View count mode
  final LoopViewCountMode viewCountMode;

  static const _keyFav = 'loop_fav_w';
  static const _keyOtd = 'loop_otd_w';
  static const _keyRecent = 'loop_recent_w';
  static const _keyBase = 'loop_base_w';
  static const _keyVcMode = 'loop_vc_mode';

  static Future<LoopAlgorithmSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    return LoopAlgorithmSettings(
      favoriteWeight: prefs.getInt(_keyFav) ?? 3,
      onThisDayWeight: prefs.getInt(_keyOtd) ?? 3,
      recentWeight: prefs.getInt(_keyRecent) ?? 2,
      baseWeight: prefs.getInt(_keyBase) ?? 1,
      viewCountMode: LoopViewCountMode.values.firstWhere(
        (e) => e.name == prefs.getString(_keyVcMode),
        orElse: () => LoopViewCountMode.boostUnwatched,
      ),
    );
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyFav, favoriteWeight);
    await prefs.setInt(_keyOtd, onThisDayWeight);
    await prefs.setInt(_keyRecent, recentWeight);
    await prefs.setInt(_keyBase, baseWeight);
    await prefs.setString(_keyVcMode, viewCountMode.name);
  }

  LoopAlgorithmSettings copyWith({
    int? favoriteWeight,
    int? onThisDayWeight,
    int? recentWeight,
    int? baseWeight,
    LoopViewCountMode? viewCountMode,
  }) {
    return LoopAlgorithmSettings(
      favoriteWeight: favoriteWeight ?? this.favoriteWeight,
      onThisDayWeight: onThisDayWeight ?? this.onThisDayWeight,
      recentWeight: recentWeight ?? this.recentWeight,
      baseWeight: baseWeight ?? this.baseWeight,
      viewCountMode: viewCountMode ?? this.viewCountMode,
    );
  }
}
