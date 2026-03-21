import '../database/app_database.dart';
import '../models/daily_stats.dart';
import '../models/event_summary.dart';
import '../models/indexing_state.dart';
import '../models/location_cluster.dart';
import '../models/location_filter.dart';
import '../models/photo_asset_metadata.dart';
import '../models/tag_summary.dart';

class PhotoMetadataRepository {
  const PhotoMetadataRepository(this._database);

  final AppDatabase _database;

  Future<void> upsertBatch(List<PhotoAssetMetadata> assets) {
    return _database.upsertPhotoAssets(assets);
  }

  Future<List<Map<String, Object?>>> loadAssetsInRange({
    required DateTime start,
    required DateTime end,
  }) {
    return _database.loadAssetsInRange(start: start, end: end);
  }

  Future<void> replaceEventsInRange({
    required DateTime start,
    required DateTime end,
    required List<PersistedEventRecord> events,
    required Map<String, List<String>> assetTags,
  }) {
    return _database.replaceEventsInRange(
      start: start,
      end: end,
      events: events,
      assetTags: assetTags,
    );
  }

  Future<IndexingStateModel> loadIndexingState() {
    return _database.loadIndexingState();
  }

  Future<void> startRun({
    required int resumePage,
    required DateTime? anchorCreatedAt,
    required String? anchorAssetId,
  }) {
    return _database.markIndexingStarted(
      resumePage: resumePage,
      anchorCreatedAt: anchorCreatedAt,
      anchorAssetId: anchorAssetId,
    );
  }

  Future<void> updateRunProgress({
    required int resumePage,
    required int scannedCount,
    required int insertedCount,
    required int skippedCount,
  }) {
    return _database.updateIndexingProgress(
      resumePage: resumePage,
      scannedCount: scannedCount,
      insertedCount: insertedCount,
      skippedCount: skippedCount,
    );
  }

  Future<void> finishRun({
    required DateTime? lastCompletedCreatedAt,
    required String? lastCompletedAssetId,
    required int scannedCount,
    required int insertedCount,
    required int skippedCount,
  }) {
    return _database.markIndexingCompleted(
      lastCompletedCreatedAt: lastCompletedCreatedAt,
      lastCompletedAssetId: lastCompletedAssetId,
      scannedCount: scannedCount,
      insertedCount: insertedCount,
      skippedCount: skippedCount,
    );
  }

  Future<void> failRun() {
    return _database.markIndexingFailed();
  }

  Future<List<DailyStats>> dailyStats({
    required DateTime start,
    required DateTime end,
    LocationFilter? locationFilter,
  }) {
    return _database.queryDailyStats(
      start: start,
      end: end,
      locationFilter: locationFilter,
    );
  }

  Future<List<EventSummary>> eventsForDay({
    required DateTime day,
    LocationFilter? locationFilter,
  }) {
    return _database.queryEventsForDay(
        day: day, locationFilter: locationFilter);
  }

  Future<List<EventSummary>> eventsInRange({
    required DateTime start,
    required DateTime end,
    LocationFilter? locationFilter,
  }) {
    return _database.queryEventsInRange(
      start: start,
      end: end,
      locationFilter: locationFilter,
    );
  }

  Future<List<LocationCluster>> locationClusters() {
    return _database.queryLocationClusters();
  }

  Future<List<LocationCluster>> locationClustersInRange({
    required DateTime start,
    required DateTime end,
  }) {
    return _database.queryLocationClustersInRange(start: start, end: end);
  }

  Future<List<TagSummary>> tagSummaries({
    required DateTime start,
    required DateTime end,
    LocationFilter? locationFilter,
  }) {
    return _database.queryTagSummaries(
      start: start,
      end: end,
      locationFilter: locationFilter,
    );
  }

  Future<int> indexedAssetCount() {
    return _database.countIndexedAssets();
  }
}
