import 'dart:convert';
import 'package:http/http.dart' as http;

import '../key.dart';

Future<List<Map<String, String>>> addressAutoComplete(String text, double lat, double long) async {
  final headers = {'Content-Type': 'application/json', 'X-Goog-Api-Key': MAPS_API_KEY};
  final body = jsonEncode({
    "input": text,
    "locationBias": {
      "circle": {
        "center": {
          "latitude": lat,
          "longitude": long
        },
        "radius": 5000.0
      }
    }});
  final response = await http.post(Uri.parse('https://places.googleapis.com/v1/places:autocomplete'), headers: headers, body: body);

  final List<Map<String, String>> filtered_data = [];

  if (response.statusCode == 200) {
    final data = jsonDecode(response.body);

    // print(data);
    for (final suggestion in data['suggestions']) {
      filtered_data.add({
        'placeId': suggestion['placePrediction']['placeId'] ?? "",
        'text': suggestion['placePrediction']['text']['text'] ?? ""
      });
    }
  } else {
    print('Request failed with status: ${response.statusCode}.');
  }

  return filtered_data;
}

Future<Map<String, double>?> getGeocodingFromPlaceId (String placeId) async {
  final response = await http.get(Uri.parse('https://places.googleapis.com/v1/places/$placeId?fields=location&key=$MAPS_API_KEY'));

  Map<String, double>? answer;
  if (response.statusCode == 200) {
    final data = jsonDecode(response.body);
    print(data);

    answer = {'lat': data['location']['latitude'], 'long': data['location']['longitude']};
  } else {
    print('Request failed with status: ${response.statusCode}.');
  }

  return answer;
}

Future<List<Map<String, String>>> getReverseGeocoding(double lat, double long) async {
  final response = await http.get(Uri.parse('https://maps.googleapis.com/maps/api/geocode/json?latlng=$lat,$long&key=$MAPS_API_KEY'));

  final List<Map<String, String>> filtered_data = [];
  if (response.statusCode == 200) {
    final data = jsonDecode(response.body);
    for (final result in data['results']) {
      filtered_data.add({
        'text': result['formatted_address']
      });
    }
    print(data);
  } else {
    print('Request failed with status: ${response.statusCode}.');
  }

  return filtered_data;
}

// 5분마다 호출하면 좋을 듯
Future<List<Map<String, Object>>> getDirection(double start_lat, double start_long, double end_lat, double end_long, {String mode="Driving"}) async { // or Walking
  mode = mode.toLowerCase();
  final response = await http.get(Uri.parse('https://maps.googleapis.com/maps/api/directions/json?destination=$end_lat,$end_long&origin=$start_lat,$start_long&mode=$mode&key=YOUR_API_KEY'));

  final List<Map<String, Object>> filtered_data = [];
  if (response.statusCode == 200) {
    final data = jsonDecode(response.body);
    print(data);

    DateTime now = DateTime.now();

    if (data['routes'].length > 0) {
      if (data['routes'][0]['legs'] > 0) {
        int secondsSinceEpoch = now.millisecondsSinceEpoch ~/ 1000;
        for (final step in data['routes'][0]['legs'][0]['steps']) {
          filtered_data.add({
            'start_time': secondsSinceEpoch,
            'end_time': secondsSinceEpoch + step['duration']['value'],
            'start_lat': step['start_location']['lat'],
            'start_long': step['start_location']['lng'],
            'end_lat': step['end_location']['lat'],
            'end_long':step['end_location']['lng'],
          });

          secondsSinceEpoch += step['duration']['value'] as int;
        }
      }
    }
  } else {
    print('Request failed with status: ${response.statusCode}.');
  }

  return filtered_data;
}

// Future<List<Map<String, String>>> getGeocoding(String address) async {
//   final response = await http.get(Uri.parse('https://maps.googleapis.com/maps/api/geocode/json?address=$address&key=$MAPS_API_KEY'));
//
//   final List<Map<String, String>> filtered_data = [];
//   if (response.statusCode == 200) {
//     final data = jsonDecode(response.body);
//
//     print(data);
//   } else {
//     print('Request failed with status: ${response.statusCode}.');
//   }
//
//   return filtered_data;
// }