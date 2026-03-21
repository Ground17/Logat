class IndexingProgress {
  const IndexingProgress({
    required this.status,
    required this.scannedCount,
    required this.insertedCount,
    required this.skippedCount,
    required this.currentPage,
    this.totalAssets,
    this.message,
  });

  const IndexingProgress.idle()
      : status = 'idle',
        scannedCount = 0,
        insertedCount = 0,
        skippedCount = 0,
        currentPage = 0,
        totalAssets = null,
        message = null;

  final String status;
  final int scannedCount;
  final int insertedCount;
  final int skippedCount;
  final int currentPage;
  final int? totalAssets;
  final String? message;

  bool get isRunning => status == 'running';

  /// 0.0–1.0, null when total is unknown
  double? get fraction =>
      (totalAssets != null && totalAssets! > 0)
          ? (scannedCount / totalAssets!).clamp(0.0, 1.0)
          : null;
}
