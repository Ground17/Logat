import 'package:workmanager/workmanager.dart';

import '../database/app_database.dart';
import '../models/diary_notification_settings.dart';
import '../repositories/photo_library_repository.dart';
import '../repositories/photo_metadata_repository.dart';
import 'diary_notification_manager.dart';
import 'event_generation_service.dart';
import 'hundred_days_notification_service.dart';
import 'notification_ai_generator.dart';
import 'photo_indexing_service.dart';

// Top-level callback required by workmanager (must be a top-level function)
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    try {
      if (taskName == 'bgIndexTask') {
        final db = AppDatabase();
        try {
          final service = PhotoIndexingService(
            photoLibraryRepository: PhotoLibraryRepository(),
            photoMetadataRepository: PhotoMetadataRepository(db),
            eventGenerationService: const EventGenerationService(),
          );
          await service.run(onProgress: (_) {});
        } finally {
          await db.close();
        }
        return true;
      }

      // 1. Initialize notification manager (new isolate — must re-initialize)
      await DiaryNotificationManager.instance.initialize();

      // 2. Load settings
      final settings = await DiaryNotificationSettings.load();

      // 3. Generate AI content for enabled rules
      String? otdAiTitle;
      String? otdAiBody;
      final periodicAiContent = <int, ({String title, String body})>{};

      if (settings.onThisDay.enabled && settings.onThisDay.useAi) {
        final db = AppDatabase();
        try {
          final result = await const NotificationAiGenerator()
              .generateOnThisDayContent(settings.onThisDay, db);
          if (result != null) {
            otdAiTitle = result.title;
            otdAiBody = result.body;
          }
        } finally {
          await db.close();
        }
      }

      for (var i = 0; i < settings.periodicRules.length; i++) {
        final rule = settings.periodicRules[i];
        if (rule.enabled && rule.useAi) {
          final db = AppDatabase();
          try {
            final result = await const NotificationAiGenerator()
                .generatePeriodicContent(rule, db);
            if (result != null) {
              periodicAiContent[i] = result;
            }
          } finally {
            await db.close();
          }
        }
      }

      // 4. Compute N×100 day milestones
      List<HundredDaysMilestone> hundredDaysMilestones = [];
      if (settings.hundredDays.enabled) {
        final db = AppDatabase();
        try {
          final now = DateTime.now().toUtc();
          final events = await db.queryEventsInRange(
            start: DateTime.utc(now.year - 10, 1, 1),
            end: now.add(const Duration(days: 1)),
          );
          hundredDaysMilestones =
              HundredDaysNotificationService.computeUpcomingMilestones(
            events: events,
            settings: settings.hundredDays,
            now: DateTime.now(),
          );
        } finally {
          await db.close();
        }
      }

      // 5. Reschedule all notifications
      await DiaryNotificationManager.instance.rescheduleAll(
        settings,
        otdAiTitle: otdAiTitle,
        otdAiBody: otdAiBody,
        periodicAiContent: periodicAiContent,
        hundredDaysMilestones: hundredDaysMilestones,
      );
    } catch (_) {
      // Do not rethrow — returning false would retry the task
    }
    return true;
  });
}

class NotificationBackgroundRefresh {
  static const taskName = 'diary_notification_refresh';

  static Future<void> register() async {
    await Workmanager().initialize(callbackDispatcher);
    await Workmanager().registerPeriodicTask(
      taskName,
      taskName,
      frequency: const Duration(hours: 12),
      constraints: Constraints(networkType: NetworkType.connected),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.replace,
    );
  }
}
