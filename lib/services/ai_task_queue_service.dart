import 'dart:async';
import 'dart:math';
import '../database/database_helper.dart';
import '../models/ai_task.dart';
import '../models/ai_persona.dart';
import '../models/post.dart';
import '../models/scheduled_notification.dart';
import '../services/ai_service.dart';
import '../services/settings_service.dart';

class AiTaskQueueService {
  static final AiTaskQueueService instance = AiTaskQueueService._init();

  AiTaskQueueService._init();

  /// Enqueue a new AI reaction task for a post
  Future<void> enqueueReactionTask(int postId) async {
    final task = AiTask(
      postId: postId,
      taskType: 'reactions',
      createdAt: DateTime.now(),
    );

    await DatabaseHelper.instance.createAiTask(task);
    print('✅ Enqueued AI reaction task for post $postId');
  }

  /// Process pending AI tasks (up to 3 in parallel)
  Future<void> processPendingTasks() async {
    final pendingTasks = await DatabaseHelper.instance.getPendingAiTasks(limit: 3);

    if (pendingTasks.isEmpty) {
      print('ℹ️ No pending AI tasks to process');
      return;
    }

    print('🔄 Processing ${pendingTasks.length} pending AI tasks in parallel...');

    // Process all tasks in parallel
    await Future.wait(
      pendingTasks.map((task) => _processTask(task)),
    );

    print('✅ Finished processing ${pendingTasks.length} tasks');
  }

  /// Process a single AI task with retry logic
  Future<void> _processTask(AiTask task) async {
    try {
      print('🤖 Processing task ${task.id} for post ${task.postId} (attempt ${task.retryCount + 1}/5)');

      // Load app settings
      final settings = await SettingsService.loadSettings();

      // Check if AI reactions are enabled
      if (!settings.enableAiReactions) {
        print('⚠️ AI reactions disabled, removing task ${task.id}');
        await DatabaseHelper.instance.deleteAiTask(task.id!);
        return;
      }

      // Get the post
      final post = await DatabaseHelper.instance.getPost(task.postId);
      if (post == null) {
        print('⚠️ Post ${task.postId} not found, removing task ${task.id}');
        await DatabaseHelper.instance.deleteAiTask(task.id!);
        return;
      }

      // Check if AI reactions are disabled for this post
      if (!post.enableAiReactions) {
        print('⚠️ AI reactions disabled for post ${task.postId}, removing task ${task.id}');
        await DatabaseHelper.instance.deleteAiTask(task.id!);
        return;
      }

      // Get enabled personas
      final allPersonas = await DatabaseHelper.instance.getAllPersonas();
      final enabledPersonas = allPersonas
          .where((p) => settings.enabledPersonaIds.contains(p.id))
          .toList();

      if (enabledPersonas.isEmpty) {
        print('⚠️ No enabled personas, removing task ${task.id}');
        await DatabaseHelper.instance.deleteAiTask(task.id!);
        return;
      }

      // Generate a single random time within 24 hours for ALL AI personas
      final randomMinutes = Random().nextInt(24 * 60); // 0 to 1440 minutes (24 hours)
      final scheduledTime = DateTime.now().add(Duration(minutes: randomMinutes));

      print('📅 Scheduled time for all AI reactions: $scheduledTime (in ${randomMinutes ~/ 60}h ${randomMinutes % 60}m)');

      // Process each enabled persona
      for (final persona in enabledPersonas) {
        await _processPersonaReaction(
          persona: persona,
          post: post,
          scheduledTime: scheduledTime,
          settings: settings,
        );
      }

      // Task completed successfully, delete it
      await DatabaseHelper.instance.deleteAiTask(task.id!);
      print('✅ Task ${task.id} completed successfully');

    } catch (e, stackTrace) {
      print('❌ Error processing task ${task.id}: $e');
      print('Stack trace: $stackTrace');

      // Update retry count
      final newRetryCount = task.retryCount + 1;

      if (newRetryCount >= 5) {
        // Max retries reached, silently delete the task
        await DatabaseHelper.instance.deleteAiTask(task.id!);
        print('🔴 Task ${task.id} failed after 5 attempts, removing silently');
      } else {
        // Update task with new retry count and error message
        final updatedTask = task.copyWith(
          retryCount: newRetryCount,
          lastAttemptAt: DateTime.now(),
          errorMessage: e.toString(),
        );
        await DatabaseHelper.instance.updateAiTask(updatedTask);

        // Calculate exponential backoff delay
        final delayMinutes = _calculateBackoffDelay(newRetryCount);
        print('⏳ Will retry task ${task.id} in $delayMinutes minutes (attempt ${newRetryCount + 1}/5)');
      }
    }
  }

  /// Process AI reaction for a single persona
  Future<void> _processPersonaReaction({
    required AiPersona persona,
    required Post post,
    required DateTime scheduledTime,
    required settings,
  }) async {
    final random = Random();

    // Determine if persona should like based on probability
    final shouldLike = random.nextDouble() < persona.likeProbability;

    if (shouldLike) {
      // Check AI's decision to like
      final aiDecision = await AiService.shouldLikePost(
        persona: persona,
        post: post,
        userProfile: settings.userProfile,
      );

      if (aiDecision) {
        // Create scheduled notification for like
        final notification = ScheduledNotification(
          postId: post.id!,
          aiPersonaId: persona.id,
          notificationType: 'like',
          scheduledTime: scheduledTime,
          createdAt: DateTime.now(),
        );
        await DatabaseHelper.instance.createScheduledNotification(notification);
        print('👍 Scheduled like from ${persona.name} at $scheduledTime');
      }
    }

    // Determine if persona should comment based on probability
    final shouldComment = random.nextDouble() < persona.commentProbability;

    if (shouldComment) {
      // Generate comment
      final comment = await AiService.generateComment(
        persona: persona,
        post: post,
        userProfile: settings.userProfile,
      );

      // Create scheduled notification for comment
      final notification = ScheduledNotification(
        postId: post.id!,
        aiPersonaId: persona.id,
        notificationType: 'comment',
        commentContent: comment,
        scheduledTime: scheduledTime,
        createdAt: DateTime.now(),
      );
      await DatabaseHelper.instance.createScheduledNotification(notification);
      print('💬 Scheduled comment from ${persona.name} at $scheduledTime');
    }
  }

  /// Calculate exponential backoff delay in minutes
  /// Attempt 1: 1min, Attempt 2: 2min, Attempt 3: 4min, Attempt 4: 8min, Attempt 5: 16min
  int _calculateBackoffDelay(int retryCount) {
    return pow(2, retryCount - 1).toInt(); // 2^0=1, 2^1=2, 2^2=4, 2^3=8, 2^4=16
  }
}
