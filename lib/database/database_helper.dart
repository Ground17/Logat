import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import '../models/ai_task.dart';
import '../models/comment.dart';
import '../models/like.dart';
import '../models/post.dart';
import '../models/scheduled_notification.dart';
import '../models/task.dart';

const String _legacySchemaSql = '''
CREATE TABLE posts (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  title TEXT,
  mediaPaths TEXT NOT NULL,
  caption TEXT,
  locationName TEXT,
  latitude REAL,
  longitude REAL,
  postDate TEXT,
  tag TEXT,
  keywords TEXT NOT NULL DEFAULT '',
  viewCount INTEGER NOT NULL DEFAULT 0,
  likeCount INTEGER NOT NULL DEFAULT 0,
  enableAiReactions INTEGER NOT NULL DEFAULT 1,
  createdAt TEXT NOT NULL,
  updatedAt TEXT NOT NULL
);
CREATE TABLE comments (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  postId INTEGER NOT NULL,
  aiPersonaId INTEGER,
  isUser INTEGER NOT NULL DEFAULT 0,
  content TEXT NOT NULL,
  createdAt TEXT NOT NULL
);
CREATE TABLE likes (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  postId INTEGER NOT NULL,
  aiPersonaId INTEGER,
  isUser INTEGER NOT NULL DEFAULT 0,
  createdAt TEXT NOT NULL
);
CREATE TABLE tag_settings (
  tag TEXT PRIMARY KEY,
  customName TEXT NOT NULL
);
CREATE TABLE ai_tasks (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  postId INTEGER NOT NULL,
  taskType TEXT NOT NULL,
  retryCount INTEGER NOT NULL DEFAULT 0,
  createdAt TEXT NOT NULL,
  lastAttemptAt TEXT,
  errorMessage TEXT
);
CREATE TABLE scheduled_notifications (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  postId INTEGER NOT NULL,
  aiPersonaId INTEGER,
  notificationType TEXT NOT NULL,
  commentContent TEXT,
  scheduledTime TEXT NOT NULL,
  isDelivered INTEGER NOT NULL DEFAULT 0,
  isRead INTEGER NOT NULL DEFAULT 0,
  createdAt TEXT NOT NULL
);
CREATE TABLE tasks (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  aiPersonaId INTEGER,
  title TEXT NOT NULL,
  description TEXT,
  dueDate TEXT,
  recurrenceType INTEGER NOT NULL DEFAULT 0,
  intervalDays INTEGER,
  weekdays TEXT,
  monthDay INTEGER,
  time TEXT,
  isCompleted INTEGER NOT NULL DEFAULT 0,
  lastNotificationDate TEXT,
  createdAt TEXT NOT NULL,
  completedAt TEXT
);
''';

QueryExecutor _openLegacyConnection() {
  return driftDatabase(name: 'legacy_logat');
}

class _LegacyDatabase extends GeneratedDatabase {
  _LegacyDatabase() : super(_openLegacyConnection());

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON;');
        },
        onCreate: (migrator) async {
          for (final statement in _legacySchemaSql
              .split(';')
              .map((item) => item.trim())
              .where((item) => item.isNotEmpty)) {
            await customStatement('$statement;');
          }
        },
        onUpgrade: (migrator, from, to) async {
          if (from < 2) {
            await customStatement(
              'ALTER TABLE posts ADD COLUMN keywords TEXT NOT NULL DEFAULT ""',
            );
          }
        },
      );

  @override
  Iterable<TableInfo<Table, Object?>> get allTables => const [];

  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => const [];
}

class DatabaseHelper {
  DatabaseHelper._init();

  static final DatabaseHelper instance = DatabaseHelper._init();

  final _LegacyDatabase _database = _LegacyDatabase();

  Future<void> _ensureSeeded() async {}

  Future<int> createPost(Post post) async {
    await _ensureSeeded();
    return _insert(
      '''
      INSERT INTO posts (
        title, mediaPaths, caption, locationName, latitude, longitude, postDate,
        tag, keywords, viewCount, likeCount, enableAiReactions, createdAt, updatedAt
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ''',
      [
        post.title,
        post.toMap()['mediaPaths'],
        post.caption,
        post.locationName,
        post.latitude,
        post.longitude,
        post.postDate?.toIso8601String(),
        post.tag,
        post.keywords.isEmpty ? '' : post.keywords.join('|||'),
        post.viewCount,
        post.likeCount,
        post.enableAiReactions ? 1 : 0,
        post.createdAt.toIso8601String(),
        post.updatedAt.toIso8601String(),
      ],
    );
  }

