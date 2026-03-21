class DailyStats {
  const DailyStats({
    required this.day,
    required this.assetCount,
    required this.eventCount,
    required this.photoCount,
    required this.videoCount,
    required this.nightRatio,
    required this.weekendRatio,
    required this.movingEventRatio,
  });

  final DateTime day;
  final int assetCount;
  final int eventCount;
  final int photoCount;
  final int videoCount;
  final double nightRatio;
  final double weekendRatio;
  final double movingEventRatio;
}
