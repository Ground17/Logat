import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import 'package:photo_manager/photo_manager.dart' hide LatLng;
import 'package:reorderable_grid_view/reorderable_grid_view.dart';
import 'package:video_player/video_player.dart';

import '../models/event_summary.dart';
import '../models/folder.dart';
import '../models/heuristic_tag.dart';
import '../providers/diary_providers.dart';
import '../services/view_count_service.dart';
import '../services/geocoding_service.dart';
import 'location_picker_screen.dart';
import 'share_customize_screen.dart';

class EventDetailScreen extends ConsumerStatefulWidget {
  const EventDetailScreen({super.key, required this.event});

  final EventSummary event;

  @override
  ConsumerState<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends ConsumerState<EventDetailScreen> {
  late EventSummary _event;
  String? _address; // resolved or overridden address text
  bool _loadingAddress = false;
  List<DiaryFolder> _eventFolders = [];

  static const _colorOptions = [
    Color(0xFFBF616A), // Red
    Color(0xFF88C0D0), // Sky
    Color(0xFFEBCB8B), // Yellow
    Color(0xFFA3BE8C), // Green
    Color(0xFF5E81AC), // Blue
    Color(0xFFB48EAD), // Purple
  ];

  @override
  void initState() {
    super.initState();
    _event = widget.event;
    _loadAddress();
    _loadFolders();
    ViewCountService.increment(widget.event.eventId);
  }

  Future<void> _loadFolders() async {
    final db = ref.read(appDatabaseProvider);
    final folders = await db.getFoldersForEvent(_event.eventId);
    if (mounted) setState(() => _eventFolders = folders);
  }

  Future<void> _showFolderPicker() async {
    final db = ref.read(appDatabaseProvider);
    final all = await db.getAllFolders();
    if (!mounted) return;

    final currentIds = _eventFolders.map((f) => f.folderId).toSet();
    final selected = Set<String>.from(currentIds);

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _FolderPickerSheet(
        folders: all,
        initialSelected: selected,
        onCreateFolder: (name) async {
          final folderId = 'folder_${DateTime.now().millisecondsSinceEpoch}';
          await db.insertFolder(folderId: folderId, name: name);
          return db.getAllFolders();
        },
        onConfirm: (chosen) async {
          final toAdd = chosen.difference(currentIds);
          final toRemove = currentIds.difference(chosen);
          for (final id in toAdd) {
            await db.addEventToFolder(id, _event.eventId);
          }
          for (final id in toRemove) {
            await db.removeEventFromFolder(id, _event.eventId);
          }
          await _loadFolders();
          ref.invalidate(folderContentsProvider(_event.eventId));
        },
      ),
    );
  }

  Future<void> _loadAddress() async {
    // Use custom address if set
    if (_event.customAddress != null) {
      setState(() => _address = _event.customAddress);
      return;
    }
    if (_event.latitude == null || _event.longitude == null) return;
    setState(() => _loadingAddress = true);
    final address = await GeocodingService()
        .reverseGeocode(_event.latitude!, _event.longitude!);
    if (mounted) {
      setState(() {
        _address = address;
        _loadingAddress = false;
      });
    }
  }

