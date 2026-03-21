import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:photo_manager/photo_manager.dart' hide LatLng;

import '../providers/diary_providers.dart';
import 'location_picker_screen.dart';

class ManualRecordScreen extends ConsumerStatefulWidget {
  const ManualRecordScreen({super.key, this.initialTitle});

  final String? initialTitle;

  @override
  ConsumerState<ManualRecordScreen> createState() => _ManualRecordScreenState();
}

class _ManualRecordScreenState extends ConsumerState<ManualRecordScreen> {
  late final TextEditingController _titleController =
      TextEditingController(text: widget.initialTitle);
  final _memoController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();
  LatLng? _selectedLocation;
  List<String> _selectedAssetIds = [];
  bool _saving = false;

  @override
  void dispose() {
    _titleController.dispose();
    _memoController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked != null) {
      setState(() => _selectedTime = picked);
    }
  }

  Future<void> _pickLocation() async {
    final result = await Navigator.push<LatLng>(
      context,
      MaterialPageRoute(
        builder: (_) => LocationPickerScreen(initialLatLng: _selectedLocation),
      ),
    );
    if (result != null) {
      setState(() => _selectedLocation = result);
    }
  }

  Future<void> _pickPhotos() async {
    final permission = await PhotoManager.requestPermissionExtend();
    if (!permission.isAuth) return;

    final albums = await PhotoManager.getAssetPathList(type: RequestType.image);
    if (albums.isEmpty) return;
    final recent = albums.first;
    final assets = await recent.getAssetListPaged(page: 0, size: 50);

    if (!mounted) return;

    final selected = await showDialog<List<String>>(
      context: context,
      builder: (ctx) => _AssetPickerDialog(
        assets: assets,
        initialSelected: _selectedAssetIds,
      ),
    );
    if (selected != null) {
      setState(() => _selectedAssetIds = selected);
    }
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a title.')),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      final startAt = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _selectedTime.hour,
        _selectedTime.minute,
      ).toUtc();
      final eventId = 'manual_${DateTime.now().millisecondsSinceEpoch}';

      await ref.read(diaryRepositoryProvider).createManualRecord(
            eventId: eventId,
            startAt: startAt,
            endAt: startAt.add(const Duration(hours: 1)),
            title: title,
            userMemo:
                _memoController.text.trim().isEmpty ? null : _memoController.text.trim(),
            latitude: _selectedLocation?.latitude,
            longitude: _selectedLocation?.longitude,
            assetIds: _selectedAssetIds,
          );

      ref.invalidate(dailyStatsProvider);
      ref.invalidate(diaryCandidatesProvider);
      ref.invalidate(mapEventsProvider);
      ref.invalidate(onThisDayProvider);

      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('New Record'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(
              labelText: 'Title *',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickDate,
                  icon: const Icon(Icons.calendar_today),
                  label: Text(
                    '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickTime,
                  icon: const Icon(Icons.access_time),
                  label: Text(_selectedTime.format(context)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _memoController,
            decoration: const InputDecoration(
              labelText: 'Memo (optional)',
              border: OutlineInputBorder(),
            ),
            maxLines: 4,
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _pickLocation,
            icon: const Icon(Icons.location_on),
            label: Text(
              _selectedLocation == null
                  ? 'Location (optional)'
                  : '${_selectedLocation!.latitude.toStringAsFixed(4)}, ${_selectedLocation!.longitude.toStringAsFixed(4)}',
            ),
          ),
          if (_selectedLocation != null)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => setState(() => _selectedLocation = null),
                child: const Text('Remove location'),
              ),
            ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _pickPhotos,
            icon: const Icon(Icons.photo_library),
            label: Text(
              _selectedAssetIds.isEmpty
                  ? 'Select Photos'
                  : '${_selectedAssetIds.length} selected',
            ),
          ),
        ],
      ),
    );
  }
}

class _AssetPickerDialog extends StatefulWidget {
  const _AssetPickerDialog({
    required this.assets,
    required this.initialSelected,
  });

  final List<AssetEntity> assets;
  final List<String> initialSelected;

  @override
  State<_AssetPickerDialog> createState() => _AssetPickerDialogState();
}

class _AssetPickerDialogState extends State<_AssetPickerDialog> {
  late Set<String> _selected;

  @override
  void initState() {
    super.initState();
    _selected = Set.from(widget.initialSelected);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Select Photos'),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 4,
            mainAxisSpacing: 4,
          ),
          itemCount: widget.assets.length,
          itemBuilder: (ctx, i) {
            final asset = widget.assets[i];
            final isSelected = _selected.contains(asset.id);
            return GestureDetector(
              onTap: () => setState(() {
                if (isSelected) {
                  _selected.remove(asset.id);
                } else {
                  _selected.add(asset.id);
                }
              }),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  FutureBuilder<Uint8List?>(
                    future: asset.thumbnailDataWithSize(
                      const ThumbnailSize(200, 200),
                    ),
                    builder: (ctx3, snap) {
                      if (!snap.hasData) return Container(color: Colors.grey[300]);
                      return Image.memory(snap.data!, fit: BoxFit.cover);
                    },
                  ),
                  if (isSelected)
                    Container(
                      color: Colors.blue.withValues(alpha: 0.4),
                      child: const Icon(Icons.check_circle, color: Colors.white),
                    ),
                ],
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _selected.toList()),
          child: Text('Confirm (${_selected.length})'),
        ),
      ],
    );
  }
}
