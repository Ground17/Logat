import 'package:photo_manager/photo_manager.dart';

class PhotoAssetMetadata {
  const PhotoAssetMetadata({
    required this.assetId,
    required this.mediaType,
    required this.width,
    required this.height,
    required this.durationSeconds,
    required this.createdAt,
    required this.modifiedAt,
    required this.bucketId,
    required this.bucketName,
    required this.latitude,
    required this.longitude,
    required this.isFavorite,
    required this.isLocallyAvailable,
  });

  final String assetId;
  final AssetType mediaType;
  final int width;
  final int height;
  final int durationSeconds;
  final DateTime createdAt;
  final DateTime modifiedAt;
  final String? bucketId;
  final String? bucketName;
  final double? latitude;
  final double? longitude;
  final bool isFavorite;
  final bool isLocallyAvailable;

  String get mediaTypeName {
    switch (mediaType) {
      case AssetType.image:
        return 'image';
      case AssetType.video:
        return 'video';
      case AssetType.audio:
        return 'audio';
      case AssetType.other:
        return 'other';
    }
  }
}
