import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:photo_manager/photo_manager.dart';

import '../models/event_summary.dart';
import '../providers/diary_providers.dart';
import 'add_to_folder_screen.dart';
import 'event_detail_screen.dart';
import 'event_map_screen.dart';
import 'memory_reel_view.dart';

class RecapScreen extends ConsumerWidget {
  const RecapScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final viewMode = ref.watch(diaryViewModeProvider);
    final eventsAsync = ref.watch(filteredJournalEventsProvider);

    if (viewMode == DiaryViewMode.map) {
      return const EventMapScreen(key: ValueKey('recap_map'));
    }

    if (viewMode == DiaryViewMode.reel) {
      return const MemoryReelView();
    }

    return eventsAsync.when(
      data: (events) {
        if (events.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.auto_stories_outlined, size: 48,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3)),
                const SizedBox(height: 12),
                Text(
                  'No events found',
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
                ),
                const SizedBox(height: 4),
                Text(
                  'Try adjusting your filters',
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45),
                      fontSize: 13),
                ),
              ],
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: events.length,
          itemBuilder: (ctx, i) => EventListTile(event: events[i]),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Failed to load events: $e')),
    );
  }
}

class EventListTile extends StatelessWidget {
  const EventListTile({super.key, required this.event});

  final EventSummary event;

  String _relativeDate(DateTime dt) {
    final diff = DateTime.now().difference(dt.toLocal());
    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return '1 day ago';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    final weeks = (diff.inDays / 7).floor();
    if (diff.inDays < 30) return weeks == 1 ? '1 week ago' : '$weeks weeks ago';
    final months = (diff.inDays / 30).floor();
    if (diff.inDays < 365) return months == 1 ? '1 month ago' : '$months months ago';
    final years = (diff.inDays / 365).floor();
    return years == 1 ? '1 year ago' : '$years years ago';
  }

  @override
  Widget build(BuildContext context) {
    final formatter = DateFormat('MMM d, yyyy · HH:mm');
    final local = event.startAt.toLocal();

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      clipBehavior: Clip.hardEdge,
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => EventDetailScreen(event: event)),
        ),
        onLongPress: () => _showContextMenu(context, event),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (event.assetIds.isNotEmpty ||
                event.representativeAssetId != 'manual_no_photo')
              EventCardGallery(event: event),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FutureBuilder<AssetEntity?>(
                    future: event.representativeAssetId == 'manual_no_photo'
                        ? Future.value(null)
                        : AssetEntity.fromId(event.representativeAssetId),
                    builder: (ctx, snap) {
                      final isVideo = snap.data?.type == AssetType.video;
                      final count = event.assetCount;
                      final mediaLabel = isVideo
                          ? '$count ${count == 1 ? 'video' : 'videos'}'
                          : '$count ${count == 1 ? 'photo' : 'photos'}';
                      return Text(
                        event.title ?? mediaLabel,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        formatter.format(local),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '(${_relativeDate(local)})',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .primary
                                  .withValues(alpha: 0.8),
                            ),
                      ),
                      if (event.isFavorite) ...[
                        const Spacer(),
                        const Icon(Icons.star, color: Colors.amber, size: 16),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showContextMenu(BuildContext context, EventSummary event) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.folder_outlined),
              title: const Text('Add to folder'),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AddToFolderScreen(eventId: event.eventId),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('View details'),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => EventDetailScreen(event: event),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class EventCardGallery extends StatefulWidget {
  const EventCardGallery({super.key, required this.event});
  final EventSummary event;

  @override
  State<EventCardGallery> createState() => _CardGalleryState();
}

class _CardGalleryState extends State<EventCardGallery> {
  int _page = 0;

  List<String> get _ids {
    if (widget.event.assetIds.isNotEmpty) return widget.event.assetIds;
    if (widget.event.representativeAssetId != 'manual_no_photo') {
      return [widget.event.representativeAssetId];
    }
    return [];
  }

  @override
  Widget build(BuildContext context) {
    final ids = _ids;
    if (ids.isEmpty) return const SizedBox.shrink();

    return Stack(
      children: [
        SizedBox(
          height: 220,
          child: PageView.builder(
            itemCount: ids.length,
            onPageChanged: (i) => setState(() => _page = i),
            itemBuilder: (ctx, i) => FutureBuilder<AssetEntity?>(
              future: AssetEntity.fromId(ids[i]),
              builder: (ctx, assetSnap) {
                if (!assetSnap.hasData) {
                  return Container(
                    color: Theme.of(ctx).colorScheme.surfaceContainerHighest,
                  );
                }
                return FutureBuilder<Uint8List?>(
                  future: assetSnap.data!.thumbnailDataWithSize(
                    const ThumbnailSize(800, 440),
                  ),
                  builder: (ctx2, thumbSnap) {
                    if (!thumbSnap.hasData) {
                      return Container(
                        color: Theme.of(ctx2)
                            .colorScheme
                            .surfaceContainerHighest,
                      );
                    }
                    return Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.memory(
                          thumbSnap.data!,
                          fit: BoxFit.cover,
                        ),
                        if (assetSnap.data!.type == AssetType.video)
                          const Center(
                            child: Icon(
                              Icons.play_circle_outline,
                              color: Colors.white,
                              size: 48,
                            ),
                          ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ),
        if (ids.length > 1)
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${_page + 1}/${ids.length}',
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
          ),
        if (widget.event.color != null)
          Positioned(
            bottom: 8,
            right: 8,
            child: Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: Color(widget.event.color!),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1.5),
              ),
            ),
          ),
      ],
    );
  }
}
