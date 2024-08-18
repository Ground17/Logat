import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:logat/utils/structure.dart';
import 'package:native_exif/native_exif.dart';

import '../key.dart';

final coordModel = GenerativeModel(
  model: 'gemini-1.5-flash',
  apiKey: GEMINI_KEYS,

  // Specify the function declaration.
  tools: [
    Tool(functionDeclarations: [getCoord])
  ],
);

final getCoord = FunctionDeclaration(
    'getCoord',
    'Find the proper coordinates of where you need to go by using the given coordinate information.',
    Schema(SchemaType.object, properties: {
      'latitude': Schema(SchemaType.number,
          description: 'latitude of where you go. '
              'range of value is -90 ~ 90'),
      'longitude': Schema(SchemaType.number,
          description: 'longitude of where you go. '
              'range of value is -180 ~ 180'),
    }, requiredProperties: [
      'latitude',
      'longitude'
    ]));

final addressModel = GenerativeModel(
  model: 'gemini-1.5-flash',
  apiKey: GEMINI_KEYS,

  // Specify the function declaration.
  tools: [
    Tool(functionDeclarations: [getAddress])
  ],
);

final getAddress = FunctionDeclaration(
    'getAddress',
    'Find the proper Address of where you need to go by using the given information.',
    Schema(SchemaType.object, properties: {
      'address': Schema(SchemaType.string,
          description: 'address of where you go. '
              'Must be a real address'),
    }, requiredProperties: [
      'address'
    ]));

final textModel = GenerativeModel(
  model: 'gemini-1.5-flash',
  apiKey: GEMINI_KEYS,
);

Future<String?> getText({String type = "title", String sub="", required String date, required Loc location, String address="", String path=""}) async {
  final List<Part> parts = [];
  if (sub != "") {
    parts.add(TextPart("${type == "title" ? "description" : "title"}: $sub"));
  }

  parts.add(TextPart("date: $date"));
  parts.add(TextPart("address: (latitude: ${location.lat}, longitude: ${location.long}) $address"));

  if (path != "") {
    try {
      parts.add(DataPart('image/jpeg', File(path).readAsBytesSync()));
    } catch (e) {
      print(e);
    }
  }

  parts.add(TextPart("Please make the simple $type of given information."));

  final response = await textModel.generateContent([
    Content.multi(parts),
  ]);

  print(response.text);

  return response.text?.substring(0, min(response.text?.length ?? 0, 100)) ?? "";
}