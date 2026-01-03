class AiTask {
  final int? id;
  final int postId;
  final String taskType; // 'reactions' for initial AI reactions
  final int retryCount;
  final DateTime createdAt;
  final DateTime? lastAttemptAt;
  final String? errorMessage;

  AiTask({
    this.id,
    required this.postId,
    required this.taskType,
    this.retryCount = 0,
    required this.createdAt,
    this.lastAttemptAt,
    this.errorMessage,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'postId': postId,
      'taskType': taskType,
      'retryCount': retryCount,
      'createdAt': createdAt.toIso8601String(),
      'lastAttemptAt': lastAttemptAt?.toIso8601String(),
      'errorMessage': errorMessage,
    };
  }

  factory AiTask.fromMap(Map<String, dynamic> map) {
    return AiTask(
      id: map['id'] as int?,
      postId: map['postId'] as int,
      taskType: map['taskType'] as String,
      retryCount: map['retryCount'] as int,
      createdAt: DateTime.parse(map['createdAt'] as String),
      lastAttemptAt: map['lastAttemptAt'] != null
          ? DateTime.parse(map['lastAttemptAt'] as String)
          : null,
      errorMessage: map['errorMessage'] as String?,
    );
  }

  AiTask copyWith({
    int? id,
    int? postId,
    String? taskType,
    int? retryCount,
    DateTime? createdAt,
    DateTime? lastAttemptAt,
    String? errorMessage,
  }) {
    return AiTask(
      id: id ?? this.id,
      postId: postId ?? this.postId,
      taskType: taskType ?? this.taskType,
      retryCount: retryCount ?? this.retryCount,
      createdAt: createdAt ?? this.createdAt,
      lastAttemptAt: lastAttemptAt ?? this.lastAttemptAt,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}