  Future<void> _editDetails() async {
    final titleCtrl = TextEditingController(text: _event.title ?? '');
    final memoCtrl = TextEditingController(text: _event.userMemo ?? '');
    int? selectedColor = _event.color; // -1 = clear, null = no change

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('Edit Event'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Title',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: memoCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Memo',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Color',
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    // No color option
                    GestureDetector(
                      onTap: () => setS(() => selectedColor = -1),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: selectedColor == -1
                                ? Theme.of(ctx).colorScheme.primary
                                : Colors.grey.shade400,
                            width: selectedColor == -1 ? 2.5 : 1,
                          ),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(Icons.cancel_outlined, size: 18),
                      ),
                    ),
                    // Color swatches
                    ..._colorOptions.asMap().entries.map((e) {
                      final isSelected = selectedColor == e.value.toARGB32();
                      return GestureDetector(
                        onTap: () =>
                            setS(() => selectedColor = e.value.toARGB32()),
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: e.value,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: isSelected
                                  ? Theme.of(ctx).colorScheme.primary
                                  : Colors.transparent,
                              width: isSelected ? 2.5 : 0,
                            ),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: e.value.withValues(alpha: 0.5),
                                      blurRadius: 6,
                                    )
                                  ]
                                : null,
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    if (saved == true && mounted) {
      final db = ref.read(appDatabaseProvider);
      final newTitle =
          titleCtrl.text.trim().isEmpty ? null : titleCtrl.text.trim();
      final newMemo =
          memoCtrl.text.trim().isEmpty ? null : memoCtrl.text.trim();
      // -1 sentinel = clear color
      final newColor = selectedColor == -1 ? null : selectedColor;
      final colorChanged = newColor != _event.color;

      await db.updateEventDetails(
        _event.eventId,
        title: newTitle,
        userMemo: newMemo,
      );
      if (colorChanged) {
        await db.updateEventColor(_event.eventId, newColor);
      }

      setState(() {
        _event = EventSummary(
          eventId: _event.eventId,
          startAt: _event.startAt,
          endAt: _event.endAt,
          assetCount: _event.assetCount,
          representativeAssetId: _event.representativeAssetId,
          qualityScore: _event.qualityScore,
          isMoving: _event.isMoving,
          assetIds: _event.assetIds,
          tags: _event.tags,
          latitude: _event.latitude,
          longitude: _event.longitude,
          isManual: _event.isManual,
          title: newTitle,
          userMemo: newMemo,
          isFavorite: _event.isFavorite,
          color: newColor,
          customAddress: _event.customAddress,
        );
      });
      ref.invalidate(mapEventsProvider);
      ref.invalidate(filteredJournalEventsProvider);
    }
  }

  Future<void> _editTime() async {
    final local = _event.startAt.toLocal();

    // Pick date
    final date = await showDatePicker(
      context: context,
      initialDate: local,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;

    // Pick time
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(local),
    );
    if (time == null || !mounted) return;

    final newStart = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    ).toUtc();
    final duration = _event.endAt.difference(_event.startAt);
    final newEnd = newStart.add(duration);

    final db = ref.read(appDatabaseProvider);
    await db.updateEventTime(_event.eventId, newStart, newEnd);
    setState(() {
      _event = _copyEvent(startAt: newStart, endAt: newEnd);
    });
    ref.invalidate(filteredJournalEventsProvider);
  }

  Future<void> _editLocation() async {
    final initial = (_event.latitude != null && _event.longitude != null)
        ? LatLng(_event.latitude!, _event.longitude!)
        : null;

    final result = await Navigator.push<LatLng>(
      context,
      MaterialPageRoute(
        builder: (_) => LocationPickerScreen(initialLatLng: initial),
      ),
    );
    if (result == null || !mounted) return;

    final db = ref.read(appDatabaseProvider);
    await db.updateEventLocation(
        _event.eventId, result.latitude, result.longitude);
    setState(() {
      _event =
          _copyEvent(latitude: result.latitude, longitude: result.longitude);
      _address = null;
      _loadingAddress = true;
    });
    ref.invalidate(mapEventsProvider);
    ref.invalidate(filteredJournalEventsProvider);

    // Reverse geocode and offer to update address
    final newAddr = await GeocodingService()
        .reverseGeocode(result.latitude, result.longitude);
    if (!mounted) return;
    setState(() {
      _loadingAddress = false;
      _address = newAddr;
    });

    if (newAddr.isNotEmpty) {
      final update = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Update address?'),
          content: Text(newAddr),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Keep current'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Update'),
            ),
          ],
        ),
      );
      if (update == true && mounted) {
        await db.updateEventAddress(_event.eventId, newAddr);
        setState(() => _event = _copyEvent(customAddress: newAddr));
      }
    }
  }

  Future<void> _editAddress() async {
    final ctrl = TextEditingController(text: _address ?? '');
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit address'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: 'Enter address',
          ),
          maxLines: 2,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (saved != true || !mounted) return;

    final newAddr = ctrl.text.trim().isEmpty ? null : ctrl.text.trim();
    final db = ref.read(appDatabaseProvider);
    await db.updateEventAddress(_event.eventId, newAddr);
    setState(() {
      _address = newAddr;
      _event = _copyEvent(customAddress: newAddr);
    });
  }

  Future<void> _toggleFavorite() async {
    final db = ref.read(appDatabaseProvider);
    final newValue = !_event.isFavorite;
    await db.updateEventFavorite(_event.eventId, newValue);
    setState(() => _event = _copyEvent(isFavorite: newValue));
    ref.invalidate(mapEventsProvider);
    ref.invalidate(filteredJournalEventsProvider);
  }

  // Helper to copy _event with partial overrides
  EventSummary _copyEvent({
    DateTime? startAt,
    DateTime? endAt,
    double? latitude,
    double? longitude,
    String? customAddress,
    int? color,
    String? title,
    String? userMemo,
    bool? isFavorite,
  }) {
    return EventSummary(
      eventId: _event.eventId,
      startAt: startAt ?? _event.startAt,
      endAt: endAt ?? _event.endAt,
      assetCount: _event.assetCount,
      representativeAssetId: _event.representativeAssetId,
      qualityScore: _event.qualityScore,
      isMoving: _event.isMoving,
      assetIds: _event.assetIds,
      tags: _event.tags,
      latitude: latitude ?? _event.latitude,
      longitude: longitude ?? _event.longitude,
      isManual: _event.isManual,
      title: title ?? _event.title,
      userMemo: userMemo ?? _event.userMemo,
      isFavorite: isFavorite ?? _event.isFavorite,
      color: color ?? _event.color,
      customAddress: customAddress ?? _event.customAddress,
    );
  }

  Future<void> _addTag() async {
    final tagCtrl = TextEditingController();
    final added = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Tag'),
        content: TextField(
          controller: tagCtrl,
          decoration: const InputDecoration(
            labelText: 'Tag name',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (added == true && tagCtrl.text.trim().isNotEmpty && mounted) {
      final name = tagCtrl.text.trim();
      final tagId = name.toLowerCase().replaceAll(' ', '_');
      final db = ref.read(appDatabaseProvider);
      await db.addEventTag(_event.eventId, tagId, name);
      final newTag = HeuristicTag(
        id: tagId,
        name: name,
        type: 'user',
        confidence: 1.0,
      );
      setState(() {
        _event = EventSummary(
          eventId: _event.eventId,
          startAt: _event.startAt,
          endAt: _event.endAt,
          assetCount: _event.assetCount,
          representativeAssetId: _event.representativeAssetId,
          qualityScore: _event.qualityScore,
          isMoving: _event.isMoving,
          assetIds: _event.assetIds,
          tags: [..._event.tags, newTag],
          latitude: _event.latitude,
          longitude: _event.longitude,
          isManual: _event.isManual,
          title: _event.title,
          userMemo: _event.userMemo,
          isFavorite: _event.isFavorite,
          color: _event.color,
          customAddress: _event.customAddress,
        );
      });
      ref.invalidate(mapEventsProvider);
      ref.invalidate(filteredJournalEventsProvider);
    }
  }

  Future<void> _removeTag(HeuristicTag tag) async {
    final db = ref.read(appDatabaseProvider);
    await db.removeEventTag(_event.eventId, tag.id);
    setState(() {
      _event = EventSummary(
        eventId: _event.eventId,
        startAt: _event.startAt,
        endAt: _event.endAt,
        assetCount: _event.assetCount,
        representativeAssetId: _event.representativeAssetId,
        qualityScore: _event.qualityScore,
        isMoving: _event.isMoving,
        assetIds: _event.assetIds,
        tags: _event.tags.where((t) => t.id != tag.id).toList(),
        latitude: _event.latitude,
        longitude: _event.longitude,
        isManual: _event.isManual,
        title: _event.title,
        userMemo: _event.userMemo,
        isFavorite: _event.isFavorite,
        color: _event.color,
        customAddress: _event.customAddress,
      );
    });
    ref.invalidate(mapEventsProvider);
    ref.invalidate(filteredJournalEventsProvider);
  }

  String _relativeDate(DateTime dt) {
    final diff = DateTime.now().difference(dt.toLocal());
    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return '1 day ago';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    final weeks = (diff.inDays / 7).floor();
    if (diff.inDays < 30) return weeks == 1 ? '1 week ago' : '$weeks weeks ago';
    final months = (diff.inDays / 30).floor();
    if (diff.inDays < 365) {
      return months == 1 ? '1 month ago' : '$months months ago';
    }
    final years = (diff.inDays / 365).floor();
    return years == 1 ? '1 year ago' : '$years years ago';
  }

  Future<void> _deleteEvent() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Memory'),
        content: const Text(
            'This memory will be permanently deleted. This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final db = ref.read(appDatabaseProvider);
    await db.deleteEvent(_event.eventId);
    ref.invalidate(filteredJournalEventsProvider);
    ref.invalidate(mapEventsProvider);
    ref.invalidate(dailyStatsProvider);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _editAssetOrder() async {
    final ids = List<String>.from(_event.assetIds
        .where((id) => id != 'manual_no_photo'));
    if (ids.length < 2) return;

    final result = await Navigator.push<List<String>>(
      context,
      MaterialPageRoute(
        builder: (_) => _AssetReorderScreen(assetIds: ids),
      ),
    );
    if (result == null || !mounted) return;

    final db = ref.read(appDatabaseProvider);
    await db.updateEventAssetOrder(_event.eventId, result);
    setState(() {
      _event = EventSummary(
        eventId: _event.eventId,
        startAt: _event.startAt,
        endAt: _event.endAt,
        assetCount: _event.assetCount,
        representativeAssetId: result.first,
        qualityScore: _event.qualityScore,
        isMoving: _event.isMoving,
        assetIds: result,
        tags: _event.tags,
        latitude: _event.latitude,
        longitude: _event.longitude,
        isManual: _event.isManual,
        title: _event.title,
        userMemo: _event.userMemo,
        isFavorite: _event.isFavorite,
        color: _event.color,
        customAddress: _event.customAddress,
      );
    });
    ref.invalidate(filteredJournalEventsProvider);
  }

  Future<void> _splitEvent() async {
    final result = await Navigator.push<List<String>>(
      context,
      MaterialPageRoute(
        builder: (_) => _SplitScreen(event: _event),
      ),
    );
    if (result == null || !mounted) return;
    final db = ref.read(appDatabaseProvider);
    await db.splitEvent(_event.eventId, result);
    ref.invalidate(mapEventsProvider);
    ref.invalidate(filteredJournalEventsProvider);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _mergeEvent() async {
    final picked = await Navigator.push<EventSummary>(
      context,
      MaterialPageRoute(
        builder: (_) => _MergePickerScreen(currentEventId: _event.eventId),
      ),
    );
    if (picked == null || !mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Merge events?'),
        content: Text(
          'Merge ${_event.assetCount} photos into "${picked.title ?? 'Memory'}"?\n\nThis event will be deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Merge'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final db = ref.read(appDatabaseProvider);
    await db.mergeEventsInto(picked.eventId, _event.eventId);
    ref.invalidate(mapEventsProvider);
    ref.invalidate(filteredJournalEventsProvider);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final formatter = DateFormat('MMM d, yyyy HH:mm');

    return Scaffold(
      appBar: AppBar(
        title: Text(_event.title ?? 'Memory'),
        actions: [
          IconButton(
            icon: Icon(
              _event.isFavorite ? Icons.favorite : Icons.favorite_border,
              color: _event.isFavorite ? Colors.red : null,
            ),
            tooltip: _event.isFavorite
                ? 'Remove from favorites'
                : 'Add to favorites',
            onPressed: _toggleFavorite,
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: _editDetails,
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'share',
                child: Row(
                  children: [
                    Icon(Icons.share_outlined, size: 20),
                    SizedBox(width: 8),
                    Text('Share'),
                  ],
                ),
              ),
              if (_event.assetIds.length >= 2)
                const PopupMenuItem(
                  value: 'reorder',
                  child: Row(
                    children: [
                      Icon(Icons.swap_vert, size: 20),
                      SizedBox(width: 8),
                      Text('Reorder media'),
                    ],
                  ),
                ),
              if (_event.assetIds.length >= 2)
                const PopupMenuItem(
                  value: 'split',
                  child: Row(
                    children: [
                      Icon(Icons.call_split, size: 20),
                      SizedBox(width: 8),
                      Text('Split event'),
                    ],
                  ),
                ),
              const PopupMenuItem(
                value: 'merge',
                child: Row(
                  children: [
                    Icon(Icons.merge, size: 20),
                    SizedBox(width: 8),
                    Text('Merge with…'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline, size: 20, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Delete', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
            onSelected: (v) {
              if (v == 'share') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ShareCustomizeScreen(event: _event),
                  ),
                );
              }
              if (v == 'reorder') _editAssetOrder();
              if (v == 'split') _splitEvent();
              if (v == 'merge') _mergeEvent();
              if (v == 'delete') _deleteEvent();
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_event.assetIds.isNotEmpty)
            _MediaGallery(assetIds: _event.assetIds)
          else if (_event.representativeAssetId != 'manual_no_photo')
            _MediaGallery(assetIds: [_event.representativeAssetId])
          else
            Container(
              height: 200,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(
                child: Icon(Icons.note_alt_outlined, size: 64),
              ),
            ),
          const SizedBox(height: 16),
          if (_event.title != null)
            Text(
              _event.title!,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          const SizedBox(height: 8),
          // Time row — tappable to edit
          InkWell(
            onTap: _editTime,
            borderRadius: BorderRadius.circular(6),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  const Icon(Icons.access_time, size: 16),
                  const SizedBox(width: 4),
                  Text(formatter.format(_event.startAt.toLocal())),
                  const SizedBox(width: 6),
                  Text(
                    '(${_relativeDate(_event.startAt.toLocal())})',
                    style: TextStyle(
                      fontSize: 13,
                      color: Theme.of(context)
                          .colorScheme
                          .primary
                          .withValues(alpha: 0.8),
                    ),
                  ),
                  const Spacer(),
                  const Icon(Icons.edit_outlined, size: 14, color: Colors.grey),
                ],
              ),
            ),
          ),
          // Location row — tappable to edit address text; map icon to move pin
          ...[
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.location_on, size: 16),
                const SizedBox(width: 4),
                Expanded(
                  child: InkWell(
                    onTap: _editAddress,
                    borderRadius: BorderRadius.circular(4),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: _loadingAddress
                          ? const Text('Loading address…',
                              style: TextStyle(color: Colors.grey))
                          : Text(
                              _address ??
                                  (_event.latitude != null
                                      ? '${_event.latitude!.toStringAsFixed(4)}, ${_event.longitude!.toStringAsFixed(4)}'
                                      : 'No location'),
                            ),
                    ),
                  ),
                ),
                // Edit address text
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  tooltip: 'Edit address text',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: _editAddress,
                ),
                // Edit pin on map
                IconButton(
                  icon: const Icon(Icons.map_outlined, size: 16),
                  tooltip: 'Edit location on map',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: _editLocation,
                ),
              ],
            ),
            if (_event.latitude != null) ...[
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  height: 160,
                  child: GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: LatLng(_event.latitude!, _event.longitude!),
                      zoom: 14,
                    ),
                    markers: {
                      Marker(
                        markerId: const MarkerId('event'),
                        position: LatLng(_event.latitude!, _event.longitude!),
                        icon: _event.color != null
                            ? BitmapDescriptor.defaultMarkerWithHue(
                                HSVColor.fromColor(Color(_event.color!)).hue)
                            : BitmapDescriptor.defaultMarker,
                      ),
                    },
                    myLocationButtonEnabled: false,
                    zoomControlsEnabled: true,
                    scrollGesturesEnabled: true,
                    zoomGesturesEnabled: true,
                    gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
                      Factory<EagerGestureRecognizer>(
                          () => EagerGestureRecognizer()),
                    },
                  ),
                ),
              ),
            ],
          ],
          if (_event.userMemo != null) ...[
            const SizedBox(height: 16),
            Text(
              _event.userMemo!,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Text(
                'Tags',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(width: 8),
              ActionChip(
                avatar: const Icon(Icons.add, size: 16),
                label: const Text('Add'),
                onPressed: _addTag,
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_event.tags.isNotEmpty)
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: _event.tags
                  .map(
                    (tag) => Chip(
                      label: Text(tag.name),
                      onDeleted: () => _removeTag(tag),
                    ),
                  )
                  .toList(),
            ),
          const Divider(height: 24),
          Row(
            children: [
              Text(
                'Folders',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(width: 8),
              ActionChip(
                avatar: const Icon(Icons.create_new_folder_outlined, size: 16),
                label: const Text('Manage'),
                onPressed: _showFolderPicker,
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_eventFolders.isEmpty)
            Text(
              'Not in any folder',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Colors.grey),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: _eventFolders
                  .map((f) => Chip(
                        avatar: const Icon(Icons.folder_outlined, size: 16),
                        label: Text(f.name),
                      ))
                  .toList(),
            ),
          const SizedBox(height: 16),
          Text(
            '${_event.assetCount} items',
            style: Theme.of(context).textTheme.labelMedium,
          ),
        ],
      ),
    );
  }
}

