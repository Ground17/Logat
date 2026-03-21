class LocationFilter {
  const LocationFilter({
    required this.label,
    required this.latitude,
    required this.longitude,
    required this.radiusKm,
  });

  final String label;
  final double latitude;
  final double longitude;
  final double radiusKm;
}
