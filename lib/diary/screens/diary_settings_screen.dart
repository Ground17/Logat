import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/notification_settings.dart';
import '../models/recommendation_settings.dart';
import '../providers/diary_providers.dart';
import '../services/memories_notification_service.dart';

class DiarySettingsScreen extends ConsumerWidget {
  const DiarySettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(recommendationSettingsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Diary Settings')),
      body: ListView(
        children: [
          // ── AI 추천 섹션 ─────────────────────────────────────────────
          _SectionHeader(title: 'AI Diary Recommendations'),
          SwitchListTile(
            title: const Text('Enable AI Recommendations'),
            subtitle: const Text(
                'AI suggests diary topics based on recent photos, frequent locations, and on-this-day memories'),
            value: settings.enabled,
            onChanged: (v) => _update(ref, settings.copyWith(enabled: v)),
          ),
          if (settings.enabled) ...[
            ListTile(
              title: const Text('AI Model'),
              subtitle: Text(settings.model.displayName),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _pickModel(context, ref, settings),
            ),
            ListTile(
              title: const Text('Format'),
              subtitle: Text(settings.format.displayName),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _pickFormat(context, ref, settings),
            ),
            ListTile(
              title: const Text('Style Instruction'),
              subtitle: Text(
                settings.promptStyle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: const Icon(Icons.edit_outlined),
              onTap: () => _editPromptStyle(context, ref, settings),
            ),
          ],

          const Divider(),

          // ── AI 추천 알림 ──────────────────────────────────────────────
          if (settings.enabled) ...[
            _SectionHeader(title: 'AI Recommendation Notifications'),
            SwitchListTile(
              title: const Text('Daily Recommendations'),
              subtitle:
                  const Text('Get diary suggestions at the scheduled time'),
              value: settings.notificationEnabled,
              onChanged: (v) async {
                final updated = settings.copyWith(notificationEnabled: v);
                _update(ref, updated);
                final svc = ref.read(memoriesNotificationServiceProvider);
                if (v) {
                  await svc.scheduleDaily(
                    hour: settings.notificationHour,
                    minute: settings.notificationMinute,
                  );
                } else {
                  await svc.cancelDaily();
                }
              },
            ),
            if (settings.notificationEnabled)
              ListTile(
                leading: const Icon(Icons.access_time),
                title: const Text('Notification Time'),
                trailing: Text(
                  '${settings.notificationHour.toString().padLeft(2, '0')}:${settings.notificationMinute.toString().padLeft(2, '0')}',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                onTap: () => _pickNotifTime(context, ref, settings),
              ),
            const Divider(),
          ],

          // ── On This Day notifications ──────────────────────────────────
          _SectionHeader(title: 'On This Day Notifications'),
          const _MemoriesNotificationSection(),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  void _update(WidgetRef ref, RecommendationSettings settings) {
    ref.read(recommendationSettingsProvider.notifier).update(settings);
  }

  Future<void> _pickModel(
    BuildContext context,
    WidgetRef ref,
    RecommendationSettings settings,
  ) async {
    final result = await showDialog<RecommendationModel>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Select AI Model'),
        children: RecommendationModel.values
            .map(
              (m) => ListTile(
                title: Text(m.displayName),
                leading: Icon(
                  m == settings.model
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  color: m == settings.model
                      ? Theme.of(ctx).colorScheme.primary
                      : null,
                ),
                onTap: () => Navigator.pop(ctx, m),
              ),
            )
            .toList(),
      ),
    );
    if (result != null) _update(ref, settings.copyWith(model: result));
  }

  Future<void> _pickFormat(
    BuildContext context,
    WidgetRef ref,
    RecommendationSettings settings,
  ) async {
    final result = await showDialog<RecommendationFormat>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Select Format'),
        children: RecommendationFormat.values
            .map(
              (f) => ListTile(
                title: Text(f.displayName),
                subtitle: Text(f.instruction),
                leading: Icon(
                  f == settings.format
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  color: f == settings.format
                      ? Theme.of(ctx).colorScheme.primary
                      : null,
                ),
                onTap: () => Navigator.pop(ctx, f),
              ),
            )
            .toList(),
      ),
    );
    if (result != null) _update(ref, settings.copyWith(format: result));
  }

  Future<void> _editPromptStyle(
    BuildContext context,
    WidgetRef ref,
    RecommendationSettings settings,
  ) async {
    final ctrl = TextEditingController(text: settings.promptStyle);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Style Instruction'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Write a style instruction to pass directly to the AI.',
              style: Theme.of(ctx).textTheme.bodySmall,
            ),
            const SizedBox(height: 4),
            Text(
              'e.g. "In a warm and emotional tone", "Short and witty", "In a poetic style"',
              style: Theme.of(ctx)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Colors.black45),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              maxLines: 4,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Enter style instruction...',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (result != null && result.trim().isNotEmpty) {
      _update(ref, settings.copyWith(promptStyle: result.trim()));
    }
  }

  Future<void> _pickNotifTime(
    BuildContext context,
    WidgetRef ref,
    RecommendationSettings settings,
  ) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: settings.notificationHour,
        minute: settings.notificationMinute,
      ),
    );
    if (picked == null) return;
    final updated = settings.copyWith(
      notificationHour: picked.hour,
      notificationMinute: picked.minute,
    );
    _update(ref, updated);
    if (updated.notificationEnabled) {
      await ref.read(memoriesNotificationServiceProvider).scheduleDaily(
            hour: picked.hour,
            minute: picked.minute,
          );
    }
  }
}