  Future<List<Post>> getAllPosts() async {
    await _ensureSeeded();
    final rows = await _database
        .customSelect(
          'SELECT * FROM posts ORDER BY createdAt DESC',
        )
        .get();
    return Future.wait(rows.map((row) => Post.fromMap(row.data)));
  }

  Future<Post?> getPost(int id) async {
    await _ensureSeeded();
    final rows = await _database.customSelect(
      'SELECT * FROM posts WHERE id = ? LIMIT 1',
      variables: [Variable<int>(id)],
    ).get();
    if (rows.isEmpty) {
      return null;
    }
    return Post.fromMap(rows.first.data);
  }

  Future<int> updatePost(Post post) async {
    await _ensureSeeded();
    if (post.id == null) {
      return 0;
    }
    await _database.customStatement(
      '''
      UPDATE posts
      SET title = ?, mediaPaths = ?, caption = ?, locationName = ?, latitude = ?,
          longitude = ?, postDate = ?, tag = ?, keywords = ?, viewCount = ?,
          likeCount = ?, enableAiReactions = ?, createdAt = ?, updatedAt = ?
      WHERE id = ?
      ''',
      [
        post.title,
        post.toMap()['mediaPaths'],
        post.caption,
        post.locationName,
        post.latitude,
        post.longitude,
        post.postDate?.toIso8601String(),
        post.tag,
        post.keywords.isEmpty ? '' : post.keywords.join('|||'),
        post.viewCount,
        post.likeCount,
        post.enableAiReactions ? 1 : 0,
        post.createdAt.toIso8601String(),
        post.updatedAt.toIso8601String(),
        post.id,
      ],
    );
    return 1;
  }

  Future<int> deletePost(int id) async {
    await _ensureSeeded();
    await _database.transaction(() async {
      await _database
          .customStatement('DELETE FROM comments WHERE postId = ?', [id]);
      await _database
          .customStatement('DELETE FROM likes WHERE postId = ?', [id]);
      await _database
          .customStatement('DELETE FROM ai_tasks WHERE postId = ?', [id]);
      await _database.customStatement(
        'DELETE FROM scheduled_notifications WHERE postId = ?',
        [id],
      );
      await _database.customStatement('DELETE FROM posts WHERE id = ?', [id]);
    });
    return 1;
  }

  Future<int> incrementViewCount(int postId) async {
    await _ensureSeeded();
    await _database.customStatement(
      'UPDATE posts SET viewCount = viewCount + 1 WHERE id = ?',
      [postId],
    );
    return 1;
  }

  Future<int> createComment(Comment comment) async {
    await _ensureSeeded();
    return _insert(
      '''
      INSERT INTO comments (postId, aiPersonaId, isUser, content, createdAt)
      VALUES (?, ?, ?, ?, ?)
      ''',
      [
        comment.postId,
        comment.aiPersonaId,
        comment.isUser ? 1 : 0,
        comment.content,
        comment.createdAt.toIso8601String(),
      ],
    );
  }

  Future<List<Comment>> getCommentsByPost(int postId) async {
    await _ensureSeeded();
    final rows = await _database.customSelect(
      'SELECT * FROM comments WHERE postId = ? ORDER BY createdAt ASC',
      variables: [Variable<int>(postId)],
    ).get();
    return rows.map((row) => Comment.fromMap(row.data)).toList();
  }

  Future<int> updateComment(Comment comment) async {
    await _ensureSeeded();
    if (comment.id == null) {
      return 0;
    }
    await _database.customStatement(
      '''
      UPDATE comments
      SET postId = ?, aiPersonaId = ?, isUser = ?, content = ?, createdAt = ?
      WHERE id = ?
      ''',
      [
        comment.postId,
        comment.aiPersonaId,
        comment.isUser ? 1 : 0,
        comment.content,
        comment.createdAt.toIso8601String(),
        comment.id,
      ],
    );
    return 1;
  }

