import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../database/database_helper.dart';
import '../models/scheduled_notification.dart';
import '../models/like.dart';
import '../models/comment.dart';

class NotificationSchedulerService {
  static final NotificationSchedulerService instance = NotificationSchedulerService._init();

  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  NotificationSchedulerService._init();

  /// Initialize the notification service
  Future<void> initialize() async {
    if (_initialized) {
      print('ℹ️ NotificationSchedulerService already initialized');
      return;
    }

    print('🔔 Initializing NotificationSchedulerService...');

    // Initialize timezone database
    tz.initializeTimeZones();

    // Initialize notification plugin
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Request permissions
    await _requestPermissions();

    // Schedule any pending notifications
    await _schedulePendingNotifications();

    _initialized = true;
    print('✅ NotificationSchedulerService initialized');
  }

  /// Request notification permissions
  Future<void> _requestPermissions() async {
    // Android 13+ requires runtime permission
    final androidPlugin = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      await androidPlugin.requestNotificationsPermission();
    }

    // iOS requires runtime permission
    final iosPlugin = _notifications.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    if (iosPlugin != null) {
      await iosPlugin.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
    }
  }

  /// Handle notification tap
  Future<void> _onNotificationTapped(NotificationResponse response) async {
    print('📱 Notification tapped: ${response.payload}');
    // The app will handle navigation through the notification management screen
  }

  /// Schedule all pending notifications
  Future<void> _schedulePendingNotifications() async {
    final pendingNotifications = await DatabaseHelper.instance
        .getScheduledNotifications(isDelivered: false);

    print('📅 Scheduling ${pendingNotifications.length} pending notifications...');

    for (final notification in pendingNotifications) {
      await scheduleNotification(notification);
    }

    print('✅ All pending notifications scheduled');
  }

  /// Schedule a notification
  Future<void> scheduleNotification(ScheduledNotification notification) async {
    if (notification.id == null) {
      print('⚠️ Cannot schedule notification without ID');
      return;
    }

    // Check if scheduled time is in the past
    if (notification.scheduledTime.isBefore(DateTime.now())) {
      // Deliver immediately if time has passed
      await deliverNotification(notification.id!);
      return;
    }

    // Get persona details
    String title = 'New notification';
    String body = '';

    if (notification.aiPersonaId != null) {
      final persona = await DatabaseHelper.instance.getPersona(notification.aiPersonaId!);
      if (persona != null) {
        if (notification.notificationType == 'like') {
          title = '${persona.name} liked your post';
          body = 'Check out who liked your post!';
        } else if (notification.notificationType == 'comment') {
          title = '${persona.name} commented on your post';
          body = notification.commentContent ?? 'New comment on your post';
        }
      }
    }

    // Schedule the notification
    final tzScheduledTime = tz.TZDateTime.from(
      notification.scheduledTime,
      tz.local,
    );

    await _notifications.zonedSchedule(
      notification.id!,
      title,
      body,
      tzScheduledTime,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'ai_reactions_channel',
          'AI Reactions',
          channelDescription: 'Notifications for AI likes and comments',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: notification.id.toString(),
    );

    print('📅 Scheduled notification ${notification.id} for ${notification.scheduledTime}');
  }

  /// Deliver a notification (create actual Like/Comment in database)
  Future<void> deliverNotification(int notificationId) async {
    final notification = await DatabaseHelper.instance.getScheduledNotification(notificationId);

    if (notification == null) {
      print('⚠️ Notification $notificationId not found');
      return;
    }

    if (notification.isDelivered) {
      print('ℹ️ Notification $notificationId already delivered');
      return;
    }

    print('📬 Delivering notification $notificationId...');

    try {
      // Create the actual Like or Comment in database
      if (notification.notificationType == 'like') {
        final like = Like(
          postId: notification.postId,
          aiPersonaId: notification.aiPersonaId,
          isUser: false,
          createdAt: DateTime.now(),
        );
        await DatabaseHelper.instance.createLike(like);
        print('👍 Like created for notification $notificationId');
      } else if (notification.notificationType == 'comment') {
        final comment = Comment(
          postId: notification.postId,
          aiPersonaId: notification.aiPersonaId,
          isUser: false,
          content: notification.commentContent ?? '',
          createdAt: DateTime.now(),
        );
        await DatabaseHelper.instance.createComment(comment);
        print('💬 Comment created for notification $notificationId');
      }

      // Mark notification as delivered
      final updatedNotification = notification.copyWith(isDelivered: true);
      await DatabaseHelper.instance.updateScheduledNotification(updatedNotification);

      print('✅ Notification $notificationId delivered successfully');
    } catch (e) {
      print('❌ Failed to deliver notification $notificationId: $e');
    }
  }

  /// Reschedule a notification to a new time
  Future<void> rescheduleNotification(int notificationId, DateTime newTime) async {
    final notification = await DatabaseHelper.instance.getScheduledNotification(notificationId);

    if (notification == null) {
      print('⚠️ Notification $notificationId not found');
      return;
    }

    if (notification.isDelivered) {
      print('⚠️ Cannot reschedule delivered notification $notificationId');
      return;
    }

    // Cancel existing notification
    await _notifications.cancel(notificationId);

    // Update scheduled time in database
    final updatedNotification = notification.copyWith(scheduledTime: newTime);
    await DatabaseHelper.instance.updateScheduledNotification(updatedNotification);

    // Schedule with new time
    await scheduleNotification(updatedNotification);

    print('🔄 Rescheduled notification $notificationId to $newTime');
  }

  /// Cancel a notification
  Future<void> cancelNotification(int notificationId) async {
    // Cancel from notification system
    await _notifications.cancel(notificationId);

    // Delete from database
    await DatabaseHelper.instance.deleteScheduledNotification(notificationId);

    print('🚫 Cancelled notification $notificationId');
  }

  /// Get unread notification count
  Future<int> getBadgeCount() async {
    return await DatabaseHelper.instance.getUnreadNotificationCount();
  }

  /// Mark notifications as read
  Future<void> markNotificationsAsRead(List<int> ids) async {
    await DatabaseHelper.instance.markNotificationsAsRead(ids);
  }

  /// Mark all notifications as read
  Future<void> markAllNotificationsAsRead() async {
    await DatabaseHelper.instance.markAllNotificationsAsRead();
  }

  /// Process notifications that should have been delivered (catch up after app restart)
  Future<void> processOverdueNotifications() async {
    final allPending = await DatabaseHelper.instance
        .getScheduledNotifications(isDelivered: false);

    final now = DateTime.now();
    final overdue = allPending.where((n) => n.scheduledTime.isBefore(now)).toList();

    if (overdue.isEmpty) {
      print('ℹ️ No overdue notifications to process');
      return;
    }

    print('⏰ Processing ${overdue.length} overdue notifications...');

    for (final notification in overdue) {
      await deliverNotification(notification.id!);
    }

    print('✅ Processed ${overdue.length} overdue notifications');
  }
}
