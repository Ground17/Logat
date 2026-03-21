import 'dart:io';

import 'package:photo_manager/photo_manager.dart';

import '../models/photo_asset_metadata.dart';

class PhotoPageResult {
  const PhotoPageResult({
    required this.assets,
    required this.skippedUnavailableCount,
    required this.hasMore,
  });

  final List<PhotoAssetMetadata> assets;
  final int skippedUnavailableCount;
  final bool hasMore;
}

class PhotoLibraryRepository {
  static const PermissionRequestOption _permissionRequestOption =
      PermissionRequestOption(
    androidPermission: AndroidPermission(
      type: RequestType.common,
      mediaLocation: false,
    ),
  );

  Future<PermissionState> requestPermission() {
    return PhotoManager.requestPermissionExtend(
      requestOption: _permissionRequestOption,
    );
  }

  Future<PermissionState> permissionState() {
    return PhotoManager.getPermissionState(
        requestOption: _permissionRequestOption);
  }

  Future<AssetPathEntity?> loadPrimaryAlbum() async {
    final paths = await PhotoManager.getAssetPathList(
      type: RequestType.common,
      onlyAll: true,
      filterOption: FilterOptionGroup(
        orders: const [
          OrderOption(type: OrderOptionType.createDate, asc: false),
        ],
      ),
    );

    if (paths.isEmpty) {
      return null;
    }
    return paths.first;
  }

  Future<PhotoPageResult> loadMetadataPage({
    required AssetPathEntity album,
    required int page,
    required int pageSize,
    required bool skipUnavailableOnIos,
  }) async {
    final entities = await album.getAssetListPaged(page: page, size: pageSize);
    final metadata = <PhotoAssetMetadata>[];
    var skippedUnavailable = 0;

    for (final entity in entities) {
      final isLocallyAvailable = await entity.isLocallyAvailable();
      if (Platform.isIOS && skipUnavailableOnIos && !isLocallyAvailable) {
        skippedUnavailable += 1;
        continue;
      }

      metadata.add(
        PhotoAssetMetadata(
          assetId: entity.id,
          mediaType: entity.type,
          width: entity.width,
          height: entity.height,
          durationSeconds: entity.duration,
          createdAt: entity.createDateTime.toUtc(),
          modifiedAt: entity.modifiedDateTime.toUtc(),
          bucketId: entity.relativePath,
          bucketName: entity.title,
          latitude: entity.latitude == 0 ? null : entity.latitude,
          longitude: entity.longitude == 0 ? null : entity.longitude,
          isFavorite: entity.isFavorite,
          isLocallyAvailable: isLocallyAvailable,
        ),
      );
    }

    return PhotoPageResult(
      assets: metadata,
      skippedUnavailableCount: skippedUnavailable,
      hasMore: entities.length == pageSize,
    );
  }
}