  Future<int> deleteComment(int id) async {
    await _ensureSeeded();
    await _database.customStatement('DELETE FROM comments WHERE id = ?', [id]);
    return 1;
  }

  Future<int> createLike(Like like) async {
    await _ensureSeeded();
    return _insert(
      '''
      INSERT INTO likes (postId, aiPersonaId, isUser, createdAt)
      VALUES (?, ?, ?, ?)
      ''',
      [
        like.postId,
        like.aiPersonaId,
        like.isUser ? 1 : 0,
        like.createdAt.toIso8601String(),
      ],
    );
  }

  Future<int> deleteLike(int postId,
      {int? aiPersonaId, bool isUser = false}) async {
    await _ensureSeeded();
    await _database.customStatement(
      '''
      DELETE FROM likes
      WHERE postId = ?
        AND ${aiPersonaId == null ? 'aiPersonaId IS NULL' : 'aiPersonaId = ?'}
        AND isUser = ?
      ''',
      [
        postId,
        if (aiPersonaId != null) aiPersonaId,
        isUser ? 1 : 0,
      ],
    );
    return 1;
  }

  Future<List<Like>> getLikesByPost(int postId) async {
    await _ensureSeeded();
    final rows = await _database.customSelect(
      'SELECT * FROM likes WHERE postId = ? ORDER BY createdAt ASC',
      variables: [Variable<int>(postId)],
    ).get();
    return rows.map((row) => Like.fromMap(row.data)).toList();
  }

  Future<bool> hasLiked(int postId, int aiPersonaId) async {
    await _ensureSeeded();
    final row = await _database.customSelect(
      'SELECT COUNT(*) AS count FROM likes WHERE postId = ? AND aiPersonaId = ?',
      variables: [Variable<int>(postId), Variable<int>(aiPersonaId)],
    ).getSingle();
    return row.read<int>('count') > 0;
  }

  Future<Map<String, String>> getAllTagSettings() async {
    await _ensureSeeded();
    final rows =
        await _database.customSelect('SELECT * FROM tag_settings').get();
    return {
      for (final row in rows)
        row.read<String>('tag'): row.read<String>('customName'),
    };
  }

  Future<String?> getTagCustomName(String tag) async {
    await _ensureSeeded();
    final rows = await _database.customSelect(
      'SELECT customName FROM tag_settings WHERE tag = ? LIMIT 1',
      variables: [Variable<String>(tag)],
    ).get();
    if (rows.isEmpty) {
      return null;
    }
    return rows.first.read<String>('customName');
  }

  Future<void> setTagCustomName(String tag, String customName) async {
    await _ensureSeeded();
    await _database.customStatement(
      '''
      INSERT INTO tag_settings (tag, customName)
      VALUES (?, ?)
      ON CONFLICT(tag) DO UPDATE SET customName = excluded.customName
      ''',
      [tag, customName],
    );
  }

  Future<void> deleteTagCustomName(String tag) async {
    await _ensureSeeded();
    await _database
        .customStatement('DELETE FROM tag_settings WHERE tag = ?', [tag]);
  }

  Future<int> createAiTask(AiTask task) async {
    await _ensureSeeded();
    return _insert(
      '''
      INSERT INTO ai_tasks (postId, taskType, retryCount, createdAt, lastAttemptAt, errorMessage)
      VALUES (?, ?, ?, ?, ?, ?)
      ''',
      [
        task.postId,
        task.taskType,
        task.retryCount,
        task.createdAt.toIso8601String(),
        task.lastAttemptAt?.toIso8601String(),
        task.errorMessage,
      ],
    );
  }

  Future<List<AiTask>> getPendingAiTasks({int limit = 3}) async {
    await _ensureSeeded();
    final rows = await _database.customSelect(
      '''
      SELECT * FROM ai_tasks
      ORDER BY createdAt ASC
      LIMIT ?
      ''',
      variables: [Variable<int>(limit)],
    ).get();
    return rows.map((row) => AiTask.fromMap(row.data)).toList();
  }

