import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'diary/models/diary_notification_settings.dart';
import 'diary/services/diary_notification_manager.dart';
import 'diary/services/notification_background_refresh.dart';
import 'diary/screens/diary_home_screen.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> _rescheduleAllNotificationsOnStartup() async {
  final settings = await DiaryNotificationSettings.load();
  // No AI on startup — skip network call for fast launch
  await DiaryNotificationManager.instance.rescheduleAll(settings);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DiaryNotificationManager.instance.initialize();
  await NotificationBackgroundRefresh.register();
  await _rescheduleAllNotificationsOnStartup();
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
