import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import '../database/database_helper.dart';
import '../models/task.dart';

class TaskNotificationService {
  static final TaskNotificationService instance = TaskNotificationService._init();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  // Maximum notification count (considering iOS/Android limits)
  static const int maxNotifications = 50;
  // Task notification ID range: 100000 ~ 149999
  static const int taskNotificationIdStart = 100000;

  TaskNotificationService._init();

  /// Update all task notifications (called on app start)
  Future<void> updateAllTaskNotifications() async {
    print('🔔 Updating all task notifications...');

    // Cancel all existing task notifications
    await _cancelAllTaskNotifications();

    // Get active tasks
    final tasks = await DatabaseHelper.instance.getActiveTasks();

    if (tasks.isEmpty) {
      print('ℹ️ No active tasks to schedule');
      return;
    }

    // Schedule next notification for each task
    int scheduledCount = 0;
    for (final task in tasks) {
      if (scheduledCount >= maxNotifications) {
        print('⚠️ Reached max notification limit ($maxNotifications)');
        break;
      }

      final scheduled = await _scheduleTaskNotification(task);
      if (scheduled) scheduledCount++;
    }

    print('✅ Scheduled $scheduledCount task notifications');
  }

  /// Schedule notification for a specific task
  Future<bool> scheduleTaskNotification(Task task) async {
    if (task.id == null) return false;

    // Cancel existing notification
    await _cancelTaskNotification(task.id!);

    return await _scheduleTaskNotification(task);
  }

  /// Schedule task notification (internal)
  Future<bool> _scheduleTaskNotification(Task task) async {
    if (task.id == null || task.isCompleted) return false;

    final nextScheduleTime = _calculateNextScheduleTime(task);
    if (nextScheduleTime == null) {
      print('⚠️ No next schedule time for task: ${task.title}');
      return false;
    }

    // Skip if schedule time is in the past
    if (nextScheduleTime.isBefore(DateTime.now())) {
      print('⚠️ Schedule time is in the past for task: ${task.title}');
      return false;
    }

    final notificationId = taskNotificationIdStart + task.id!;

    try {
      await _notifications.zonedSchedule(
        notificationId,
        '⏰ ${task.title}',
        task.description ?? 'Task reminder',
        tz.TZDateTime.from(nextScheduleTime, tz.local),
        NotificationDetails(
          android: AndroidNotificationDetails(
            'task_reminders',
            'Task Reminders',
            channelDescription: 'Notifications for scheduled tasks',
            importance: Importance.high,
            priority: Priority.high,
            playSound: true,
            enableVibration: true,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: 'task_${task.id}',
      );

      // Update lastNotificationDate
      await DatabaseHelper.instance.updateTask(
        task.copyWith(lastNotificationDate: nextScheduleTime),
      );

      print('📅 Scheduled task notification: ${task.title} at $nextScheduleTime');
      return true;
    } catch (e) {
      print('❌ Failed to schedule task notification: $e');
      return false;
    }
  }

  /// Calculate the next notification time
  DateTime? _calculateNextScheduleTime(Task task) {
    final now = DateTime.now();

    // Parse time (HH:mm format)
    int hour = 9; // default
    int minute = 0;
    if (task.time != null) {
      final timeParts = task.time!.split(':');
      if (timeParts.length == 2) {
        hour = int.tryParse(timeParts[0]) ?? 9;
        minute = int.tryParse(timeParts[1]) ?? 0;
      }
    }

    switch (task.recurrenceType) {
      case TaskRecurrenceType.none:
        // Once only — use dueDate
        if (task.dueDate == null) return null;
        return DateTime(
          task.dueDate!.year,
          task.dueDate!.month,
          task.dueDate!.day,
          hour,
          minute,
        );

      case TaskRecurrenceType.daily:
        // Daily — if today's time has passed, schedule for tomorrow
        var nextTime = DateTime(now.year, now.month, now.day, hour, minute);
        if (nextTime.isBefore(now)) {
          nextTime = nextTime.add(const Duration(days: 1));
        }
        return nextTime;

      case TaskRecurrenceType.weekly:
        // Weekly on specific weekdays
        if (task.weekdays == null || task.weekdays!.isEmpty) return null;

        // Current weekday (1=Monday, 7=Sunday)
        final currentWeekday = now.weekday;

        // Find the next notification weekday
        int daysToAdd = 0;
        bool found = false;

        for (int i = 0; i <= 7; i++) {
          final checkWeekday = ((currentWeekday - 1 + i) % 7) + 1;
          if (task.weekdays!.contains(checkWeekday)) {
            final checkTime = now.add(Duration(days: i));
            final scheduledTime = DateTime(
              checkTime.year,
              checkTime.month,
              checkTime.day,
              hour,
              minute,
            );

            if (scheduledTime.isAfter(now)) {
              daysToAdd = i;
              found = true;
              break;
            }
          }
        }

        if (!found) return null;

        final nextDate = now.add(Duration(days: daysToAdd));
        return DateTime(nextDate.year, nextDate.month, nextDate.day, hour, minute);

      case TaskRecurrenceType.monthly:
        // Monthly on a specific day
        if (task.monthDay == null) return null;

        var nextTime = DateTime(now.year, now.month, task.monthDay!, hour, minute);
        if (nextTime.isBefore(now)) {
          // Next month
          nextTime = DateTime(now.year, now.month + 1, task.monthDay!, hour, minute);
        }
        return nextTime;

      case TaskRecurrenceType.interval:
        // Every N days
        if (task.intervalDays == null) return null;

        if (task.lastNotificationDate != null) {
          // N days after the last notification
          return task.lastNotificationDate!.add(Duration(days: task.intervalDays!));
        } else {
          // First time — start from today
          var nextTime = DateTime(now.year, now.month, now.day, hour, minute);
          if (nextTime.isBefore(now)) {
            nextTime = nextTime.add(Duration(days: task.intervalDays!));
          }
          return nextTime;
        }
    }
  }

  /// Cancel task notification
  Future<void> cancelTaskNotification(int taskId) async {
    await _cancelTaskNotification(taskId);
  }

  Future<void> _cancelTaskNotification(int taskId) async {
    final notificationId = taskNotificationIdStart + taskId;
    await _notifications.cancel(notificationId);
    print('🔕 Cancelled notification for task ID: $taskId');
  }

  /// Cancel all task notifications
  Future<void> _cancelAllTaskNotifications() async {
    // Cancel all notifications in the task notification ID range
    for (int i = 0; i < maxNotifications; i++) {
      await _notifications.cancel(taskNotificationIdStart + i);
    }
    print('🔕 Cancelled all task notifications');
  }

  /// Cancel notification for a completed task
  Future<void> cancelCompletedTaskNotification(int taskId) async {
    await _cancelTaskNotification(taskId);
  }
}
