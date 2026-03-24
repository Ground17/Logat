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
    'orange': 'Sky',
    'yellow': 'Yellow',
    'green': 'Green',
    'blue': 'Blue',
    'purple': 'Purple',
  };

  static Color getTagColor(String tag) {
    switch (tag) {
      case 'red':
        return const Color(0xFFBF616A);
      case 'orange':
        return const Color(0xFF88C0D0);
      case 'yellow':
        return const Color(0xFFEBCB8B);
      case 'green':
        return const Color(0xFFA3BE8C);
      case 'blue':
        return const Color(0xFF5E81AC);
      case 'purple':
        return const Color(0xFFB48EAD);
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
