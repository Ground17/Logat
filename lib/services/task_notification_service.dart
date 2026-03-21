import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import '../database/database_helper.dart';
import '../models/task.dart';

class TaskNotificationService {
  static final TaskNotificationService instance = TaskNotificationService._init();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  // 최대 알림 개수 (iOS/Android 제한 고려)
  static const int maxNotifications = 50;
  // 작업 알림 ID 범위: 100000 ~ 149999
  static const int taskNotificationIdStart = 100000;

  TaskNotificationService._init();

  /// 모든 작업의 알림 업데이트 (앱 시작 시 호출)
  Future<void> updateAllTaskNotifications() async {
    print('🔔 Updating all task notifications...');

    // 기존 작업 관련 알림 모두 취소
    await _cancelAllTaskNotifications();

    // 활성 작업 가져오기
    final tasks = await DatabaseHelper.instance.getActiveTasks();

    if (tasks.isEmpty) {
      print('ℹ️ No active tasks to schedule');
      return;
    }

    // 각 작업의 다음 알림 스케줄
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

  /// 특정 작업의 알림 스케줄
  Future<bool> scheduleTaskNotification(Task task) async {
    if (task.id == null) return false;

    // 기존 알림 취소
    await _cancelTaskNotification(task.id!);

    return await _scheduleTaskNotification(task);
  }

  /// 작업 알림 스케줄 (내부)
  Future<bool> _scheduleTaskNotification(Task task) async {
    if (task.id == null || task.isCompleted) return false;

    final nextScheduleTime = _calculateNextScheduleTime(task);
    if (nextScheduleTime == null) {
      print('⚠️ No next schedule time for task: ${task.title}');
      return false;
    }

    // 과거 시간이면 스킵
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

      // lastNotificationDate 업데이트
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

  /// 다음 알림 시간 계산
  DateTime? _calculateNextScheduleTime(Task task) {
    final now = DateTime.now();

    // 시간 파싱 (HH:mm 형식)
    int hour = 9; // 기본값
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
        // 한 번만 - dueDate 사용
        if (task.dueDate == null) return null;
        return DateTime(
          task.dueDate!.year,
          task.dueDate!.month,
          task.dueDate!.day,
          hour,
          minute,
        );

      case TaskRecurrenceType.daily:
        // 매일 - 오늘 시간이 지났으면 내일
        var nextTime = DateTime(now.year, now.month, now.day, hour, minute);
        if (nextTime.isBefore(now)) {
          nextTime = nextTime.add(const Duration(days: 1));
        }
        return nextTime;

      case TaskRecurrenceType.weekly:
        // 매주 특정 요일
        if (task.weekdays == null || task.weekdays!.isEmpty) return null;

        // 현재 요일 (1=Monday, 7=Sunday)
        final currentWeekday = now.weekday;

        // 다음 알림 요일 찾기
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
        // 매월 특정 일
        if (task.monthDay == null) return null;

        var nextTime = DateTime(now.year, now.month, task.monthDay!, hour, minute);
        if (nextTime.isBefore(now)) {
          // 다음 달
          nextTime = DateTime(now.year, now.month + 1, task.monthDay!, hour, minute);
        }
        return nextTime;

      case TaskRecurrenceType.interval:
        // N일마다
        if (task.intervalDays == null) return null;

        if (task.lastNotificationDate != null) {
          // 마지막 알림에서 N일 후
          return task.lastNotificationDate!.add(Duration(days: task.intervalDays!));
        } else {
          // 처음 - 오늘부터 시작
          var nextTime = DateTime(now.year, now.month, now.day, hour, minute);
          if (nextTime.isBefore(now)) {
            nextTime = nextTime.add(Duration(days: task.intervalDays!));
          }
          return nextTime;
        }
    }
  }

  /// 작업 알림 취소
  Future<void> cancelTaskNotification(int taskId) async {
    await _cancelTaskNotification(taskId);
  }

  Future<void> _cancelTaskNotification(int taskId) async {
    final notificationId = taskNotificationIdStart + taskId;
    await _notifications.cancel(notificationId);
    print('🔕 Cancelled notification for task ID: $taskId');
  }

  /// 모든 작업 알림 취소
  Future<void> _cancelAllTaskNotifications() async {
    // 작업 알림 ID 범위의 모든 알림 취소
    for (int i = 0; i < maxNotifications; i++) {
      await _notifications.cancel(taskNotificationIdStart + i);
    }
    print('🔕 Cancelled all task notifications');
  }

  /// 완료된 작업의 알림 취소
  Future<void> cancelCompletedTaskNotification(int taskId) async {
    await _cancelTaskNotification(taskId);
  }
}
