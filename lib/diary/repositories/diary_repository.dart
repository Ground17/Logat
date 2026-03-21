import '../database/app_database.dart';
import '../models/daily_stats.dart';
import '../models/diary_candidate.dart';
import '../models/event_summary.dart';
import '../models/location_cluster.dart';
import '../models/location_filter.dart';
import '../models/tag_summary.dart';
import '../services/event_grouping_service.dart';
import 'photo_metadata_repository.dart';

class DiaryRepository {
  const DiaryRepository({
    required this.photoMetadataRepository,
    required this.eventGroupingService,
    required this.database,
  });

  final PhotoMetadataRepository photoMetadataRepository;
  final EventGroupingService eventGroupingService;
  final AppDatabase database;

  Future<List<DailyStats>> dailyStats({
    required DateTime start,
    required DateTime end,
    LocationFilter? locationFilter,
  }) {
    return photoMetadataRepository.dailyStats(
      start: start,
      end: end,
      locationFilter: locationFilter,
    );
  }

  Future<List<DiaryCandidate>> recommendationCandidates({
    required DateTime day,
    LocationFilter? locationFilter,
  }) async {
    final events = await photoMetadataRepository.eventsForDay(
      day: day,
      locationFilter: locationFilter,
    );
    return eventGroupingService.buildCandidates(events);
  }

  Future<List<EventSummary>> eventsInRange({
    required DateTime start,
    required DateTime end,
    LocationFilter? locationFilter,
  }) {
    return photoMetadataRepository.eventsInRange(
      start: start,
      end: end,
      locationFilter: locationFilter,
    );
  }

  Future<List<LocationCluster>> locationClusters() {
    return photoMetadataRepository.locationClusters();
  }

  Future<List<LocationCluster>> locationClustersInRange({
    required DateTime start,
    required DateTime end,
  }) {
    return photoMetadataRepository.locationClustersInRange(
      start: start,
      end: end,
    );
  }

  Future<List<TagSummary>> tagSummaries({
    required DateTime start,
    required DateTime end,
    LocationFilter? locationFilter,
  }) {
    return photoMetadataRepository.tagSummaries(
      start: start,
      end: end,
      locationFilter: locationFilter,
    );
  }

  Future<int> indexedAssetCount() {
    return photoMetadataRepository.indexedAssetCount();
  }

  Future<void> createManualRecord({
    required String eventId,
    required DateTime startAt,
    required DateTime endAt,
    required String title,
    String? userMemo,
    double? latitude,
    double? longitude,
    List<String> assetIds = const [],
  }) {
    return database.insertManualEvent(
      eventId: eventId,
      startAt: startAt,
      endAt: endAt,
      title: title,
      userMemo: userMemo,
      latitude: latitude,
      longitude: longitude,
      assetIds: assetIds,
    );
  }

  Future<List<EventSummary>> eventsOnThisDay({
    required int month,
    required int day,
    required int currentYear,
    int windowDays = 7,
  }) {
    return database.queryEventsOnThisDay(
      month: month,
      day: day,
      windowDays: windowDays,
      currentYear: currentYear,
    );
  }

  Future<void> toggleRecordFavorite(String eventId, bool value) {
    return database.updateEventFavorite(eventId, value);
  }
}
