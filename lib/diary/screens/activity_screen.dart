import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:photo_manager/photo_manager.dart';

import '../models/date_range_filter.dart';
import '../models/event_summary.dart';
import '../models/location_filter.dart';
import '../models/recommendation_settings.dart';
import '../providers/diary_providers.dart';
import '../widgets/heatmap_widget.dart';
import 'event_detail_screen.dart';
import 'manual_record_screen.dart';
import 'monthly_recap_screen.dart';
import 'share_customize_screen.dart';

class ActivityScreen extends ConsumerWidget {
  const ActivityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final permissionState = ref.watch(permissionStateProvider);
    final indexing = ref.watch(indexingControllerProvider);
    final indexedAssetCount = ref.watch(indexedAssetCountProvider);
    final recSettings = ref.watch(recommendationSettingsProvider);
    final onThisDay = ref.watch(onThisDayProvider);
    final yearlyStats = ref.watch(yearlyDailyStatsProvider);

    final isOnboarding =
        indexedAssetCount.valueOrNull == 0 && !indexing.isRunning;

    Future<void> runIndex() async {
      await ref
          .read(indexingControllerProvider.notifier)
          .requestPermissionAndIndex();
      ref.invalidate(permissionStateProvider);
      ref.invalidate(indexedAssetCountProvider);
      ref.invalidate(dailyStatsProvider);
      ref.invalidate(diaryCandidatesProvider);
      ref.invalidate(locationClustersProvider);
      ref.invalidate(mapEventsProvider);
      ref.invalidate(tagSummariesProvider);
      ref.invalidate(onThisDayProvider);
      ref.invalidate(yearlyDailyStatsProvider);
      ref.invalidate(filteredJournalEventsProvider);
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (isOnboarding) ...[
          _OnboardingBanner(onTap: runIndex),
          const SizedBox(height: 12),
        ],
        permissionState.when(
          data: (permission) => _PermissionCard(
            permission: permission,
            onManageLimitedAccess: () async {
              await PhotoManager.presentLimited();
              ref.invalidate(permissionStateProvider);
            },
            onOpenSettings: () async {
              await PhotoManager.openSetting();
            },
          ),
          loading: () => const LinearProgressIndicator(),
          error: (error, _) => Text('Permission check failed: $error'),
        ),
        const SizedBox(height: 12),
        if (!isOnboarding)
          _IndexingCard(
            indexingMessage: indexing.message ?? 'Ready',
            indexingLabel:
                'Scanned ${indexing.scannedCount} · Inserted ${indexing.insertedCount} · Skipped ${indexing.skippedCount}',
            indexedAssetCount: indexedAssetCount,
            isRunning: indexing.isRunning,
            fraction: indexing.fraction,
            onRun: runIndex,
          ),
        const SizedBox(height: 12),
        // Annual heatmap
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'Activity',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () {
                        final now = DateTime.now();
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => MonthlyRecapScreen(
                              year: now.year,
                              month: now.month,
                            ),
                          ),
                        );
                      },
                      child: const Text('Monthly Report →'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                yearlyStats.when(
                  data: (stats) => HeatmapWidget(
                    stats: stats,
                    onDayTap: (day) {
                      ref.read(selectedDateProvider.notifier).state =
                          DateTime.utc(day.year, day.month, day.day);
                      ref.invalidate(diaryCandidatesProvider);
                    },
                  ),
                  loading: () => const LinearProgressIndicator(),
                  error: (e, _) => Text('Failed: $e'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        _OnThisDayCard(onThisDayAsync: onThisDay),
        const SizedBox(height: 12),
        const _TopLocationsCard(),
        const SizedBox(height: 12),
        _AiRecommendationsCard(settingsEnabled: recSettings.enabled),
        const SizedBox(height: 32),
      ],
    );
  }
}

// ─── Onboarding banner ─────────────────────────────────────────────────────

