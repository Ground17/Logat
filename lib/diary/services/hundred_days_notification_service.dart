import '../models/event_summary.dart';
import '../models/hundred_days_notif_settings.dart';

class HundredDaysMilestone {
  const HundredDaysMilestone({
    required this.eventId,
    required this.eventStartAt,
    required this.milestoneN,
    required this.scheduledAt,
    this.eventTitle,
  });

  final String eventId;
  final DateTime eventStartAt; // payload용 원본 시각
  final int milestoneN;        // 100, 200, 300...
  final DateTime scheduledAt;  // milestone 날짜 + 설정된 hour:minute
  final String? eventTitle;
}

class HundredDaysNotificationService {
  /// 알림을 보낼 고정 milestone 목록 (일 수)
  static const List<int> milestones = [
    100, 200, 300, 400, 500, 600, 700, 800, 900,
    1000, 2000, 3000, 4000, 5000, 6000, 7000, 8000, 9000, 10000,
  ];

  static List<HundredDaysMilestone> computeUpcomingMilestones({
    required List<EventSummary> events,
    required HundredDaysNotifSettings settings,
    required DateTime now,
    int maxAhead = 50,
  }) {
    final results = <HundredDaysMilestone>[];

    for (final event in events) {
      final origin = event.startAt.toLocal();
      final daysSince = now.difference(origin).inDays;
      if (daysSince < 0) continue; // 미래 이벤트 제외

      for (final n in milestones) {
        if (n <= daysSince) continue; // 이미 지난 milestone 스킵

        final milestoneDate = origin.add(Duration(days: n));
        final scheduledAt = DateTime(
          milestoneDate.year,
          milestoneDate.month,
          milestoneDate.day,
          settings.hour,
          settings.minute,
        );

        if (scheduledAt.isBefore(now)) continue;

        results.add(HundredDaysMilestone(
          eventId: event.eventId,
          eventStartAt: event.startAt,
          milestoneN: n,
          scheduledAt: scheduledAt,
          eventTitle: event.title,
        ));

        // 이 이벤트에서 첫 번째 미래 milestone만 수집 (다음 milestone은 너무 먼 미래)
        break;
      }
    }

    // scheduledAt 오름차순 정렬 후 상위 maxAhead개
    results.sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
    return results.take(maxAhead).toList();
  }
}
