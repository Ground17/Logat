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

class MonthlyRecapScreen extends ConsumerStatefulWidget {
  const MonthlyRecapScreen({
    super.key,
    required this.year,
    required this.month,
  });

  final int year;
  final int month;

  @override
  ConsumerState<MonthlyRecapScreen> createState() => _MonthlyRecapScreenState();
}

class _MonthlyRecapScreenState extends ConsumerState<MonthlyRecapScreen> {
  final GlobalKey _bodyKey = GlobalKey();
  final GlobalKey _shareButtonKey = GlobalKey();
  String? _aiSummary;
  bool _loadingAi = false;
  bool _sharing = false;

  late int _year;
  late int _month;

  @override
  void initState() {
    super.initState();
    _year = widget.year;
    _month = widget.month;
  }

  void _goToPrevMonth() {
    setState(() {
      _aiSummary = null;
      if (_month == 1) {
        _year -= 1;
        _month = 12;
      } else {
        _month -= 1;
      }
    });
  }

  void _goToNextMonth() {
    setState(() {
      _aiSummary = null;
      if (_month == 12) {
        _year += 1;
        _month = 1;
      } else {
        _month += 1;
      }
    });
  }

  Future<void> _pickMonth() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(_year, _month),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      initialEntryMode: DatePickerEntryMode.calendarOnly,
    );
    if (picked != null) {
      setState(() {
        _aiSummary = null;
        _year = picked.year;
        _month = picked.month;
      });
    }
  }

  bool get _isCurrentMonth {
    final now = DateTime.now();
    return _year == now.year && _month == now.month;
  }

  @override
  Widget build(BuildContext context) {
    final monthName = DateFormat('MMMM yyyy').format(DateTime(_year, _month));
    final statsAsync = ref.watch(monthlyStatsProvider((_year, _month)));
    final locationClusters =
        ref.watch(monthlyLocationClustersProvider((_year, _month)));

    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(
          onTap: _pickMonth,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(monthName),
              const SizedBox(width: 4),
              const Icon(Icons.arrow_drop_down, size: 20),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            tooltip: 'Previous month',
            onPressed: _goToPrevMonth,
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            tooltip: 'Next month',
            onPressed: _isCurrentMonth ? null : _goToNextMonth,
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
    final daysInMonth = DateTime(_year, _month + 1, 0).day;

    DailyStats? mostActiveDay;
    for (final s in stats) {
      if (mostActiveDay == null || s.assetCount > mostActiveDay.assetCount) {
        mostActiveDay = s;
      }
    }

    final topDays = [...stats]
      ..sort((a, b) => b.assetCount.compareTo(a.assetCount));
    final highlightDays = topDays.take(3).toList();

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
                  _buildHeader(totalPhotos, activeDays, daysInMonth),
                  const SizedBox(height: 16),
                  if (highlightDays.isNotEmpty) ...[
                    _SectionCard(
                      title: 'Highlights',
                      child: _HighlightThumbnails(
                        days: highlightDays,
                        year: _year,
                        month: _month,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  _SectionCard(
                    title: 'Stats',
                    child: _StatsRow(
                      totalPhotos: totalPhotos,
                      activeDays: activeDays,
                      mostActiveDay: mostActiveDay,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _SectionCard(
                    title: 'Top Locations',
                    child: locationClusters.when(
                      data: (clusters) =>
                          _TopLocations(clusters: clusters.take(3).toList()),
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
              label: Text(_sharing ? 'Preparing...' : 'Share this Month'),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(int totalPhotos, int activeDays, int daysInMonth) {
    final monthName = DateFormat('MMMM yyyy')
        .format(DateTime(_year, _month));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          monthName,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          '$totalPhotos photos · $activeDays active ${activeDays == 1 ? 'day' : 'days'}',
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
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;
      final dir = await getTemporaryDirectory();
      final path =
          '${dir.path}/monthly_${_year}_${_month}_${DateTime.now().millisecondsSinceEpoch}.png';
      final file = await File(path).writeAsBytes(byteData.buffer.asUint8List());
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
    required AsyncValue<dynamic> locationClusters,
  }) async {
    setState(() => _loadingAi = true);
    try {
      String topLocation = 'unknown';
      locationClusters.whenData((clusters) {
        if (clusters.isNotEmpty) topLocation = clusters.first.label as String;
      });

      final prompt = '''
Monthly diary summary for $_month/$_year:
- Total photos: $totalPhotos
- Active days: $activeDays/${DateTime(_year, _month + 1, 0).day}
- Top location: $topLocation
Write a single warm sentence summarizing this month.
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
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

// ─── Highlight thumbnails ─────────────────────────────────────────────────

class _HighlightThumbnails extends StatelessWidget {
  const _HighlightThumbnails({
    required this.days,
    required this.year,
    required this.month,
  });

  final List<DailyStats> days;
  final int year;
  final int month;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: days.map((d) => Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Column(
            children: [
              _DayThumbnail(day: d.day),
              const SizedBox(height: 4),
              Text(
                DateFormat('MMM d').format(d.day.toLocal()),
                style: const TextStyle(fontSize: 11),
                textAlign: TextAlign.center,
              ),
              Text(
                '${d.assetCount} photos',
                style: const TextStyle(fontSize: 10, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      )).toList(),
    );
  }
}

class _DayThumbnail extends ConsumerWidget {
  const _DayThumbnail({required this.day});

  final DateTime day;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Query asset IDs directly from the diary DB — same source as DailyStats.assetCount.
    final future = ref
        .read(appDatabaseProvider)
        .queryAssetIdsForDay(day);

    return FutureBuilder<List<String>>(
      future: future,
      builder: (context, idsSnap) {
        if (idsSnap.connectionState == ConnectionState.waiting) {
          return AspectRatio(
            aspectRatio: 1,
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
          );
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
            if (asset == null) {
              return AspectRatio(
                aspectRatio: 1,
                child: Container(
                  decoration: BoxDecoration(
                    color: Theme.of(ctx).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              );
            }

            return FutureBuilder<Uint8List?>(
              future: asset.thumbnailDataWithSize(const ThumbnailSize(400, 400)),
              builder: (ctx2, thumbSnap) {
                if (!thumbSnap.hasData) {
                  return AspectRatio(
                    aspectRatio: 1,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Theme.of(ctx2)
                            .colorScheme
                            .surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  );
                }
                return AspectRatio(
                  aspectRatio: 1,
                  child: GestureDetector(
                    onTap: () => Navigator.push(
                      ctx2,
                      MaterialPageRoute(
                        fullscreenDialog: true,
                        builder: (_) => _FullScreenPhotoViewById(
                          assetIds: ids,
                          initialIndex: 0,
                        ),
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.memory(
                        thumbSnap.data!,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

// ─── Stats row ────────────────────────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  const _StatsRow({
    required this.totalPhotos,
    required this.activeDays,
    required this.mostActiveDay,
  });

  final int totalPhotos;
  final int activeDays;
  final DailyStats? mostActiveDay;

  @override
  Widget build(BuildContext context) {
    return Row(
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
          label: 'Best Day',
          value: mostActiveDay != null
              ? DateFormat('MMM d').format(mostActiveDay!.day.toLocal())
              : '—',
        ),
      ],
    );
  }
}

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

// ─── Top locations (map) ──────────────────────────────────────────────────

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
          icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueRose),
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
          initialCameraPosition: CameraPosition(target: center, zoom: 11),
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

// ─── AI summary section ───────────────────────────────────────────────────

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
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
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

// ─── Full-screen swipeable photo viewer (by asset ID list) ───────────────

class _FullScreenPhotoViewById extends StatefulWidget {
  const _FullScreenPhotoViewById({
    required this.assetIds,
    required this.initialIndex,
  });

  final List<String> assetIds;
  final int initialIndex;

  @override
  State<_FullScreenPhotoViewById> createState() =>
      _FullScreenPhotoViewByIdState();
}

class _FullScreenPhotoViewByIdState extends State<_FullScreenPhotoViewById> {
  late int _current;

  @override
  void initState() {
    super.initState();
    _current = widget.initialIndex;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        title: widget.assetIds.length > 1
            ? Text(
                '${_current + 1} / ${widget.assetIds.length}',
                style: const TextStyle(color: Colors.white, fontSize: 15),
              )
            : null,
      ),
      body: PageView.builder(
        controller: PageController(initialPage: widget.initialIndex),
        itemCount: widget.assetIds.length,
        onPageChanged: (i) => setState(() => _current = i),
        itemBuilder: (ctx, i) => _PhotoPageById(assetId: widget.assetIds[i]),
      ),
    );
  }
}

class _PhotoPageById extends StatelessWidget {
  const _PhotoPageById({required this.assetId});

  final String assetId;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AssetEntity?>(
      future: AssetEntity.fromId(assetId),
      builder: (ctx, assetSnap) {
        if (!assetSnap.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.white),
          );
        }
        return FutureBuilder<Uint8List?>(
          future: assetSnap.data!
              .thumbnailDataWithSize(const ThumbnailSize(1200, 1200)),
          builder: (ctx2, snap) {
            if (!snap.hasData) {
              return const Center(
                child: CircularProgressIndicator(color: Colors.white),
              );
            }
            return InteractiveViewer(
              minScale: 0.8,
              maxScale: 5.0,
              child: Center(
                child: Image.memory(snap.data!, fit: BoxFit.contain),
              ),
            );
          },
        );
      },
    );
  }
}

// ─── Full-screen swipeable photo viewer ──────────────────────────────────

class _FullScreenPhotoView extends StatefulWidget {
  const _FullScreenPhotoView({
    required this.assets,
    required this.initialIndex,
  });

  final List<AssetEntity> assets;
  final int initialIndex;

  @override
  State<_FullScreenPhotoView> createState() => _FullScreenPhotoViewState();
}

class _FullScreenPhotoViewState extends State<_FullScreenPhotoView> {
  late int _current;

  @override
  void initState() {
    super.initState();
    _current = widget.initialIndex;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        title: widget.assets.length > 1
            ? Text(
                '${_current + 1} / ${widget.assets.length}',
                style: const TextStyle(color: Colors.white, fontSize: 15),
              )
            : null,
      ),
      body: PageView.builder(
        controller: PageController(initialPage: widget.initialIndex),
        itemCount: widget.assets.length,
        onPageChanged: (i) => setState(() => _current = i),
        itemBuilder: (ctx, i) => _PhotoPage(asset: widget.assets[i]),
      ),
    );
  }
}

class _PhotoPage extends StatelessWidget {
  const _PhotoPage({required this.asset});

  final AssetEntity asset;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List?>(
      future: asset.thumbnailDataWithSize(const ThumbnailSize(1200, 1200)),
      builder: (ctx, snap) {
        if (!snap.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.white),
          );
        }
        return InteractiveViewer(
          minScale: 0.8,
          maxScale: 5.0,
          child: Center(
            child: Image.memory(snap.data!, fit: BoxFit.contain),
          ),
        );
      },
    );
  }
}
