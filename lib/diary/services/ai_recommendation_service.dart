import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import '../../key.dart';
import '../models/event_summary.dart';
import '../models/location_cluster.dart';
import '../models/recommendation_settings.dart';

class AiRecommendationService {
  const AiRecommendationService();

  /// 최근 이벤트, N년 전 오늘 이벤트, 위치 클러스터를 기반으로
  /// AI 다이어리 작성 추천을 생성합니다.
  Future<List<DiaryRecommendation>> generate({
    required List<EventSummary> recentEvents,
    required List<EventSummary> onThisDayEvents,
    required List<LocationCluster> clusters,
    required RecommendationSettings settings,
  }) async {
    final recommendations = <DiaryRecommendation>[];

    // 1. N년 전 오늘 이벤트 추천 (최대 3개)
    for (final event in onThisDayEvents.take(3)) {
      final rec = await _generateForEvent(
        event: event,
        source: RecommendationSource.onThisDay,
        settings: settings,
      );
      if (rec != null) recommendations.add(rec);
    }

    // 2. 최근 사진 이벤트 추천 (최대 3개, 점수 높은 순)
    final sortedRecent = [...recentEvents]
      ..sort((a, b) => b.qualityScore.compareTo(a.qualityScore));
    for (final event in sortedRecent.take(3)) {
      final rec = await _generateForEvent(
        event: event,
        source: RecommendationSource.recentPhoto,
        settings: settings,
      );
      if (rec != null) recommendations.add(rec);
    }

    // 3. 위치 클러스터 기반 추천 (최대 2개)
    for (final cluster in clusters.take(2)) {
      final rec = await _generateForCluster(
        cluster: cluster,
        settings: settings,
      );
      if (rec != null) recommendations.add(rec);
    }

    return recommendations;
  }

  Future<DiaryRecommendation?> _generateForEvent({
    required EventSummary event,
    required RecommendationSource source,
    required RecommendationSettings settings,
  }) async {
    final formatter = DateFormat('MMM d, yyyy HH:mm');
    final tagNames = event.tags.take(3).map((t) => t.name).join(', ');

    final contextLines = [
      '- Date/Time: ${formatter.format(event.startAt.toLocal())}',
      '- Photo count: ${event.assetCount}',
      if (event.isMoving) '- Photos taken while moving',
      if (tagNames.isNotEmpty) '- Tags: $tagNames',
      if (event.latitude != null)
        '- Location: ${event.latitude!.toStringAsFixed(3)}, ${event.longitude!.toStringAsFixed(3)}',
      if (event.title != null) '- Title: ${event.title}',
      if (event.userMemo != null) '- Memo: ${event.userMemo}',
      if (source == RecommendationSource.onThisDay)
        '- A memory from ${DateTime.now().year - event.startAt.toLocal().year} years ago today',
    ];

    final prompt = '''
Below is the user's photo record data.
${contextLines.join('\n')}

Based on the above, write a recommendation ${settings.format.instruction} to inspire the user to write a diary entry.
${settings.promptStyle}

Response format (JSON):
{
  "title": "Recommendation title (within 10 chars)",
  "body": "Recommendation text"
}
''';

    try {
      final response = await _callGemini(prompt, settings.model);
      final json = _parseJson(response);
      if (json == null) return null;
      return DiaryRecommendation(
        title: json['title'] as String? ?? 'Diary suggestion',
        body: json['body'] as String? ?? response,
        source: source,
        eventId: event.eventId,
      );
    } catch (e) {
      return null;
    }
  }

  Future<DiaryRecommendation?> _generateForCluster({
    required LocationCluster cluster,
    required RecommendationSettings settings,
  }) async {
    final prompt = '''
This is information about a place the user frequently visits.
- Location: ${cluster.label}
- Photo count: ${cluster.assetCount}

Write a recommendation ${settings.format.instruction} to inspire the user to record their memories or impressions of this place in a diary entry.
${settings.promptStyle}

Response format (JSON):
{
  "title": "Recommendation title (within 10 chars)",
  "body": "Recommendation text"
}
''';

    try {
      final response = await _callGemini(prompt, settings.model);
      final json = _parseJson(response);
      if (json == null) return null;
      return DiaryRecommendation(
        title: json['title'] as String? ?? 'Place memory',
        body: json['body'] as String? ?? response,
        source: RecommendationSource.locationCluster,
      );
    } catch (e) {
      return null;
    }
  }

  Future<String> _callGemini(String prompt, RecommendationModel model) async {
    final url = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/${model.modelId}:generateContent?key=$GEMINI_KEYS',
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

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return data['candidates'][0]['content']['parts'][0]['text'] as String;
    }
    throw Exception('Gemini API error: ${response.statusCode}');
  }

  Map<String, dynamic>? _parseJson(String text) {
    try {
      // JSON 블록 추출 (```json ... ``` 형식 대응)
      final cleaned = text
          .replaceAll(RegExp(r'```json\s*'), '')
          .replaceAll(RegExp(r'```\s*'), '')
          .trim();
      return jsonDecode(cleaned) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }
}