// ─── Section header ────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

// ─── On This Day notifications section ─────────────────────────────────────

class _MemoriesNotificationSection extends StatefulWidget {
  const _MemoriesNotificationSection();

  @override
  State<_MemoriesNotificationSection> createState() =>
      _MemoriesNotificationSectionState();
}

class _MemoriesNotificationSectionState
    extends State<_MemoriesNotificationSection> {
  MemoriesNotificationSettings _settings =
      const MemoriesNotificationSettings();
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final settings = await MemoriesNotificationSettings.load();
    if (mounted) {
      setState(() {
        _settings = settings;
        _loaded = true;
      });
    }
  }

  Future<void> _save(MemoriesNotificationSettings settings) async {
    setState(() => _settings = settings);
    await settings.save();
    final svc = MemoriesNotificationService();
    await svc.schedule(settings);
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const LinearProgressIndicator();

    return Column(
      children: [
        SwitchListTile(
          title: const Text('On This Day'),
          subtitle: const Text(
              'Get daily reminders of past memories from today in previous years'),
          value: _settings.enabled,
          onChanged: (v) => _save(_settings.copyWith(enabled: v)),
        ),
        if (_settings.enabled) ...[
          ListTile(
            leading: const Icon(Icons.access_time),
            title: const Text('Notification Time'),
            trailing: Text(
              '${_settings.hour.toString().padLeft(2, '0')}:${_settings.minute.toString().padLeft(2, '0')}',
            ),
            onTap: () async {
              final picked = await showTimePicker(
                context: context,
                initialTime:
                    TimeOfDay(hour: _settings.hour, minute: _settings.minute),
              );
              if (picked != null) {
                _save(_settings.copyWith(
                    hour: picked.hour, minute: picked.minute));
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.repeat),
            title: const Text('Schedule'),
            trailing: Text(
              _scheduleLabel(_settings),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            onTap: () => _pickSchedule(context),
          ),
          SwitchListTile(
            title: const Text('N years ago today'),
            subtitle: const Text(
                'Include year info in notification (e.g. "3 years ago today")'),
            value: _settings.onThisDayEnabled,
            onChanged: (v) =>
                _save(_settings.copyWith(onThisDayEnabled: v)),
          ),
          ListTile(
            leading: const Icon(Icons.title),
            title: const Text('Notification title'),
            subtitle: Text(_settings.notificationTitle),
            trailing: const Icon(Icons.edit_outlined),
            onTap: () => _editText(
              context,
              label: 'Notification Title',
              initial: _settings.notificationTitle,
              onSave: (v) => _save(_settings.copyWith(notificationTitle: v)),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.message_outlined),
            title: const Text('Notification body'),
            subtitle: Text(
              _settings.notificationBody,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: const Icon(Icons.edit_outlined),
            onTap: () => _editText(
              context,
              label: 'Notification Body',
              initial: _settings.notificationBody,
              onSave: (v) => _save(_settings.copyWith(notificationBody: v)),
              maxLines: 3,
            ),
          ),
        ],
      ],
    );
  }

  String _scheduleLabel(MemoriesNotificationSettings s) {
    switch (s.scheduleType) {
      case NotificationScheduleType.daily:
        return 'Daily';
      case NotificationScheduleType.everyNDays:
        return 'Every ${s.intervalDays} days';
      case NotificationScheduleType.weekdays:
        final dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
        final selected = s.weekdays.toList()..sort();
        return selected.map((d) => dayNames[d - 1]).join(', ');
    }
  }

  Future<void> _pickSchedule(BuildContext context) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _SchedulePickerSheet(
        settings: _settings,
        onChanged: _save,
      ),
    );
  }

  Future<void> _editText(
    BuildContext context, {
    required String label,
    required String initial,
    required void Function(String) onSave,
    int maxLines = 1,
  }) async {
    final ctrl = TextEditingController(text: initial);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(label),
        content: TextField(
          controller: ctrl,
          maxLines: maxLines,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (result != null && result.trim().isNotEmpty) onSave(result.trim());
  }
}

// ─── Schedule picker sheet ─────────────────────────────────────────────────

class _SchedulePickerSheet extends StatefulWidget {
  const _SchedulePickerSheet({
    required this.settings,
    required this.onChanged,
  });

  final MemoriesNotificationSettings settings;
  final void Function(MemoriesNotificationSettings) onChanged;

  @override
  State<_SchedulePickerSheet> createState() => _SchedulePickerSheetState();
}

class _SchedulePickerSheetState extends State<_SchedulePickerSheet> {
  late MemoriesNotificationSettings _s;
  late TextEditingController _intervalCtrl;

  static const _dayNames = [
    'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'
  ];

  @override
  void initState() {
    super.initState();
    _s = widget.settings;
    _intervalCtrl =
        TextEditingController(text: _s.intervalDays.toString());
  }

  @override
  void dispose() {
    _intervalCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Schedule',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            // Schedule type
            SegmentedButton<NotificationScheduleType>(
              segments: const [
                ButtonSegment(
                  value: NotificationScheduleType.daily,
                  label: Text('Daily'),
                ),
                ButtonSegment(
                  value: NotificationScheduleType.everyNDays,
                  label: Text('Every N days'),
                ),
                ButtonSegment(
                  value: NotificationScheduleType.weekdays,
                  label: Text('Weekdays'),
                ),
              ],
              selected: {_s.scheduleType},
              onSelectionChanged: (v) {
                setState(() => _s = _s.copyWith(scheduleType: v.first));
              },
            ),
            const SizedBox(height: 16),
            if (_s.scheduleType == NotificationScheduleType.everyNDays) ...[
              Row(
                children: [
                  const Text('Repeat every '),
                  SizedBox(
                    width: 60,
                    child: TextField(
                      controller: _intervalCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      onChanged: (v) {
                        final n = int.tryParse(v);
                        if (n != null && n > 0) {
                          setState(() => _s = _s.copyWith(intervalDays: n));
                        }
                      },
                    ),
                  ),
                  const Text(' days'),
                ],
              ),
            ],
            if (_s.scheduleType == NotificationScheduleType.weekdays) ...[
              const Text('Select days:'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: List.generate(7, (i) {
                  final day = i + 1;
                  final selected = _s.weekdays.contains(day);
                  return FilterChip(
                    label: Text(_dayNames[i]),
                    selected: selected,
                    onSelected: (v) {
                      final newDays = Set<int>.from(_s.weekdays);
                      if (v) {
                        newDays.add(day);
                      } else {
                        newDays.remove(day);
                      }
                      setState(
                          () => _s = _s.copyWith(weekdays: newDays));
                    },
                  );
                }),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    widget.onChanged(_s);
                    Navigator.pop(context);
                  },
                  child: const Text('Save'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
