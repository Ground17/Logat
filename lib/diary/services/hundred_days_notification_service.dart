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
  final DateTime eventStartAt; // original timestamp for payload
  final int milestoneN;        // 100, 200, 300...
  final DateTime scheduledAt;  // milestone date + configured hour:minute
  final String? eventTitle;
}

class HundredDaysNotificationService {
  /// Fixed milestone list to notify (in days)
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
      if (daysSince < 0) continue; // Skip future events

      for (final n in milestones) {
        if (n <= daysSince) continue; // Skip already-passed milestones

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

        // Only collect the first upcoming milestone per event (subsequent ones are too far ahead)
        break;
      }
    }

    // Sort by scheduledAt ascending and return top maxAhead entries
    results.sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
    return results.take(maxAhead).toList();
  }
}
