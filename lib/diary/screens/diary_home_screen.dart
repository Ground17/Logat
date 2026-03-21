import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import 'package:location/location.dart';

import '../database/app_database.dart';
import '../models/date_range_filter.dart';
import '../models/diary_filter.dart';
import '../models/location_filter.dart';
import '../models/notification_settings.dart';
import '../providers/diary_providers.dart';
import '../services/memories_notification_service.dart';
import 'activity_screen.dart';
import 'diary_settings_screen.dart';
import 'folder_browser_screen.dart';
import 'manual_record_screen.dart';
import 'radius_picker_screen.dart';
import 'recap_screen.dart';

class DiaryHomeScreen extends ConsumerStatefulWidget {
  const DiaryHomeScreen({super.key});

  @override
  ConsumerState<DiaryHomeScreen> createState() => _DiaryHomeScreenState();
}

class _DiaryHomeScreenState extends ConsumerState<DiaryHomeScreen> {
  int _index = 0;
  bool _initialTabChecked = false;

  Future<void> _createTopLevelFolder() async {
    final ctrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New Folder'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Create'),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    try {
      final folderId = 'folder_${DateTime.now().millisecondsSinceEpoch}';
      await ref.read(appDatabaseProvider).insertFolder(
            folderId: folderId,
            name: name,
          );
      ref.invalidate(folderListProvider(null));
    } on FolderDepthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<void> _goToMyLocation() async {
    try {
      final loc = Location();
      final data = await loc.getLocation();
      final controller = ref.read(mapControllerProvider);
      if (data.latitude != null && data.longitude != null && controller != null) {
        await controller.animateCamera(
          CameraUpdate.newLatLng(LatLng(data.latitude!, data.longitude!)),
        );
      }
    } catch (_) {}
  }

  static const _tabTitles = ['Journal', 'Activity', 'Folders'];

  static const _screens = [
    RecapScreen(),
    ActivityScreen(),
    FolderBrowserScreen(isEmbedded: true),
  ];

  @override
  Widget build(BuildContext context) {
    final viewMode = ref.watch(diaryViewModeProvider);

    // Navigate to a specific tab when requested by a child widget (e.g. activity screen)
    ref.listen(pendingTabProvider, (_, next) {
      if (next != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() => _index = next);
            ref.read(pendingTabProvider.notifier).state = null;
          }
        });
      }
    });

    // Switch to Activity tab on first data load if no photos have been indexed
    if (!_initialTabChecked) {
      ref.watch(indexedAssetCountProvider).whenData((count) {
        _initialTabChecked = true;
        if (count == 0 && _index == 0) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _index = 1);
          });
        }
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_tabTitles[_index]),
        actions: [
          if (_index == 0) ...[
            IconButton(
              icon: const Icon(Icons.filter_list_outlined),
              tooltip: 'Filter',
              onPressed: () => _showFilterSheet(context),
            ),
            IconButton(
              icon: Icon(
                viewMode == DiaryViewMode.map
                    ? Icons.list_outlined
                    : Icons.map_outlined,
              ),
              tooltip: viewMode == DiaryViewMode.map ? 'List view' : 'Map view',
              onPressed: () => ref
                  .read(diaryViewModeProvider.notifier)
                  .setMode(viewMode == DiaryViewMode.map
                      ? DiaryViewMode.list
                      : DiaryViewMode.map),
            ),
          ],
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            tooltip: 'Notification settings',
            onPressed: () => _showNotificationSheet(context),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const DiarySettingsScreen(),
              ),
            ),
          ),
        ],
      ),
      body: IndexedStack(
        index: _index,
        children: _screens,
      ),
      floatingActionButton: _index == 2
          ? FloatingActionButton(
              heroTag: 'createFolder',
              onPressed: _createTopLevelFolder,
              tooltip: 'New folder',
              child: const Icon(Icons.create_new_folder_outlined),
            )
          : _index == 0 && viewMode == DiaryViewMode.map
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FloatingActionButton.small(
                      heroTag: 'mapMyLocation',
                      onPressed: _goToMyLocation,
                      child: const Icon(Icons.my_location),
                    ),
                    const SizedBox(height: 8),
                    FloatingActionButton(
                      heroTag: 'addDiaryEntry',
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const ManualRecordScreen()),
                      ),
                      child: const Icon(Icons.add),
                    ),
                  ],
                )
              : FloatingActionButton(
                  heroTag: 'addDiaryEntry',
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const ManualRecordScreen()),
                  ),
                  child: const Icon(Icons.add),
                ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) {
          setState(() {
            _index = value;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.auto_stories_outlined),
            selectedIcon: Icon(Icons.auto_stories),
            label: 'Journal',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart),
            label: 'Activity',
          ),
          NavigationDestination(
            icon: Icon(Icons.folder_outlined),
            selectedIcon: Icon(Icons.folder),
            label: 'Folders',
          ),
        ],
      ),
    );
  }

  Future<void> _showFilterSheet(BuildContext context) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => const _FilterSheet(),
    );
  }

  Future<void> _showNotificationSheet(BuildContext context) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => const _NotificationSheet(),
    );
  }
}

