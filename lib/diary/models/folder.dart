class DiaryFolder {
  const DiaryFolder({
    required this.folderId,
    required this.name,
    required this.createdAt,
    this.parentId,
    this.isFavorite = false,
  });

  final String folderId;
  final String name;
  final String? parentId;
  final bool isFavorite;
  final DateTime createdAt;
}
