import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:video_player/video_player.dart';

import '../models/event_summary.dart';
import '../providers/diary_providers.dart';
import 'event_detail_screen.dart';
// userLocationProvider, distanceKm, formatDistanceLabel are imported via diary_providers

// ─── Public entry point ───────────────────────────────────────────────────

class MemoryLoopView extends ConsumerWidget {
  const MemoryLoopView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsAsync = ref.watch(loopItemsProvider);
    return itemsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (events) {
        if (events.isEmpty) {
          return const Center(
            child: Text('No memories yet', style: TextStyle(fontSize: 18)),
          );
        }
        return _LoopPageView(events: events);
      },
    );
  }
}

// ─── Helpers ──────────────────────────────────────────────────────────────

String? _specialDayLabel(DateTime eventDate) {
  final today = DateTime.now().toLocal();
  final local = eventDate.toLocal();
  final days = DateTime(today.year, today.month, today.day)
      .difference(DateTime(local.year, local.month, local.day))
      .inDays;
  if (days <= 0) return null;
  if (today.month == local.month && today.day == local.day) {
    final years = today.year - local.year;
    if (years > 0) return '🎊 $years-year anniversary';
  }
  if (days % 100 == 0) return '🎉 Day $days';
  return null;
}

String _daysAgoLabel(DateTime eventDate) {
  final today = DateTime.now().toLocal();
  final local = eventDate.toLocal();
  final days = DateTime(today.year, today.month, today.day)
      .difference(DateTime(local.year, local.month, local.day))
      .inDays;
  if (days == 0) return 'Today';
  if (days == 1) return 'Yesterday';
  return '$days days ago';
}

// ─── Vertical PageView (event level) ─────────────────────────────────────

class _LoopPageView extends StatefulWidget {
  const _LoopPageView({required this.events});

  final List<EventSummary> events;

  @override
  State<_LoopPageView> createState() => _LoopPageViewState();
}

class _LoopPageViewState extends State<_LoopPageView> {
  final PageController _pageCtrl = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PageView.builder(
      scrollDirection: Axis.vertical,
      controller: _pageCtrl,
      itemCount: widget.events.length,
      onPageChanged: (idx) => setState(() => _currentPage = idx),
      itemBuilder: (ctx, i) => _LoopPage(
        key: ValueKey(widget.events[i].eventId),
        event: widget.events[i],
        isActive: i == _currentPage,
      ),
    );
  }
}

// ─── Single event page ────────────────────────────────────────────────────

class _LoopPage extends ConsumerStatefulWidget {
  const _LoopPage({
    super.key,
    required this.event,
    required this.isActive,
  });

  final EventSummary event;
  final bool isActive;

  @override
  ConsumerState<_LoopPage> createState() => _LoopPageState();
}