  Future<int> updateAiTask(AiTask task) async {
    await _ensureSeeded();
    if (task.id == null) {
      return 0;
    }
    await _database.customStatement(
      '''
      UPDATE ai_tasks
      SET postId = ?, taskType = ?, retryCount = ?, createdAt = ?,
          lastAttemptAt = ?, errorMessage = ?
      WHERE id = ?
      ''',
      [
        task.postId,
        task.taskType,
        task.retryCount,
        task.createdAt.toIso8601String(),
        task.lastAttemptAt?.toIso8601String(),
        task.errorMessage,
        task.id,
      ],
    );
    return 1;
  }

  Future<int> deleteAiTask(int id) async {
    await _ensureSeeded();
    await _database.customStatement('DELETE FROM ai_tasks WHERE id = ?', [id]);
    return 1;
  }

  Future<int> createScheduledNotification(
      ScheduledNotification notification) async {
    await _ensureSeeded();
    return _insert(
      '''
      INSERT INTO scheduled_notifications (
        postId, aiPersonaId, notificationType, commentContent, scheduledTime,
        isDelivered, isRead, createdAt
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
      ''',
      [
        notification.postId,
        notification.aiPersonaId,
        notification.notificationType,
        notification.commentContent,
        notification.scheduledTime.toIso8601String(),
        notification.isDelivered ? 1 : 0,
        notification.isRead ? 1 : 0,
        notification.createdAt.toIso8601String(),
      ],
    );
  }

  Future<List<ScheduledNotification>> getScheduledNotifications(
      {bool? isDelivered}) async {
    await _ensureSeeded();
    final rows = await _database.customSelect(
      '''
      SELECT * FROM scheduled_notifications
      ${isDelivered == null ? '' : 'WHERE isDelivered = ?'}
      ORDER BY scheduledTime ASC
      ''',
      variables:
          isDelivered == null ? const [] : [Variable<int>(isDelivered ? 1 : 0)],
    ).get();
    return rows.map((row) => ScheduledNotification.fromMap(row.data)).toList();
  }

  Future<ScheduledNotification?> getScheduledNotification(int id) async {
    await _ensureSeeded();
    final rows = await _database.customSelect(
      'SELECT * FROM scheduled_notifications WHERE id = ? LIMIT 1',
      variables: [Variable<int>(id)],
    ).get();
    if (rows.isEmpty) {
      return null;
    }
    return ScheduledNotification.fromMap(rows.first.data);
  }

  Future<int> updateScheduledNotification(
      ScheduledNotification notification) async {
    await _ensureSeeded();
    if (notification.id == null) {
      return 0;
    }
    await _database.customStatement(
      '''
      UPDATE scheduled_notifications
      SET postId = ?, aiPersonaId = ?, notificationType = ?, commentContent = ?,
          scheduledTime = ?, isDelivered = ?, isRead = ?, createdAt = ?
      WHERE id = ?
      ''',
      [
        notification.postId,
        notification.aiPersonaId,
        notification.notificationType,
        notification.commentContent,
        notification.scheduledTime.toIso8601String(),
        notification.isDelivered ? 1 : 0,
        notification.isRead ? 1 : 0,
        notification.createdAt.toIso8601String(),
        notification.id,
      ],
    );
    return 1;
  }

  Future<int> deleteScheduledNotification(int id) async {
    await _ensureSeeded();
    await _database.customStatement(
      'DELETE FROM scheduled_notifications WHERE id = ?',
      [id],
    );
    return 1;
  }

  Future<int> getUnreadNotificationCount() async {
    await _ensureSeeded();
    final row = await _database
        .customSelect(
          'SELECT COUNT(*) AS count FROM scheduled_notifications WHERE isRead = 0',
        )
        .getSingle();
    return row.read<int>('count');
  }

  Future<int> markNotificationsAsRead(List<int> ids) async {
    await _ensureSeeded();
    if (ids.isEmpty) {
      return 0;
    }
    await _database.customStatement(
      'UPDATE scheduled_notifications SET isRead = 1 WHERE id IN (${List.filled(ids.length, '?').join(', ')})',
      ids,
    );
    return ids.length;
  }

  Future<int> markAllNotificationsAsRead() async {
    await _ensureSeeded();
    await _database.customStatement(
      'UPDATE scheduled_notifications SET isRead = 1 WHERE isRead = 0',
    );
    return 1;
  }