// ─── Filter bottom sheet ──────────────────────────────────────────────────

class _FilterSheet extends ConsumerStatefulWidget {
  const _FilterSheet();

  @override
  ConsumerState<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends ConsumerState<_FilterSheet> {
  late TextEditingController _searchCtrl;
  late DiaryFilter _filter;

  @override
  void initState() {
    super.initState();
    _filter = ref.read(diaryFilterProvider);
    _searchCtrl = TextEditingController(text: _filter.searchText);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _applyFilter(DiaryFilter filter) {
    setState(() => _filter = filter);
    ref.read(diaryFilterProvider.notifier).update(filter);
  }

  @override
  Widget build(BuildContext context) {
    final dateRange = ref.watch(dateRangeFilterProvider);
    final selectedLocation = ref.watch(locationFilterProvider);
    final selectedDate = ref.watch(selectedDateProvider);
    final formatter = DateFormat('yyyy-MM-dd');

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                children: [
                  const Text(
                    'Filter',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () {
                      _searchCtrl.clear();
                      _applyFilter(const DiaryFilter());
                      ref.read(dateRangeFilterProvider.notifier).update(
                          _defaultDateRange());
                      ref.read(locationFilterProvider.notifier).state = null;
                      ref.invalidate(mapEventsProvider);
                      ref.invalidate(filteredJournalEventsProvider);
                    },
                    child: const Text('Reset'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Search text
              TextField(
                controller: _searchCtrl,
                decoration: const InputDecoration(
                  labelText: 'Search',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                ),
                onChanged: (v) => _applyFilter(
                    _filter.copyWith(searchText: v)),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Similar date (±7 days)'),
                subtitle: Text(
                    'Around ${formatter.format(selectedDate.toLocal())}'),
                value: _filter.similarDate,
                onChanged: (v) =>
                    _applyFilter(_filter.copyWith(similarDate: v)),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Favorites only'),
                value: _filter.favoritesOnly,
                onChanged: (v) =>
                    _applyFilter(_filter.copyWith(favoritesOnly: v)),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Has location'),
                value: _filter.hasLocation,
                onChanged: (v) =>
                    _applyFilter(_filter.copyWith(hasLocation: v)),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Has photo / video'),
                value: _filter.hasMedia,
                onChanged: (v) =>
                    _applyFilter(_filter.copyWith(hasMedia: v)),
              ),
              const Divider(),
              // Date range
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.date_range_outlined),
                title: Text(
                  '${formatter.format(dateRange.start)} ~ ${formatter.format(dateRange.end.subtract(const Duration(days: 1)))}',
                ),
                subtitle: const Text('Date range'),
                onTap: () => _pickDateRange(context, ref, dateRange),
              ),
              // Location filter
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.my_location),
                title: Text(
                    selectedLocation?.label ?? 'All locations'),
                subtitle: const Text('Location filter'),
                trailing: selectedLocation != null
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          ref.read(locationFilterProvider.notifier).state =
                              null;
                          ref.invalidate(mapEventsProvider);
                          ref.invalidate(filteredJournalEventsProvider);
                        },
                      )
                    : const Icon(Icons.chevron_right),
                onTap: () async {
                  final result = await Navigator.push<dynamic>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => RadiusPickerScreen(
                        initialFilter: selectedLocation,
                      ),
                    ),
                  );
                  if (result != null) {
                    ref.read(locationFilterProvider.notifier).state =
                        result as LocationFilter;
                    ref.invalidate(mapEventsProvider);
                    ref.invalidate(filteredJournalEventsProvider);
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  DateRangeFilter _defaultDateRange() {
    final now = DateTime.now().toUtc();
    return DateRangeFilter(
      start: DateTime.utc(now.year, now.month - 1, now.day),
      end: DateTime.utc(now.year, now.month, now.day + 1),
    );
  }

  Future<void> _pickDateRange(
    BuildContext context,
    WidgetRef ref,
    DateRangeFilter current,
  ) async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2010),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDateRange: DateTimeRange(
        start: current.start.toLocal(),
        end: current.end.subtract(const Duration(days: 1)).toLocal(),
      ),
    );
    if (picked == null) return;
    ref.read(dateRangeFilterProvider.notifier).update(DateRangeFilter(
      start:
          DateTime.utc(picked.start.year, picked.start.month, picked.start.day),
      end: DateTime.utc(picked.end.year, picked.end.month, picked.end.day + 1),
    ));
    ref.invalidate(dailyStatsProvider);
    ref.invalidate(mapEventsProvider);
    ref.invalidate(filteredJournalEventsProvider);
    ref.invalidate(tagSummariesProvider);
  }
}