class _LoopPageState extends ConsumerState<_LoopPage>
    with SingleTickerProviderStateMixin {
  bool _isFavorite = false;
  int _mediaPage = 0;
  late final AnimationController _heartCtrl;
  Offset _heartPos = Offset.zero;
  final ValueNotifier<double> _speedNotifier = ValueNotifier(1.0);

  List<String> get _mediaIds =>
      widget.event.assetIds.where((id) => id != 'manual_no_photo').toList();

  @override
  void initState() {
    super.initState();
    _isFavorite = widget.event.isFavorite;
    _heartCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 750),
    );
  }

  @override
  void dispose() {
    _heartCtrl.dispose();
    _speedNotifier.dispose();
    super.dispose();
  }

  Future<void> _toggleFavorite() async {
    final newValue = !_isFavorite;
    setState(() => _isFavorite = newValue);
    await ref
        .read(appDatabaseProvider)
        .updateEventFavorite(widget.event.eventId, newValue);
    ref.invalidate(filteredJournalEventsProvider);
  }

  void _handleDoubleTap() {
    _toggleFavorite();
    _heartCtrl.forward(from: 0.0);
  }

  void _handleLongPressStart(LongPressStartDetails d) {
    final w = MediaQuery.of(context).size.width;
    if (d.localPosition.dx < w * 0.22 || d.localPosition.dx > w * 0.78) {
      _speedNotifier.value = 2.0;
    }
  }

  void _handleLongPressEnd(LongPressEndDetails _) {
    _speedNotifier.value = 1.0;
  }

  @override
  Widget build(BuildContext context) {
    final event = widget.event;
    final ids = _mediaIds;
    final specialLabel = _specialDayLabel(event.startAt);
    final dateLabel =
        '${DateFormat('MMM d, yyyy').format(event.startAt.toLocal())}  ·  ${_daysAgoLabel(event.startAt)}';

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onDoubleTapDown: (d) => setState(() => _heartPos = d.localPosition),
      onDoubleTap: _handleDoubleTap,
      onLongPressStart: _handleLongPressStart,
      onLongPressEnd: _handleLongPressEnd,
      onLongPressCancel: () => _speedNotifier.value = 1.0,
      child: Stack(
      fit: StackFit.expand,
      children: [
        // 1. Media slider (background)
        ColoredBox(
          color: Colors.black,
          child: _LoopMediaSlider(
            assetIds: ids,
            isPageActive: widget.isActive,
            speedNotifier: _speedNotifier,
            onPageChanged: (i) => setState(() => _mediaPage = i),
          ),
        ),

        // 2. Bottom gradient + metadata
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [Colors.black87, Colors.transparent],
              ),
            ),
            padding: const EdgeInsets.fromLTRB(16, 40, 72, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (specialLabel != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEBCB8B).withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      specialLabel,
                      style: const TextStyle(
                        color: Colors.black87,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                ],
                Text(
                  dateLabel,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (event.title != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    event.title!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                if (event.customAddress != null ||
                    event.latitude != null) ...[
                  const SizedBox(height: 4),
                  EventAddressRow(event: event, dark: true),
                ],
                if (event.tags.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: event.tags
                        .take(3)
                        .map((t) => Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.white24,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                t.name,
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 12),
                              ),
                            ))
                        .toList(),
                  ),
                ],
              ],
            ),
          ),
        ),

        // 3. Media dot indicators
        if (ids.length > 1)
          Positioned(
            right: 8,
            bottom: 140,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(
                ids.length,
                (i) => Container(
                  width: 6,
                  height: 6,
                  margin: const EdgeInsets.symmetric(vertical: 2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i == _mediaPage
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.4),
                  ),
                ),
              ),
            ),
          ),

        // 4. Right sidebar (favorite, detail)
        Positioned(
          right: 8,
          bottom: 80,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: Icon(
                  _isFavorite ? Icons.favorite : Icons.favorite_border,
                  color: _isFavorite ? Colors.red : Colors.white,
                  size: 30,
                ),
                onPressed: _toggleFavorite,
              ),
              const SizedBox(height: 8),
              IconButton(
                icon: const Icon(Icons.arrow_forward_ios,
                    color: Colors.white, size: 24),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => EventDetailScreen(event: event),
                  ),
                ),
              ),
            ],
          ),
        ),

        // 5. Double-tap heart animation
        AnimatedBuilder(
          animation: _heartCtrl,
          builder: (ctx, _) {
            if (!_heartCtrl.isAnimating && !_heartCtrl.isCompleted) {
              return const SizedBox.shrink();
            }
            final scale = Tween<double>(begin: 0.4, end: 1.6).animate(
              CurvedAnimation(
                parent: _heartCtrl,
                curve: const Interval(0.0, 0.6, curve: Curves.elasticOut),
              ),
            );
            final fade = Tween<double>(begin: 1.0, end: 0.0).animate(
              CurvedAnimation(
                parent: _heartCtrl,
                curve: const Interval(0.55, 1.0, curve: Curves.easeOut),
              ),
            );
            return Positioned(
              left: (_heartPos.dx - 44).clamp(0, double.infinity),
              top: (_heartPos.dy - 44).clamp(0, double.infinity),
              child: IgnorePointer(
                child: FadeTransition(
                  opacity: fade,
                  child: ScaleTransition(
                    scale: scale,
                    child: const Icon(Icons.favorite,
                        color: Colors.white, size: 88),
                  ),
                ),
              ),
            );
          },
        ),

        // 6. 2× speed indicator
        ValueListenableBuilder<double>(
          valueListenable: _speedNotifier,
          builder: (ctx, speed, _) {
            if (speed <= 1.0) return const SizedBox.shrink();
            return Positioned(
              top: 16,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    '2×',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    ),  // end inner Stack
    );  // end GestureDetector
  }
}

// ─── Horizontal media slider (asset level) ────────────────────────────────

class _LoopMediaSlider extends StatefulWidget {
  const _LoopMediaSlider({
    required this.assetIds,
    required this.isPageActive,
    required this.speedNotifier,
    required this.onPageChanged,
  });

  final List<String> assetIds;
  final bool isPageActive;
  final ValueNotifier<double> speedNotifier;
  final ValueChanged<int> onPageChanged;

  @override
  State<_LoopMediaSlider> createState() => _LoopMediaSliderState();
}

class _LoopMediaSliderState extends State<_LoopMediaSlider> {
  final PageController _hCtrl = PageController();
  int _currentMedia = 0;

  @override
  void dispose() {
    _hCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.assetIds.isEmpty) {
      return const Center(
        child: Icon(Icons.broken_image_outlined,
            color: Colors.white54, size: 64),
      );
    }
    if (widget.assetIds.length == 1) {
      return _MediaTile(
        assetId: widget.assetIds[0],
        isActive: widget.isPageActive,
        speedNotifier: widget.speedNotifier,
      );
    }
    return PageView.builder(
      controller: _hCtrl,
      scrollDirection: Axis.horizontal,
      itemCount: widget.assetIds.length,
      onPageChanged: (i) {
        _currentMedia = i;
        widget.onPageChanged(i);
      },
      itemBuilder: (ctx, i) => _MediaTile(
        key: ValueKey(widget.assetIds[i]),
        assetId: widget.assetIds[i],
        isActive: widget.isPageActive && i == _currentMedia,
        speedNotifier: widget.speedNotifier,
      ),
    );
  }
}

