import 'dart:convert';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/notification_history_entry.dart';

class NotificationHistoryService {
  static const _kEntries = 'notif_history_entries';
  static const _maxEntries = 100;

  Future<List<NotificationHistoryEntry>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_kEntries) ?? [];
    return list
        .map(NotificationHistoryEntry.tryFromJsonString)
        .whereType<NotificationHistoryEntry>()
        .toList();
  }

  Future<void> addEntry(NotificationHistoryEntry entry) async {
    final all = await loadAll();
    // Prevent duplicate IDs
    all.removeWhere((e) => e.id == entry.id);
    all.insert(0, entry);
    await _save(all.take(_maxEntries).toList());
  }

  /// Replace undelivered existing entries on reschedule (prevents duplicates)
  Future<void> replaceEntriesOfType(String type) async {
    final all = await loadAll();
    all.removeWhere((e) => e.type == type && !e.delivered);
    await _save(all);
  }

  Future<void> markDelivered(String entryId) async {
    final all = await loadAll();
    final idx = all.indexWhere((e) => e.id == entryId);
    if (idx >= 0) {
      all[idx] = all[idx].copyWith(delivered: true);
      await _save(all);
    }
  }

  Future<({
    List<NotificationHistoryEntry> recent,
    List<NotificationHistoryEntry> upcoming,
  })> loadSections(FlutterLocalNotificationsPlugin plugin) async {
    final all = await loadAll();
    final now = DateTime.now();

    final pendingRequests = await plugin.pendingNotificationRequests();
    final pendingIds = pendingRequests.map((r) => r.id).toSet();

    final upcoming = all
        .where((e) =>
            !e.delivered &&
            e.scheduledAt.isAfter(now) &&
            pendingIds.contains(e.notificationId))
        .toList()
      ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));

    final recent = all
        .where((e) => e.delivered || e.scheduledAt.isBefore(now))
        .toList()
      ..sort((a, b) => b.scheduledAt.compareTo(a.scheduledAt));

    return (recent: recent, upcoming: upcoming);
  }

  Future<void> _save(List<NotificationHistoryEntry> entries) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _kEntries,
      entries.map((e) => jsonEncode(e.toJson())).toList(),
    );
  }
}
