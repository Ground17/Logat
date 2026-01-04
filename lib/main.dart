import 'package:flutter/material.dart';
import 'screens/feed_screen.dart';
import 'screens/terms_agreement_screen.dart';
import 'screens/post_detail_screen.dart';
import 'services/settings_service.dart';
import 'services/notification_scheduler_service.dart';
import 'services/ai_task_queue_service.dart';
import 'utils/media_migration.dart';
import 'database/database_helper.dart';

// Global navigator key for accessing navigation from anywhere
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'Logat',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.light,
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
        ),
      ),
      themeMode: ThemeMode.system,
      home: const SplashScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkFirstTime();
  }

  Future<void> _checkFirstTime() async {
    // Initialize notification system FIRST
    await NotificationSchedulerService.instance.initialize();

    // Process overdue notifications (deliver immediately)
    await NotificationSchedulerService.instance.processOverdueNotifications();

    // Process pending AI tasks in background (don't await)
    AiTaskQueueService.instance.processPendingTasks();

    // Check and migrate media files to permanent storage
    await MediaMigration.logMediaStats();
    await MediaMigration.checkAndMigratePostMedia();

    final isFirstTime = await SettingsService.isFirstTime();

    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) =>
              isFirstTime ? const TermsAgreementScreen() : const FeedScreen(),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}
