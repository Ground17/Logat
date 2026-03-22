import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:video_player/video_player.dart';

import '../models/event_summary.dart';
import '../providers/diary_providers.dart';
import 'event_detail_screen.dart';

class MemoryReelView extends ConsumerWidget {
  const MemoryReelView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsAsync = ref.watch(reelItemsProvider);
    return itemsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (items) {
        if (items.isEmpty) {
          return const Center(
            child: Text(
              '추억이 없어요',
              style: TextStyle(fontSize: 18),
            ),
          );
        }
        return _ReelPageView(items: items);
      },
    );
  }
}

class _ReelPageView extends StatefulWidget {
  const _ReelPageView({required this.items});

  final List<({String assetId, EventSummary event})> items;

  @override
  State<_ReelPageView> createState() => _ReelPageViewState();
}

class _ReelPageViewState extends State<_ReelPageView> {
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
      itemCount: widget.items.length,
      onPageChanged: (idx) {
        setState(() => _currentPage = idx);
      },
      itemBuilder: (ctx, i) => _ReelPage(
        key: ValueKey(widget.items[i].assetId + i.toString()),
        item: widget.items[i],
        isActive: i == _currentPage,
      ),
    );
  }
}

class _ReelPage extends ConsumerStatefulWidget {
  const _ReelPage({
    super.key,
    required this.item,
    required this.isActive,
  });

  final ({String assetId, EventSummary event}) item;
  final bool isActive;

  @override
  ConsumerState<_ReelPage> createState() => _ReelPageState();
}

class _ReelPageState extends ConsumerState<_ReelPage> {
  Uint8List? _imageBytes;
  VideoPlayerController? _videoCtrl;
  bool _isFavorite = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _isFavorite = widget.item.event.isFavorite;
    _load();
  }

  @override
  void didUpdateWidget(_ReelPage old) {
    super.didUpdateWidget(old);
    if (!widget.isActive && old.isActive) {
      _videoCtrl?.pause();
    } else if (widget.isActive && !old.isActive) {
      _videoCtrl?.play();
    }
  }

  Future<void> _load() async {
    final asset = await AssetEntity.fromId(widget.item.assetId);
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
    _videoCtrl?.dispose();
    super.dispose();
  }

  Future<void> _toggleFavorite() async {
    final newValue = !_isFavorite;
    setState(() => _isFavorite = newValue);
    await ref
        .read(appDatabaseProvider)
        .updateEventFavorite(widget.item.event.eventId, newValue);
    ref.invalidate(filteredJournalEventsProvider);
  }

  @override
  Widget build(BuildContext context) {
    final event = widget.item.event;

    if (_loading) {
      return const ColoredBox(
        color: Colors.black,
        child: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        // 1. Media (fullscreen)
        ColoredBox(color: Colors.black, child: _buildMedia()),

        // 2. Bottom gradient + metadata
        Positioned(
          bottom: 0,
          left: 0,
          right: 60,
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [Colors.black87, Colors.transparent],
                stops: [0.0, 1.0],
              ),
            ),
            padding: const EdgeInsets.fromLTRB(16, 40, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  DateFormat('yyyy년 M월 d일').format(event.startAt.toLocal()),
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
                if (event.customAddress != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.place_outlined,
                          color: Colors.white70, size: 14),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          event.customAddress!,
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 13),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
                if (event.tags.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: event.tags
                        .take(3)
                        .map(
                          (t) => Container(
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
                          ),
                        )
                        .toList(),
                  ),
                ],
              ],
            ),
          ),
        ),

        // 3. Right sidebar (favorite, detail)
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

        // 4. Video progress indicator
        if (_videoCtrl != null)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: VideoProgressIndicator(
              _videoCtrl!,
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

  Widget _buildMedia() {
    final ctrl = _videoCtrl;
    if (ctrl != null) {
      return GestureDetector(
        onTap: () {
          if (ctrl.value.isPlaying) {
            ctrl.pause();
          } else {
            ctrl.play();
          }
          setState(() {});
        },
        child: Center(
          child: AspectRatio(
            aspectRatio: ctrl.value.aspectRatio,
            child: VideoPlayer(ctrl),
          ),
        ),
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