class _OnboardingBanner extends StatelessWidget {
  const _OnboardingBanner({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.photo_library_outlined,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Get Started',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Allow photo access and index your library to automatically create diary events from your memories.',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: onTap,
              icon: const Icon(Icons.bolt_outlined),
              label: const Text('Allow & Index Photos'),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── N년 전 오늘 카드 ────────────────────────────────────────────────────────

class _OnThisDayCard extends StatelessWidget {
  const _OnThisDayCard({required this.onThisDayAsync});

  final AsyncValue<List<EventSummary>> onThisDayAsync;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'On This Day',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            onThisDayAsync.when(
              data: (events) => events.isEmpty
                  ? const Text('No memories for this day')
                  : Column(
                      children: events
                          .take(5)
                          .map((e) => _MemoryCard(event: e))
                          .toList(),
                    ),
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('Failed to load: $e'),
            ),
          ],
        ),
      ),
    );
  }
}

class _MemoryCard extends StatelessWidget {
  const _MemoryCard({required this.event});

  final EventSummary event;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final yearsAgo = now.year - event.startAt.toLocal().year;
    final formatter = DateFormat('MMM d');

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: event.representativeAssetId == 'manual_no_photo'
          ? const CircleAvatar(child: Icon(Icons.note_alt_outlined))
          : FutureBuilder<AssetEntity?>(
              future: AssetEntity.fromId(event.representativeAssetId),
              builder: (ctx, assetSnap) {
                if (!assetSnap.hasData) return const CircleAvatar();
                return FutureBuilder<Uint8List?>(
                  future: assetSnap.data!
                      .thumbnailDataWithSize(const ThumbnailSize(80, 80)),
                  builder: (ctx2, thumbSnap) {
                    if (!thumbSnap.hasData) return const CircleAvatar();
                    return CircleAvatar(
                      backgroundImage: MemoryImage(thumbSnap.data!),
                    );
                  },
                );
              },
            ),
      title: Text(event.title ?? '${event.assetCount} photos'),
      subtitle: Text(
          '$yearsAgo ${yearsAgo == 1 ? 'year' : 'years'} ago · ${formatter.format(event.startAt.toLocal())}'),
      trailing: IconButton(
        icon: const Icon(Icons.share_outlined, size: 18),
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ShareCustomizeScreen(event: event),
          ),
        ),
      ),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => EventDetailScreen(event: event)),
      ),
    );
  }
}

// ─── Top locations card ────────────────────────────────────────────────────

class _TopLocationsCard extends ConsumerStatefulWidget {
  const _TopLocationsCard();

  @override
  ConsumerState<_TopLocationsCard> createState() => _TopLocationsCardState();
}

