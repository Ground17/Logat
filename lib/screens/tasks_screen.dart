import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/task.dart';
import '../database/database_helper.dart';
import '../services/task_notification_service.dart';

class TasksScreen extends StatefulWidget {
  const TasksScreen({Key? key}) : super(key: key);

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  final DatabaseHelper _db = DatabaseHelper.instance;
  List<Task> _tasks = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  Future<void> _loadTasks() async {
    setState(() => _isLoading = true);
    final tasks = await _db.getActiveTasks();
    setState(() {
      _tasks = tasks;
      _isLoading = false;
    });
  }

  Future<void> _completeTask(Task task) async {
    if (task.id == null) return;

    await _db.completeTask(task.id!);
    await TaskNotificationService.instance.cancelCompletedTaskNotification(task.id!);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('✓ ${task.title} completed')),
      );
    }

    await _loadTasks();
  }

  Future<void> _deleteTask(Task task) async {
    if (task.id == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Task'),
        content: Text('Delete "${task.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _db.deleteTask(task.id!);
      await TaskNotificationService.instance.cancelTaskNotification(task.id!);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Task deleted')),
        );
      }

      await _loadTasks();
    }
  }

  String _getRecurrenceText(Task task) {
    switch (task.recurrenceType) {
      case TaskRecurrenceType.none:
        return 'Once';
      case TaskRecurrenceType.daily:
        return 'Daily';
      case TaskRecurrenceType.weekly:
        final days = task.weekdays?.map((d) {
          switch (d) {
            case 1:
              return 'Mon';
            case 2:
              return 'Tue';
            case 3:
              return 'Wed';
            case 4:
              return 'Thu';
            case 5:
              return 'Fri';
            case 6:
              return 'Sat';
            case 7:
              return 'Sun';
            default:
              return '';
          }
        }).join(', ');
        return 'Weekly: $days';
      case TaskRecurrenceType.monthly:
        return 'Monthly on day ${task.monthDay}';
      case TaskRecurrenceType.interval:
        return 'Every ${task.intervalDays} days';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tasks'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () async {
              await TaskNotificationService.instance.updateAllTaskNotifications();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Notification updated')),
                );
              }
            },
            tooltip: 'Update Notification',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'addTask',
        onPressed: () => _showCreateTaskDialog(),
        tooltip: 'Add Recurring Reminder',
        child: const Icon(Icons.add_alarm),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _tasks.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.task_alt,
                        size: 80,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No tasks',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Tap + to add a recurring reminder',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadTasks,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _tasks.length,
                    itemBuilder: (context, index) {
                      final task = _tasks[index];
                      return _buildTaskCard(task);
                    },
                  ),
                ),
    );
  }

  static final _presets = [
    _TaskPreset(label: 'Weekly Date Night', emoji: '💑',
        recurrence: TaskRecurrenceType.weekly, weekday: 6, time: '19:00'),
    _TaskPreset(label: 'Menstrual Cycle', emoji: '🌸',
        recurrence: TaskRecurrenceType.interval, intervalDays: 28, time: '08:00'),
    _TaskPreset(label: 'Weekly Review', emoji: '📋',
        recurrence: TaskRecurrenceType.weekly, weekday: 7, time: '20:00'),
    _TaskPreset(label: 'Monthly Check-in', emoji: '📅',
        recurrence: TaskRecurrenceType.monthly, monthDay: 1, time: '09:00'),
    _TaskPreset(label: 'Daily Journal', emoji: '📓',
        recurrence: TaskRecurrenceType.daily, time: '22:00'),
  ];

  Future<void> _showCreateTaskDialog({Task? editing}) async {
    final titleController =
        TextEditingController(text: editing?.title ?? '');
    final descController =
        TextEditingController(text: editing?.description ?? '');
    var recurrence =
        editing?.recurrenceType ?? TaskRecurrenceType.weekly;
    var selectedWeekdays =
        List<int>.from(editing?.weekdays ?? [6]); // Saturday default
    var monthDay = editing?.monthDay ?? 1;
    var intervalDays = editing?.intervalDays ?? 28;
    TimeOfDay time = TimeOfDay(
      hour: int.tryParse(
              (editing?.time ?? '09:00').split(':').firstOrNull ?? '9') ??
          9,
      minute: int.tryParse(
              (editing?.time ?? '09:00').split(':').lastOrNull ?? '0') ??
          0,
    );
    DateTime? dueDate = editing?.dueDate;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: Text(editing == null ? 'New Reminder' : 'Edit Reminder'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Presets row (only for new)
                if (editing == null) ...[
                  const Text('Quick Presets:',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 12)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    children: _presets.map((p) {
                      return ActionChip(
                        label: Text('${p.emoji} ${p.label}'),
                        onPressed: () {
                          setS(() {
                            titleController.text = '${p.emoji} ${p.label}';
                            recurrence = p.recurrence;
                            if (p.weekday != null) {
                              selectedWeekdays = [p.weekday!];
                            }
                            if (p.intervalDays != null) {
                              intervalDays = p.intervalDays!;
                            }
                            if (p.monthDay != null) {
                              monthDay = p.monthDay!;
                            }
                            final timeParts = p.time.split(':');
                            time = TimeOfDay(
                              hour: int.parse(timeParts[0]),
                              minute: int.parse(timeParts[1]),
                            );
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const Divider(height: 20),
                ],

                // Title
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'Title',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),

                // Description
                TextField(
                  controller: descController,
                  decoration: const InputDecoration(
                    labelText: 'Description (optional)',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 12),

                // Recurrence
                const Text('Repeat:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                DropdownButton<TaskRecurrenceType>(
                  value: recurrence,
                  isExpanded: true,
                  items: const [
                    DropdownMenuItem(
                        value: TaskRecurrenceType.none, child: Text('Once')),
                    DropdownMenuItem(
                        value: TaskRecurrenceType.daily, child: Text('Daily')),
                    DropdownMenuItem(
                        value: TaskRecurrenceType.weekly,
                        child: Text('Weekly')),
                    DropdownMenuItem(
                        value: TaskRecurrenceType.monthly,
                        child: Text('Monthly')),
                    DropdownMenuItem(
                        value: TaskRecurrenceType.interval,
                        child: Text('Every N days')),
                  ],
                  onChanged: (v) => setS(() => recurrence = v!),
                ),
                const SizedBox(height: 8),

                // Weekly: weekday selector
                if (recurrence == TaskRecurrenceType.weekly) ...[
                  const Text('Days:',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  Wrap(
                    spacing: 4,
                    children: [
                      for (int i = 1; i <= 7; i++)
                        FilterChip(
                          label: Text(_weekdayAbbr(i)),
                          selected: selectedWeekdays.contains(i),
                          onSelected: (v) => setS(() {
                            if (v) {
                              selectedWeekdays.add(i);
                            } else {
                              selectedWeekdays.remove(i);
                            }
                          }),
                        ),
                    ],
                  ),
                ],

                // Monthly: day selector
                if (recurrence == TaskRecurrenceType.monthly) ...[
                  const Text('Day of month:',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  Row(
                    children: [
                      Expanded(
                        child: Slider(
                          value: monthDay.toDouble(),
                          min: 1,
                          max: 28,
                          divisions: 27,
                          label: '$monthDay',
                          onChanged: (v) =>
                              setS(() => monthDay = v.round()),
                        ),
                      ),
                      Text('Day $monthDay'),
                    ],
                  ),
                ],

                // Interval: N days
                if (recurrence == TaskRecurrenceType.interval) ...[
                  const Text('Every N days:',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  Row(
                    children: [
                      Expanded(
                        child: Slider(
                          value: intervalDays.toDouble(),
                          min: 1,
                          max: 90,
                          divisions: 89,
                          label: '$intervalDays',
                          onChanged: (v) =>
                              setS(() => intervalDays = v.round()),
                        ),
                      ),
                      Text('$intervalDays days'),
                    ],
                  ),
                ],

                // One-time: due date
                if (recurrence == TaskRecurrenceType.none) ...[
                  OutlinedButton.icon(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate: dueDate ?? DateTime.now(),
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now()
                            .add(const Duration(days: 365 * 5)),
                      );
                      if (picked != null) setS(() => dueDate = picked);
                    },
                    icon: const Icon(Icons.calendar_today, size: 16),
                    label: Text(dueDate != null
                        ? DateFormat('yyyy-MM-dd').format(dueDate!)
                        : 'Select due date'),
                  ),
                ],

                const SizedBox(height: 8),

                // Time
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.access_time),
                  title: Text('Notification time: ${time.format(ctx)}'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () async {
                    final picked = await showTimePicker(
                      context: ctx,
                      initialTime: time,
                    );
                    if (picked != null) setS(() => time = picked);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                if (titleController.text.trim().isEmpty) return;
                Navigator.pop(ctx);

                final timeStr =
                    '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

                final task = editing != null
                    ? editing.copyWith(
                        title: titleController.text.trim(),
                        description: descController.text.trim().isEmpty
                            ? null
                            : descController.text.trim(),
                        recurrenceType: recurrence,
                        weekdays: recurrence == TaskRecurrenceType.weekly
                            ? selectedWeekdays
                            : null,
                        monthDay: recurrence == TaskRecurrenceType.monthly
                            ? monthDay
                            : null,
                        intervalDays:
                            recurrence == TaskRecurrenceType.interval
                                ? intervalDays
                                : null,
                        dueDate: recurrence == TaskRecurrenceType.none
                            ? dueDate
                            : null,
                        time: timeStr,
                      )
                    : Task(
                        title: titleController.text.trim(),
                        description: descController.text.trim().isEmpty
                            ? null
                            : descController.text.trim(),
                        recurrenceType: recurrence,
                        weekdays: recurrence == TaskRecurrenceType.weekly
                            ? selectedWeekdays
                            : null,
                        monthDay: recurrence == TaskRecurrenceType.monthly
                            ? monthDay
                            : null,
                        intervalDays:
                            recurrence == TaskRecurrenceType.interval
                                ? intervalDays
                                : null,
                        dueDate: recurrence == TaskRecurrenceType.none
                            ? dueDate
                            : null,
                        time: timeStr,
                      );

                if (editing != null) {
                  await _db.updateTask(task);
                } else {
                  final id = await _db.createTask(task);
                  final saved = await _db.getTask(id);
                  if (saved != null) {
                    await TaskNotificationService.instance
                        .scheduleTaskNotification(saved);
                  }
                }
                await _loadTasks();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(editing != null
                          ? 'Reminder updated'
                          : 'Reminder created'),
                    ),
                  );
                }
              },
              child: Text(editing == null ? 'Create' : 'Save'),
            ),
          ],
        ),
      ),
    );
    titleController.dispose();
    descController.dispose();
  }

  String _weekdayAbbr(int day) {
    const abbrs = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return abbrs[day - 1];
  }

  Widget _buildTaskCard(Task task) {
    final dateFormat = DateFormat('yyyy-MM-dd');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          child: Icon(
            _getTaskIcon(task.recurrenceType),
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        title: Text(
          task.title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (task.description != null) ...[
              const SizedBox(height: 4),
              Text(task.description!),
            ],
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.repeat, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  _getRecurrenceText(task),
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
            if (task.dueDate != null && task.recurrenceType == TaskRecurrenceType.none) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    dateFormat.format(task.dueDate!),
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            ],
            if (task.time != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    task.time!,
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            ],
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            switch (value) {
              case 'edit':
                _showCreateTaskDialog(editing: task);
                break;
              case 'complete':
                _completeTask(task);
                break;
              case 'delete':
                _deleteTask(task);
                break;
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'edit',
              child: Row(
                children: [
                  Icon(Icons.edit),
                  SizedBox(width: 8),
                  Text('Edit'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'complete',
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green),
                  SizedBox(width: 8),
                  Text('Complete'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Delete'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getTaskIcon(TaskRecurrenceType type) {
    switch (type) {
      case TaskRecurrenceType.none:
        return Icons.event;
      case TaskRecurrenceType.daily:
        return Icons.today;
      case TaskRecurrenceType.weekly:
        return Icons.calendar_view_week;
      case TaskRecurrenceType.monthly:
        return Icons.calendar_month;
      case TaskRecurrenceType.interval:
        return Icons.repeat;
    }
  }
}

class _TaskPreset {
  const _TaskPreset({
    required this.label,
    required this.emoji,
    required this.recurrence,
    required this.time,
    this.weekday,
    this.intervalDays,
    this.monthDay,
  });

  final String label;
  final String emoji;
  final TaskRecurrenceType recurrence;
  final String time;
  final int? weekday;
  final int? intervalDays;
  final int? monthDay;
}
