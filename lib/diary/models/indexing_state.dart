class IndexingStateModel {
  const IndexingStateModel({
    required this.status,
    required this.resumePage,
    required this.scannedCount,
    required this.insertedCount,
    required this.skippedCount,
    required this.updatedAt,
    this.lastCompletedCreatedAt,
    this.lastCompletedAssetId,
    this.anchorCreatedAt,
    this.anchorAssetId,
    this.startedAt,
    this.completedAt,
  });

  final String status;
  final int resumePage;
  final int scannedCount;
  final int insertedCount;
  final int skippedCount;
  final DateTime updatedAt;
  final DateTime? lastCompletedCreatedAt;
  final String? lastCompletedAssetId;
  final DateTime? anchorCreatedAt;
  final String? anchorAssetId;
  final DateTime? startedAt;
  final DateTime? completedAt;

  bool get isRunning => status == 'running';
}