  Future<int> createTask(Task task) async {
    await _ensureSeeded();
    return _insert(
      '''
      INSERT INTO tasks (
        aiPersonaId, title, description, dueDate, recurrenceType, intervalDays,
        weekdays, monthDay, time, isCompleted, lastNotificationDate, createdAt, completedAt
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ''',
      [
        task.aiPersonaId,
        task.title,
        task.description,
        task.dueDate?.toIso8601String(),
        task.recurrenceType.index,
        task.intervalDays,
        task.weekdays?.join(','),
        task.monthDay,
        task.time,
        task.isCompleted ? 1 : 0,
        task.lastNotificationDate?.toIso8601String(),
        task.createdAt.toIso8601String(),
        task.completedAt?.toIso8601String(),
      ],
    );
  }

  Future<List<Task>> getAllTasks() async {
    await _ensureSeeded();
    final rows = await _database
        .customSelect('SELECT * FROM tasks ORDER BY createdAt DESC')
        .get();
    return rows.map((row) => Task.fromMap(row.data)).toList();
  }

  Future<List<Task>> getActiveTasks() async {
    await _ensureSeeded();
    final rows = await _database
        .customSelect(
          'SELECT * FROM tasks WHERE isCompleted = 0 ORDER BY createdAt DESC',
        )
        .get();
    return rows.map((row) => Task.fromMap(row.data)).toList();
  }

  Future<List<Task>> getRecurringTasks() async {
    await _ensureSeeded();
    final rows = await _database
        .customSelect(
          'SELECT * FROM tasks WHERE recurrenceType != 0 ORDER BY createdAt DESC',
        )
        .get();
    return rows.map((row) => Task.fromMap(row.data)).toList();
  }

  Future<Task?> getTask(int id) async {
    await _ensureSeeded();
    final rows = await _database.customSelect(
      'SELECT * FROM tasks WHERE id = ? LIMIT 1',
      variables: [Variable<int>(id)],
    ).get();
    if (rows.isEmpty) {
      return null;
    }
    return Task.fromMap(rows.first.data);
  }

  Future<int> updateTask(Task task) async {
    await _ensureSeeded();
    if (task.id == null) {
      return 0;
    }
    await _database.customStatement(
      '''
      UPDATE tasks
      SET aiPersonaId = ?, title = ?, description = ?, dueDate = ?, recurrenceType = ?,
          intervalDays = ?, weekdays = ?, monthDay = ?, time = ?, isCompleted = ?,
          lastNotificationDate = ?, createdAt = ?, completedAt = ?
      WHERE id = ?
      ''',
      [
        task.aiPersonaId,
        task.title,
        task.description,
        task.dueDate?.toIso8601String(),
        task.recurrenceType.index,
        task.intervalDays,
        task.weekdays?.join(','),
        task.monthDay,
        task.time,
        task.isCompleted ? 1 : 0,
        task.lastNotificationDate?.toIso8601String(),
        task.createdAt.toIso8601String(),
        task.completedAt?.toIso8601String(),
        task.id,
      ],
    );
    return 1;
  }

  Future<int> deleteTask(int id) async {
    await _ensureSeeded();
    await _database.customStatement('DELETE FROM tasks WHERE id = ?', [id]);
    return 1;
  }

  Future<int> completeTask(int id) async {
    await _ensureSeeded();
    await _database.customStatement(
      'UPDATE tasks SET isCompleted = 1, completedAt = ? WHERE id = ?',
      [DateTime.now().toIso8601String(), id],
    );
    return 1;
  }

  Future<void> printAllDatabaseContents() async {
    await _ensureSeeded();
    const tables = [
      'posts',
      'comments',
      'likes',
      'tag_settings',
      'ai_tasks',
      'scheduled_notifications',
      'tasks',
    ];

    for (final table in tables) {
      final rows = await _database.customSelect('SELECT * FROM $table').get();
      // ignore: avoid_print
      print('TABLE: $table');
      for (final row in rows) {
        // ignore: avoid_print
        print(row.data);
      }
    }
  }

  Future<void> close() => _database.close();

  Future<int> _insert(String sql, List<Object?> args) async {
    await _database.customStatement(sql, args);
    final row = await _database
        .customSelect('SELECT last_insert_rowid() AS id')
        .getSingle();
    return row.read<int>('id');
  }
}
