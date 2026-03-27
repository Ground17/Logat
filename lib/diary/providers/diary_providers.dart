import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:location/location.dart' as loc_pkg;
import 'package:photo_manager/photo_manager.dart' hide LatLng;
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
import '../models/loop_algorithm_settings.dart';
import '../models/recommendation_settings.dart';
import '../repositories/diary_repository.dart';
import '../repositories/folder_repository.dart';
import '../repositories/photo_library_repository.dart';
import '../repositories/photo_metadata_repository.dart';
import '../services/ai_recommendation_service.dart';
import '../services/event_generation_service.dart';
import '../services/event_grouping_service.dart';
import '../services/geocoding_service.dart';
import '../services/photo_indexing_service.dart';
import '../services/recommendation_settings_service.dart';
import '../services/view_count_service.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

final mapControllerProvider = StateProvider<GoogleMapController?>((ref) => null);

// ─── User location ────────────────────────────────────────────────────────

/// Current user location (LatLng?). Null if permission denied or failed.
final userLocationProvider = FutureProvider<LatLng?>((ref) async {
  try {
    final location = loc_pkg.Location();
    final permission = await location.hasPermission();
    if (permission == loc_pkg.PermissionStatus.denied ||
        permission == loc_pkg.PermissionStatus.deniedForever) {
      return null;
    }
    final data = await location.getLocation();
    if (data.latitude != null && data.longitude != null) {
      return LatLng(data.latitude!, data.longitude!);
    }
  } catch (_) {}
  return null;
});

/// Haversine distance calculation (km)
double distanceKm(
    double lat1, double lon1, double lat2, double lon2) {
  const r = 6371.0;
  final dLat = (lat2 - lat1) * pi / 180;
  final dLon = (lon2 - lon1) * pi / 180;
  final a = sin(dLat / 2) * sin(dLat / 2) +
      cos(lat1 * pi / 180) *
          cos(lat2 * pi / 180) *
          sin(dLon / 2) *
          sin(dLon / 2);
  return r * 2 * atan2(sqrt(a), sqrt(1 - a));
}

/// Distance label (< Xkm style). Empty string if too far.
String formatDistanceLabel(double km) {
  if (km < 0.1) return '< 100m';
  if (km < 0.5) return '< 500m';
  if (km < 1) return '< 1km';
  if (km < 2) return '< 2km';
  if (km < 5) return '< 5km';
  if (km < 10) return '< 10km';
  if (km < 20) return '< 20km';
  if (km < 50) return '< 50km';
  if (km < 100) return '< 100km';
  return '';
}

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
  DateRangeFilterNotifier()
      : super(DateRangeFilter.relative(1, RelativeDateUnit.months)) {
    _load();
  }

  Future<void> _load() async {
    state = await DateRangeFilter.load();
  }

  Future<void> update(DateRangeFilter filter) async {
    state = filter;
    await filter.save();
  }

  Future<void> resetToDefault() async {
    final def = await DateRangeFilter.loadDefault();
    state = def;
    await def.save();
  }
}

final dateRangeFilterProvider =
    StateNotifierProvider<DateRangeFilterNotifier, DateRangeFilter>(
  (ref) => DateRangeFilterNotifier(),
);

final locationFilterProvider = StateProvider<LocationFilter?>((ref) => null);

/// When non-null, DiaryHomeScreen switches to this tab index and resets to null.
final pendingTabProvider = StateProvider<int?>((ref) => null);

final gridColumnCountProvider = StateProvider<int>((ref) => 3);

// ─── Tab order ────────────────────────────────────────────────────────────

class TabOrderNotifier extends StateNotifier<List<int>> {
  TabOrderNotifier() : super(const [0, 1, 2, 3, 4]) {
    _load();
  }

