import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/post.dart';

class PostShareScreen extends StatefulWidget {
  const PostShareScreen({super.key, required this.post});

  final Post post;

  @override
  State<PostShareScreen> createState() => _PostShareScreenState();
}

class _PostShareScreenState extends State<PostShareScreen> {
  final GlobalKey _previewKey = GlobalKey();

  static const _presetColors = [
    Color(0xFF1A1A2E),
    Color(0xFF16213E),
    Color(0xFF0F3460),
    Color(0xFF2D6A4F),
    Color(0xFF533483),
    Color(0xFF774936),
    Color(0xFF212121),
    Color(0xFF880E4F),
  ];

  Color _selectedColor = const Color(0xFF1A1A2E);
  bool _usePhoto = true;
  bool _showDate = true;
  bool _showCaption = true;
  bool _showLocation = true;
  bool _isSquare = true;
  bool _isSharing = false;

  @override
  Widget build(BuildContext context) {
    final hasMedia = widget.post.mediaPaths.isNotEmpty &&
        File(widget.post.mediaPaths.first).existsSync() &&
        !widget.post.mediaPaths.first.toLowerCase().endsWith('.mp4') &&
        !widget.post.mediaPaths.first.toLowerCase().endsWith('.mov');

    return Scaffold(
      appBar: AppBar(title: const Text('Share')),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildPreview(hasMedia),
                  const SizedBox(height: 24),
                  _buildControls(hasMedia),
                ],
              ),
            ),
          ),
          _buildShareButton(),
        ],
      ),
    );
  }

  Widget _buildPreview(bool hasMedia) {
    final ratio = _isSquare ? 1.0 : 9 / 16;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: AspectRatio(
          aspectRatio: ratio,
          child: RepaintBoundary(
            key: _previewKey,
            child: _ShareCard(
              post: widget.post,
              usePhoto: _usePhoto && hasMedia,
              backgroundColor: _selectedColor,
              showDate: _showDate,
              showCaption: _showCaption,
              showLocation: _showLocation,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildControls(bool hasMedia) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Background
        const Text('Background', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              if (hasMedia)
                GestureDetector(
                  onTap: () => setState(() => _usePhoto = true),
                  child: Container(
                    width: 40,
                    height: 40,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _usePhoto
                            ? Theme.of(context).colorScheme.primary
                            : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Image.file(
                        File(widget.post.mediaPaths.first),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
              ..._presetColors.map((c) => GestureDetector(
                    onTap: () => setState(() {
                      _selectedColor = c;
                      _usePhoto = false;
                    }),
                    child: Container(
                      width: 40,
                      height: 40,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: c,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: (!_usePhoto && _selectedColor == c)
                              ? Theme.of(context).colorScheme.primary
                              : Colors.transparent,
                          width: 2,
                        ),
                      ),
                    ),
                  )),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Toggles
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Show date'),
          value: _showDate,
          onChanged: (v) => setState(() => _showDate = v),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Show caption'),
          value: _showCaption,
          onChanged: (v) => setState(() => _showCaption = v),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Show location'),
          value: _showLocation,
          onChanged: (v) => setState(() => _showLocation = v),
        ),
        const SizedBox(height: 8),
        const Text('Ratio', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(value: true, label: Text('1:1  Feed')),
            ButtonSegment(value: false, label: Text('9:16  Story')),
          ],
          selected: {_isSquare},
          onSelectionChanged: (s) => setState(() => _isSquare = s.first),
        ),
      ],
    );
  }

  Widget _buildShareButton() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: FilledButton.icon(
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
      final byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;
      final file = await _saveTempFile(byteData.buffer.asUint8List());
      await Share.shareXFiles([XFile(file.path)]);
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  Future<File> _saveTempFile(Uint8List bytes) async {
    final dir = await getTemporaryDirectory();
    final path =
        '${dir.path}/share_post_${DateTime.now().millisecondsSinceEpoch}.png';
    return File(path).writeAsBytes(bytes);
  }
}

// ─── Share card ────────────────────────────────────────────────────────────

class _ShareCard extends StatelessWidget {
  const _ShareCard({
    required this.post,
    required this.usePhoto,
    required this.backgroundColor,
    required this.showDate,
    required this.showCaption,
    required this.showLocation,
  });

  final Post post;
  final bool usePhoto;
  final Color backgroundColor;
  final bool showDate;
  final bool showCaption;
  final bool showLocation;

  @override
  Widget build(BuildContext context) {
    final dateText = showDate
        ? DateFormat('MMM d, yyyy')
            .format((post.postDate ?? post.createdAt).toLocal())
        : null;

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Background
          if (usePhoto)
            Image.file(File(post.mediaPaths.first), fit: BoxFit.cover)
          else
            Container(color: backgroundColor),
          // Gradient overlay
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Color(0xDD000000)],
                stops: [0.35, 1.0],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // App logo top-left + date top-right
                Row(
                  children: [
                    const Icon(Icons.photo_album_outlined,
                        color: Colors.white70, size: 16),
                    const SizedBox(width: 4),
                    const Text(
                      'logat',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                    const Spacer(),
                    if (dateText != null)
                      Text(
                        dateText,
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 12),
                      ),
                  ],
                ),
                const Spacer(),
                // Title
                if (post.title != null && post.title!.isNotEmpty) ...[
                  Text(
                    post.title!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      shadows: [Shadow(blurRadius: 8)],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                ],
                // Caption
                if (showCaption &&
                    post.caption != null &&
                    post.caption!.isNotEmpty) ...[
                  Text(
                    post.caption!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      height: 1.4,
                      shadows: [Shadow(blurRadius: 4)],
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                ],
                // Location
                if (showLocation &&
                    post.locationName != null &&
                    post.locationName!.isNotEmpty)
                  Row(
                    children: [
                      const Icon(Icons.location_on,
                          color: Colors.white70, size: 14),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          post.locationName!,
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                // Keywords
                if (post.keywords.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: post.keywords.take(5).map((k) => Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: Colors.white.withValues(alpha: 0.4)),
                          ),
                          child: Text(
                            '#$k',
                            style: const TextStyle(
                                color: Colors.white, fontSize: 11),
                          ),
                        )).toList(),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
