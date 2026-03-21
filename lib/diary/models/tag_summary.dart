class TagSummary {
  const TagSummary({
    required this.tagId,
    required this.name,
    required this.type,
    required this.count,
    required this.confidence,
  });

  final String tagId;
  final String name;
  final String type;
  final int count;
  final double confidence;
}
