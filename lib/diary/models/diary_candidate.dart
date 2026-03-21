import 'event_summary.dart';

class DiaryCandidate {
  const DiaryCandidate({
    required this.title,
    required this.summary,
    required this.prompt,
    required this.score,
    required this.event,
  });

  final String title;
  final String summary;
  final String prompt;
  final double score;
  final EventSummary event;
}
