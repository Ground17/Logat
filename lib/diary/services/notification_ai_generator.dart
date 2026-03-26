import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import '../../key.dart';
import '../database/app_database.dart';
import '../models/diary_notification_settings.dart';

class NotificationAiGenerator {
  const NotificationAiGenerator();

  static const _modelId = 'gemini-3-flash-preview';

  Future<({String title, String subtitle, String body})?> generateOnThisDayContent(
    OnThisDayNotifSettings settings,
    AppDatabase db,
  ) async {
    final now = DateTime.now();
    final events = await db.queryEventsOnThisDay(
      month: now.month,
      day: now.day,
      windowDays: 7,
      currentYear: now.year,
    );

    if (events.isEmpty) return null;

    final formatter = DateFormat('MMM d, yyyy');
    final eventLines = events.take(3).map((e) {
      final yearsAgo = now.year - e.startAt.toLocal().year;
      final parts = [
        '- ${formatter.format(e.startAt.toLocal())} ($yearsAgo years ago)',
        '${e.assetCount} photos',
      ];
      if (e.title != null) parts.add('title: ${e.title}');
      return parts.join(', ');
    }).join('\n');

    final prompt = '''The user has the following diary memories from today in past years:
$eventLines

Write a notification ${settings.aiFormat.instruction} to remind them of these memories.
${settings.aiPromptStyle}

Response format (JSON):
{
  "title": "Notification title (within 20 chars)",
  "body": "Notification body (within 60 chars)"
}
''';

    return _callGemini(prompt);
  }

  Future<({String title, String subtitle, String body})?> generatePeriodicContent(
    PeriodicNotifRule rule,
    AppDatabase db,
  ) async {
    final now = DateTime.now();
    final events = await db.queryEventsInRange(
      start: now.toUtc().subtract(const Duration(days: 14)),
      end: now.toUtc(),
    );

    final formatter = DateFormat('MMM d');
    final contextLines = events.take(3).map((e) {
      final parts = [
        '- ${formatter.format(e.startAt.toLocal())}',
        '${e.assetCount} photos',
      ];
      if (e.title != null) parts.add(e.title!);
      return parts.join(', ');
    }).join('\n');

    final prompt = '''
Based on recent diary activity:
${contextLines.isEmpty ? "(no recent events)" : contextLines}

Rule: ${rule.label}
Write a diary writing prompt ${rule.aiFormat.instruction}.
${rule.aiPromptStyle}

Response format (JSON):
{
  "title": "Notification title (within 20 chars)",
  "subtitle": "Short subtitle line (within 30 chars, optional context)",
  "body": "Notification body (within 60 chars)"
}
''';

    return _callGemini(prompt);
  }

  Future<({String title, String subtitle, String body})?> _callGemini(String prompt) async {
    try {
      final url = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/$_modelId:generateContent?key=$GEMINI_KEYS',
      );
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [
            {
              'role': 'user',
              'parts': [
                {'text': prompt}
              ],
            }
          ],
          'generationConfig': {
            'temperature': 0.8,
            'responseMimeType': 'application/json',
          },
        }),
      );

      if (response.statusCode != 200) return null;

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final text =
          data['candidates'][0]['content']['parts'][0]['text'] as String;
      final cleaned = text
          .replaceAll(RegExp(r'```json\s*'), '')
          .replaceAll(RegExp(r'```\s*'), '')
          .trim();
      final json = jsonDecode(cleaned) as Map<String, dynamic>;
      return (
        title: json['title'] as String? ?? '',
        subtitle: json['subtitle'] as String? ?? '',
        body: json['body'] as String? ?? '',
      );
    } catch (_) {
      return null;
    }
  }
}
