import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import 'package:location/location.dart';

import '../models/date_range_filter.dart';
import '../models/diary_filter.dart';
import '../models/folder.dart';
import '../models/location_filter.dart';
import '../providers/diary_providers.dart';
import 'activity_screen.dart';
import 'diary_settings_screen.dart';
import 'notification_history_screen.dart';
import 'event_map_screen.dart';
import 'folder_browser_screen.dart';
import 'manual_record_screen.dart';
import 'memory_reel_view.dart';
import 'photo_grid_screen.dart';
import 'radius_picker_screen.dart';
import 'recap_screen.dart';
import 'tab_order_settings_screen.dart';

class DiaryHomeScreen extends ConsumerStatefulWidget {
  const DiaryHomeScreen({super.key});

  @override
  ConsumerState<DiaryHomeScreen> createState() => _DiaryHomeScreenState();
}

class _DiaryHomeScreenState extends ConsumerState<DiaryHomeScreen> {
  int _index = 0;
  late StreamSubscription _intentSub;

  @override
  void initState() {
    super.initState();
    _intentSub =
        ReceiveSharingIntent.instance.getMediaStream().listen((files) {
      if (files.isNotEmpty && mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ManualRecordScreen()),
        );
      }
    });
    ReceiveSharingIntent.instance.getInitialMedia().then((files) {
      ReceiveSharingIntent.instance.reset();
      if (files.isNotEmpty && mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ManualRecordScreen()),
            );
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _intentSub.cancel();
    super.dispose();
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

  Widget? _buildFab(BuildContext context, int logicalTab) {
    switch (logicalTab) {
      case 0: // Loop — folder shortcut
        return FloatingActionButton.small(
          heroTag: 'openFolders',
          tooltip: '폴더 관리',
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const FolderBrowserScreen()),
          ),
          child: const Icon(Icons.folder_outlined),
        );
      case 1: // List
      case 2: // Grid
        return FloatingActionButton(
          heroTag: 'addDiaryEntry',
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ManualRecordScreen()),
          ),
          child: const Icon(Icons.add),
        );
      case 4: // Map
        return Column(
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
                MaterialPageRoute(builder: (_) => const ManualRecordScreen()),
              ),
              child: const Icon(Icons.add),
            ),
          ],
        );
      default:
        return null;
    }
  }

  static const Map<int, IconData> _tabSelectedIcons = {
    0: Icons.loop,
    1: Icons.auto_stories,
    2: Icons.grid_view,
    3: Icons.bar_chart,
    4: Icons.map,
  };

  static final Map<int, Widget> _tabScreens = {
    0: const MemoryLoopView(),
    1: const JournalListScreen(),
    2: const PhotoGridScreen(),
    3: const ActivityScreen(),
    4: const EventMapScreen(key: ValueKey('home_map')),
  };

  @override
  Widget build(BuildContext context) {
    final tabOrder = ref.watch(tabOrderProvider);
    final logicalTab = tabOrder[_index.clamp(0, tabOrder.length - 1)];

    // Navigate to a specific tab when requested by a child widget
    // pendingTabProvider stores logical tab ID
    ref.listen(pendingTabProvider, (_, next) {
      if (next != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            final pos = tabOrder.indexOf(next);
            setState(() => _index = pos >= 0 ? pos : 0);
            ref.read(pendingTabProvider.notifier).state = null;
          }
        });
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: Text(kTabLabels[logicalTab] ?? ''),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list_outlined),
            tooltip: 'Filter',
            onPressed: () => _showFilterSheet(context),
          ),
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            tooltip: '알림 내역',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const NotificationHistoryScreen()),
            ),
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
        children: tabOrder
            .map((id) => _tabScreens[id] ?? const SizedBox.shrink())
            .toList(),
      ),
      floatingActionButton: _buildFab(context, logicalTab),
      bottomNavigationBar: NavigationBar(
        height: 60,
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: tabOrder.map((id) {
          return NavigationDestination(
            icon: Icon(kTabIcons[id]),
            selectedIcon: Icon(_tabSelectedIcons[id] ?? kTabIcons[id]!),
            label: kTabLabels[id] ?? '',
          );
        }).toList(),
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
                      ref.read(selectedFolderFilterProvider.notifier).state =
                          null;
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
              // Folder filter
              _FolderFilterTile(
                onFolderSelected: (folder) {
                  ref.read(selectedFolderFilterProvider.notifier).state =
                      folder;
                  ref.invalidate(filteredJournalEventsProvider);
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


// ─── Folder filter tile ────────────────────────────────────────────────────

class _FolderFilterTile extends ConsumerWidget {
  const _FolderFilterTile({required this.onFolderSelected});

  final void Function(DiaryFolder?) onFolderSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedFolder = ref.watch(selectedFolderFilterProvider);

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.folder_outlined),
      title: Text(selectedFolder?.name ?? '모든 폴더'),
      subtitle: const Text('폴더 필터'),
      trailing: selectedFolder != null
          ? IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () => onFolderSelected(null),
            )
          : const Icon(Icons.chevron_right),
      onTap: () => _pickFolder(context, ref),
    );
  }

  void _pickFolder(BuildContext context, WidgetRef ref) {
    final folders = ref.read(allFoldersProvider).valueOrNull ?? [];
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(
              leading: const Icon(Icons.folder_off_outlined),
              title: const Text('모든 폴더'),
              onTap: () {
                onFolderSelected(null);
                Navigator.pop(ctx);
              },
            ),
            ...folders.map(
              (f) => ListTile(
                leading: const Icon(Icons.folder_outlined),
                title: Text(f.name),
                onTap: () {
                  onFolderSelected(f);
                  Navigator.pop(ctx);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
