class LocationCluster {
  const LocationCluster({
    required this.key,
    required this.label,
    required this.assetCount,
    required this.latitude,
    required this.longitude,
  });

  final String key;
  final String label;
  final int assetCount;
  final double latitude;
  final double longitude;
}
