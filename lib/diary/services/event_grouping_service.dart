import 'package:intl/intl.dart';

import '../models/diary_candidate.dart';
import '../models/event_summary.dart';

class EventGroupingService {
  const EventGroupingService();

  List<DiaryCandidate> buildCandidates(List<EventSummary> events) {
    final items = events
        .map(
          (event) => DiaryCandidate(
            title: _title(event),
            summary: _summary(event),
            prompt: _prompt(event),
            score: _score(event),
            event: event,
          ),
        )
        .toList()
      ..sort((a, b) => b.score.compareTo(a.score));
    return items;
  }

  String _title(EventSummary event) {
    final timeRange =
        '${DateFormat('HH:mm').format(event.startAt.toLocal())} - ${DateFormat('HH:mm').format(event.endAt.toLocal())}';
    final place = event.latitude == null || event.longitude == null
        ? 'Time-based event'
        : '${event.latitude!.toStringAsFixed(2)}, ${event.longitude!.toStringAsFixed(2)}';
    return '$place · $timeRange';
  }

  String _summary(EventSummary event) {
    final tags = event.tags.take(3).map((tag) => tag.name).join(', ');
    final movement = event.isMoving ? 'Moving event' : 'Single area';
    return '${event.assetCount} assets · $movement${tags.isEmpty ? '' : ' · $tags'}';
  }

  String _prompt(EventSummary event) {
    final locationText = event.latitude == null || event.longitude == null
        ? 'an unknown place'
        : '${event.latitude!.toStringAsFixed(2)}, ${event.longitude!.toStringAsFixed(2)}';
    final tags = event.tags.take(3).map((tag) => tag.name).join(', ');
    return '${DateFormat('HH:mm').format(event.startAt.toLocal())}~${DateFormat('HH:mm').format(event.endAt.toLocal())}에 $locationText에서 ${tags.isEmpty ? '기록' : tags} 활동이 있었어요. 그날 가장 기억나는 장면은 무엇인가요?';
  }

  double _score(EventSummary event) {
    return event.qualityScore +
        (event.isMoving ? 1.5 : 0) +
        (event.tags.length * 0.25) +
        (event.assetCount >= 12 ? 1.0 : 0);
  }
}
