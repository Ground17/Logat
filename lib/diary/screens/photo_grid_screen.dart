import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_manager/photo_manager.dart' hide LatLng;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/event_summary.dart';
import '../providers/diary_providers.dart';
import 'event_detail_screen.dart';

class PhotoGridScreen extends ConsumerStatefulWidget {
  const PhotoGridScreen({super.key});

  @override
  ConsumerState<PhotoGridScreen> createState() => _PhotoGridScreenState();
}

class _PhotoGridScreenState extends ConsumerState<PhotoGridScreen> {
  @override
  void initState() {
    super.initState();
    _loadColumnCount();
  }

  Future<void> _loadColumnCount() async {
    final prefs = await SharedPreferences.getInstance();
    final count = prefs.getInt('grid_column_count') ?? 3;
    if (mounted) ref.read(gridColumnCountProvider.notifier).state = count;
  }

  Future<void> _setColumnCount(int count) async {
    ref.read(gridColumnCountProvider.notifier).state = count;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('grid_column_count', count);
  }

  void showColumnPicker(BuildContext context) {
    final current = ref.read(gridColumnCountProvider);
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                '열 수 설정',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
            for (int n = 3; n <= 5; n++)
              ListTile(
                title: Text('$n열'),
                trailing: n == current
                    ? Icon(Icons.check,
                        color: Theme.of(ctx).colorScheme.primary)
                    : null,
                onTap: () {
                  _setColumnCount(n);
                  Navigator.pop(ctx);
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final eventsAsync = ref.watch(filteredJournalEventsProvider);
    final columns = ref.watch(gridColumnCountProvider);

    return Stack(
      children: [
        eventsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Failed to load: $e')),
          data: (events) {
            if (events.isEmpty) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.photo_library_outlined,
                        size: 48,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.3)),
                    const SizedBox(height: 12),
                    Text(
                      'No events found',
                      style: TextStyle(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.6)),
                    ),
                  ],
                ),
              );
            }
            return GridView.builder(
              padding: const EdgeInsets.all(2),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                crossAxisSpacing: 2,
                mainAxisSpacing: 2,
              ),
              itemCount: events.length,
              itemBuilder: (ctx, i) => _GridTile(event: events[i]),
            );
          },
        ),
        // Column count picker button
        Positioned(
          bottom: 16,
          right: 16,
          child: _ColumnPickerButton(
            onTap: () => showColumnPicker(context),
          ),
        ),
      ],
    );
  }
}

// ─── Column picker button ─────────────────────────────────────────────────

class _ColumnPickerButton extends ConsumerWidget {
  const _ColumnPickerButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final columns = ref.watch(gridColumnCountProvider);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(blurRadius: 6, color: Colors.black26, offset: Offset(0, 2)),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.grid_view_outlined, size: 16),
            const SizedBox(width: 6),
            for (int n = 3; n <= 5; n++) ...[
              if (n > 3) const SizedBox(width: 2),
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: n == columns
                      ? Theme.of(context).colorScheme.primary
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Text(
                  '$n',
                  style: TextStyle(
                    color: n == columns
                        ? Theme.of(context).colorScheme.onPrimary
                        : Theme.of(context).colorScheme.onSurface,
                    fontWeight: n == columns ? FontWeight.bold : FontWeight.normal,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Grid tile ────────────────────────────────────────────────────────────

class _GridTile extends StatefulWidget {
  const _GridTile({required this.event});
  final EventSummary event;

  @override
  State<_GridTile> createState() => _GridTileState();
}

class _GridTileState extends State<_GridTile> {
  Uint8List? _thumb;

  @override
  void initState() {
    super.initState();
    _loadThumb();
  }

  Future<void> _loadThumb() async {
    final id = widget.event.representativeAssetId;
    if (id == 'manual_no_photo') return;
    final asset = await AssetEntity.fromId(id);
    if (asset == null || !mounted) return;
    final bytes =
        await asset.thumbnailDataWithSize(const ThumbnailSize(300, 300));
    if (mounted) setState(() => _thumb = bytes);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => EventDetailScreen(event: widget.event)),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (_thumb != null)
            Image.memory(_thumb!, fit: BoxFit.cover)
          else
            Container(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: const Icon(Icons.photo_outlined,
                  color: Colors.white54, size: 28),
            ),
          if (widget.event.isFavorite)
            const Positioned(
              top: 3,
              right: 3,
              child: Icon(Icons.favorite, color: Colors.red, size: 12),
            ),
          if (widget.event.color != null)
            Positioned(
              bottom: 3,
              right: 3,
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: Color(widget.event.color!),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
