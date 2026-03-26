import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:share_plus/share_plus.dart';

import '../models/event_summary.dart';
import '../services/geocoding_service.dart';

// ─── text element keys ──────────────────────────────────────────────────────
enum _Elem { title, caption, date, address }

// ─── per-text-element layout state ─────────────────────────────────────────
class _ElemLayout {
  _ElemLayout(
      {required this.x,
      required this.y,
      required this.size,
      this.visible = true});

  double x; // fraction of card width (left edge)
  double y; // fraction of card height (top edge)
  double size; // font size
  bool visible;

  _ElemLayout copyWith({double? x, double? y, double? size, bool? visible}) =>
      _ElemLayout(
        x: x ?? this.x,
        y: y ?? this.y,
        size: size ?? this.size,
        visible: visible ?? this.visible,
      );
}

// ─── per-photo item ─────────────────────────────────────────────────────────
class _PhotoItem {
  _PhotoItem({
    required this.assetId,
    this.bytes,
    required this.x,
    required this.y,
    required this.w,
    required this.h,
    this.scale = 1.0,
  });

  final String assetId;
  Uint8List? bytes;
  double x, y, w, h;
  double scale; // zoom factor: 1.0 = fill box, >1 zooms in

  _PhotoItem copyWith(
          {Uint8List? bytes,
          double? x,
          double? y,
          double? w,
          double? h,
          double? scale}) =>
      _PhotoItem(
        assetId: assetId,
        bytes: bytes ?? this.bytes,
        x: x ?? this.x,
        y: y ?? this.y,
        w: w ?? this.w,
        h: h ?? this.h,
        scale: scale ?? this.scale,
      );
}

// ──────────────────────────────────────────────────────────────────────────
class ShareCustomizeScreen extends StatefulWidget {
  const ShareCustomizeScreen({
    super.key,
    this.event,
    this.summaryText,
    this.coverImage,
  });

  final EventSummary? event;
  final String? summaryText;
  final Uint8List? coverImage;

  @override
  State<ShareCustomizeScreen> createState() => _ShareCustomizeScreenState();
}

class _ShareCustomizeScreenState extends State<ShareCustomizeScreen> {
  final GlobalKey _previewKey = GlobalKey();
  final GlobalKey _shareButtonKey = GlobalKey();

  static const _presetColors = [
    Color(0xFFBF616A),
    Color(0xFF88C0D0),
    Color(0xFFEBCB8B),
    Color(0xFFA3BE8C),
    Color(0xFF5E81AC),
    Color(0xFFB48EAD),
  ];

  Color _bgColor = const Color(0xFF5E81AC);
  bool _isSquare = true;
  bool _isSharing = false;

  // Selection: null | _Elem | int (photo index)
  Object? _selected;

  // Photos
  List<_PhotoItem> _photos = [];
  final Map<int, double> _gestureStartW = {};
  final Map<int, double> _gestureStartH = {};

  String? _address;

  // Text element layouts
  final Map<_Elem, _ElemLayout> _layout = {
    _Elem.title: _ElemLayout(x: 0.05, y: 0.62, size: 22.0),
    _Elem.caption: _ElemLayout(x: 0.05, y: 0.77, size: 13.0),
    _Elem.date: _ElemLayout(x: 0.52, y: 0.03, size: 11.0),
    _Elem.address: _ElemLayout(x: 0.05, y: 0.90, size: 10.0, visible: false),
  };

  @override
  void initState() {
    super.initState();
    _loadPhotos();
    _loadAddress();
  }

