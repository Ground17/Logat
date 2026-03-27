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
          MaterialPageRoute(
            builder: (_) => ManualRecordScreen(
              sharedFilePaths: files.map((f) => f.path).toList(),
            ),
          ),
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
              MaterialPageRoute(
                builder: (_) => ManualRecordScreen(
                  sharedFilePaths: files.map((f) => f.path).toList(),
                ),
              ),
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

  Widget _folderFab() => FloatingActionButton.small(
        heroTag: 'openFolders',
        tooltip: 'Manage Folders',
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const FolderBrowserScreen()),
        ),
        child: const Icon(Icons.folder_outlined),
      );

  Widget? _buildFab(BuildContext context, int logicalTab) {
    switch (logicalTab) {
      case 0: // Loop — folder shortcut only
        return _folderFab();
      case 1: // List
      case 2: // Tile
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _folderFab(),
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
      case 4: // Map
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _folderFab(),
            const SizedBox(height: 8),
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
            tooltip: 'Notification History',
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
                    onPressed: () async {
                      _searchCtrl.clear();
                      _applyFilter(const DiaryFilter(colorFilters: {}));
                      await ref.read(dateRangeFilterProvider.notifier).resetToDefault();
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
                title: const Text('Anniversary Day'),
                subtitle: const Text('100, 200, ... 900, 1000, 2000, ... 10,000 day milestones'),
                value: _filter.isMilestoneDay,
                onChanged: (v) =>
                    _applyFilter(_filter.copyWith(isMilestoneDay: v)),
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
                title: const Text('Has photo'),
                value: _filter.hasPhoto,
                onChanged: (v) =>
                    _applyFilter(_filter.copyWith(hasPhoto: v)),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Has video'),
                value: _filter.hasVideo,
                onChanged: (v) =>
                    _applyFilter(_filter.copyWith(hasVideo: v)),
              ),
              _ColorFilterRow(
                selected: _filter.colorFilters,
                onChanged: (colors) =>
                    _applyFilter(_filter.copyWith(colorFilters: colors)),
              ),
              const Divider(),
              // Date range
              _DateRangeSection(dateRange: dateRange),
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

}

// ─── Color filter row ──────────────────────────────────────────────────────

class _ColorFilterRow extends StatelessWidget {
  const _ColorFilterRow({required this.selected, required this.onChanged});

  final Set<int> selected;
  final void Function(Set<int>) onChanged;

  static const _colors = [
    Color(0xFFBF616A), // Red
    Color(0xFF88C0D0), // Sky
    Color(0xFFEBCB8B), // Yellow
    Color(0xFFA3BE8C), // Green
    Color(0xFF5E81AC), // Blue
    Color(0xFFB48EAD), // Purple
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          const Text('Color', style: TextStyle(fontSize: 14)),
          const SizedBox(width: 12),
          ...(_colors.map((c) {
            final value = c.toARGB32();
            final isSelected = selected.contains(value);
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () {
                  final next = Set<int>.from(selected);
                  if (isSelected) {
                    next.remove(value);
                  } else {
                    next.add(value);
                  }
                  onChanged(next);
                },
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: c,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected
                          ? Theme.of(context).colorScheme.primary
                          : Colors.transparent,
                      width: 2.5,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: c.withValues(alpha: 0.5),
                              blurRadius: 4,
                              spreadRadius: 1,
                            )
                          ]
                        : null,
                  ),
                ),
              ),
            );
          })),
          if (selected.isNotEmpty)
            GestureDetector(
              onTap: () => onChanged(const {}),
              child: const Icon(Icons.clear, size: 18, color: Colors.grey),
            ),
        ],
      ),
    );
  }
}

// ─── Date range section widget ─────────────────────────────────────────────

class _DateRangeSection extends ConsumerStatefulWidget {
  const _DateRangeSection({required this.dateRange});
  final DateRangeFilter dateRange;

  @override
  ConsumerState<_DateRangeSection> createState() => _DateRangeSectionState();
}

class _DateRangeSectionState extends ConsumerState<_DateRangeSection> {
  late bool _isAllTime;
  late bool _isRelative;
  late int _amount;
  late RelativeDateUnit _unit;

  @override
  void initState() {
    super.initState();
    _syncFromWidget(widget.dateRange);
  }

