import 'package:shared_preferences/shared_preferences.dart';

enum LoopViewCountMode {
  ignore,
  boostUnwatched, // 조회 적은 게시물 우선
  boostWatched,   // 조회 많은 게시물 우선
}

extension LoopViewCountModeLabel on LoopViewCountMode {
  String get label {
    switch (this) {
      case LoopViewCountMode.ignore:
        return '조회수 무시';
      case LoopViewCountMode.boostUnwatched:
        return '안 본 것 우선 노출';
      case LoopViewCountMode.boostWatched:
        return '많이 본 것 우선 노출';
    }
  }

  String get description {
    switch (this) {
      case LoopViewCountMode.ignore:
        return '조회수를 Loop 순서에 반영하지 않습니다';
      case LoopViewCountMode.boostUnwatched:
        return '조회수가 낮은 게시물이 더 자주 노출됩니다';
      case LoopViewCountMode.boostWatched:
        return '조회수가 높은 게시물이 더 자주 노출됩니다';
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

  /// 즐겨찾기 이벤트 추가 가중치 (0~10)
  final int favoriteWeight;
  /// N년 전 오늘 / N×100일 이벤트 추가 가중치 (0~10)
  final int onThisDayWeight;
  /// 최근 30일 이내 이벤트 추가 가중치 (0~10)
  final int recentWeight;
  /// 모든 이벤트의 기본 가중치 (1~10)
  final int baseWeight;
  /// 조회수 반영 방식
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
