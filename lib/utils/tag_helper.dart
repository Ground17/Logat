import 'package:flutter/material.dart';
import '../database/database_helper.dart';

class TagHelper {
  static const List<String> availableTags = [
    'red',
    'orange',
    'yellow',
    'green',
    'blue',
    'purple',
  ];

  static const Map<String, String> defaultTagNames = {
    'red': 'Red',
    'orange': 'Orange',
    'yellow': 'Yellow',
    'green': 'Green',
    'blue': 'Blue',
    'purple': 'Purple',
  };

  static Color getTagColor(String tag) {
    switch (tag) {
      case 'red':
        return Colors.red;
      case 'orange':
        return Colors.orange;
      case 'yellow':
        return Colors.yellow.shade700;
      case 'green':
        return Colors.green;
      case 'blue':
        return Colors.blue;
      case 'purple':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  static Future<String> getTagName(String tag) async {
    final db = DatabaseHelper.instance;
    final customName = await db.getTagCustomName(tag);
    return customName ?? defaultTagNames[tag] ?? tag;
  }

  static Future<Map<String, String>> getAllTagNames() async {
    final db = DatabaseHelper.instance;
    final customSettings = await db.getAllTagSettings();

    final result = <String, String>{};
    for (var tag in availableTags) {
      result[tag] = customSettings[tag] ?? defaultTagNames[tag]!;
    }
    return result;
  }
}
