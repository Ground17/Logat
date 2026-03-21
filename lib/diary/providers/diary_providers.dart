import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../database/app_database.dart';
import '../models/daily_stats.dart';
import '../models/date_range_filter.dart';
import '../models/diary_filter.dart';
import '../models/event_summary.dart';
import '../models/folder.dart';
import '../models/indexing_progress.dart';
import '../models/location_cluster.dart';
import '../models/location_filter.dart';
import '../models/recommendation_settings.dart';
import '../repositories/diary_repository.dart';
import '../repositories/folder_repository.dart';
import '../repositories/photo_library_repository.dart';
import '../repositories/photo_metadata_repository.dart';
import '../services/ai_recommendation_service.dart';
import '../services/event_generation_service.dart';
import '../services/event_grouping_service.dart';
import '../services/geocoding_service.dart';
import '../services/memories_notification_service.dart';
import '../services/photo_indexing_service.dart';
import '../services/recommendation_settings_service.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

final mapControllerProvider = StateProvider<GoogleMapController?>((ref) => null);

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final database = AppDatabase();
  ref.onDispose(database.close);
  return database;
});

final photoLibraryRepositoryProvider = Provider((ref) {
  return PhotoLibraryRepository();
});

final photoMetadataRepositoryProvider = Provider((ref) {
  return PhotoMetadataRepository(ref.watch(appDatabaseProvider));
});

final eventGenerationServiceProvider = Provider((ref) {
  return const EventGenerationService();
});

final eventGroupingServiceProvider = Provider((ref) {
  return const EventGroupingService();
});

final diaryRepositoryProvider = Provider((ref) {
  return DiaryRepository(
    photoMetadataRepository: ref.watch(photoMetadataRepositoryProvider),
    eventGroupingService: ref.watch(eventGroupingServiceProvider),
    database: ref.watch(appDatabaseProvider),
  );
});

final photoIndexingServiceProvider = Provider((ref) {
  return PhotoIndexingService(
    photoLibraryRepository: ref.watch(photoLibraryRepositoryProvider),
    photoMetadataRepository: ref.watch(photoMetadataRepositoryProvider),
    eventGenerationService: ref.watch(eventGenerationServiceProvider),
  );
});

final folderRepositoryProvider = Provider((ref) {
  return FolderRepository(ref.watch(appDatabaseProvider));
});

final memoriesNotificationServiceProvider = Provider((ref) {
  return MemoriesNotificationService();
});

final aiRecommendationServiceProvider = Provider((ref) {
  return const AiRecommendationService();
});

final recommendationSettingsServiceProvider = Provider((ref) {
  return RecommendationSettingsService();
});

// ─── Recommendation settings state ───────────────────────────────────────

class RecommendationSettingsNotifier
    extends StateNotifier<RecommendationSettings> {
  RecommendationSettingsNotifier(this._service)
      : super(const RecommendationSettings()) {
    _load();
  }

  final RecommendationSettingsService _service;

  Future<void> _load() async {
    state = await _service.load();
  }

  Future<void> update(RecommendationSettings settings) async {
    await _service.save(settings);
    state = settings;
  }
}

final recommendationSettingsProvider = StateNotifierProvider<
    RecommendationSettingsNotifier, RecommendationSettings>((ref) {
  return RecommendationSettingsNotifier(
    ref.watch(recommendationSettingsServiceProvider),
  );
});

// ─── AI recommendations ───────────────────────────────────────────────────

final aiRecommendationsProvider =
    FutureProvider<List<DiaryRecommendation>>((ref) async {
  final settings = ref.watch(recommendationSettingsProvider);
  if (!settings.enabled) return const [];

  final service = ref.watch(aiRecommendationServiceProvider);
  final repository = ref.watch(diaryRepositoryProvider);

  final now = DateTime.now();
  final rangeStart = now.toUtc().subtract(const Duration(days: 30));
  final rangeEnd = now.toUtc().add(const Duration(days: 1));

  final recentEvents = await repository.eventsInRange(
    start: rangeStart,
    end: rangeEnd,
  );
  final onThisDayEvents = await repository.eventsOnThisDay(
    month: now.month,
    day: now.day,
    currentYear: now.year,
  );
  final clusters = await repository.locationClusters();

  return service.generate(
    recentEvents: recentEvents,
    onThisDayEvents: onThisDayEvents,
    clusters: clusters,
    settings: settings,
  );
});

