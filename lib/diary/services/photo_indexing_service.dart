import '../models/indexing_progress.dart';
import '../models/photo_asset_metadata.dart';
import '../repositories/photo_library_repository.dart';
import '../repositories/photo_metadata_repository.dart';
import 'event_generation_service.dart';

class PhotoIndexingService {
  const PhotoIndexingService({
    required this.photoLibraryRepository,
    required this.photoMetadataRepository,
    required this.eventGenerationService,
    this.pageSize = 250,
    this.skipUnavailableOnIos = true,
  });

  final PhotoLibraryRepository photoLibraryRepository;
  final PhotoMetadataRepository photoMetadataRepository;
  final EventGenerationService eventGenerationService;
  final int pageSize;
  final bool skipUnavailableOnIos;

  Future<IndexingProgress> run({
    required void Function(IndexingProgress progress) onProgress,
  }) async {
    final album = await photoLibraryRepository.loadPrimaryAlbum();
    if (album == null) {
      return const IndexingProgress(
        status: 'idle',
        scannedCount: 0,
        insertedCount: 0,
        skippedCount: 0,
        currentPage: 0,
        message: 'No photo album available.',
      );
    }

    final totalAssets = await album.assetCountAsync;
    final state = await photoMetadataRepository.loadIndexingState();
    final resumePage = state.resumePage;
    PhotoAssetMetadata? newestAsset;
    DateTime? oldestInsertedAt;
    var page = resumePage;
    var scannedCount = state.scannedCount;
    var insertedCount = state.insertedCount;
    var skippedCount = state.skippedCount;

    await photoMetadataRepository.startRun(
      resumePage: resumePage,
      anchorCreatedAt: state.anchorCreatedAt,
      anchorAssetId: state.anchorAssetId,
    );

    try {
      while (true) {
        final pageResult = await photoLibraryRepository.loadMetadataPage(
          album: album,
          page: page,
          pageSize: pageSize,
          skipUnavailableOnIos: skipUnavailableOnIos,
        );

        if (pageResult.assets.isEmpty && !pageResult.hasMore) {
          break;
        }

        final freshAssets = _takeFreshAssets(
          assets: pageResult.assets,
          lastCompletedCreatedAt: state.lastCompletedCreatedAt,
          lastCompletedAssetId: state.lastCompletedAssetId,
        );

        scannedCount += pageResult.assets.length;
        skippedCount += pageResult.skippedUnavailableCount;

        if (freshAssets.isNotEmpty) {
          newestAsset ??= freshAssets.first;
          oldestInsertedAt = freshAssets.last.createdAt;
          await photoMetadataRepository.upsertBatch(freshAssets);
          insertedCount += freshAssets.length;
        }

        await photoMetadataRepository.updateRunProgress(
          resumePage: page + 1,
          scannedCount: scannedCount,
          insertedCount: insertedCount,
          skippedCount: skippedCount,
        );

        onProgress(
          IndexingProgress(
            status: 'running',
            scannedCount: scannedCount,
            insertedCount: insertedCount,
            skippedCount: skippedCount,
            currentPage: page,
            totalAssets: totalAssets,
            message: 'Page ${page + 1} · $scannedCount / $totalAssets',
          ),
        );

        if (freshAssets.length < pageResult.assets.length) {
          break;
        }
        if (!pageResult.hasMore) {
          break;
        }
        page += 1;
      }

      if (newestAsset != null && oldestInsertedAt != null) {
        final rows = await photoMetadataRepository.loadAssetsInRange(
          start: oldestInsertedAt.subtract(const Duration(hours: 6)),
          end: newestAsset.createdAt.add(const Duration(hours: 6)),
        );
        final generated = eventGenerationService.buildFromRows(rows);
        await photoMetadataRepository.replaceEventsInRange(
          start: oldestInsertedAt.subtract(const Duration(hours: 6)),
          end: newestAsset.createdAt.add(const Duration(hours: 6)),
          events: generated.events,
          assetTags: generated.assetTags,
        );
      }

      await photoMetadataRepository.finishRun(
        lastCompletedCreatedAt:
            newestAsset?.createdAt ?? state.lastCompletedCreatedAt,
        lastCompletedAssetId:
            newestAsset?.assetId ?? state.lastCompletedAssetId,
        scannedCount: scannedCount,
        insertedCount: insertedCount,
        skippedCount: skippedCount,
      );

      final result = IndexingProgress(
        status: 'idle',
        scannedCount: scannedCount,
        insertedCount: insertedCount,
        skippedCount: skippedCount,
        currentPage: page,
        totalAssets: totalAssets,
        message: 'Metadata and events updated.',
      );
      onProgress(result);
      return result;
    } catch (_) {
      await photoMetadataRepository.failRun();
      rethrow;
    }
  }

  List<PhotoAssetMetadata> _takeFreshAssets({
    required List<PhotoAssetMetadata> assets,
    required DateTime? lastCompletedCreatedAt,
    required String? lastCompletedAssetId,
  }) {
    if (lastCompletedCreatedAt == null || lastCompletedAssetId == null) {
      return assets;
    }

    final freshAssets = <PhotoAssetMetadata>[];
    for (final asset in assets) {
      if (asset.createdAt.isBefore(lastCompletedCreatedAt)) {
        break;
      }
      if (asset.createdAt.isAtSameMomentAs(lastCompletedCreatedAt) &&
          asset.assetId == lastCompletedAssetId) {
        break;
      }
      freshAssets.add(asset);
    }
    return freshAssets;
  }
}
