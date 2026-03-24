import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/notification_history_entry.dart';
import '../services/diary_notification_manager.dart';
import '../services/notification_history_service.dart';
import 'diary_notification_settings_screen.dart';

class NotificationHistoryScreen extends StatefulWidget {
  const NotificationHistoryScreen({super.key});

  @override
  State<NotificationHistoryScreen> createState() =>
      _NotificationHistoryScreenState();
}

class _NotificationHistoryScreenState extends State<NotificationHistoryScreen> {
  late Future<({
    List<NotificationHistoryEntry> recent,
    List<NotificationHistoryEntry> upcoming,
  })> _sectionsFuture;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _sectionsFuture = NotificationHistoryService().loadSections(
      DiaryNotificationManager.instance.plugin,
    );
  }

  Future<void> _onTapEntry(NotificationHistoryEntry entry) async {
    if (entry.payload != null) {
      await DiaryNotificationManager.handleNotificationTap(entry.payload);
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Notification History'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Upcoming'),
              Tab(text: 'History'),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.settings_outlined),
              tooltip: 'Notification Settings',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const DiaryNotificationSettingsScreen(),
                ),
              ),
            ),
          ],
        ),
        body: FutureBuilder(
          future: _sectionsFuture,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final upcoming = snapshot.data!.upcoming;
            final recent = snapshot.data!.recent;
            return TabBarView(
              children: [
                _EntryList(
                  entries: upcoming,
                  emptyMessage: 'No upcoming notifications',
                  onTap: null,
                ),
                _EntryList(
                  entries: recent,
                  emptyMessage: 'No notification history',
                  onTap: _onTapEntry,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _EntryList extends StatelessWidget {
  const _EntryList({
    required this.entries,
    required this.emptyMessage,
    required this.onTap,
  });

  final List<NotificationHistoryEntry> entries;
  final String emptyMessage;
  final Future<void> Function(NotificationHistoryEntry)? onTap;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return Center(
        child: Text(
          emptyMessage,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.outline,
              ),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: entries.length,
      separatorBuilder: (_, __) => const Divider(height: 1, indent: 56),
      itemBuilder: (context, i) {
        final e = entries[i];
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: _typeColor(context, e.type).withAlpha(38),
            child: Icon(_typeIcon(e.type), color: _typeColor(context, e.type)),
          ),
          title: Text(e.title, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: e.body.isNotEmpty
              ? Text(e.body, maxLines: 1, overflow: TextOverflow.ellipsis)
              : null,
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _formatDate(e.scheduledAt),
                style: Theme.of(context).textTheme.labelSmall,
              ),
              const SizedBox(height: 2),
              if (e.delivered)
                Icon(Icons.check_circle_outline,
                    size: 16,
                    color: Theme.of(context).colorScheme.primary)
              else
                Text(
                  _formatTime(e.scheduledAt),
                  style: Theme.of(context).textTheme.labelSmall,
                ),
            ],
          ),
          onTap: onTap != null ? () => onTap!(e) : null,
        );
      },
    );
  }

  IconData _typeIcon(String type) {
    switch (type) {
      case 'hundredDays':
        return Icons.cake_outlined;
      case 'onThisDay':
        return Icons.history;
      default:
        return Icons.alarm;
    }
  }

  Color _typeColor(BuildContext context, String type) {
    final cs = Theme.of(context).colorScheme;
    switch (type) {
      case 'hundredDays':
        return Colors.amber.shade700;
      case 'onThisDay':
        return cs.primary;
      default:
        return Colors.green.shade600;
    }
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
      return 'Today';
    }
    if (dt.year == now.year) {
      return DateFormat('M/d').format(dt);
    }
    return DateFormat('yy/M/d').format(dt);
  }

  String _formatTime(DateTime dt) {
    return DateFormat('HH:mm').format(dt);
  }
}