  @override
  void didUpdateWidget(_DateRangeSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.dateRange != widget.dateRange) {
      _syncFromWidget(widget.dateRange);
    }
  }

  void _syncFromWidget(DateRangeFilter dr) {
    _isAllTime = dr.isAllTime;
    _isRelative = dr.isRelative;
    _amount = dr.relativeAmount;
    _unit = dr.relativeUnit;
  }

  void _switchToAllTime() {
    setState(() {
      _isAllTime = true;
      _isRelative = false;
    });
    ref.read(dateRangeFilterProvider.notifier).update(DateRangeFilter.allTime());
    _invalidate();
  }

  void _applyRelative({int? amount, RelativeDateUnit? unit}) {
    final a = amount ?? _amount;
    final u = unit ?? _unit;
    setState(() {
      _isAllTime = false;
      _isRelative = true;
      _amount = a;
      _unit = u;
    });
    final filter = DateRangeFilter.relative(a, u);
    ref.read(dateRangeFilterProvider.notifier).update(filter);
    _invalidate();
  }

  void _switchToAbsolute() async {
    final current = ref.read(dateRangeFilterProvider);
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2010),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDateRange: DateTimeRange(
        start: current.start.toLocal(),
        end: current.end.subtract(const Duration(days: 1)).toLocal(),
      ),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _isAllTime = false;
      _isRelative = false;
    });
    final filter = DateRangeFilter.absolute(
      DateTime.utc(picked.start.year, picked.start.month, picked.start.day),
      DateTime.utc(picked.end.year, picked.end.month, picked.end.day + 1),
    );
    ref.read(dateRangeFilterProvider.notifier).update(filter);
    _invalidate();
  }

  void _invalidate() {
    ref.invalidate(dailyStatsProvider);
    ref.invalidate(mapEventsProvider);
    ref.invalidate(filteredJournalEventsProvider);
    ref.invalidate(tagSummariesProvider);
  }

  Future<void> _saveAsDefault() async {
    final filter = DateRangeFilter.relative(_amount, _unit);
    await filter.saveAsDefault();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Default date range saved as ${_unit.labelFor(_amount)}.'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _pickAmount() async {
    final amounts = [
      for (int i = 1; i <= 30; i++) i,
      45, 60, 90, 180, 365,
    ];
    await showModalBottomSheet(
      context: context,
      builder: (ctx) => ListView.builder(
        itemCount: amounts.length,
        itemBuilder: (_, i) => ListTile(
          title: Text(_unit.labelFor(amounts[i])),
          selected: amounts[i] == _amount,
          onTap: () {
            Navigator.pop(ctx);
            _applyRelative(amount: amounts[i]);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final formatter = DateFormat('yyyy-MM-dd');
    final dateRange = ref.watch(dateRangeFilterProvider);
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.date_range_outlined, size: 20),
            const SizedBox(width: 8),
            const Text('Date range',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
            const Spacer(),
            // Relative / Absolute / All time segmented control
            _ModeChip(
              label: 'All Time',
              selected: _isAllTime,
              onTap: _switchToAllTime,
            ),
            const SizedBox(width: 6),
            _ModeChip(
              label: 'Relative',
              selected: !_isAllTime && _isRelative,
              onTap: () {
                if (_isAllTime || !_isRelative) _applyRelative();
              },
            ),
            const SizedBox(width: 6),
            _ModeChip(
              label: 'Absolute',
              selected: !_isAllTime && !_isRelative,
              onTap: _switchToAbsolute,
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_isAllTime) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text(
              'All time',
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ] else if (_isRelative) ...[
          Row(
            children: [
              // Amount selector
              GestureDetector(
                onTap: _pickAmount,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: primaryColor.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    '$_amount',
                    style: TextStyle(
                        color: primaryColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 15),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Unit selector
              ...RelativeDateUnit.values.map((u) => Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: _ModeChip(
                      label: u.label,
                      selected: _unit == u,
                      onTap: () => _applyRelative(unit: u),
                    ),
                  )),
              const Spacer(),
              // Save as default
              TextButton(
                style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    minimumSize: Size.zero),
                onPressed: _saveAsDefault,
                child: const Text('Save as default',
                    style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${formatter.format(dateRange.start)} ~ ${formatter.format(dateRange.end.subtract(const Duration(days: 1)))}',
            style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 12),
          ),
        ] else ...[
          GestureDetector(
            onTap: _switchToAbsolute,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: primaryColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border:
                    Border.all(color: primaryColor.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${formatter.format(dateRange.start)}  ~  ${formatter.format(dateRange.end.subtract(const Duration(days: 1)))}',
                    style: TextStyle(color: primaryColor, fontSize: 13),
                  ),
                  const SizedBox(width: 6),
                  Icon(Icons.edit_calendar_outlined,
                      size: 16, color: primaryColor),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 4),
      ],
    );
  }
}

class _ModeChip extends StatelessWidget {
  const _ModeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: selected ? color : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: selected ? 1 : 0.4)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : color,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
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
      title: Text(selectedFolder?.name ?? 'All Folders'),
      subtitle: const Text('Folder Filter'),
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
              title: const Text('All Folders'),
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