  static const _key = 'tab_order';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final str = prefs.getString(_key);
    if (str == null) return;
    final parts = str.split(',');
    if (parts.length != 5) return;
    final parsed = parts.map(int.tryParse).toList();
    if (parsed.any((v) => v == null)) return;
    final order = parsed.cast<int>();
    if (order.toSet().length != 5) return;
    state = order;
  }

  Future<void> setOrder(List<int> order) async {
    state = List.unmodifiable(order);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, order.join(','));
  }
}

final tabOrderProvider =
    StateNotifierProvider<TabOrderNotifier, List<int>>((ref) {
  return TabOrderNotifier();
});

// ─── Loop algorithm settings ──────────────────────────────────────────────

class LoopAlgorithmSettingsNotifier
    extends StateNotifier<LoopAlgorithmSettings> {
  LoopAlgorithmSettingsNotifier() : super(const LoopAlgorithmSettings()) {
    _load();
  }

  Future<void> _load() async {
    state = await LoopAlgorithmSettings.load();
  }

  Future<void> update(LoopAlgorithmSettings settings) async {
    await settings.save();
    state = settings;
  }
}

final loopAlgorithmSettingsProvider =
    StateNotifierProvider<LoopAlgorithmSettingsNotifier, LoopAlgorithmSettings>(
  (ref) => LoopAlgorithmSettingsNotifier(),
);

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

final lastIndexingDateProvider = FutureProvider<DateTime?>((ref) {
  return ref.watch(appDatabaseProvider).getLastIndexingCompletedAt();
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

// Always 365 days from today — independent of dateRangeFilter
final yearlyDailyStatsProvider = FutureProvider<List<DailyStats>>((ref) {
  final now = DateTime.now().toUtc();
  final start = DateTime.utc(now.year - 1, now.month, now.day);
  final end = DateTime.utc(now.year, now.month, now.day + 1);
  return ref.watch(diaryRepositoryProvider).dailyStats(start: start, end: end);
});

// family: year → DailyStats list
final yearlyStatsProvider =
    FutureProvider.family<List<DailyStats>, int>((ref, year) {
  final start = DateTime.utc(year, 1, 1);
  final end = DateTime.utc(year + 1, 1, 1);
  return ref.watch(diaryRepositoryProvider).dailyStats(start: start, end: end);
});

// family: year → LocationCluster list
final yearlyLocationClustersProvider =
    FutureProvider.family<List<LocationCluster>, int>((ref, year) {
  final start = DateTime.utc(year, 1, 1);
  final end = DateTime.utc(year + 1, 1, 1);
  return ref
      .watch(diaryRepositoryProvider)
      .locationClustersInRange(start: start, end: end);
});

// family: (year, month) → LocationCluster list
final monthlyLocationClustersProvider =
    FutureProvider.family<List<LocationCluster>, (int, int)>((ref, ym) {
  final (year, month) = ym;
  final start = DateTime.utc(year, month, 1);
  final end = DateTime.utc(year, month + 1, 1);
  return ref
      .watch(diaryRepositoryProvider)
      .locationClustersInRange(start: start, end: end);
});

// family: (year, month) → DailyStats list
final monthlyStatsProvider =
    FutureProvider.family<List<DailyStats>, (int, int)>((ref, ym) {
  final (year, month) = ym;
  final start = DateTime.utc(year, month, 1);
  final end = DateTime.utc(year, month + 1, 1);
  return ref.watch(diaryRepositoryProvider).dailyStats(start: start, end: end);
});

// LocationCluster enriched with address labels (TOP 5)
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
    if (filter.similarDate || filter.isMilestoneDay) {
      final local = e.startAt.toLocal();
      final dayDiff = (local.month * 31 + local.day) -
          (selectedDate.month * 31 + selectedDate.day);
      final matchesSimilar = filter.similarDate && dayDiff.abs() <= 7;
      final matchesMilestone =
          filter.isMilestoneDay && _isMilestoneDayCheck(e.startAt);
      if (!matchesSimilar && !matchesMilestone) return false;
    }
    if (filter.favoritesOnly && !e.isFavorite) return false;
    if (filter.hasLocation && (e.latitude == null || e.longitude == null)) {
      return false;
    }
    if (filter.colorFilters.isNotEmpty) {
      if (e.color == null || !filter.colorFilters.contains(e.color)) {
        return false;
      }
    }
    return true;
  }).toList();
}

