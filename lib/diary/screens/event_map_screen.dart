import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import 'package:photo_manager/photo_manager.dart' hide LatLng;

import '../models/event_summary.dart';
import '../providers/diary_providers.dart';
import '../services/geocoding_service.dart';
import 'event_detail_screen.dart';

class EventMapScreen extends ConsumerStatefulWidget {
  const EventMapScreen({super.key});

  @override
  ConsumerState<EventMapScreen> createState() => _EventMapScreenState();
}

class _EventMapScreenState extends ConsumerState<EventMapScreen> {
  void _showEventBottomSheet(BuildContext context, EventSummary event) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => _EventBottomSheet(event: event),
    );
  }

  @override
  Widget build(BuildContext context) {
    final eventsAsync = ref.watch(filteredJournalEventsProvider);

    return Scaffold(
      body: eventsAsync.when(
        data: (events) {
          final geoEvents = events
              .where((item) => item.latitude != null && item.longitude != null)
              .toList();
          if (geoEvents.isEmpty) {
            return const Center(
              child: Text('No events with location data yet.'),
            );
          }

          final first = geoEvents.first;
          return Stack(
            children: [
              GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: LatLng(first.latitude!, first.longitude!),
                  zoom: 11,
                ),
                onMapCreated: (controller) {
                  ref.read(mapControllerProvider.notifier).state = controller;
                },
                myLocationButtonEnabled: false,
                myLocationEnabled: false,
                markers: geoEvents
                    .map(
                      (event) => Marker(
                        markerId: MarkerId(event.eventId),
                        position: LatLng(event.latitude!, event.longitude!),
                        icon: event.color != null
                            ? BitmapDescriptor.defaultMarkerWithHue(
                                HSVColor.fromColor(Color(event.color!)).hue)
                            : BitmapDescriptor.defaultMarkerWithHue(
                                BitmapDescriptor.hueRose),
                        onTap: () => _showEventBottomSheet(context, event),
                      ),
                    )
                    .toSet(),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Map data failed: $error')),
      ),
    );
  }
}

class _EventBottomSheet extends StatefulWidget {
  const _EventBottomSheet({required this.event});

  final EventSummary event;

  @override
  State<_EventBottomSheet> createState() => _EventBottomSheetState();
}

class _EventBottomSheetState extends State<_EventBottomSheet> {
  String? _address;

  @override
  void initState() {
    super.initState();
    _loadAddress();
  }

  Future<void> _loadAddress() async {
    if (widget.event.latitude == null || widget.event.longitude == null) return;
    final address = await GeocodingService()
        .reverseGeocode(widget.event.latitude!, widget.event.longitude!);
    if (mounted) setState(() => _address = address);
  }

  @override
  Widget build(BuildContext context) {
    final event = widget.event;
    final formatter = DateFormat('MMM d, yyyy HH:mm');

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (event.representativeAssetId == 'manual_no_photo')
            Container(
              height: 140,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Center(
                child: Icon(Icons.note_alt_outlined, size: 48),
              ),
            )
          else
            FutureBuilder<AssetEntity?>(
              future: AssetEntity.fromId(event.representativeAssetId),
              builder: (ctx, snap) {
                if (!snap.hasData) {
                  return Container(
                    height: 140,
                    decoration: BoxDecoration(
                      color:
                          Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  );
                }
                return FutureBuilder<Uint8List?>(
                  future: snap.data!.thumbnailDataWithSize(
                    const ThumbnailSize(400, 140),
                  ),
                  builder: (ctx2, thumbSnap) {
                    if (!thumbSnap.hasData) {
                      return Container(
                        height: 140,
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(8),
                        ),
                      );
                    }
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.memory(
                        thumbSnap.data!,
                        height: 140,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    );
                  },
                );
              },
            ),
          const SizedBox(height: 12),
          Text(
            event.title ?? '${event.assetCount} items',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(
            formatter.format(event.startAt.toLocal()),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (event.latitude != null) ...[
            const SizedBox(height: 2),
            Text(
              _address ??
                  '${event.latitude!.toStringAsFixed(4)}, ${event.longitude!.toStringAsFixed(4)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          if (event.userMemo != null) ...[
            const SizedBox(height: 8),
            Text(
              event.userMemo!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => EventDetailScreen(event: event),
                  ),
                );
              },
              child: const Text('View Details'),
            ),
          ),
        ],
      ),
    );
  }
}