class _MediaGallery extends StatefulWidget {
  const _MediaGallery({required this.assetIds});

  final List<String> assetIds;

  @override
  State<_MediaGallery> createState() => _MediaGalleryState();
}

class _MediaGalleryState extends State<_MediaGallery> {
  int _currentPage = 0;
  Future<double>? _aspectFuture;

  @override
  void initState() {
    super.initState();
    if (widget.assetIds.isNotEmpty) {
      _aspectFuture = AssetEntity.fromId(widget.assetIds.first).then((a) {
        if (a == null) return 4 / 3;
        final s = a.orientatedSize;
        if (s.height == 0) return 4 / 3;
        return s.width / s.height;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<double>(
      future: _aspectFuture,
      initialData: 4 / 3,
      builder: (ctx, snap) {
        final ratio = snap.data ?? 4 / 3;
        return AspectRatio(
          aspectRatio: ratio,
          child: Stack(
            children: [
              PageView.builder(
                itemCount: widget.assetIds.length,
                onPageChanged: (i) => setState(() => _currentPage = i),
                itemBuilder: (ctx2, i) =>
                    _AssetTile(assetId: widget.assetIds[i]),
              ),
              if (widget.assetIds.length > 1)
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${_currentPage + 1}/${widget.assetIds.length}',
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

// ─── Folder picker bottom sheet ───────────────────────────────────────────

class _FolderPickerSheet extends StatefulWidget {
  const _FolderPickerSheet({
    required this.folders,
    required this.initialSelected,
    required this.onConfirm,
    required this.onCreateFolder,
  });

  final List<DiaryFolder> folders;
  final Set<String> initialSelected;
  final Future<void> Function(Set<String> chosen) onConfirm;
  final Future<List<DiaryFolder>> Function(String name) onCreateFolder;

  @override
  State<_FolderPickerSheet> createState() => _FolderPickerSheetState();
}

class _FolderPickerSheetState extends State<_FolderPickerSheet> {
  late Set<String> _selected;
  late List<DiaryFolder> _folders;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _selected = Set.from(widget.initialSelected);
    _folders = List.from(widget.folders);
  }

  Future<void> _createFolder() async {
    final ctrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New folder'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(
            labelText: 'Folder name',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Create'),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty || !mounted) return;
    final updated = await widget.onCreateFolder(name);
    setState(() => _folders = updated);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Text(
                  'Save to folders',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: _createFolder,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('New'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_folders.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: Text('No folders yet')),
              )
            else
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.4,
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _folders.length,
                  itemBuilder: (ctx, i) {
                    final folder = _folders[i];
                    final isSelected = _selected.contains(folder.folderId);
                    return CheckboxListTile(
                      value: isSelected,
                      secondary: const Icon(Icons.folder_outlined),
                      title: Text(folder.name),
                      onChanged: (v) {
                        setState(() {
                          if (v == true) {
                            _selected.add(folder.folderId);
                          } else {
                            _selected.remove(folder.folderId);
                          }
                        });
                      },
                    );
                  },
                ),
              ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _saving
                    ? null
                    : () async {
                        setState(() => _saving = true);
                        await widget.onConfirm(_selected);
                        if (context.mounted) Navigator.pop(context);
                      },
                child: _saving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Save'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Split event screen ───────────────────────────────────────────────────

class _SplitScreen extends StatefulWidget {
  const _SplitScreen({required this.event});

  final EventSummary event;

  @override
  State<_SplitScreen> createState() => _SplitScreenState();
}

class _SplitScreenState extends State<_SplitScreen> {
  final Set<String> _selected = {};

  @override
  Widget build(BuildContext context) {
    final assets = widget.event.assetIds;
    final canConfirm = _selected.isNotEmpty && _selected.length < assets.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Split event'),
        actions: [
          TextButton(
            onPressed: canConfirm
                ? () => Navigator.pop(context, _selected.toList())
                : null,
            child: const Text('Split'),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              'Select photos to move to a new event (${_selected.length} of ${assets.length} selected)',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(4),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 4,
                mainAxisSpacing: 4,
              ),
              itemCount: assets.length,
              itemBuilder: (ctx, i) {
                final assetId = assets[i];
                final isSelected = _selected.contains(assetId);
                return GestureDetector(
                  onTap: () => setState(() {
                    if (isSelected) {
                      _selected.remove(assetId);
                    } else {
                      _selected.add(assetId);
                    }
                  }),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _AssetTile(assetId: assetId),
                      if (isSelected)
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.blue.withValues(alpha: 0.4),
                            border: Border.all(color: Colors.blue, width: 3),
                          ),
                          alignment: Alignment.topRight,
                          padding: const EdgeInsets.all(4),
                          child: const CircleAvatar(
                            radius: 12,
                            backgroundColor: Colors.blue,
                            child: Icon(Icons.check,
                                size: 16, color: Colors.white),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Merge picker screen ──────────────────────────────────────────────────

class _MergePickerScreen extends ConsumerWidget {
  const _MergePickerScreen({required this.currentEventId});

  final String currentEventId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventsAsync = ref.watch(mapEventsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Merge with…')),
      body: eventsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (events) {
          final others =
              events.where((e) => e.eventId != currentEventId).toList();
          if (others.isEmpty) {
            return const Center(child: Text('No other events to merge with'));
          }
          final fmt = DateFormat('MMM d, yyyy HH:mm');
          return ListView.builder(
            itemCount: others.length,
            itemBuilder: (ctx, i) {
              final e = others[i];
              return ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: Text(e.title ?? fmt.format(e.startAt.toLocal())),
                subtitle: Text('${e.assetCount} photos'),
                onTap: () => Navigator.pop(context, e),
              );
            },
          );
        },
      ),
    );
  }
}

class _AssetTile extends StatelessWidget {
  const _AssetTile({required this.assetId});

  final String assetId;

  Future<void> _playVideo(BuildContext context, AssetEntity asset) async {
    final file = await asset.originFile;
    if (file == null || !context.mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _VideoPlayerScreen(file: file),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AssetEntity?>(
      future: AssetEntity.fromId(assetId),
      builder: (ctx, assetSnap) {
        if (!assetSnap.hasData) {
          return Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
          );
        }
        final asset = assetSnap.data!;
        final isVideo = asset.type == AssetType.video;

        return FutureBuilder<Uint8List?>(
          future: asset.thumbnailDataWithSize(const ThumbnailSize(800, 560)),
          builder: (ctx2, thumbSnap) {
            if (!thumbSnap.hasData) {
              return Container(
                decoration: BoxDecoration(
                  color: Theme.of(ctx2).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
              );
            }
            return Stack(
              fit: StackFit.expand,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.memory(
                    thumbSnap.data!,
                    fit: BoxFit.contain,
                  ),
                ),
                if (isVideo)
                  GestureDetector(
                    onTap: () => _playVideo(ctx2, asset),
                    child: const Center(
                      child: CircleAvatar(
                        radius: 28,
                        backgroundColor: Colors.black45,
                        child: Icon(
                          Icons.play_arrow,
                          color: Colors.white,
                          size: 36,
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }
}

// ─── Full-screen video player ─────────────────────────────────────────────

class _VideoPlayerScreen extends StatefulWidget {
  const _VideoPlayerScreen({required this.file});

  final File file;

  @override
  State<_VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<_VideoPlayerScreen> {
  late final VideoPlayerController _controller;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.file(widget.file)
      ..initialize().then((_) {
        if (mounted) {
          setState(() => _initialized = true);
          _controller.play();
        }
      });
    _controller.setLooping(true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: _initialized
            ? GestureDetector(
                onTap: () {
                  setState(() {
                    _controller.value.isPlaying
                        ? _controller.pause()
                        : _controller.play();
                  });
                },
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    AspectRatio(
                      aspectRatio: _controller.value.aspectRatio,
                      child: VideoPlayer(_controller),
                    ),
                    ValueListenableBuilder(
                      valueListenable: _controller,
                      builder: (_, value, __) => AnimatedOpacity(
                        opacity: value.isPlaying ? 0.0 : 1.0,
                        duration: const Duration(milliseconds: 300),
                        child: const CircleAvatar(
                          radius: 32,
                          backgroundColor: Colors.black45,
                          child: Icon(Icons.play_arrow,
                              color: Colors.white, size: 40),
                        ),
                      ),
                    ),
                  ],
                ),
              )
            : const CircularProgressIndicator(color: Colors.white),
      ),
    );
  }
}

// ─── Asset reorder screen ─────────────────────────────────────────────────

class _AssetReorderScreen extends StatefulWidget {
  const _AssetReorderScreen({required this.assetIds});

  final List<String> assetIds;

  @override
  State<_AssetReorderScreen> createState() => _AssetReorderScreenState();
}

class _AssetReorderScreenState extends State<_AssetReorderScreen> {
  late List<String> _ids;
  final Map<String, Uint8List?> _thumbs = {};

  @override
  void initState() {
    super.initState();
    _ids = List.from(widget.assetIds);
    _loadThumbs();
  }

  Future<void> _loadThumbs() async {
    for (final id in _ids) {
      final asset = await AssetEntity.fromId(id);
      if (asset == null || !mounted) continue;
      final bytes =
          await asset.thumbnailDataWithSize(const ThumbnailSize(200, 200));
      if (mounted) setState(() => _thumbs[id] = bytes);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reorder Media'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, _ids),
            child: const Text('Done'),
          ),
        ],
      ),
      body: ReorderableGridView.builder(
        padding: const EdgeInsets.all(4),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 4,
          mainAxisSpacing: 4,
        ),
        itemCount: _ids.length,
        onReorder: (oldIndex, newIndex) {
          setState(() {
            final item = _ids.removeAt(oldIndex);
            _ids.insert(newIndex, item);
          });
        },
        itemBuilder: (ctx, i) {
          final id = _ids[i];
          final bytes = _thumbs[id];
          return Stack(
            key: ValueKey(id),
            fit: StackFit.expand,
            children: [
              if (bytes != null)
                Image.memory(bytes, fit: BoxFit.cover)
              else
                Container(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: const Icon(Icons.photo_outlined, color: Colors.white54),
                ),
              if (i == 0)
                Positioned(
                  top: 4,
                  left: 4,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Cover',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimary,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