class _TopLocationsCardState extends ConsumerState<_TopLocationsCard> {
  late DateRangeFilter _range;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now().toUtc();
    _range = DateRangeFilter(
      start: DateTime.utc(now.year - 1, now.month, now.day),
      end: DateTime.utc(now.year, now.month, now.day + 1),
    );
  }

  Future<void> _pickRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2010),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDateRange: DateTimeRange(
        start: _range.start.toLocal(),
        end: _range.end.subtract(const Duration(days: 1)).toLocal(),
      ),
    );
    if (picked == null) return;
    setState(() {
      _range = DateRangeFilter(
        start: DateTime.utc(
            picked.start.year, picked.start.month, picked.start.day),
        end:
            DateTime.utc(picked.end.year, picked.end.month, picked.end.day + 1),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final enrichedClusters =
        ref.watch(enrichedLocationClustersInRangeProvider(_range));
    final formatter = DateFormat('yyyy.M.d');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Frequent Locations',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                ),
                TextButton.icon(
                  onPressed: _pickRange,
                  icon: const Icon(Icons.date_range, size: 16),
                  label: Text(
                    '${formatter.format(_range.start)}~${formatter.format(_range.end.subtract(const Duration(days: 1)))}',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            enrichedClusters.when(
              data: (items) {
                if (items.isEmpty) {
                  return const Text('No location data yet');
                }
                final maxCount = items.first.cluster.assetCount;
                return Column(
                  children: items.asMap().entries.map((entry) {
                    final i = entry.key;
                    final item = entry.value;
                    final count = item.cluster.assetCount;
                    final ratio = maxCount > 0 ? count / maxCount : 0.0;
                    return _LocationRankItem(
                      rank: i,
                      address: item.address,
                      assetCount: count,
                      ratio: ratio,
                      onTap: () async {
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('View in Journal'),
                            content: const Text(
                                'Would you like to view this location in the Journal?'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                child: const Text('Cancel'),
                              ),
                              FilledButton(
                                onPressed: () => Navigator.pop(ctx, true),
                                child: const Text('View'),
                              ),
                            ],
                          ),
                        );
                        if (confirmed != true) return;
                        final c = item.cluster;
                        ref.read(locationFilterProvider.notifier).state =
                            LocationFilter(
                          label: c.label,
                          latitude: c.latitude,
                          longitude: c.longitude,
                          radiusKm: 2.0,
                        );
                        ref.invalidate(dailyStatsProvider);
                        ref.invalidate(diaryCandidatesProvider);
                        ref.invalidate(mapEventsProvider);
                        ref.invalidate(tagSummariesProvider);
                        ref.read(pendingTabProvider.notifier).state = 0;
                      },
                    );
                  }).toList(),
                );
              },
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('Failed: $e'),
            ),
          ],
        ),
      ),
    );
  }
}

class _LocationRankItem extends StatelessWidget {
  const _LocationRankItem({
    required this.rank,
    required this.address,
    required this.assetCount,
    required this.ratio,
    required this.onTap,
  });

  final int rank;
  final String address;
  final int assetCount;
  final double ratio;
  final VoidCallback onTap;

