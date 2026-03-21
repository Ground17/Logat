enum TaskRecurrenceType {
  none, // 한 번만
  daily, // 매일
  weekly, // 매주 특정 요일
  monthly, // 매월 특정 일
  interval, // N일마다
}

class Task {
  final int? id;
  final int? aiPersonaId; // 어떤 AI가 감지했는지
  final String title; // 작업 제목
  final String? description; // 작업 설명
  final DateTime? dueDate; // 특정 날짜 (none, weekly, monthly인 경우)
  final TaskRecurrenceType recurrenceType; // 반복 유형
  final int? intervalDays; // interval인 경우 N일
  final List<int>? weekdays; // weekly인 경우 요일 (1=Monday, 7=Sunday)
  final int? monthDay; // monthly인 경우 일 (1-31)
  final String? time; // 알림 시간 (HH:mm 형식)
  final bool isCompleted; // 완료 여부
  final DateTime? lastNotificationDate; // 마지막 알림 날짜 (반복 작업용)
  final DateTime createdAt;
  final DateTime? completedAt;

  Task({
    this.id,
    this.aiPersonaId,
    required this.title,
    this.description,
    this.dueDate,
    this.recurrenceType = TaskRecurrenceType.none,
    this.intervalDays,
    this.weekdays,
    this.monthDay,
    this.time,
    this.isCompleted = false,
    this.lastNotificationDate,
    DateTime? createdAt,
    this.completedAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'aiPersonaId': aiPersonaId,
      'title': title,
      'description': description,
      'dueDate': dueDate?.toIso8601String(),
      'recurrenceType': recurrenceType.index,
      'intervalDays': intervalDays,
      'weekdays': weekdays?.join(','),
      'monthDay': monthDay,
      'time': time,
      'isCompleted': isCompleted ? 1 : 0,
      'lastNotificationDate': lastNotificationDate?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
    };
  }

  factory Task.fromMap(Map<String, dynamic> map) {
    final weekdaysStr = map['weekdays'] as String?;
    final weekdays = weekdaysStr != null && weekdaysStr.isNotEmpty
        ? weekdaysStr.split(',').map((e) => int.parse(e)).toList()
        : null;

    return Task(
      id: map['id'] as int?,
      aiPersonaId: map['aiPersonaId'] as int?,
      title: map['title'] as String,
      description: map['description'] as String?,
      dueDate: map['dueDate'] != null
          ? DateTime.parse(map['dueDate'] as String)
          : null,
      recurrenceType: TaskRecurrenceType.values[map['recurrenceType'] as int],
      intervalDays: map['intervalDays'] as int?,
      weekdays: weekdays,
      monthDay: map['monthDay'] as int?,
      time: map['time'] as String?,
      isCompleted: map['isCompleted'] == 1,
      lastNotificationDate: map['lastNotificationDate'] != null
          ? DateTime.parse(map['lastNotificationDate'] as String)
          : null,
      createdAt: DateTime.parse(map['createdAt'] as String),
      completedAt: map['completedAt'] != null
          ? DateTime.parse(map['completedAt'] as String)
          : null,
    );
  }

  Task copyWith({
    int? id,
    int? aiPersonaId,
    String? title,
    String? description,
    DateTime? dueDate,
    TaskRecurrenceType? recurrenceType,
    int? intervalDays,
    List<int>? weekdays,
    int? monthDay,
    String? time,
    bool? isCompleted,
    DateTime? lastNotificationDate,
    DateTime? createdAt,
    DateTime? completedAt,
  }) {
    return Task(
      id: id ?? this.id,
      aiPersonaId: aiPersonaId ?? this.aiPersonaId,
      title: title ?? this.title,
      description: description ?? this.description,
      dueDate: dueDate ?? this.dueDate,
      recurrenceType: recurrenceType ?? this.recurrenceType,
      intervalDays: intervalDays ?? this.intervalDays,
      weekdays: weekdays ?? this.weekdays,
      monthDay: monthDay ?? this.monthDay,
      time: time ?? this.time,
      isCompleted: isCompleted ?? this.isCompleted,
      lastNotificationDate: lastNotificationDate ?? this.lastNotificationDate,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }
}