final permissionStateProvider = FutureProvider<PermissionState>((ref) {
  return ref.watch(photoLibraryRepositoryProvider).permissionState();
});

final selectedDateProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now().toUtc();
  return DateTime.utc(now.year, now.month, now.day);
});

class DateRangeFilterNotifier extends StateNotifier<DateRangeFilter> {
  static DateRangeFilter _defaultRange() {
    final now = DateTime.now().toUtc();
    return DateRangeFilter(
      start: DateTime.utc(now.year, now.month - 1, now.day),
      end: DateTime.utc(now.year, now.month, now.day + 1),
    );
  }

  DateRangeFilterNotifier() : super(_defaultRange()) {
    _load();
  }

  Future<void> _load() async {
    state = await DateRangeFilter.load();
  }

  Future<void> update(DateRangeFilter filter) async {
    state = filter;
    await filter.save();
  }
}

final dateRangeFilterProvider =
    StateNotifierProvider<DateRangeFilterNotifier, DateRangeFilter>(
  (ref) => DateRangeFilterNotifier(),
);

final locationFilterProvider = StateProvider<LocationFilter?>((ref) => null);

/// When non-null, DiaryHomeScreen switches to this tab index and resets to null.
final pendingTabProvider = StateProvider<int?>((ref) => null);

final indexingControllerProvider =
    StateNotifierProvider<IndexingController, IndexingProgress>((ref) {
  return IndexingController(
    photoLibraryRepository: ref.watch(photoLibraryRepositoryProvider),
    photoIndexingService: ref.watch(photoIndexingServiceProvider),
  );
});

final dailyStatsProvider = FutureProvider((ref) {
  final repository = ref.watch(diaryRepositoryProvider);
  final filter = ref.watch(dateRangeFilterProvider);
  final locationFilter = ref.watch(locationFilterProvider);
  return repository.dailyStats(
    start: filter.start,
    end: filter.end,
    locationFilter: locationFilter,
  );
});

final diaryCandidatesProvider = FutureProvider((ref) {
  final repository = ref.watch(diaryRepositoryProvider);
  final day = ref.watch(selectedDateProvider);
  final locationFilter = ref.watch(locationFilterProvider);
  return repository.recommendationCandidates(
    day: day,
    locationFilter: locationFilter,
  );
});

final indexedAssetCountProvider = FutureProvider((ref) {
  return ref.watch(diaryRepositoryProvider).indexedAssetCount();
});

final locationClustersProvider = FutureProvider((ref) {
  return ref.watch(diaryRepositoryProvider).locationClusters();
});

final mapEventsProvider = FutureProvider((ref) {
  final repository = ref.watch(diaryRepositoryProvider);
  final filter = ref.watch(dateRangeFilterProvider);
  final locationFilter = ref.watch(locationFilterProvider);
  return repository.eventsInRange(
    start: filter.start,
    end: filter.end,
    locationFilter: locationFilter,
  );
});

final tagSummariesProvider = FutureProvider((ref) {
  final repository = ref.watch(diaryRepositoryProvider);
  final filter = ref.watch(dateRangeFilterProvider);
  final locationFilter = ref.watch(locationFilterProvider);
  return repository.tagSummaries(
    start: filter.start,
    end: filter.end,
    locationFilter: locationFilter,
  );
});

final onThisDayProvider = FutureProvider<List<EventSummary>>((ref) {
  final now = DateTime.now();
  return ref.watch(diaryRepositoryProvider).eventsOnThisDay(
        month: now.month,
        day: now.day,
        currentYear: now.year,
      );
});

