import 'heuristic_tag.dart';

class PhotoEvent {
  const PhotoEvent({
    required this.startAt,
    required this.endAt,
    required this.assetIds,
    required this.assetCount,
    required this.photoCount,
    required this.videoCount,
    required this.representativeAssetId,
    required this.qualityScore,
    required this.isMoving,
    required this.tags,
    this.latitude,
    this.longitude,
  });

  final DateTime startAt;
  final DateTime endAt;
  final List<String> assetIds;
  final int assetCount;
  final int photoCount;
  final int videoCount;
  final String representativeAssetId;
  final double qualityScore;
  final bool isMoving;
  final List<HeuristicTag> tags;
  final double? latitude;
  final double? longitude;

  Duration get duration => endAt.difference(startAt);
}