// ─── Notification settings sheet ──────────────────────────────────────────

class _NotificationSheet extends ConsumerStatefulWidget {
  const _NotificationSheet();

  @override
  ConsumerState<_NotificationSheet> createState() => _NotificationSheetState();
}

class _NotificationSheetState extends ConsumerState<_NotificationSheet> {
  MemoriesNotificationSettings _memoriesSettings =
      const MemoriesNotificationSettings();
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    MemoriesNotificationSettings.load().then((s) {
      if (mounted) setState(() { _memoriesSettings = s; _loaded = true; });
    });
  }

  Future<void> _saveMemories(MemoriesNotificationSettings s) async {
    setState(() => _memoriesSettings = s);
    await s.save();
    await MemoriesNotificationService().schedule(s);
  }

  @override
  Widget build(BuildContext context) {
    final recSettings = ref.watch(recommendationSettingsProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.4,
      maxChildSize: 0.85,
      expand: false,
      builder: (ctx, scrollCtrl) => SafeArea(
        child: ListView(
          controller: scrollCtrl,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const Text(
              'Notifications',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),

            // ── On This Day ──────────────────────────────────────────
            const Text('On This Day',
                style: TextStyle(fontWeight: FontWeight.w500)),
            if (!_loaded) const LinearProgressIndicator()
            else ...[
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Enable'),
                subtitle: const Text('Reminders from past memories'),
                value: _memoriesSettings.enabled,
                onChanged: (v) => _saveMemories(_memoriesSettings.copyWith(enabled: v)),
              ),
              if (_memoriesSettings.enabled)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.access_time),
                  title: const Text('Time'),
                  trailing: Text(
                    '${_memoriesSettings.hour.toString().padLeft(2,'0')}:'
                    '${_memoriesSettings.minute.toString().padLeft(2,'0')}',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  onTap: () async {
                    final picked = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay(
                        hour: _memoriesSettings.hour,
                        minute: _memoriesSettings.minute,
                      ),
                    );
                    if (picked != null) {
                      _saveMemories(_memoriesSettings.copyWith(
                        hour: picked.hour,
                        minute: picked.minute,
                      ));
                    }
                  },
                ),
            ],

            const Divider(height: 24),

            // ── AI Recommendations ───────────────────────────────────
            const Text('AI Recommendations',
                style: TextStyle(fontWeight: FontWeight.w500)),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Enable notifications'),
              subtitle: const Text('Daily diary topic suggestions'),
              value: recSettings.enabled && recSettings.notificationEnabled,
              onChanged: recSettings.enabled
                  ? (v) async {
                      final updated = recSettings.copyWith(notificationEnabled: v);
                      ref.read(recommendationSettingsProvider.notifier).update(updated);
                      final svc = ref.read(memoriesNotificationServiceProvider);
                      if (v) {
                        await svc.scheduleDaily(
                          hour: recSettings.notificationHour,
                          minute: recSettings.notificationMinute,
                        );
                      } else {
                        await svc.cancelDaily();
                      }
                    }
                  : null,
            ),
            if (!recSettings.enabled)
              Padding(
                padding: const EdgeInsets.only(left: 16, bottom: 8),
                child: Text(
                  'Enable AI Recommendations in Settings to configure this',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: Colors.grey),
                ),
              ),
            if (recSettings.enabled && recSettings.notificationEnabled)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.access_time),
                title: const Text('Time'),
                trailing: Text(
                  '${recSettings.notificationHour.toString().padLeft(2,'0')}:'
                  '${recSettings.notificationMinute.toString().padLeft(2,'0')}',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                onTap: () async {
                  final picked = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay(
                      hour: recSettings.notificationHour,
                      minute: recSettings.notificationMinute,
                    ),
                  );
                  if (picked == null) return;
                  final updated = recSettings.copyWith(
                    notificationHour: picked.hour,
                    notificationMinute: picked.minute,
                  );
                  ref.read(recommendationSettingsProvider.notifier).update(updated);
                  if (updated.notificationEnabled) {
                    await ref.read(memoriesNotificationServiceProvider).scheduleDaily(
                      hour: picked.hour,
                      minute: picked.minute,
                    );
                  }
                },
              ),
          const Divider(height: 24),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.tune_outlined),
            title: const Text('More notification settings'),
            subtitle: const Text(
                'Schedule, frequency, notification text…'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 14),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const DiarySettingsScreen(),
                ),
              );
            },
          ),
          ],
        ),
      ),
    );
  }
}