// 항상 오늘 기준 365일 - dateRangeFilter와 무관
final yearlyDailyStatsProvider = FutureProvider<List<DailyStats>>((ref) {
  final now = DateTime.now().toUtc();
  final start = DateTime.utc(now.year - 1, now.month, now.day);
  final end = DateTime.utc(now.year, now.month, now.day + 1);
  return ref.watch(diaryRepositoryProvider).dailyStats(start: start, end: end);
});

// family: (year, month) → DailyStats 리스트
final monthlyStatsProvider =
    FutureProvider.family<List<DailyStats>, (int, int)>((ref, ym) {
  final (year, month) = ym;
  final start = DateTime.utc(year, month, 1);
  final end = DateTime.utc(year, month + 1, 1);
  return ref.watch(diaryRepositoryProvider).dailyStats(start: start, end: end);
});

// LocationCluster에 주소 레이블을 붙인 확장 데이터 (TOP 5)
final enrichedLocationClustersProvider = FutureProvider<
    List<({LocationCluster cluster, String address})>>((ref) async {
  final clusters = await ref.watch(locationClustersProvider.future);
  final svc = GeocodingService();
  return Future.wait(clusters.take(5).map((c) async {
    final address = await svc.reverseGeocode(c.latitude, c.longitude);
    return (cluster: c, address: address);
  }));
});

final enrichedLocationClustersInRangeProvider = FutureProvider.family<
    List<({LocationCluster cluster, String address})>,
    DateRangeFilter>((ref, range) async {
  final clusters =
      await ref.watch(diaryRepositoryProvider).locationClustersInRange(
            start: range.start,
            end: range.end,
          );
  final svc = GeocodingService();
  return Future.wait(clusters.take(5).map((c) async {
    final address = await svc.reverseGeocode(c.latitude, c.longitude);
    return (cluster: c, address: address);
  }));
});

// ─── Folder providers ─────────────────────────────────────────────────────

final folderListProvider =
    FutureProvider.family<List<DiaryFolder>, String?>((ref, parentId) {
  return ref.watch(folderRepositoryProvider).listFolders(parentId: parentId);
});

final eventFoldersProvider =
    FutureProvider.family<List<DiaryFolder>, String>((ref, eventId) {
  return ref.watch(appDatabaseProvider).getFoldersForEvent(eventId);
});

final allFoldersProvider = FutureProvider<List<DiaryFolder>>((ref) {
  return ref.watch(appDatabaseProvider).getAllFolders();
});

final folderContentsProvider =
    FutureProvider.family<List<EventSummary>, String>((ref, folderId) {
  return ref.watch(folderRepositoryProvider).folderContents(folderId);
});

// ─── Diary filter ─────────────────────────────────────────────────────────

class DiaryFilterNotifier extends StateNotifier<DiaryFilter> {
  DiaryFilterNotifier() : super(const DiaryFilter()) {
    _load();
  }

  Future<void> _load() async {
    state = await DiaryFilter.load();
  }

  Future<void> update(DiaryFilter filter) async {
    state = filter;
    await filter.save();
  }
}

final diaryFilterProvider =
    StateNotifierProvider<DiaryFilterNotifier, DiaryFilter>(
  (ref) => DiaryFilterNotifier(),
);

List<EventSummary> _applyFilter(
  List<EventSummary> events,
  DiaryFilter filter,
  DateTime selectedDate,
) {
  return events.where((e) {
    if (filter.searchText.isNotEmpty) {
      final text = filter.searchText.toLowerCase();
      final titleMatch = e.title?.toLowerCase().contains(text) ?? false;
      final memoMatch = e.userMemo?.toLowerCase().contains(text) ?? false;
      if (!titleMatch && !memoMatch) return false;
    }
    if (filter.similarDate) {
      final local = e.startAt.toLocal();
      final dayDiff = (local.month * 31 + local.day) -
          (selectedDate.month * 31 + selectedDate.day);
      if (dayDiff.abs() > 7) return false;
    }
    if (filter.favoritesOnly && !e.isFavorite) return false;
    if (filter.hasLocation && (e.latitude == null || e.longitude == null)) {
      return false;
    }
    if (filter.hasMedia &&
        (e.representativeAssetId == 'manual_no_photo' || e.assetCount == 0)) {
      return false;
    }
    return true;
  }).toList();
}