// ─── Single media tile ────────────────────────────────────────────────────

class _MediaTile extends StatefulWidget {
  const _MediaTile({
    super.key,
    required this.assetId,
    required this.isActive,
    required this.speedNotifier,
  });

  final String assetId;
  final bool isActive;
  final ValueNotifier<double> speedNotifier;

  @override
  State<_MediaTile> createState() => _MediaTileState();
}

class _MediaTileState extends State<_MediaTile> {
  Uint8List? _imageBytes;
  VideoPlayerController? _videoCtrl;
  bool _loading = true;
  late ValueNotifier<double> _speedNotifier;

  @override
  void initState() {
    super.initState();
    _speedNotifier = widget.speedNotifier;
    _speedNotifier.addListener(_onSpeedChanged);
    _load();
  }

  @override
  void didUpdateWidget(_MediaTile old) {
    super.didUpdateWidget(old);
    if (widget.speedNotifier != _speedNotifier) {
      _speedNotifier.removeListener(_onSpeedChanged);
      _speedNotifier = widget.speedNotifier;
      _speedNotifier.addListener(_onSpeedChanged);
    }
    if (!widget.isActive && old.isActive) {
      _videoCtrl?.pause();
    } else if (widget.isActive && !old.isActive) {
      _videoCtrl?.play();
    }
  }

  void _onSpeedChanged() {
    _videoCtrl?.setPlaybackSpeed(_speedNotifier.value);
  }

  Future<void> _load() async {
    final asset = await AssetEntity.fromId(widget.assetId);
    if (asset == null || !mounted) return;

    if (asset.type == AssetType.video) {
      final file = await asset.file;
      if (file == null || !mounted) return;
      final ctrl = VideoPlayerController.file(file);
      await ctrl.initialize();
      if (!mounted) {
        ctrl.dispose();
        return;
      }
      await ctrl.setLooping(true);
      _videoCtrl = ctrl;
      if (widget.isActive) ctrl.play();
    } else {
      final bytes = await asset.thumbnailDataWithSize(
        const ThumbnailSize(1080, 1920),
      );
      if (!mounted) return;
      _imageBytes = bytes;
    }

    if (mounted) setState(() => _loading = false);
  }

  @override
  void dispose() {
    _speedNotifier.removeListener(_onSpeedChanged);
    _videoCtrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const ColoredBox(
        color: Colors.black,
        child: Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    final ctrl = _videoCtrl;
    if (ctrl != null) {
      return Stack(
        fit: StackFit.expand,
        children: [
          GestureDetector(
            onTap: () {
              ctrl.value.isPlaying ? ctrl.pause() : ctrl.play();
              setState(() {});
            },
            child: Center(
              child: AspectRatio(
                aspectRatio: ctrl.value.aspectRatio,
                child: VideoPlayer(ctrl),
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: VideoProgressIndicator(
              ctrl,
              allowScrubbing: true,
              colors: const VideoProgressColors(
                playedColor: Colors.white,
                bufferedColor: Colors.white38,
                backgroundColor: Colors.white12,
              ),
            ),
          ),
        ],
      );
    }

    final bytes = _imageBytes;
    if (bytes != null) {
      return Image.memory(bytes, fit: BoxFit.cover);
    }

    return const Center(
      child: Icon(Icons.broken_image_outlined, color: Colors.white54, size: 64),
    );
  }
}

// ─── Address + distance row ───────────────────────────────────────────────

/// [dark] = true: Loop (white text), false: List (default theme color)
class EventAddressRow extends ConsumerWidget {
  const EventAddressRow({super.key, required this.event, this.dark = false});

  final EventSummary event;
  final bool dark;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userLoc = ref.watch(userLocationProvider).valueOrNull;

    String? distLabel;
    if (userLoc != null &&
        event.latitude != null &&
        event.longitude != null) {
      final km = distanceKm(
        userLoc.latitude, userLoc.longitude,
        event.latitude!, event.longitude!,
      );
      final label = formatDistanceLabel(km);
      if (label.isNotEmpty) distLabel = label;
    }

    // Don't render if there's no address and no distance
    if (event.customAddress == null && distLabel == null) {
      return const SizedBox.shrink();
    }

    final textColor = dark ? Colors.white70 : Theme.of(context).colorScheme.onSurfaceVariant;
    final iconColor = dark ? Colors.white70 : Theme.of(context).colorScheme.onSurfaceVariant;

    return Row(
      children: [
        Icon(Icons.place_outlined, color: iconColor, size: 14),
        const SizedBox(width: 4),
        if (event.customAddress != null)
          Flexible(
            child: Text(
              event.customAddress!,
              style: TextStyle(color: textColor, fontSize: 13),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        if (distLabel != null) ...[
          if (event.customAddress != null) const SizedBox(width: 4),
          Text(
            '($distLabel)',
            style: TextStyle(color: textColor, fontSize: 12),
          ),
        ],
      ],
    );
  }
}