final selectedFolderFilterProvider = StateProvider<DiaryFolder?>((_) => null);

// In-memory edits made in EventDetailScreen — applied on top of DB data
// so changes are visible immediately without a full re-query.
final eventPatchProvider =
    StateProvider<Map<String, EventSummary>>((ref) => const {});

final filteredJournalEventsProvider = FutureProvider<List<EventSummary>>((ref) async {
  final events = await ref.watch(mapEventsProvider.future);
  final filter = ref.watch(diaryFilterProvider);
  final selectedDate = ref.watch(selectedDateProvider);
  var filtered = _applyFilter(events, filter, selectedDate);

  // Async media-type filters (requires DB lookup)
  if (filter.hasPhoto || filter.hasVideo) {
    final db = ref.read(appDatabaseProvider);
    if (filter.hasPhoto) {
      final ids = await db.getEventIdsWithMediaType('image');
      filtered = filtered.where((e) => ids.contains(e.eventId)).toList();
    }
    if (filter.hasVideo) {
      final ids = await db.getEventIdsWithMediaType('video');
      filtered = filtered.where((e) => ids.contains(e.eventId)).toList();
    }
  }

  final folderFilter = ref.watch(selectedFolderFilterProvider);
  if (folderFilter != null) {
    final folderContents = await ref.watch(
      folderContentsProvider(folderFilter.folderId).future,
    );
    final folderEventIds = {for (final e in folderContents) e.eventId};
    filtered = filtered.where((e) => folderEventIds.contains(e.eventId)).toList();
  }

  // Apply in-memory patches so detail-screen edits are visible immediately.
  final patches = ref.watch(eventPatchProvider);
  if (patches.isNotEmpty) {
    filtered = filtered.map((e) => patches[e.eventId] ?? e).toList();
  }

  return filtered;
});

// ─── View mode ────────────────────────────────────────────────────────────

enum DiaryViewMode { list, map, loop }

class ViewModeNotifier extends StateNotifier<DiaryViewMode> {
  ViewModeNotifier() : super(DiaryViewMode.list) {
    _loadFromPrefs();
  }

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('diary_view_mode');
    if (saved == 'map') state = DiaryViewMode.map;
    if (saved == 'reel' || saved == 'loop') state = DiaryViewMode.loop;
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

bool _isMilestoneDayCheck(DateTime eventDate) {
  final today = DateTime.now().toLocal();
  final local = eventDate.toLocal();
  final days = DateTime(today.year, today.month, today.day)
      .difference(DateTime(local.year, local.month, local.day))
      .inDays;
  if (days <= 0 || days > 10000) return false;
  return days < 1000 ? days % 100 == 0 : days % 1000 == 0;
}

bool _isSpecialDay(DateTime eventDate) {
  final today = DateTime.now().toLocal();
  final local = eventDate.toLocal();
  final days = DateTime(today.year, today.month, today.day)
      .difference(DateTime(local.year, local.month, local.day))
      .inDays;
  if (days <= 0) return false;
  if (days <= 10000 && (days < 1000 ? days % 100 == 0 : days % 1000 == 0)) return true;
  if (today.month == local.month && today.day == local.day) return true;
  return false;
}

// Maintains a stable weighted-random ordering of loop event IDs.
// Only re-randomises when the SET of eligible event IDs changes, so
// individual event edits never reset the loop position.
class LoopOrderNotifier extends StateNotifier<List<String>> {
  LoopOrderNotifier(this._ref) : super(const []) {
    _initialize();
  }

  final Ref _ref;
  Set<String> _lastEligibleIds = {};