final filteredJournalEventsProvider = FutureProvider<List<EventSummary>>((ref) async {
  final events = await ref.watch(mapEventsProvider.future);
  final filter = ref.watch(diaryFilterProvider);
  final selectedDate = ref.watch(selectedDateProvider);
  return _applyFilter(events, filter, selectedDate);
});

// ─── View mode ────────────────────────────────────────────────────────────

enum DiaryViewMode { list, map }

class ViewModeNotifier extends StateNotifier<DiaryViewMode> {
  ViewModeNotifier() : super(DiaryViewMode.list) {
    _loadFromPrefs();
  }

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getString('diary_view_mode') == 'map') {
      state = DiaryViewMode.map;
    }
  }

  Future<void> setMode(DiaryViewMode mode) async {
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('diary_view_mode', mode.name);
  }
}

final diaryViewModeProvider =
    StateNotifierProvider<ViewModeNotifier, DiaryViewMode>(
  (ref) => ViewModeNotifier(),
);

// ─── Notification time ────────────────────────────────────────────────────

class NotificationTimeNotifier extends StateNotifier<TimeOfDay> {
  NotificationTimeNotifier(this._service)
      : super(const TimeOfDay(hour: 9, minute: 0)) {
    _loadFromPrefs();
  }

  final MemoriesNotificationService _service;

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final hour = prefs.getInt('diary_memories_notification_hour') ?? 9;
    final minute = prefs.getInt('diary_memories_notification_minute') ?? 0;
    state = TimeOfDay(hour: hour, minute: minute);
  }

  Future<void> setTime(TimeOfDay time) async {
    state = time;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('diary_memories_notification_hour', time.hour);
    await prefs.setInt('diary_memories_notification_minute', time.minute);
    final enabled =
        prefs.getBool('diary_memories_notification_enabled') ?? false;
    if (enabled) {
      await _service.scheduleDaily(hour: time.hour, minute: time.minute);
    }
  }
}

final notificationTimeProvider =
    StateNotifierProvider<NotificationTimeNotifier, TimeOfDay>((ref) {
  return NotificationTimeNotifier(
    ref.watch(memoriesNotificationServiceProvider),
  );
});

// ─── Indexing controller ──────────────────────────────────────────────────

class IndexingController extends StateNotifier<IndexingProgress> {
  IndexingController({
    required this.photoLibraryRepository,
    required this.photoIndexingService,
  }) : super(const IndexingProgress.idle());

  final PhotoLibraryRepository photoLibraryRepository;
  final PhotoIndexingService photoIndexingService;

  Future<void> requestPermissionAndIndex() async {
    final permission = await photoLibraryRepository.requestPermission();
    if (!permission.isAuth) {
      state = const IndexingProgress(
        status: 'error',
        scannedCount: 0,
        insertedCount: 0,
        skippedCount: 0,
        currentPage: 0,
        message: 'Photo permission denied.',
      );
      return;
    }

    state = const IndexingProgress(
      status: 'running',
      scannedCount: 0,
      insertedCount: 0,
      skippedCount: 0,
      currentPage: 0,
      message: 'Starting metadata indexing...',
    );

    try {
      final result = await photoIndexingService.run(
        onProgress: (progress) => state = progress,
      );
      state = result;
    } catch (error) {
      state = IndexingProgress(
        status: 'error',
        scannedCount: state.scannedCount,
        insertedCount: state.insertedCount,
        skippedCount: state.skippedCount,
        currentPage: state.currentPage,
        message: error.toString(),
      );
    }
  }
}
