import 'dart:math' as math;

import '../database/app_database.dart';
import '../models/heuristic_tag.dart';

class EventGenerationResult {
  const EventGenerationResult({
    required this.events,
    required this.assetTags,
  });

  final List<PersistedEventRecord> events;
  final Map<String, List<String>> assetTags;
}

class EventGenerationService {
  const EventGenerationService({
    this.timeGapThreshold = const Duration(minutes: 60),
    this.distanceThresholdKm = 1.5,
  });

  final Duration timeGapThreshold;
  final double distanceThresholdKm;

  EventGenerationResult buildFromRows(List<Map<String, Object?>> rows) {
    if (rows.isEmpty) {
      return const EventGenerationResult(events: [], assetTags: {});
    }

    final assetTags = <String, List<String>>{};
    final events = <PersistedEventRecord>[];
    final bucket = <Map<String, Object?>>[];

    void flush() {
      if (bucket.isEmpty) {
        return;
      }
      final event = _buildEvent(bucket, assetTags);
      events.add(event);
      bucket.clear();
    }

    for (final row in rows) {
      if (bucket.isEmpty) {
        bucket.add(row);
        continue;
      }

      final previous = bucket.last;
      final prevAt = _readDate(previous['created_at']! as int);
      final currentAt = _readDate(row['created_at']! as int);
      final timeGap = currentAt.difference(prevAt);
      final distance = _distanceKm(
        previous['latitude'] as double?,
        previous['longitude'] as double?,
        row['latitude'] as double?,
        row['longitude'] as double?,
      );

      if (timeGap > timeGapThreshold ||
          (distance != null && distance > distanceThresholdKm)) {
        flush();
      }
      bucket.add(row);
    }
    flush();

    return EventGenerationResult(events: events, assetTags: assetTags);
  }

  PersistedEventRecord _buildEvent(
    List<Map<String, Object?>> rows,
    Map<String, List<String>> assetTags,
  ) {
    final first = rows.first;
    final last = rows.last;
    final assetIds = rows.map((row) => row['asset_id']! as String).toList();
    final representative = _selectRepresentative(rows);
    final latitudes = rows
        .map((row) => row['latitude'] as double?)
        .whereType<double>()
        .toList();
    final longitudes = rows
        .map((row) => row['longitude'] as double?)
        .whereType<double>()
        .toList();
    final latitude = latitudes.isEmpty
        ? null
        : latitudes.reduce((a, b) => a + b) / latitudes.length;
    final longitude = longitudes.isEmpty
        ? null
        : longitudes.reduce((a, b) => a + b) / longitudes.length;
    final videoCount = rows.where((row) => row['media_type'] == 'video').length;

    final tagIds = <String>{};
    for (final row in rows) {
      final rowTags = <String>[
        if ((row['is_favorite'] as int?) == 1) 'favorite',
        if (row['media_type'] == 'video') 'video',
        if (_isNight(_readDate(row['created_at']! as int))) 'night',
      ];
      assetTags[row['asset_id']! as String] = rowTags;
      tagIds.addAll(rowTags);
    }

    final movementDistance = _distanceKm(
      first['latitude'] as double?,
      first['longitude'] as double?,
      last['latitude'] as double?,
      last['longitude'] as double?,
    );
    final isMoving =
        movementDistance != null && movementDistance > distanceThresholdKm;
    if (rows.length >= 20) {
      tagIds.add('dense');
    }

    final eventId =
        'evt_${(first['asset_id']! as String).replaceAll('/', '_')}_${rows.length}';
    final qualityScore = rows.length +
        (videoCount * 0.75) +
        (tagIds.contains('favorite') ? 1.2 : 0) +
        (isMoving ? 1.5 : 0) +
        ((last['created_at']! as int) - (first['created_at']! as int)) /
            1800000.0;

    return PersistedEventRecord(
      eventId: eventId,
      startAt: _readDate(first['created_at']! as int),
      endAt: _readDate(last['created_at']! as int),
      latitude: latitude,
      longitude: longitude,
      assetCount: rows.length,
      representativeAssetId: representative,
      qualityScore: qualityScore,
      isMoving: isMoving,
      assetIds: assetIds,
      tags: tagIds.map(_toTag).toList(),
    );
  }

  String _selectRepresentative(List<Map<String, Object?>> rows) {
    final favorite = rows.cast<Map<String, Object?>>().firstWhere(
          (row) => (row['is_favorite'] as int?) == 1,
          orElse: () => rows[rows.length ~/ 2],
        );
    return favorite['asset_id']! as String;
  }

  HeuristicTag _toTag(String tagId) {
    switch (tagId) {
      case 'favorite':
        return const HeuristicTag(
          id: 'favorite',
          name: 'Favorite',
          type: 'emotion',
          confidence: 0.95,
        );
      case 'video':
        return const HeuristicTag(
          id: 'video',
          name: 'Video',
          type: 'activity',
          confidence: 0.8,
        );
      case 'night':
        return const HeuristicTag(
          id: 'night',
          name: 'Night',
          type: 'activity',
          confidence: 0.82,
        );
      case 'weekend':
        return const HeuristicTag(
          id: 'weekend',
          name: 'Weekend',
          type: 'activity',
          confidence: 0.9,
        );
      case 'travel':
        return const HeuristicTag(
          id: 'travel',
          name: 'Movement',
          type: 'activity',
          confidence: 0.88,
        );
      case 'dense':
        return const HeuristicTag(
          id: 'dense',
          name: 'Busy day',
          type: 'activity',
          confidence: 0.74,
        );
      default:
        return HeuristicTag(
          id: tagId,
          name: tagId,
          type: 'activity',
          confidence: 0.5,
        );
    }
  }

  bool _isNight(DateTime dateTime) => dateTime.hour >= 22 || dateTime.hour < 6;

  DateTime _readDate(int millis) =>
      DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true).toLocal();

  double? _distanceKm(
    double? lat1,
    double? lng1,
    double? lat2,
    double? lng2,
  ) {
    if (lat1 == null || lng1 == null || lat2 == null || lng2 == null) {
      return null;
    }
    const earthRadiusKm = 6371.0;
    final dLat = _toRadians(lat2 - lat1);
    final dLng = _toRadians(lng2 - lng1);
    final a = _sinSquared(dLat / 2) +
        _cosRadians(lat1) * _cosRadians(lat2) * _sinSquared(dLng / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusKm * c;
  }

  double _toRadians(double degree) => degree * 0.017453292519943295;

  double _sinSquared(double value) {
    final sinValue = math.sin(value);
    return sinValue * sinValue;
  }

  double _cosRadians(double degree) => math.cos(_toRadians(degree));
}
