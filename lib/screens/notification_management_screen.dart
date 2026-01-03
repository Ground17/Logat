import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import '../database/database_helper.dart';
import '../models/scheduled_notification.dart';
import '../models/ai_persona.dart';
import '../services/notification_scheduler_service.dart';

class NotificationManagementScreen extends StatefulWidget {
  const NotificationManagementScreen({Key? key}) : super(key: key);

  @override
  State<NotificationManagementScreen> createState() => _NotificationManagementScreenState();
}

class _NotificationManagementScreenState extends State<NotificationManagementScreen> {
  List<ScheduledNotification> _pendingNotifications = [];
  List<ScheduledNotification> _deliveredNotifications = [];
  final Map<int, AiPersona?> _personaCache = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    setState(() => _isLoading = true);

    try {
      // Load all scheduled notifications
      final allNotifications = await DatabaseHelper.instance.getScheduledNotifications();

      // Separate pending and delivered
      final pending = allNotifications.where((n) => !n.isDelivered).toList();
      final delivered = allNotifications.where((n) => n.isDelivered).toList();

      // Load persona details
      final personaIds = allNotifications
          .map((n) => n.aiPersonaId)
          .where((id) => id != null)
          .toSet();

      for (final personaId in personaIds) {
        if (!_personaCache.containsKey(personaId)) {
          final persona = await DatabaseHelper.instance.getPersona(personaId!);

          // Convert avatar filename to full path if needed
          if (persona != null) {
            final convertedPersona = await _convertPersonaAvatarPath(persona);
            _personaCache[personaId] = convertedPersona;
          } else {
            _personaCache[personaId] = persona;
          }
        }
      }

      // Mark all delivered notifications as read
      final deliveredIds = delivered.map((n) => n.id!).toList();
      if (deliveredIds.isNotEmpty) {
        await NotificationSchedulerService.instance.markNotificationsAsRead(deliveredIds);
      }

      setState(() {
        _pendingNotifications = pending;
        _deliveredNotifications = delivered;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load notifications: $e')),
        );
      }
    }
  }

  /// Convert persona avatar filename to full path if needed
  Future<AiPersona> _convertPersonaAvatarPath(AiPersona persona) async {
    final avatarText = persona.avatar;
    print('🔍 Converting avatar for ${persona.name}: $avatarText');

    // Check if it's a filename (has image extension but no path separator)
    if (avatarText.isNotEmpty &&
        !avatarText.contains('/') &&
        (avatarText.endsWith('.png') ||
            avatarText.endsWith('.jpg') ||
            avatarText.endsWith('.jpeg') ||
            avatarText.endsWith('.webp'))) {
      try {
        final appDir = await getApplicationDocumentsDirectory();
        final fullPath = '${appDir.path}/$avatarText';
        print('📁 Checking file: $fullPath');

        // Check if file exists at this path
        final file = File(fullPath);
        if (await file.exists()) {
          print('✅ File exists, converting to: $fullPath');
          // Return persona with converted avatar path
          return persona.copyWith(avatar: fullPath);
        } else {
          print('⚠️ File does not exist: $fullPath');
        }
      } catch (e) {
        print('❌ Error converting persona avatar path: $e');
      }
    } else {
      print('ℹ️ No conversion needed (already path or emoji): $avatarText');
    }

    // Return original persona if no conversion needed
    return persona;
  }

  Future<void> _editNotificationTime(ScheduledNotification notification) async {
    final newDate = await showDatePicker(
      context: context,
      initialDate: notification.scheduledTime,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (newDate == null || !mounted) return;

    final newTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(notification.scheduledTime),
    );

    if (newTime == null || !mounted) return;

    final newDateTime = DateTime(
      newDate.year,
      newDate.month,
      newDate.day,
      newTime.hour,
      newTime.minute,
    );

    try {
      await NotificationSchedulerService.instance.rescheduleNotification(
        notification.id!,
        newDateTime,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Notification rescheduled successfully')),
        );
        _loadNotifications();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to reschedule notification: $e')),
        );
      }
    }
  }

  Future<void> _deleteNotification(ScheduledNotification notification) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Notification'),
        content: const Text('Are you sure you want to delete this scheduled notification?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await NotificationSchedulerService.instance.cancelNotification(notification.id!);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Notification deleted')),
        );
        _loadNotifications();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete notification: $e')),
        );
      }
    }
  }

  Widget _buildNotificationCard(ScheduledNotification notification, {required bool isPending}) {
    final persona = notification.aiPersonaId != null
        ? _personaCache[notification.aiPersonaId!]
        : null;

    final personaName = persona?.name ?? 'AI';
    final personaAvatar = persona?.avatar ?? '🤖';

    String title;
    String subtitle;

    if (notification.notificationType == 'like') {
      title = '$personaName liked your post';
      subtitle = isPending ? 'Scheduled' : 'Delivered';
    } else {
      title = '$personaName commented';
      subtitle = notification.commentContent ?? '';
    }

    final dateFormat = DateFormat('MMM d, y • h:mm a');
    final timeInfo = isPending
        ? 'Scheduled for ${dateFormat.format(notification.scheduledTime)}'
        : 'Delivered ${dateFormat.format(notification.scheduledTime)}';

    // Check if avatar is an image path
    final bool isImagePath = personaAvatar.contains('/') &&
        (personaAvatar.endsWith('.png') ||
            personaAvatar.endsWith('.jpg') ||
            personaAvatar.endsWith('.jpeg') ||
            personaAvatar.endsWith('.webp'));

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        leading: isImagePath
            ? CircleAvatar(
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                backgroundImage: FileImage(File(personaAvatar)),
              )
            : CircleAvatar(
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                child: Text(
                  personaAvatar,
                  style: const TextStyle(fontSize: 24),
                ),
              ),
        title: Text(title),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (subtitle.isNotEmpty) ...[
              Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
            ],
            Text(
              timeInfo,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.secondary,
              ),
            ),
          ],
        ),
        trailing: isPending
            ? PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'edit') {
                    _editNotificationTime(notification);
                  } else if (value == 'delete') {
                    _deleteNotification(notification);
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit),
                        SizedBox(width: 8),
                        Text('Edit Time'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete, color: Colors.red),
                        SizedBox(width: 8),
                        Text('Delete', style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
                ],
              )
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadNotifications,
              child: _pendingNotifications.isEmpty && _deliveredNotifications.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.notifications_off, size: 64, color: Colors.grey),
                          SizedBox(height: 16),
                          Text(
                            'No notifications',
                            style: TextStyle(fontSize: 18, color: Colors.grey),
                          ),
                        ],
                      ),
                    )
                  : ListView(
                      children: [
                        if (_pendingNotifications.isNotEmpty) ...[
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                            child: Text(
                              'Pending (${_pendingNotifications.length})',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                          ),
                          ..._pendingNotifications.map((n) => _buildNotificationCard(n, isPending: true)),
                        ],
                        if (_deliveredNotifications.isNotEmpty) ...[
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                            child: Text(
                              'Delivered (${_deliveredNotifications.length})',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                          ),
                          ..._deliveredNotifications.map((n) => _buildNotificationCard(n, isPending: false)),
                        ],
                      ],
                    ),
            ),
    );
  }
}