  static const _rankEmojis = ['🥇', '🥈', '🥉', '4.', '5.'];

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          children: [
            Row(
              children: [
                Text(rank < _rankEmojis.length ? _rankEmojis[rank] : '·',
                    style: const TextStyle(fontSize: 16)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    address,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
                Text(
                  '$assetCount photos',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ],
            ),
            const SizedBox(height: 4),
            LayoutBuilder(builder: (ctx, constraints) {
              return Stack(
                children: [
                  Container(
                    height: 4,
                    width: constraints.maxWidth,
                    decoration: BoxDecoration(
                      color: Theme.of(ctx).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Container(
                    height: 4,
                    width: constraints.maxWidth * ratio,
                    decoration: BoxDecoration(
                      color: Theme.of(ctx).colorScheme.primary,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }
}

// ─── AI recommendations card ──────────────────────────────────────────────

class _AiRecommendationsCard extends ConsumerStatefulWidget {
  const _AiRecommendationsCard({required this.settingsEnabled});

  final bool settingsEnabled;

  @override
  ConsumerState<_AiRecommendationsCard> createState() =>
      _AiRecommendationsCardState();
}

class _AiRecommendationsCardState
    extends ConsumerState<_AiRecommendationsCard> {
  Future<List<DiaryRecommendation>>? _future;

  void _request() {
    final service = ref.read(aiRecommendationServiceProvider);
    final repository = ref.read(diaryRepositoryProvider);
    final settings = ref.read(recommendationSettingsProvider);
    final now = DateTime.now();

    setState(() {
      _future = Future(() async {
        final recentEvents = await repository.eventsInRange(
          start: now.toUtc().subtract(const Duration(days: 30)),
          end: now.toUtc().add(const Duration(days: 1)),
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
    });
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.auto_awesome, size: 18),
                const SizedBox(width: 6),
                const Expanded(
                  child: Text(
                    'AI Diary Recommendations',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (!widget.settingsEnabled)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'Enable AI recommendations in Settings to get diary topic suggestions.',
                  style: TextStyle(color: Colors.black54),
                ),
              )
            else if (_future == null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: OutlinedButton.icon(
                  onPressed: _request,
                  icon: const Icon(Icons.auto_awesome, size: 16),
                  label: const Text('Get recommendations'),
                ),
              )
            else
              FutureBuilder<List<DiaryRecommendation>>(
                future: _future,
                builder: (ctx, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  if (snap.hasError) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Failed: ${snap.error}',
                              style: const TextStyle(color: Colors.red)),
                          const SizedBox(height: 8),
                          TextButton.icon(
                            onPressed: _request,
                            icon: const Icon(Icons.refresh, size: 16),
                            label: const Text('Retry'),
                          ),
                        ],
                      ),
                    );
                  }
                  final recs = snap.data ?? [];
                  if (recs.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text('No recommendations generated.'),
                    );
                  }
                  return Column(
                    children: recs
                        .map((rec) => _RecommendationTile(rec: rec))
                        .toList(),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _RecommendationTile extends StatelessWidget {
  const _RecommendationTile({required this.rec});

  final DiaryRecommendation rec;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ManualRecordScreen(initialTitle: rec.title),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          rec.source.label,
                          style: TextStyle(
                            fontSize: 11,
                            color: Theme.of(context)
                                .colorScheme
                                .onPrimaryContainer,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          rec.title,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    rec.body,
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(height: 1.5),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}

// ─── Indexing card ─────────────────────────────────────────────────────────

class _IndexingCard extends StatelessWidget {
  const _IndexingCard({
    required this.indexingMessage,
    required this.indexingLabel,
    required this.indexedAssetCount,
    required this.isRunning,
    required this.onRun,
    this.fraction,
  });

  final String indexingMessage;
  final String indexingLabel;
  final AsyncValue<int> indexedAssetCount;
  final bool isRunning;
  final Future<void> Function() onRun;
  final double? fraction;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Metadata Index → Event Summary',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(indexingMessage),
            const SizedBox(height: 4),
            Text(indexingLabel),
            if (isRunning) ...[
              const SizedBox(height: 10),
              LinearProgressIndicator(
                value: fraction,
                borderRadius: BorderRadius.circular(4),
              ),
              if (fraction != null) ...[
                const SizedBox(height: 4),
                Text(
                  '${(fraction! * 100).toStringAsFixed(1)}%',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ],
            const SizedBox(height: 12),
            indexedAssetCount.when(
              data: (count) => Text('Indexed assets: $count'),
              loading: () => const Text('Loading indexed count...'),
              error: (error, _) => Text('Count failed: $error'),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: isRunning ? null : onRun,
              icon: const Icon(Icons.bolt_outlined),
              label: Text(isRunning ? 'Indexing...' : 'Allow & Index Photos'),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Permission card ────────────────────────────────────────────────────────

class _PermissionCard extends StatelessWidget {
  const _PermissionCard({
    required this.permission,
    required this.onManageLimitedAccess,
    required this.onOpenSettings,
  });

  final PermissionState permission;
  final Future<void> Function() onManageLimitedAccess;
  final Future<void> Function() onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final isAuthorized = permission.hasAccess;
    final isLimited = permission.isLimited;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isAuthorized
                      ? Icons.check_circle_outline
                      : Icons.warning_amber_rounded,
                  color: isAuthorized ? Colors.green : Colors.orange,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isLimited
                            ? 'Limited Photos access'
                            : isAuthorized
                                ? 'Photo access granted'
                                : 'Photo access required',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isLimited
                            ? 'Currently only selected photos are accessible. Change to full access for automatic indexing.'
                            : 'Only metadata is indexed, not the original files.',
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (isLimited) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.tonal(
                    onPressed: onManageLimitedAccess,
                    child: const Text('Re-select Photos'),
                  ),
                  OutlinedButton(
                    onPressed: onOpenSettings,
                    child: const Text('Allow Full Access in Settings'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
