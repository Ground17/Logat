import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/app_database.dart';
import '../models/diary_notification_settings.dart';
import '../models/hundred_days_notif_settings.dart';
import '../services/diary_notification_manager.dart';
import '../services/hundred_days_notification_service.dart';

class DiaryNotificationSettingsScreen extends ConsumerStatefulWidget {
  const DiaryNotificationSettingsScreen({super.key});

  @override
  ConsumerState<DiaryNotificationSettingsScreen> createState() =>
      _DiaryNotificationSettingsScreenState();
}

class _DiaryNotificationSettingsScreenState
    extends ConsumerState<DiaryNotificationSettingsScreen> {
  OnThisDayNotifSettings _otd = const OnThisDayNotifSettings();
  HundredDaysNotifSettings _hd = const HundredDaysNotifSettings();
  List<PeriodicNotifRule> _rules = [];
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final settings = await DiaryNotificationSettings.load();
    if (mounted) {
      setState(() {
        _otd = settings.onThisDay;
        _hd = settings.hundredDays;
        _rules = List.from(settings.periodicRules);
        _loaded = true;
      });
    }
  }

  Future<void> _saveOtd(OnThisDayNotifSettings s) async {
    setState(() => _otd = s);
    await s.save();
    await DiaryNotificationManager.instance.scheduleOnThisDay(s);
  }

  Future<void> _saveHd(HundredDaysNotifSettings s) async {
    setState(() => _hd = s);
    await s.save();
    // Recompute milestones and reschedule immediately on change
    List<HundredDaysMilestone> milestones = [];
    if (s.enabled) {
      final db = AppDatabase();
      try {
        final now = DateTime.now().toUtc();
        final events = await db.queryEventsInRange(
          start: DateTime.utc(now.year - 10, 1, 1),
          end: now.add(const Duration(days: 1)),
        );
        milestones = HundredDaysNotificationService.computeUpcomingMilestones(
          events: events,
          settings: s,
          now: DateTime.now(),
        );
      } finally {
        await db.close();
      }
    }
    await DiaryNotificationManager.instance.scheduleHundredDays(s, milestones);
  }

  Future<void> _saveRule(int idx, PeriodicNotifRule rule) async {
    final updated = List<PeriodicNotifRule>.from(_rules);
    updated[idx] = rule;
    setState(() => _rules = updated);
    await rule.save();
    await DiaryNotificationManager.instance.schedulePeriodicRule(idx, rule);
  }

  Future<void> _addRule() async {
    if (_rules.length >= 5) return;
    final newId = _rules.length;
    final rule = PeriodicNotifRule(id: newId);
    setState(() => _rules.add(rule));
    await rule.save();
    await PeriodicNotifRule.saveCount(_rules.length);
  }

  Future<void> _deleteRule(int idx) async {
    // Cancel notifications for all rules from idx onward (IDs will shift)
    for (var i = idx; i < _rules.length; i++) {
      await DiaryNotificationManager.instance.cancelPeriodicRule(i);
    }
    // Shift rules down with re-indexed IDs
    final source = List<PeriodicNotifRule>.from(_rules)..removeAt(idx);
    final reindexed = [
      for (var i = 0; i < source.length; i++)
        PeriodicNotifRule(
          id: i,
          label: source[i].label,
          subtitle: source[i].subtitle,
          enabled: source[i].enabled,
          scheduleType: source[i].scheduleType,
          hour: source[i].hour,
          minute: source[i].minute,
          intervalDays: source[i].intervalDays,
          weekdays: source[i].weekdays,
          useAi: source[i].useAi,
          aiFormat: source[i].aiFormat,
          aiPromptStyle: source[i].aiPromptStyle,
        ),
    ];
    for (var i = 0; i < reindexed.length; i++) {
      await reindexed[i].save();
      await DiaryNotificationManager.instance
          .schedulePeriodicRule(i, reindexed[i]);
    }
    await PeriodicNotifRule.saveCount(reindexed.length);
    setState(() => _rules = reindexed);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notification Settings')),
      body: _loaded
          ? ListView(
              children: [
                _SectionHeader(title: 'On This Day'),
                _buildOtdSection(),
                const Divider(),
                _SectionHeader(title: 'N×100 Day Milestones'),
                _buildHundredDaysSection(),
                const Divider(),
                _SectionHeader(title: 'Periodic Reminders'),
                _buildPeriodicSection(),
                const SizedBox(height: 32),
              ],
            )
          : const LinearProgressIndicator(),
    );
  }

  // ── On This Day section ───────────────────────────────────────────────────

  Widget _buildOtdSection() {
    return Column(
      children: [
        SwitchListTile(
          title: const Text('On This Day'),
          subtitle: const Text('Reminders of memories from past years'),
          value: _otd.enabled,
          onChanged: (v) => _saveOtd(_otd.copyWith(enabled: v)),
        ),
        if (_otd.enabled) ...[
          ListTile(
            leading: const Icon(Icons.access_time),
            title: const Text('Time'),
            subtitle: const Text('Notifies only on days with past memories'),
            trailing: Text(
              '${_otd.hour.toString().padLeft(2, '0')}:${_otd.minute.toString().padLeft(2, '0')}',
            ),
            onTap: () async {
              final picked = await showTimePicker(
                context: context,
                initialTime: TimeOfDay(hour: _otd.hour, minute: _otd.minute),
              );
              if (picked != null) {
                _saveOtd(
                    _otd.copyWith(hour: picked.hour, minute: picked.minute));
              }
            },
          ),
          SwitchListTile(
            title: const Text('AI-generated content'),
            subtitle: const Text('Use AI to write notification text'),
            value: _otd.useAi,
            onChanged: (v) => _saveOtd(_otd.copyWith(useAi: v)),
          ),
          if (_otd.useAi) ...[
            ListTile(
              title: const Text('Format'),
              subtitle: Text(_otd.aiFormat.displayName),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _pickAiFormat(
                current: _otd.aiFormat,
                onChanged: (f) => _saveOtd(_otd.copyWith(aiFormat: f)),
              ),
            ),
            ListTile(
              title: const Text('Style Instruction'),
              subtitle: Text(
                _otd.aiPromptStyle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: const Icon(Icons.edit_outlined),
              onTap: () => _editText(
                label: 'Style Instruction',
                initial: _otd.aiPromptStyle,
                onSave: (v) => _saveOtd(_otd.copyWith(aiPromptStyle: v)),
              ),
            ),
          ],
        ],
      ],
    );
  }

  // ── N×100 Day Milestones section ──────────────────────────────────────────

  Widget _buildHundredDaysSection() {
    return Column(
      children: [
        SwitchListTile(
          title: const Text('N×100 Day Milestones'),
          subtitle: const Text('Notify on 100-day, 200-day, 300-day... anniversaries'),
          value: _hd.enabled,
          onChanged: (v) => _saveHd(_hd.copyWith(enabled: v)),
        ),
        if (_hd.enabled) ...[
          ListTile(
            leading: const Icon(Icons.access_time),
            title: const Text('Time'),
            trailing: Text(
              '${_hd.hour.toString().padLeft(2, '0')}:${_hd.minute.toString().padLeft(2, '0')}',
            ),
            onTap: () async {
              final picked = await showTimePicker(
                context: context,
                initialTime: TimeOfDay(hour: _hd.hour, minute: _hd.minute),
              );
              if (picked != null) {
                _saveHd(_hd.copyWith(hour: picked.hour, minute: picked.minute));
              }
            },
          ),
          SwitchListTile(
            title: const Text('AI-generated content'),
            subtitle: const Text('Use AI to write notification text'),
            value: _hd.useAi,
            onChanged: (v) => _saveHd(_hd.copyWith(useAi: v)),
          ),
          if (_hd.useAi) ...[
            ListTile(
              title: const Text('Format'),
              subtitle: Text(_hd.aiFormat.displayName),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _pickAiFormat(
                current: _hd.aiFormat,
                onChanged: (f) => _saveHd(_hd.copyWith(aiFormat: f)),
              ),
            ),
            ListTile(
              title: const Text('Style Instruction'),
              subtitle: Text(
                _hd.aiPromptStyle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: const Icon(Icons.edit_outlined),
              onTap: () => _editText(
                label: 'Style Instruction',
                initial: _hd.aiPromptStyle,
                onSave: (v) => _saveHd(_hd.copyWith(aiPromptStyle: v)),
              ),
            ),
          ],
        ],
      ],
    );
  }

  // ── Periodic section ──────────────────────────────────────────────────────

  Widget _buildPeriodicSection() {
    return Column(
      children: [
        for (var i = 0; i < _rules.length; i++) _buildRuleCard(i, _rules[i]),
        if (_rules.length < 5)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: OutlinedButton.icon(
              onPressed: _addRule,
              icon: const Icon(Icons.add),
              label: const Text('Add Reminder'),
            ),
          ),
      ],
    );
  }

  Widget _buildRuleCard(int idx, PeriodicNotifRule rule) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        title: Text(rule.label),
        subtitle: Text(
          '${_scheduleLabel(rule.scheduleType, rule.intervalDays, rule.weekdays)}'
          '  ${rule.hour.toString().padLeft(2, '0')}:${rule.minute.toString().padLeft(2, '0')}'
          '${rule.useAi ? "  [AI]" : ""}',
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => _showRuleEditSheet(idx, rule),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _confirmDelete(idx),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(int idx) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Reminder'),
        content: const Text('Remove this reminder?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed == true) await _deleteRule(idx);
  }

  // ── Shared helpers ────────────────────────────────────────────────────────

  String _scheduleLabel(
      NotificationScheduleType type, int intervalDays, Set<int> weekdays) {
    const dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    switch (type) {
      case NotificationScheduleType.daily:
        return 'Daily';
      case NotificationScheduleType.everyNDays:
        return 'Every $intervalDays days';
      case NotificationScheduleType.weekdays:
        final sorted = weekdays.toList()..sort();
        return sorted.map((d) => dayNames[d - 1]).join(', ');
    }
  }

  Future<void> _showRuleEditSheet(int idx, PeriodicNotifRule rule) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _PeriodicRuleEditSheet(
        rule: rule,
        onSave: (updated) => _saveRule(idx, updated),
      ),
    );
  }

  Future<void> _pickAiFormat({
    required NotificationAiFormat current,
    required void Function(NotificationAiFormat) onChanged,
  }) async {
    final result = await showDialog<NotificationAiFormat>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('AI Format'),
        children: NotificationAiFormat.values
            .map((f) => ListTile(
                  title: Text(f.displayName),
                  leading: Icon(
                    f == current
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    color: f == current
                        ? Theme.of(ctx).colorScheme.primary
                        : null,
                  ),
                  onTap: () => Navigator.pop(ctx, f),
                ))
            .toList(),
      ),
    );
    if (result != null) onChanged(result);
  }

  Future<void> _editText({
    required String label,
    required String initial,
    required void Function(String) onSave,
    int maxLines = 3,
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
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text),
              child: const Text('Save')),
        ],
      ),
    );
    if (result != null && result.trim().isNotEmpty) onSave(result.trim());
  }
}

