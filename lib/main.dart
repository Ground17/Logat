import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'diary/database/app_database.dart';
import 'diary/models/diary_notification_settings.dart';
import 'diary/screens/diary_home_screen.dart';
import 'diary/services/diary_notification_manager.dart';
import 'diary/services/hundred_days_notification_service.dart';
import 'diary/services/notification_background_refresh.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> _rescheduleAllNotificationsOnStartup() async {
  final settings = await DiaryNotificationSettings.load();

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

  // No AI on startup — skip network call for fast launch
  await DiaryNotificationManager.instance.rescheduleAll(
    settings,
    hundredDaysMilestones: hundredDaysMilestones,
  );
}

Future<void> _handlePendingNotificationTap() async {
  final prefs = await SharedPreferences.getInstance();
  final payload = prefs.getString('pending_diary_notification_tap');
  if (payload == null || payload.isEmpty) return;
  await prefs.remove('pending_diary_notification_tap');
  WidgetsBinding.instance.addPostFrameCallback((_) {
    DiaryNotificationManager.handleNotificationTap(payload);
  });
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DiaryNotificationManager.instance.initialize();
  await NotificationBackgroundRefresh.register();
  await _rescheduleAllNotificationsOnStartup();
  await _handlePendingNotificationTap();
  runApp(const ProviderScope(child: DiaryApp()));
}

class DiaryApp extends StatelessWidget {
  const DiaryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'Logat',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2F6B5F),
          brightness: Brightness.light,
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2F6B5F),
          brightness: Brightness.dark,
        ),
      ),
      themeMode: ThemeMode.system,
      home: const DiaryHomeScreen(),
    );
  }
}