  Future<void> _initialize() async {
    await _recompute();
    _ref.listen<AsyncValue<List<EventSummary>>>(
      filteredJournalEventsProvider,
      (_, next) {
        if (next.hasValue) _onEventsChanged(next.requireValue);
      },
    );
  }

  void _onEventsChanged(List<EventSummary> events) {
    final ids = events
        .where((e) => e.assetIds.any((id) => id != 'manual_no_photo'))
        .map((e) => e.eventId)
        .toSet();
    if (_sameSet(ids, _lastEligibleIds)) return; // only data changed → skip
    _recomputeFromEvents(events);
  }

  Future<void> _recompute() async {
    try {
      final events = await _ref.read(filteredJournalEventsProvider.future);
      await _recomputeFromEvents(events);
    } catch (_) {}
  }

  Future<void> _recomputeFromEvents(List<EventSummary> events) async {
    final algoSettings = _ref.read(loopAlgorithmSettingsProvider);
    final viewCounts = await ViewCountService.loadAll();

    final filtered = events
        .where((e) => e.assetIds.any((id) => id != 'manual_no_photo'))
        .toList();
    _lastEligibleIds = filtered.map((e) => e.eventId).toSet();

    if (filtered.isEmpty) {
      if (mounted) state = const [];
      return;
    }

    final totalViews = viewCounts.values.fold<int>(0, (s, v) => s + v);
    final avgViews =
        viewCounts.isEmpty ? 0.0 : totalViews / viewCounts.length;
    final rng = Random();
    final now = DateTime.now();

    final scored = filtered.map((e) {
      double weight = algoSettings.baseWeight.clamp(1, 10).toDouble();
      if (e.isFavorite) weight += algoSettings.favoriteWeight;
      if (_isSpecialDay(e.startAt)) weight += algoSettings.onThisDayWeight;
      final daysDiff = now.difference(e.startAt.toLocal()).inDays.abs();
      if (daysDiff <= 30) weight += algoSettings.recentWeight;
      final vc = viewCounts[e.eventId] ?? 0;
      switch (algoSettings.viewCountMode) {
        case LoopViewCountMode.boostUnwatched:
          if (vc == 0) {
            weight *= 1.5;
          } else if (vc > avgViews) {
            weight *= (1.0 / (1.0 + (vc - avgViews) * 0.05)).clamp(0.3, 1.0);
          }
        case LoopViewCountMode.boostWatched:
          if (vc > 0) weight *= (1.0 + log(1.0 + vc) * 0.3);
        case LoopViewCountMode.ignore:
          break;
      }
      final u = rng.nextDouble().clamp(1e-10, 1.0);
      final score = pow(u, 1.0 / weight.clamp(0.1, 30.0)) as double;
      return (eventId: e.eventId, score: score);
    }).toList();

    scored.sort((a, b) => b.score.compareTo(a.score));
    if (mounted) state = scored.map((s) => s.eventId).toList();
  }

  Future<void> forceRefresh() async {
    _lastEligibleIds = {};
    await _recompute();
  }

  static bool _sameSet<T>(Set<T> a, Set<T> b) {
    if (a.length != b.length) return false;
    return a.containsAll(b);
  }
}

final loopOrderedIdsProvider =
    StateNotifierProvider<LoopOrderNotifier, List<String>>(
  (ref) => LoopOrderNotifier(ref),
);

// Maps the stable ordered IDs to current event data (including patches).
// Re-builds when data changes but preserves the loop order.
final loopItemsProvider = FutureProvider<List<EventSummary>>((ref) async {
  final orderedIds = ref.watch(loopOrderedIdsProvider);
  if (orderedIds.isEmpty) {
    await ref.watch(filteredJournalEventsProvider.future);
    return [];
  }
  final events = await ref.watch(filteredJournalEventsProvider.future);
  final eventMap = {for (final e in events) e.eventId: e};
  return orderedIds
      .map((id) => eventMap[id])
      .whereType<EventSummary>()
      .toList();
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