  Future<void> _loadPhotos() async {
    // Passed-in cover image (single)
    if (widget.coverImage != null) {
      setState(() {
        _photos = [
          _PhotoItem(
              assetId: '', bytes: widget.coverImage, x: 0, y: 0, w: 1, h: 0.55)
        ];
      });
      return;
    }

    final event = widget.event;
    if (event == null) return;

    // Gather up to 4 asset IDs
    List<String> ids = event.assetIds.isNotEmpty ? event.assetIds : [];
    if (ids.isEmpty && event.representativeAssetId != 'manual_no_photo') {
      ids = [event.representativeAssetId];
    }
    ids = ids.take(25).toList();
    if (ids.isEmpty) return;

    // Load thumbnails (works for both photos and videos)
    final items = <_PhotoItem>[];
    for (final id in ids) {
      final entity = await AssetEntity.fromId(id);
      final bytes =
          await entity?.thumbnailDataWithSize(const ThumbnailSize(800, 800));
      items.add(
          _PhotoItem(assetId: id, bytes: bytes, x: 0, y: 0, w: 1, h: 0.55));
    }

    _assignCollagePositions(items);
    if (mounted) setState(() => _photos = items);
  }

  void _assignCollagePositions(List<_PhotoItem> items) {
    const gap = 0.005;
    final n = items.length;
    if (n == 0) return;

    if (n == 1) {
      items[0] = items[0].copyWith(x: 0, y: 0, w: 1, h: 0.55);
      return;
    }
    if (n == 2) {
      items[0] = items[0].copyWith(x: 0, y: 0, w: 0.5 - gap / 2, h: 0.55);
      items[1] = items[1].copyWith(x: 0.5 + gap / 2, y: 0, w: 0.5 - gap / 2, h: 0.55);
      return;
    }
    if (n == 3) {
      items[0] = items[0].copyWith(x: 0, y: 0, w: 0.5 - gap / 2, h: 0.55);
      items[1] = items[1].copyWith(x: 0.5 + gap / 2, y: 0, w: 0.5 - gap / 2, h: 0.275 - gap / 2);
      items[2] = items[2].copyWith(x: 0.5 + gap / 2, y: 0.275 + gap / 2, w: 0.5 - gap / 2, h: 0.275 - gap / 2);
      return;
    }

    // Generic grid for 4-25 photos
    final cols = n <= 4 ? 2 : n <= 9 ? 3 : n <= 16 ? 4 : 5;
    final rows = (n / cols).ceil();
    final collageH = (n <= 4 ? 0.55 : (rows * 0.15).clamp(0.3, 0.72));
    final cellW = (1.0 - gap * (cols - 1)) / cols;
    final cellH = (collageH - gap * (rows - 1)) / rows;

    for (int i = 0; i < n; i++) {
      final col = i % cols;
      final row = i ~/ cols;
      items[i] = items[i].copyWith(
        x: col * (cellW + gap),
        y: row * (cellH + gap),
        w: cellW,
        h: cellH,
      );
    }
  }

  Future<void> _loadAddress() async {
    final lat = widget.event?.latitude;
    final lng = widget.event?.longitude;
    if (lat == null || lng == null) return;
    final addr = await GeocodingService().reverseGeocode(lat, lng);
    if (mounted) setState(() => _address = addr);
  }

