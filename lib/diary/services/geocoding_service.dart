import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../key.dart';

class GeocodingService {
  // Singleton pattern with memory cache
  static final GeocodingService _instance = GeocodingService._internal();
  factory GeocodingService() => _instance;
  GeocodingService._internal();

  final Map<String, String> _cache = {};

  Future<String> reverseGeocode(double lat, double lng) async {
    final cacheKey = '${lat.toStringAsFixed(4)},${lng.toStringAsFixed(4)}';
    if (_cache.containsKey(cacheKey)) return _cache[cacheKey]!;

    try {
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/geocode/json'
        '?latlng=$lat,$lng&key=$MAPS_API_KEY&language=en',
      );
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final results = data['results'] as List<dynamic>?;
        if (results != null && results.isNotEmpty) {
          final address =
              (results.first as Map<String, dynamic>)['formatted_address']
                  as String? ??
                  cacheKey;
          _cache[cacheKey] = address;
          return address;
        }
      }
    } catch (_) {}

    final fallback =
        '${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}';
    _cache[cacheKey] = fallback;
    return fallback;
  }
}
