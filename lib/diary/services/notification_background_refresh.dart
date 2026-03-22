import 'package:workmanager/workmanager.dart';

import '../database/app_database.dart';
import '../models/diary_notification_settings.dart';
import 'diary_notification_manager.dart';
import 'notification_ai_generator.dart';

// Top-level callback required by workmanager (must be a top-level function)
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    try {
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

      // 4. Reschedule all notifications
      await DiaryNotificationManager.instance.rescheduleAll(
        settings,
        otdAiTitle: otdAiTitle,
        otdAiBody: otdAiBody,
        periodicAiContent: periodicAiContent,
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
