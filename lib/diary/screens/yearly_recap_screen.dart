import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:photo_manager/photo_manager.dart' hide LatLng;
import 'package:share_plus/share_plus.dart';

import '../../key.dart';
import '../models/daily_stats.dart';
import '../models/recommendation_settings.dart';
import '../providers/diary_providers.dart';

class YearlyRecapScreen extends ConsumerStatefulWidget {
  const YearlyRecapScreen({super.key, required this.year});

  final int year;

  @override
  ConsumerState<YearlyRecapScreen> createState() => _YearlyRecapScreenState();
}

class _YearlyRecapScreenState extends ConsumerState<YearlyRecapScreen> {
  final GlobalKey _bodyKey = GlobalKey();
  final GlobalKey _shareButtonKey = GlobalKey();
  String? _aiSummary;
  bool _loadingAi = false;
  bool _sharing = false;

  late int _year;

  @override
  void initState() {
    super.initState();
    _year = widget.year;
  }

  bool get _isCurrentYear => _year == DateTime.now().year;

  @override
  Widget build(BuildContext context) {
    final statsAsync = ref.watch(yearlyStatsProvider(_year));
    final locationClusters = ref.watch(yearlyLocationClustersProvider(_year));

    return Scaffold(
      appBar: AppBar(
        title: Text('$_year'),
        actions: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            tooltip: 'Previous year',
            onPressed: () => setState(() {
              _aiSummary = null;
              _year -= 1;
            }),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            tooltip: 'Next year',
            onPressed: _isCurrentYear
                ? null
                : () => setState(() {
                      _aiSummary = null;
                      _year += 1;
                    }),
          ),
        ],
      ),
      body: statsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (stats) => _buildBody(context, stats, locationClusters),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    List<DailyStats> stats,
    AsyncValue<dynamic> locationClusters,
  ) {
    final totalPhotos = stats.fold(0, (sum, s) => sum + s.assetCount);
    final activeDays = stats.where((s) => s.assetCount > 0).length;

    // Group by month
    final Map<int, List<DailyStats>> byMonth = {};
    for (final s in stats) {
      byMonth.putIfAbsent(s.day.month, () => []).add(s);
    }
    final activeMonths =
        byMonth.values.where((m) => m.any((s) => s.assetCount > 0)).length;

    // Top 3 months by photo count
    final monthTotals = byMonth.entries.map((e) {
      final total = e.value.fold(0, (sum, s) => sum + s.assetCount);
      final bestDay = e.value.reduce(
          (a, b) => a.assetCount >= b.assetCount ? a : b);
      return (month: e.key, total: total, bestDay: bestDay);
    }).toList()
      ..sort((a, b) => b.total.compareTo(a.total));
    final highlightMonths = monthTotals.take(3).toList();

    // Best month
    final bestMonth =
        monthTotals.isNotEmpty ? monthTotals.first : null;

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: RepaintBoundary(
              key: _bodyKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildHeader(totalPhotos, activeDays, activeMonths),
                  const SizedBox(height: 16),
                  if (highlightMonths.isNotEmpty) ...[
                    _SectionCard(
                      title: 'Top Months',
                      child: Row(
                        children: highlightMonths
                            .map(
                              (m) => Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 4),
                                  child: Column(
                                    children: [
                                      _DayThumbnail(day: m.bestDay.day),
                                      const SizedBox(height: 4),
                                      Text(
                                        DateFormat('MMM').format(
                                            DateTime(_year, m.month)),
                                        style:
                                            const TextStyle(fontSize: 11),
                                        textAlign: TextAlign.center,
                                      ),
                                      Text(
                                        '${m.total} photos',
                                        style: const TextStyle(
                                            fontSize: 10,
                                            color: Colors.grey),
                                        textAlign: TextAlign.center,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  _SectionCard(
                    title: 'Stats',
                    child: Row(
                      children: [
                        _StatCell(
                          label: 'Total Photos',
                          value: '$totalPhotos',
                        ),
                        _StatCell(
                          label: 'Active Days',
                          value: '$activeDays',
                        ),
                        _StatCell(
                          label: 'Best Month',
                          value: bestMonth != null
                              ? DateFormat('MMM')
                                  .format(DateTime(_year, bestMonth.month))
                              : '—',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _SectionCard(
                    title: 'Top Locations',
                    child: locationClusters.when(
                      data: (clusters) => _TopLocations(
                          clusters: clusters.take(3).toList()),
                      loading: () => const LinearProgressIndicator(),
                      error: (e, _) => Text('Failed: $e'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _SectionCard(
                    title: 'AI Summary',
                    child: _AiSummarySection(
                      summary: _aiSummary,
                      isLoading: _loadingAi,
                      onGenerate: () => _generateAiSummary(
                        totalPhotos: totalPhotos,
                        activeDays: activeDays,
                        activeMonths: activeMonths,
                        locationClusters: locationClusters,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.bottomRight,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 4, bottom: 4),
                      child: Opacity(
                        opacity: 0.6,
                        child: Image.asset(
                          'assets/logo.png',
                          width: 28,
                          height: 28,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: FilledButton.icon(
              key: _shareButtonKey,
              onPressed: _sharing ? null : _captureAndShare,
              icon: const Icon(Icons.share),
              label: Text(_sharing ? 'Preparing...' : 'Share this Year'),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(int totalPhotos, int activeDays, int activeMonths) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$_year',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          '$totalPhotos photos · $activeDays active days · $activeMonths months',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      ],
    );
  }

  Future<void> _captureAndShare() async {
    setState(() => _sharing = true);
    try {
      final boundary =
          _bodyKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;
      final dir = await getTemporaryDirectory();
      final path =
          '${dir.path}/yearly_${_year}_${DateTime.now().millisecondsSinceEpoch}.png';
      final file =
          await File(path).writeAsBytes(byteData.buffer.asUint8List());
      final box =
          _shareButtonKey.currentContext?.findRenderObject() as RenderBox?;
      final sharePositionOrigin =
          box != null ? box.localToGlobal(Offset.zero) & box.size : null;
      await Share.shareXFiles(
        [XFile(file.path)],
        sharePositionOrigin: sharePositionOrigin,
      );
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  Future<void> _generateAiSummary({
    required int totalPhotos,
    required int activeDays,
    required int activeMonths,
    required AsyncValue<dynamic> locationClusters,
  }) async {
    setState(() => _loadingAi = true);
    try {
      String topLocation = 'unknown';
      locationClusters.whenData((clusters) {
        if (clusters.isNotEmpty) topLocation = clusters.first.label as String;
      });

      final prompt = '''
Yearly diary summary for $_year:
- Total photos: $totalPhotos
- Active days: $activeDays/365
- Active months: $activeMonths/12
- Top location: $topLocation
Write a single warm sentence summarizing this year.
''';

      final url = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/${RecommendationModel.geminiFlash.modelId}:generateContent?key=$GEMINI_KEYS',
      );
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [
            {
              'role': 'user',
              'parts': [
                {'text': prompt}
              ],
            }
          ],
          'generationConfig': {'temperature': 0.7},
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final text =
            data['candidates'][0]['content']['parts'][0]['text'] as String;
        setState(() => _aiSummary = text.trim());
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to generate AI summary')),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingAi = false);
    }
  }
}

// ─── Section card ─────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

// ─── Day thumbnail (reused from monthly recap) ────────────────────────────

class _DayThumbnail extends ConsumerWidget {
  const _DayThumbnail({required this.day});

  final DateTime day;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final future = ref.read(appDatabaseProvider).queryAssetIdsForDay(day);

    return FutureBuilder<List<String>>(
      future: future,
      builder: (context, idsSnap) {
        if (idsSnap.connectionState == ConnectionState.waiting) {
          return _placeholder(context);
        }
        final ids = idsSnap.data ?? [];
        if (ids.isEmpty) {
          return AspectRatio(
            aspectRatio: 1,
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.image_not_supported_outlined),
            ),
          );
        }
        return FutureBuilder<AssetEntity?>(
          future: AssetEntity.fromId(ids.first),
          builder: (ctx, assetSnap) {
            final asset = assetSnap.data;
            if (asset == null) return _placeholder(ctx);
            return FutureBuilder<Uint8List?>(
              future:
                  asset.thumbnailDataWithSize(const ThumbnailSize(400, 400)),
              builder: (ctx2, thumbSnap) {
                if (!thumbSnap.hasData) return _placeholder(ctx2);
                return AspectRatio(
                  aspectRatio: 1,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.memory(thumbSnap.data!, fit: BoxFit.cover),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _placeholder(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
}

// ─── Stats cell ────────────────────────────────────────────────────────────

class _StatCell extends StatelessWidget {
  const _StatCell({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ─── Top locations map ─────────────────────────────────────────────────────

class _TopLocations extends StatelessWidget {
  const _TopLocations({required this.clusters});

  final List<dynamic> clusters;

  @override
  Widget build(BuildContext context) {
    if (clusters.isEmpty) {
      return const Text('No location data available');
    }
    final top = clusters.first;
    final center = LatLng(top.latitude as double, top.longitude as double);
    final markers = <Marker>{
      for (int i = 0; i < clusters.length; i++)
        Marker(
          markerId: MarkerId('loc_$i'),
          position: LatLng(
            clusters[i].latitude as double,
            clusters[i].longitude as double,
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRose),
          infoWindow: InfoWindow(
            title: clusters[i].label as String,
            snippet: '${clusters[i].assetCount} photos',
          ),
        ),
    };
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        height: 200,
        child: GoogleMap(
          key: ValueKey('${center.latitude},${center.longitude}'),
          initialCameraPosition: CameraPosition(target: center, zoom: 5),
          markers: markers,
          myLocationButtonEnabled: false,
          zoomControlsEnabled: false,
          scrollGesturesEnabled: false,
          zoomGesturesEnabled: false,
          rotateGesturesEnabled: false,
          tiltGesturesEnabled: false,
        ),
      ),
    );
  }
}

// ─── AI summary section ────────────────────────────────────────────────────

class _AiSummarySection extends StatelessWidget {
  const _AiSummarySection({
    required this.summary,
    required this.isLoading,
    required this.onGenerate,
  });

  final String? summary;
  final bool isLoading;
  final VoidCallback onGenerate;

  @override
  Widget build(BuildContext context) {
    if (isLoading) return const Center(child: CircularProgressIndicator());
    if (summary != null) {
      return Text(
        summary!,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              height: 1.6,
              fontStyle: FontStyle.italic,
            ),
      );
    }
    return OutlinedButton.icon(
      onPressed: onGenerate,
      icon: const Icon(Icons.auto_awesome, size: 16),
      label: const Text('Generate Summary'),
    );
  }
}
