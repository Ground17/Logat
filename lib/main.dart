import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'diary/models/notification_settings.dart';
import 'diary/services/memories_notification_service.dart';
import 'diary/screens/diary_home_screen.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> _scheduleDefaultNotificationsOnFirstRun() async {
  final prefs = await SharedPreferences.getInstance();
  const firstRunKey = 'notifications_default_scheduled_v1';
  if (prefs.getBool(firstRunKey) == true) return;

  // Schedule On This Day notification with default settings (enabled=true)
  final memoriesSettings = await MemoriesNotificationSettings.load();
  if (memoriesSettings.enabled) {
    await MemoriesNotificationService().schedule(memoriesSettings);
  }

  await prefs.setBool(firstRunKey, true);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _scheduleDefaultNotificationsOnFirstRun();
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
