import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

/// Utility class for generating custom map markers from images and videos
class MarkerGenerator {
  /// Cache for generated markers to avoid regenerating
  static final Map<String, BitmapDescriptor> _cache = {};

  /// Generate a custom marker from a media path (image or video)
  /// Returns a BitmapDescriptor that can be used as a marker icon
  static Future<BitmapDescriptor?> generateMarker({
    required String mediaPath,
    int size = 100,
  }) async {
    // Check cache first
    final cacheKey = '$mediaPath-$size';
    if (_cache.containsKey(cacheKey)) {
      return _cache[cacheKey];
    }

    try {
      Uint8List? imageBytes;

      // Check if it's a video
      final isVideo = mediaPath.toLowerCase().endsWith('.mp4') ||
          mediaPath.toLowerCase().endsWith('.mov');

      if (isVideo) {
        // Generate thumbnail for video
        final thumbnailPath = await VideoThumbnail.thumbnailFile(
          video: mediaPath,
          thumbnailPath: (await Directory.systemTemp.createTemp()).path,
          imageFormat: ImageFormat.PNG,
          maxHeight: size,
          quality: 75,
        );

        if (thumbnailPath != null) {
          imageBytes = await File(thumbnailPath).readAsBytes();
          // Clean up temp file
          await File(thumbnailPath).delete();
        }
      } else {
        // Read image directly
        imageBytes = await File(mediaPath).readAsBytes();
      }

      if (imageBytes == null) {
        return null;
      }

      // Resize and convert to marker
      final resizedBytes = await _resizeImage(imageBytes, size);
      final marker = BitmapDescriptor.bytes(resizedBytes);

      // Cache the result
      _cache[cacheKey] = marker;

      return marker;
    } catch (e) {
      print('Error generating marker: $e');
      return null;
    }
  }

  /// Resize image to specified size while maintaining square aspect ratio
  static Future<Uint8List> _resizeImage(Uint8List data, int size) async {
    final codec = await ui.instantiateImageCodec(
      data,
      targetWidth: size,
      targetHeight: size,
    );

    final frame = await codec.getNextFrame();
    final image = frame.image;

    // Create a square canvas
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // Draw white background
    final paint = Paint()..color = Colors.white;
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.toDouble(), size.toDouble()),
      paint,
    );

    // Draw border
    final borderPaint = Paint()
      ..color = Colors.blue.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.toDouble(), size.toDouble()),
      borderPaint,
    );

    // Calculate dimensions to maintain aspect ratio
    final imageWidth = image.width.toDouble();
    final imageHeight = image.height.toDouble();
    final aspectRatio = imageWidth / imageHeight;

    double drawWidth, drawHeight, dx, dy;

    if (aspectRatio > 1) {
      // Landscape
      drawWidth = size.toDouble() - 8; // 4px border on each side
      drawHeight = drawWidth / aspectRatio;
      dx = 4;
      dy = (size - drawHeight) / 2;
    } else {
      // Portrait or square
      drawHeight = size.toDouble() - 8;
      drawWidth = drawHeight * aspectRatio;
      dx = (size - drawWidth) / 2;
      dy = 4;
    }

    // Draw the image centered
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, imageWidth, imageHeight),
      Rect.fromLTWH(dx, dy, drawWidth, drawHeight),
      Paint(),
    );

    // Convert to image bytes
    final picture = recorder.endRecording();
    final img = await picture.toImage(size, size);
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);

    return byteData!.buffer.asUint8List();
  }

  /// Clear the marker cache
  static void clearCache() {
    _cache.clear();
  }

  /// Remove specific marker from cache
  static void removeCached(String mediaPath, {int size = 100}) {
    final cacheKey = '$mediaPath-$size';
    _cache.remove(cacheKey);
  }
}
