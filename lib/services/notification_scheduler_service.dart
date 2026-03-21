import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../database/database_helper.dart';
import '../models/scheduled_notification.dart';
import '../models/like.dart';
import '../models/comment.dart';
import '../main.dart';
import '../screens/post_detail_screen.dart';

/// Top-level function for background notification handling
@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse response) async {
  print('📱 Background notification tapped: ${response.payload}');

  // Deliver the notification and navigate to post
  if (response.payload != null) {
    final notificationId = int.tryParse(response.payload!);
    if (notificationId != null) {
      // Don't show notification again when tapping existing notification
      await NotificationSchedulerService.instance
          .deliverNotification(notificationId, showNotification: false);

      // Get the notification to find the post
      final notification = await DatabaseHelper.instance
          .getScheduledNotification(notificationId);
      if (notification != null) {
        final post = await DatabaseHelper.instance.getPost(notification.postId);
        if (post != null && navigatorKey.currentContext != null) {
          navigatorKey.currentState?.push(
            MaterialPageRoute(
              builder: (context) => PostDetailScreen(post: post),
            ),
          );
        }
      }
    }
  }
}

class NotificationSchedulerService {
  static final NotificationSchedulerService instance =
      NotificationSchedulerService._init();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  Timer? _periodicTimer;

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
    final String localTz = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(localTz));

    // Initialize notification plugin
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
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
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );

    // Request permissions
    await _requestPermissions();

    // Schedule any pending notifications
    await _schedulePendingNotifications();

    // Start periodic check for overdue notifications (every 30 seconds)
    _startPeriodicCheck();

    _initialized = true;
    print('✅ NotificationSchedulerService initialized');
  }

  /// Start periodic check for overdue notifications
  void _startPeriodicCheck() {
    _periodicTimer?.cancel();
    // Check every 10 seconds for debugging, change to 60 for production
    _periodicTimer = Timer.periodic(
        const Duration(seconds: kDebugMode ? 10 : 60), (timer) async {
      await processOverdueNotifications();
    });
    print('⏰ Started periodic notification check (every 10 seconds)');
  }

  /// Stop periodic check
  void dispose() {
    _periodicTimer?.cancel();
    _periodicTimer = null;
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

    // Deliver the notification and navigate to post
    if (response.payload != null) {
      final notificationId = int.tryParse(response.payload!);
      if (notificationId != null) {
        // Don't show notification again when tapping existing notification
        await deliverNotification(notificationId, showNotification: false);

        // Get the notification to find the post
        final notification = await DatabaseHelper.instance
            .getScheduledNotification(notificationId);
        if (notification != null) {
          final post =
              await DatabaseHelper.instance.getPost(notification.postId);
          if (post != null && navigatorKey.currentContext != null) {
            navigatorKey.currentState?.push(
              MaterialPageRoute(
                builder: (context) => PostDetailScreen(post: post),
              ),
            );
          }
        }
      }
    }
  }

  /// Schedule all pending notifications
  Future<void> _schedulePendingNotifications() async {
    final pendingNotifications = await DatabaseHelper.instance
        .getScheduledNotifications(isDelivered: false);

    print(
        '📅 Scheduling ${pendingNotifications.length} pending notifications...');

    for (final notification in pendingNotifications) {
      await scheduleNotification(notification);
    }

    print('✅ All pending notifications scheduled');
  }

  /// Schedule a notification
  Future<void> scheduleNotification(ScheduledNotification notification) async {
    print('📅 scheduleNotification called for notification ${notification.id}');

    if (notification.id == null) {
      print('⚠️ Cannot schedule notification without ID');
      return;
    }

    final now = DateTime.now();
    // Check if scheduled time is in the past (with 1 second buffer)
    if (notification.scheduledTime.isBefore(now.subtract(const Duration(seconds: 1)))) {
      // Deliver immediately if time has passed
      print('⏰ Notification ${notification.id} is overdue, delivering immediately');
      await deliverNotification(notification.id!);
      return;
    }

    print('⏰ Scheduling notification ${notification.id} for ${notification.scheduledTime}');

    // Get persona details
    String title = 'New notification';
    String body = '';

    if (notification.notificationType == 'like') {
      title = 'AI liked your post';
      body = 'Check out who liked your post!';
    } else if (notification.notificationType == 'comment') {
      title = 'AI commented on your post';
      body = notification.commentContent ?? 'New comment on your post';
    }

    // Persona avatar lookup removed - personas no longer exist
    const String? largeIconPath = null;
    const String? attachmentPath = null;

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
      NotificationDetails(
        android: AndroidNotificationDetails(
          'ai_reactions_channel',
          'AI Reactions',
          channelDescription: 'Notifications for AI likes and comments',
          importance: Importance.high,
          priority: Priority.high,
          // Show notifications even when app is in foreground
          playSound: true,
          enableVibration: true,
          largeIcon: largeIconPath != null
              ? FilePathAndroidBitmap(largeIconPath)
              : null,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          attachments: attachmentPath != null
              ? [
                  DarwinNotificationAttachment(
                    attachmentPath,
                    identifier: 'profile_image',
                    hideThumbnail: false,
                  )
                ]
              : null,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: notification.id.toString(),
    );

    print(
        '📅 Scheduled notification ${notification.id} for ${notification.scheduledTime}');
  }

  /// Deliver a notification (create actual Like/Comment in database)
  Future<void> deliverNotification(int notificationId, {bool showNotification = true}) async {
    final notification =
        await DatabaseHelper.instance.getScheduledNotification(notificationId);

    if (notification == null) {
      print('⚠️ Notification $notificationId not found');
      return;
    }

    if (notification.isDelivered) {
      print('ℹ️ Notification $notificationId already delivered');
      return;
    }

    print('📬 Delivering notification $notificationId (showNotification: $showNotification)...');

    try {
      // Show system notification if requested
      if (showNotification) {
        // Get persona details for notification
        String title = 'New notification';
        String body = '';

        if (notification.notificationType == 'like') {
          title = 'AI liked your post';
          body = 'Check out who liked your post!';
        } else if (notification.notificationType == 'comment') {
          title = 'AI commented on your post';
          body = notification.commentContent ?? 'New comment on your post';
        }

        // Persona avatar lookup removed - personas no longer exist
        const String? largeIconPath = null;
        const String? attachmentPath = null;
        // Show immediate notification
        await _notifications.show(
          notificationId,
          title,
          body,
          NotificationDetails(
            android: AndroidNotificationDetails(
              'ai_reactions_channel',
              'AI Reactions',
              channelDescription: 'Notifications for AI likes and comments',
              importance: Importance.high,
              priority: Priority.high,
              playSound: true,
              enableVibration: true,
              largeIcon: largeIconPath != null
                  ? FilePathAndroidBitmap(largeIconPath)
                  : null,
            ),
            iOS: DarwinNotificationDetails(
              presentAlert: true,
              presentBadge: true,
              presentSound: true,
              attachments: attachmentPath != null
                  ? [
                      DarwinNotificationAttachment(
                        attachmentPath,
                        identifier: 'profile_image',
                        hideThumbnail: false,
                      )
                    ]
                  : null,
            ),
          ),
          payload: notificationId.toString(),
        );
        print('🔔 Showed immediate notification');
      }

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
      await DatabaseHelper.instance
          .updateScheduledNotification(updatedNotification);

      print('✅ Notification $notificationId delivered successfully');
    } catch (e) {
      print('❌ Failed to deliver notification $notificationId: $e');
    }
  }

  /// Reschedule a notification to a new time
  Future<void> rescheduleNotification(
      int notificationId, DateTime newTime) async {
    final notification =
        await DatabaseHelper.instance.getScheduledNotification(notificationId);

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
    await DatabaseHelper.instance
        .updateScheduledNotification(updatedNotification);

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
    print('🔍 Checking overdue notifications: ${allPending.length} pending, current time: $now');

    for (final n in allPending) {
      print('   - Notification ${n.id}: scheduled for ${n.scheduledTime}, overdue: ${n.scheduledTime.isBefore(now)}');
    }

    final overdue =
        allPending.where((n) => n.scheduledTime.isBefore(now.subtract(const Duration(seconds: 1)))).toList();

    if (overdue.isEmpty) {
      print('ℹ️ No overdue notifications to process');
      return;
    }

    print('⏰ Processing ${overdue.length} overdue notifications...');

    // Process all overdue notifications in parallel for speed
    // showNotification: true because user missed these notifications
    await Future.wait(
      overdue.map((notification) => deliverNotification(notification.id!, showNotification: true)),
    );

    print('✅ Processed ${overdue.length} overdue notifications');
  }
}
