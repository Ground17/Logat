import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/post.dart';
import '../models/comment.dart';
import '../models/like.dart';
import '../models/ai_persona.dart';
import '../models/chat_message.dart';
import '../data/default_personas.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('social_media.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 4,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Migrate from single mediaPath to mediaPaths
      await db.execute('ALTER TABLE posts RENAME TO posts_old');
      await db.execute('''
        CREATE TABLE posts (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          mediaPaths TEXT NOT NULL,
          caption TEXT,
          location TEXT,
          viewCount INTEGER DEFAULT 0,
          likeCount INTEGER DEFAULT 0,
          enableAiReactions INTEGER DEFAULT 1,
          createdAt TEXT NOT NULL
        )
      ''');

      // Copy old data
      await db.execute('''
        INSERT INTO posts (id, mediaPaths, caption, location, viewCount, likeCount, enableAiReactions, createdAt)
        SELECT id, mediaPath, caption, location, viewCount, likeCount, 1, createdAt FROM posts_old
      ''');

      await db.execute('DROP TABLE posts_old');
    }

    if (oldVersion < 3) {
      // Add new fields to ai_personas table
      await db.execute('ALTER TABLE ai_personas ADD COLUMN aiProvider INTEGER DEFAULT 0');
      await db.execute('ALTER TABLE ai_personas ADD COLUMN commentProbability REAL DEFAULT 0.5');
      await db.execute('ALTER TABLE ai_personas ADD COLUMN likeProbability REAL DEFAULT 0.7');
    }

    if (oldVersion < 4) {
      // Add new fields to posts table
      await db.execute('ALTER TABLE posts ADD COLUMN latitude REAL');
      await db.execute('ALTER TABLE posts ADD COLUMN longitude REAL');
      await db.execute('ALTER TABLE posts ADD COLUMN updatedAt TEXT');

      // Set updatedAt to createdAt for existing posts
      await db.execute('UPDATE posts SET updatedAt = createdAt WHERE updatedAt IS NULL');
    }
  }

  Future<void> _createDB(Database db, int version) async {
    // Posts table
    await db.execute('''
      CREATE TABLE posts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        mediaPaths TEXT NOT NULL,
        caption TEXT,
        location TEXT,
        latitude REAL,
        longitude REAL,
        viewCount INTEGER DEFAULT 0,
        likeCount INTEGER DEFAULT 0,
        enableAiReactions INTEGER DEFAULT 1,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL
      )
    ''');

    // Comments 테이블
    await db.execute('''
      CREATE TABLE comments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        postId INTEGER NOT NULL,
        aiPersonaId INTEGER NOT NULL,
        content TEXT NOT NULL,
        createdAt TEXT NOT NULL,
        FOREIGN KEY (postId) REFERENCES posts (id) ON DELETE CASCADE,
        FOREIGN KEY (aiPersonaId) REFERENCES ai_personas (id)
      )
    ''');

    // Likes 테이블
    await db.execute('''
      CREATE TABLE likes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        postId INTEGER NOT NULL,
        aiPersonaId INTEGER NOT NULL,
        createdAt TEXT NOT NULL,
        UNIQUE(postId, aiPersonaId),
        FOREIGN KEY (postId) REFERENCES posts (id) ON DELETE CASCADE,
        FOREIGN KEY (aiPersonaId) REFERENCES ai_personas (id)
      )
    ''');

    // AI Personas 테이블
    await db.execute('''
      CREATE TABLE ai_personas (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        avatar TEXT NOT NULL,
        role TEXT NOT NULL,
        personality TEXT NOT NULL,
        systemPrompt TEXT NOT NULL,
        bio TEXT,
        aiProvider INTEGER DEFAULT 0,
        commentProbability REAL DEFAULT 0.5,
        likeProbability REAL DEFAULT 0.7
      )
    ''');

    // Chat Messages 테이블
    await db.execute('''
      CREATE TABLE chat_messages (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        aiPersonaId INTEGER NOT NULL,
        isUser INTEGER NOT NULL,
        content TEXT NOT NULL,
        createdAt TEXT NOT NULL,
        FOREIGN KEY (aiPersonaId) REFERENCES ai_personas (id)
      )
    ''');

    // 기본 AI 페르소나 삽입
    final personas = getDefaultPersonas();
    for (var persona in personas) {
      await db.insert('ai_personas', persona.toMap());
    }
  }

  // ========== Posts ==========
  Future<int> createPost(Post post) async {
    final db = await database;
    return await db.insert('posts', post.toMap());
  }

  Future<List<Post>> getAllPosts() async {
    final db = await database;
    final result = await db.query(
      'posts',
      orderBy: 'createdAt DESC',
    );
    return result.map((map) => Post.fromMap(map)).toList();
  }

  Future<Post?> getPost(int id) async {
    final db = await database;
    final result = await db.query(
      'posts',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (result.isEmpty) return null;
    return Post.fromMap(result.first);
  }

  Future<int> updatePost(Post post) async {
    final db = await database;
    return await db.update(
      'posts',
      post.toMap(),
      where: 'id = ?',
      whereArgs: [post.id],
    );
  }

  Future<int> deletePost(int id) async {
    final db = await database;
    return await db.delete(
      'posts',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> incrementViewCount(int postId) async {
    final db = await database;
    return await db.rawUpdate(
      'UPDATE posts SET viewCount = viewCount + 1 WHERE id = ?',
      [postId],
    );
  }

  // ========== Comments ==========
  Future<int> createComment(Comment comment) async {
    final db = await database;
    return await db.insert('comments', comment.toMap());
  }

  Future<List<Comment>> getCommentsByPost(int postId) async {
    final db = await database;
    final result = await db.query(
      'comments',
      where: 'postId = ?',
      whereArgs: [postId],
      orderBy: 'createdAt ASC',
    );
    return result.map((map) => Comment.fromMap(map)).toList();
  }

  Future<int> deleteComment(int id) async {
    final db = await database;
    return await db.delete(
      'comments',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ========== Likes ==========
  Future<int> createLike(Like like) async {
    final db = await database;
    try {
      final id = await db.insert('likes', like.toMap());
      // 좋아요 수 증가
      await db.rawUpdate(
        'UPDATE posts SET likeCount = likeCount + 1 WHERE id = ?',
        [like.postId],
      );
      return id;
    } catch (e) {
      return -1; // 이미 좋아요를 눌렀을 경우
    }
  }

  Future<int> deleteLike(int postId, int aiPersonaId) async {
    final db = await database;
    final result = await db.delete(
      'likes',
      where: 'postId = ? AND aiPersonaId = ?',
      whereArgs: [postId, aiPersonaId],
    );
    if (result > 0) {
      // 좋아요 수 감소
      await db.rawUpdate(
        'UPDATE posts SET likeCount = likeCount - 1 WHERE id = ?',
        [postId],
      );
    }
    return result;
  }

  Future<List<Like>> getLikesByPost(int postId) async {
    final db = await database;
    final result = await db.query(
      'likes',
      where: 'postId = ?',
      whereArgs: [postId],
      orderBy: 'createdAt DESC',
    );
    return result.map((map) => Like.fromMap(map)).toList();
  }

  Future<bool> hasLiked(int postId, int aiPersonaId) async {
    final db = await database;
    final result = await db.query(
      'likes',
      where: 'postId = ? AND aiPersonaId = ?',
      whereArgs: [postId, aiPersonaId],
    );
    return result.isNotEmpty;
  }

  // ========== AI Personas ==========
  Future<List<AiPersona>> getAllPersonas() async {
    final db = await database;
    final result = await db.query('ai_personas');
    return result.map((map) => AiPersona.fromMap(map)).toList();
  }

  Future<AiPersona?> getPersona(int id) async {
    final db = await database;
    final result = await db.query(
      'ai_personas',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (result.isEmpty) return null;
    return AiPersona.fromMap(result.first);
  }

  Future<int> createPersona(AiPersona persona) async {
    final db = await database;
    return await db.insert('ai_personas', persona.toMap());
  }

  Future<int> updatePersona(AiPersona persona) async {
    final db = await database;
    return await db.update(
      'ai_personas',
      persona.toMap(),
      where: 'id = ?',
      whereArgs: [persona.id],
    );
  }

  Future<int> deletePersona(int id) async {
    final db = await database;
    return await db.delete(
      'ai_personas',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ========== Chat Messages ==========
  Future<int> createChatMessage(ChatMessage message) async {
    final db = await database;
    return await db.insert('chat_messages', message.toMap());
  }

  Future<List<ChatMessage>> getChatMessages(int aiPersonaId) async {
    final db = await database;
    final result = await db.query(
      'chat_messages',
      where: 'aiPersonaId = ?',
      whereArgs: [aiPersonaId],
      orderBy: 'createdAt ASC',
    );
    return result.map((map) => ChatMessage.fromMap(map)).toList();
  }

  Future<int> deleteChatMessages(int aiPersonaId) async {
    final db = await database;
    return await db.delete(
      'chat_messages',
      where: 'aiPersonaId = ?',
      whereArgs: [aiPersonaId],
    );
  }

  // ========== Utility ==========
  Future<void> close() async {
    final db = await database;
    await db.close();
  }
}
