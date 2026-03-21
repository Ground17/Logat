import 'heuristic_tag.dart';

class EventSummary {
  const EventSummary({
    required this.eventId,
    required this.startAt,
    required this.endAt,
    required this.assetCount,
    required this.representativeAssetId,
    required this.qualityScore,
    required this.isMoving,
    required this.assetIds,
    required this.tags,
    this.latitude,
    this.longitude,
    this.isManual = false,
    this.title,
    this.userMemo,
    this.isFavorite = false,
    this.color,
    this.customAddress,
  });

  final String eventId;
  final DateTime startAt;
  final DateTime endAt;
  final double? latitude;
  final double? longitude;
  final int assetCount;
  final String representativeAssetId;
  final double qualityScore;
  final bool isMoving;
  final List<String> assetIds;
  final List<HeuristicTag> tags;
  final bool isManual;
  final String? title;
  final String? userMemo;
  final bool isFavorite;
  final int? color; // Color.value (0xFFRRGGBB), null = default color
  final String? customAddress; // user-overridden address text

  Duration get duration => endAt.difference(startAt);
}