  // ── color picker ──────────────────────────────────────────────────────
  Future<void> _pickCustomColor() async {
    double r = (_bgColor.r * 255.0).roundToDouble();
    double g = (_bgColor.g * 255.0).roundToDouble();
    double b = (_bgColor.b * 255.0).roundToDouble();

    final result = await showDialog<Color>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('Custom Color'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 48,
                decoration: BoxDecoration(
                  color: Color.fromRGBO(r.round(), g.round(), b.round(), 1),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              const SizedBox(height: 16),
              _colorSlider('R', r, Colors.red, (v) => setS(() => r = v)),
              _colorSlider('G', g, Colors.green, (v) => setS(() => g = v)),
              _colorSlider('B', b, Colors.blue, (v) => setS(() => b = v)),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () => Navigator.pop(
                    ctx, Color.fromRGBO(r.round(), g.round(), b.round(), 1)),
                child: const Text('OK')),
          ],
        ),
      ),
    );
    if (result != null) setState(() => _bgColor = result);
  }

  Widget _colorSlider(
      String label, double value, Color color, ValueChanged<double> onChanged) {
    return Row(
      children: [
        SizedBox(
          width: 18,
          child: Text(label,
              style: TextStyle(
                  color: color, fontWeight: FontWeight.bold, fontSize: 13)),
        ),
        Expanded(
          child: Slider(
              value: value,
              min: 0,
              max: 255,
              activeColor: color,
              onChanged: onChanged),
        ),
        SizedBox(
          width: 32,
          child: Text(value.round().toString(),
              style: const TextStyle(fontSize: 12)),
        ),
      ],
    );
  }

  // ── build ─────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Customize & Share')),
      body: Column(
        children: [
          // Preview — fixed, never scrolls
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: _buildPreview(),
          ),
          // Controls — scrollable
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildElementSelector(),
                  const SizedBox(height: 10),
                  _buildActiveControls(),
                  const SizedBox(height: 14),
                  _buildBackgroundSection(),
                  const SizedBox(height: 10),
                  _buildRatioSection(),
                ],
              ),
            ),
          ),
          _buildShareButton(),
        ],
      ),
    );
  }

  // ── preview ───────────────────────────────────────────────────────────
  Widget _buildPreview() {
    final aspectRatio = _isSquare ? 1.0 : 9 / 16;
    return Center(
      child: AspectRatio(
        aspectRatio: aspectRatio,
        child: LayoutBuilder(
          builder: (ctx, constraints) {
            final w = constraints.maxWidth;
            final h = constraints.maxHeight;
            return Stack(
              children: [
                RepaintBoundary(
                  key: _previewKey,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: _buildCardContent(w, h),
                  ),
                ),
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: _buildSelectionOverlay(w, h),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildCardContent(double w, double h) {
    final title = _layout[_Elem.title]!;
    final caption = _layout[_Elem.caption]!;
    final date = _layout[_Elem.date]!;
    final addr = _layout[_Elem.address]!;

    return Stack(
      fit: StackFit.expand,
      children: [
        // Background
        Container(color: _bgColor),

        // Photos (collage) — selected photo rendered last (on top)
        ...() {
          final selectedIdx = _selected is int ? _selected as int : -1;
          final ordered = [
            ..._photos.asMap().entries
                .where((e) => e.value.bytes != null && e.key != selectedIdx),
            if (selectedIdx >= 0 && selectedIdx < _photos.length &&
                _photos[selectedIdx].bytes != null)
              _photos.asMap().entries.firstWhere((e) => e.key == selectedIdx),
          ];
          return ordered.map((e) {
            final p = e.value;
            return Positioned(
              left: p.x * w,
              top: p.y * h,
              width: p.w * w,
              height: p.h * h,
              child: ClipRect(
                child: Image.memory(p.bytes!, fit: BoxFit.contain),
              ),
            );
          });
        }(),

        // Gradient overlay for readability
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.transparent, Color(0xAA000000)],
              stops: [0.45, 1.0],
            ),
          ),
        ),

        // App icon watermark — bottom right
        Positioned(
          right: 12,
          bottom: 12,
          child: Opacity(
            opacity: 0.75,
            child: Image.asset(
              'assets/logo.png',
              width: 28,
              height: 28,
              fit: BoxFit.contain,
            ),
          ),
        ),

        // Date
        if (date.visible && widget.event != null)
          Positioned(
            left: date.x * w,
            top: date.y * h,
            right: 12,
            child: Text(
              DateFormat('MMM d, yyyy').format(widget.event!.startAt.toLocal()),
              textAlign: TextAlign.right,
              style: TextStyle(
                color: Colors.white70,
                fontSize: date.size,
                shadows: const [Shadow(blurRadius: 4)],
              ),
            ),
          ),

        // Title
        if (title.visible && widget.event?.title != null)
          Positioned(
            left: title.x * w,
            top: title.y * h,
            right: 8,
            child: Text(
              widget.event!.title!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white,
                fontSize: title.size,
                fontWeight: FontWeight.bold,
                shadows: const [Shadow(blurRadius: 8)],
              ),
            ),
          ),

        // Caption
        if (caption.visible && widget.summaryText != null)
          Positioned(
            left: caption.x * w,
            top: caption.y * h,
            right: 8,
            child: Text(
              widget.summaryText!,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white,
                fontSize: caption.size,
                height: 1.4,
                shadows: const [Shadow(blurRadius: 4)],
              ),
            ),
          ),

        // Address
        if (addr.visible && _address != null)
          Positioned(
            left: addr.x * w,
            top: addr.y * h,
            right: 8,
            child: Text(
              _address!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white60,
                fontSize: addr.size,
                shadows: const [Shadow(blurRadius: 4)],
              ),
            ),
          ),
      ],
    );
  }

  // Interactive overlay: drag to move, tap to select
  Widget _buildSelectionOverlay(double w, double h) {
    // Draggable photo box
    Widget photoBox(int idx) {
      final p = _photos[idx];
      final isSelected = _selected == idx;
      return Positioned(
        left: p.x * w,
        top: p.y * h,
        width: p.w * w,
        height: p.h * h,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => setState(() => _selected = isSelected ? null : idx),
          onScaleStart: (_) {
            _gestureStartW[idx] = _photos[idx].w;
            _gestureStartH[idx] = _photos[idx].h;
          },
          onScaleUpdate: (d) {
            final updated = List<_PhotoItem>.from(_photos);
            final startW = _gestureStartW[idx] ?? _photos[idx].w;
            final startH = _gestureStartH[idx] ?? _photos[idx].h;
            updated[idx] = _photos[idx].copyWith(
              w: (startW * d.scale).clamp(0.1, 1.0),
              h: (startH * d.scale).clamp(0.05, 1.0),
              x: (_photos[idx].x + d.focalPointDelta.dx / w).clamp(-0.5, 1.0),
              y: (_photos[idx].y + d.focalPointDelta.dy / h).clamp(-0.5, 1.0),
            );
            setState(() => _photos = updated);
          },
          child: Container(
            decoration: BoxDecoration(
              border: isSelected
                  ? Border.all(color: Colors.blueAccent, width: 2)
                  : null,
            ),
          ),
        ),
      );
    }

    // Draggable text element box
    Widget textBox(_Elem elem) {
      final lay = _layout[elem]!;
      final isSelected = _selected == elem;
      return Positioned(
        left: lay.x * w,
        top: lay.y * h,
        width: w * 0.9,
        height: lay.size * 3.0,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => setState(() => _selected = isSelected ? null : elem),
          onPanUpdate: (d) => _moveElem(elem, d.delta.dx / w, d.delta.dy / h),
          child: Container(
            decoration: BoxDecoration(
              border: isSelected
                  ? Border.all(color: Colors.blueAccent, width: 2)
                  : null,
            ),
          ),
        ),
      );
    }

    // Build photo boxes with selected last
    final selectedPhotoIdx = _selected is int ? _selected as int : -1;
    final photoBoxes = [
      for (int i = 0; i < _photos.length; i++)
        if (_photos[i].bytes != null && i != selectedPhotoIdx) photoBox(i),
      if (selectedPhotoIdx >= 0 && selectedPhotoIdx < _photos.length &&
          _photos[selectedPhotoIdx].bytes != null)
        photoBox(selectedPhotoIdx),
    ];

    // Build text boxes with selected last
    final textElems = <_Elem>[_Elem.title, _Elem.caption, _Elem.date, _Elem.address];
    final textBoxes = [
      for (final e in textElems)
        if (e != _selected &&
            _layout[e]!.visible &&
            _elemHasContent(e))
          textBox(e),
      if (_selected is _Elem && _layout[_selected as _Elem]!.visible &&
          _elemHasContent(_selected as _Elem))
        textBox(_selected as _Elem),
    ];

    return Stack(children: [...photoBoxes, ...textBoxes]);
  }

  bool _elemHasContent(_Elem e) {
    return switch (e) {
      _Elem.title => widget.event?.title != null,
      _Elem.caption => widget.summaryText != null,
      _Elem.date => widget.event != null,
      _Elem.address => _address != null,
    };
  }

  void _moveElem(_Elem elem, double dx, double dy) {
    final lay = _layout[elem]!;
    setState(() => _layout[elem] = lay.copyWith(
          x: (lay.x + dx).clamp(-0.1, 0.9),
          y: (lay.y + dy).clamp(-0.1, 0.95),
        ));
  }


  // ── element selector chips ────────────────────────────────────────────
  Widget _buildElementSelector() {
    final textElems = <({_Elem elem, String label, IconData icon})>[
      (elem: _Elem.title, label: 'Title', icon: Icons.title),
      (elem: _Elem.caption, label: 'Caption', icon: Icons.notes),
      (elem: _Elem.date, label: 'Date', icon: Icons.calendar_today_outlined),
      (elem: _Elem.address, label: 'Address', icon: Icons.location_on_outlined),
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        // Photo chips
        for (int i = 0; i < _photos.length; i++)
          FilterChip(
            avatar: const Icon(Icons.image_outlined, size: 16),
            label: Text(_photos.length == 1 ? 'Photo' : 'Photo ${i + 1}'),
            selected: _selected == i,
            showCheckmark: false,
            onSelected: (_) =>
                setState(() => _selected = (_selected == i) ? null : i),
          ),
        // Text element chips
        ...textElems.map((e) {
          final lay = _layout[e.elem]!;
          final isSelected = _selected == e.elem;
          return FilterChip(
            avatar: Icon(e.icon, size: 16),
            label: Text(e.label),
            selected: isSelected,
            showCheckmark: false,
            onSelected: (_) =>
                setState(() => _selected = isSelected ? null : e.elem),
            side: lay.visible ? null : const BorderSide(color: Colors.grey),
          );
        }),
      ],
    );
  }

  // ── controls for selected element ────────────────────────────────────
  Widget _buildActiveControls() {
    if (_selected == null) {
      return const Text(
        'Drag elements directly in the preview · Tap to select for size options',
        style: TextStyle(color: Colors.grey, fontSize: 13),
      );
    }

    // Photo selected
    if (_selected is int) {
      final idx = _selected as int;
      final p = _photos[idx];
      return Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _photos.length == 1 ? 'Photo' : 'Photo ${idx + 1}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              _slider('Width', p.w, 0.1, 1.0, (v) {
                final ratio = p.h / p.w;
                final newW = _round(v);
                final newH = _round((newW * ratio).clamp(0.05, 1.0));
                final updated = List<_PhotoItem>.from(_photos);
                updated[idx] = p.copyWith(w: newW, h: newH);
                setState(() => _photos = updated);
              }),
              const SizedBox(height: 4),
              if (_photos.length > 1)
                OutlinedButton.icon(
                  icon: const Icon(Icons.grid_view, size: 16),
                  label: const Text('Reset collage layout'),
                  onPressed: () {
                    final copy = List<_PhotoItem>.from(_photos);
                    _assignCollagePositions(copy);
                    setState(() => _photos = copy);
                  },
                ),
            ],
          ),
        ),
      );
    }

    // Text element selected
    final elem = _selected as _Elem;
    final lay = _layout[elem]!;
    final hasContent = switch (elem) {
      _Elem.title => widget.event?.title != null,
      _Elem.caption => widget.summaryText != null,
      _Elem.date => widget.event != null,
      _Elem.address => _address != null,
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(_elemLabel(elem),
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                const Spacer(),
                if (!hasContent)
                  const Text('No content',
                      style: TextStyle(color: Colors.grey, fontSize: 12)),
                if (hasContent)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Show', style: TextStyle(fontSize: 13)),
                      Switch(
                        value: lay.visible,
                        onChanged: (v) => setState(
                            () => _layout[elem] = lay.copyWith(visible: v)),
                      ),
                    ],
                  ),
              ],
            ),
            if (lay.visible && hasContent)
              _slider(
                  'Font size',
                  lay.size,
                  8.0,
                  40.0,
                  (v) => setState(
                      () => _layout[elem] = lay.copyWith(size: _round(v))),
                  showPercent: false),
          ],
        ),
      ),
    );
  }

  Widget _slider(String label, double value, double min, double max,
      ValueChanged<double> onChanged,
      {bool showPercent = true}) {
    final display = showPercent
        ? '${((value - min) / (max - min) * 100).round()}%'
        : value.round().toString();
    return Row(
      children: [
        SizedBox(
            width: 72,
            child: Text(label,
                style: const TextStyle(fontSize: 12, color: Colors.grey))),
        Expanded(
          child: Slider(
              value: value.clamp(min, max),
              min: min,
              max: max,
              onChanged: onChanged),
        ),
        SizedBox(
            width: 36,
            child: Text(display,
                style: const TextStyle(fontSize: 12),
                textAlign: TextAlign.right)),
      ],
    );
  }

  double _round(double v) => (v * 1000).round() / 1000;

  String _elemLabel(_Elem e) => switch (e) {
        _Elem.title => 'Title',
        _Elem.caption => 'Caption',
        _Elem.date => 'Date',
        _Elem.address => 'Address',
      };

  // ── background section ────────────────────────────────────────────────
  Widget _buildBackgroundSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Background color',
            style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ..._presetColors.map((c) => GestureDetector(
                  onTap: () => setState(() => _bgColor = c),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: c,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: _bgColor == c
                            ? Theme.of(context).colorScheme.primary
                            : Colors.grey.shade300,
                        width: _bgColor == c ? 2.5 : 1,
                      ),
                    ),
                  ),
                )),
            GestureDetector(
              onTap: _pickCustomColor,
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.grey.shade400),
                  gradient: const SweepGradient(colors: [
                    Colors.red,
                    Colors.yellow,
                    Colors.green,
                    Colors.cyan,
                    Colors.blue,
                    Colors.purple,
                    Colors.red,
                  ]),
                ),
                child:
                    const Icon(Icons.colorize, size: 16, color: Colors.white),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── ratio section ─────────────────────────────────────────────────────
  Widget _buildRatioSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Ratio', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(value: true, label: Text('1:1 Feed')),
            ButtonSegment(value: false, label: Text('9:16 Story')),
          ],
          selected: {_isSquare},
          onSelectionChanged: (s) => setState(() => _isSquare = s.first),
        ),
      ],
    );
  }

  // ── share button ──────────────────────────────────────────────────────
  Widget _buildShareButton() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: FilledButton.icon(
          key: _shareButtonKey,
          onPressed: _isSharing ? null : _share,
          icon: const Icon(Icons.share),
          label: Text(_isSharing ? 'Preparing...' : 'Share'),
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
          ),
        ),
      ),
    );
  }

  Future<void> _share() async {
    setState(() => _isSharing = true);
    try {
      final boundary = _previewKey.currentContext!.findRenderObject()
          as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;

      final file = await _saveTempFile(byteData.buffer.asUint8List());
      final box =
          _shareButtonKey.currentContext?.findRenderObject() as RenderBox?;
      final sharePositionOrigin =
          box != null ? box.localToGlobal(Offset.zero) & box.size : null;
      await Share.shareXFiles(
        [XFile(file.path)],
        sharePositionOrigin: sharePositionOrigin,
      );
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  Future<File> _saveTempFile(Uint8List bytes) async {
    final dir = await getTemporaryDirectory();
    final path =
        '${dir.path}/share_${DateTime.now().millisecondsSinceEpoch}.png';
    return File(path).writeAsBytes(bytes);
  }
}