// ─── Section header ──────────────────────────────────────────────────────────

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

// ─── Schedule picker sheet ────────────────────────────────────────────────────

class _SchedulePickerSheet extends StatefulWidget {
  const _SchedulePickerSheet({
    required this.scheduleType,
    required this.intervalDays,
    required this.weekdays,
    required this.onChanged,
  });

  final NotificationScheduleType scheduleType;
  final int intervalDays;
  final Set<int> weekdays;
  final void Function(NotificationScheduleType, int, Set<int>) onChanged;

  @override
  State<_SchedulePickerSheet> createState() => _SchedulePickerSheetState();
}

class _SchedulePickerSheetState extends State<_SchedulePickerSheet> {
  late NotificationScheduleType _type;
  late int _intervalDays;
  late Set<int> _weekdays;
  late TextEditingController _intervalCtrl;

  static const _dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  void initState() {
    super.initState();
    _type = widget.scheduleType;
    _intervalDays = widget.intervalDays;
    _weekdays = Set.from(widget.weekdays);
    _intervalCtrl = TextEditingController(text: _intervalDays.toString());
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
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Schedule',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            SegmentedButton<NotificationScheduleType>(
              segments: const [
                ButtonSegment(
                    value: NotificationScheduleType.daily, label: Text('Daily')),
                ButtonSegment(
                    value: NotificationScheduleType.everyNDays,
                    label: Text('Every N days')),
                ButtonSegment(
                    value: NotificationScheduleType.weekdays,
                    label: Text('Weekdays')),
              ],
              selected: {_type},
              onSelectionChanged: (v) => setState(() => _type = v.first),
            ),
            const SizedBox(height: 16),
            if (_type == NotificationScheduleType.everyNDays)
              Row(
                children: [
                  const Text('Repeat every '),
                  SizedBox(
                    width: 60,
                    child: TextField(
                      controller: _intervalCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                          border: OutlineInputBorder(), isDense: true),
                      onChanged: (v) {
                        final n = int.tryParse(v);
                        if (n != null && n > 0) setState(() => _intervalDays = n);
                      },
                    ),
                  ),
                  const Text(' days'),
                ],
              ),
            if (_type == NotificationScheduleType.weekdays) ...[
              const Text('Select days:'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: List.generate(7, (i) {
                  final day = i + 1;
                  return FilterChip(
                    label: Text(_dayNames[i]),
                    selected: _weekdays.contains(day),
                    onSelected: (v) {
                      setState(() {
                        v ? _weekdays.add(day) : _weekdays.remove(day);
                      });
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
                    child: const Text('Cancel')),
                FilledButton(
                  onPressed: () {
                    widget.onChanged(_type, _intervalDays, _weekdays);
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

// ─── Periodic rule edit sheet ─────────────────────────────────────────────────

class _PeriodicRuleEditSheet extends StatefulWidget {
  const _PeriodicRuleEditSheet({
    required this.rule,
    required this.onSave,
  });

  final PeriodicNotifRule rule;
  final void Function(PeriodicNotifRule) onSave;

  @override
  State<_PeriodicRuleEditSheet> createState() => _PeriodicRuleEditSheetState();
}

class _PeriodicRuleEditSheetState extends State<_PeriodicRuleEditSheet> {
  late PeriodicNotifRule _rule;
  late TextEditingController _labelCtrl;
  late TextEditingController _subtitleCtrl;

  @override
  void initState() {
    super.initState();
    _rule = widget.rule;
    _labelCtrl = TextEditingController(text: _rule.label);
    _subtitleCtrl = TextEditingController(text: _rule.subtitle);
  }

  @override
  void dispose() {
    _labelCtrl.dispose();
    _subtitleCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheduleLabel = _scheduleLabel();

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Edit Reminder',
                  style:
                      TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              const SizedBox(height: 16),

              // Label
              TextField(
                controller: _labelCtrl,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  border: OutlineInputBorder(),
                ),
                onChanged: (v) =>
                    setState(() => _rule = _rule.copyWith(label: v)),
              ),
              const SizedBox(height: 12),
              // Subtitle
              TextField(
                controller: _subtitleCtrl,
                decoration: const InputDecoration(
                  labelText: 'Subtitle (optional)',
                  hintText: 'Shown below the title in the notification',
                  border: OutlineInputBorder(),
                ),
                onChanged: (v) =>
                    setState(() => _rule = _rule.copyWith(subtitle: v)),
              ),
              const SizedBox(height: 16),

              // Schedule
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.repeat, size: 18),
                      label: Text(scheduleLabel),
                      onPressed: () => _pickSchedule(context),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.access_time, size: 18),
                      label: Text(
                          '${_rule.hour.toString().padLeft(2, '0')}:${_rule.minute.toString().padLeft(2, '0')}'),
                      onPressed: () => _pickTime(context),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // AI toggle
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('AI-generated content'),
                value: _rule.useAi,
                onChanged: (v) =>
                    setState(() => _rule = _rule.copyWith(useAi: v)),
              ),
              if (_rule.useAi) ...[
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Format'),
                  subtitle: Text(_rule.aiFormat.displayName),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _pickAiFormat(context),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Style Instruction'),
                  subtitle: Text(
                    _rule.aiPromptStyle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: const Icon(Icons.edit_outlined),
                  onTap: () => _editPromptStyle(context),
                ),
              ],

              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel')),
                  FilledButton(
                    onPressed: () {
                      final saved = _rule.copyWith(
                          label: _labelCtrl.text.trim().isEmpty
                              ? 'Reminder'
                              : _labelCtrl.text.trim(),
                          subtitle: _subtitleCtrl.text.trim());
                      widget.onSave(saved);
                      Navigator.pop(context);
                    },
                    child: const Text('Save'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _scheduleLabel() {
    const dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    switch (_rule.scheduleType) {
      case NotificationScheduleType.daily:
        return 'Daily';
      case NotificationScheduleType.everyNDays:
        return 'Every ${_rule.intervalDays} days';
      case NotificationScheduleType.weekdays:
        final sorted = _rule.weekdays.toList()..sort();
        return sorted.map((d) => dayNames[d - 1]).join(', ');
    }
  }

  Future<void> _pickSchedule(BuildContext context) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _SchedulePickerSheet(
        scheduleType: _rule.scheduleType,
        intervalDays: _rule.intervalDays,
        weekdays: _rule.weekdays,
        onChanged: (type, interval, days) {
          setState(() => _rule = _rule.copyWith(
                scheduleType: type,
                intervalDays: interval,
                weekdays: days,
              ));
        },
      ),
    );
  }

  Future<void> _pickTime(BuildContext context) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _rule.hour, minute: _rule.minute),
    );
    if (picked != null) {
      setState(() =>
          _rule = _rule.copyWith(hour: picked.hour, minute: picked.minute));
    }
  }

  Future<void> _pickAiFormat(BuildContext context) async {
    final result = await showDialog<NotificationAiFormat>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('AI Format'),
        children: NotificationAiFormat.values
            .map((f) => ListTile(
                  title: Text(f.displayName),
                  leading: Icon(
                    f == _rule.aiFormat
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    color: f == _rule.aiFormat
                        ? Theme.of(ctx).colorScheme.primary
                        : null,
                  ),
                  onTap: () => Navigator.pop(ctx, f),
                ))
            .toList(),
      ),
    );
    if (result != null) {
      setState(() => _rule = _rule.copyWith(aiFormat: result));
    }
  }

  Future<void> _editPromptStyle(BuildContext context) async {
    final ctrl = TextEditingController(text: _rule.aiPromptStyle);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Style Instruction'),
        content: TextField(
          controller: ctrl,
          maxLines: 4,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text),
              child: const Text('Save')),
        ],
      ),
    );
    if (result != null && result.trim().isNotEmpty) {
      setState(() => _rule = _rule.copyWith(aiPromptStyle: result.trim()));
    }
  }
}
