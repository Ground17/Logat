import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../database/database_helper.dart';
import 'path_helper.dart';

/// Utility class for migrating media files to permanent storage
class MediaMigration {
  static final DatabaseHelper _db = DatabaseHelper.instance;

  /// Check and migrate all post media files to permanent storage
  /// Also ensures files exist and converts full paths to filename-based storage
  static Future<void> checkAndMigratePostMedia() async {
    try {
      final posts = await _db.getAllPosts();
      final appDir = await getApplicationDocumentsDirectory();

      print('🔍 Checking ${posts.length} posts for media migration...');

      for (var post in posts) {
        bool needsUpdate = false;
        List<String> newMediaPaths = [];

        for (var mediaPath in post.mediaPaths) {
          // Extract filename from path (whether it's already a filename or full path)
          final filename = PathHelper.getFilename(mediaPath);
          final fullPath = '${appDir.path}/$filename';
          final file = File(fullPath);

          // Check if this is an old full path format (contains UUID pattern)
          final isOldFormat = mediaPath.contains('/Application/') && mediaPath != fullPath;

          if (!file.existsSync()) {
            // Try to find file with old path format
            final oldFile = File(mediaPath);
            if (oldFile.existsSync() && isOldFormat) {
              // Migrate from old UUID-based path to new filename-based path
              try {
                await oldFile.copy(fullPath);
                newMediaPaths.add(fullPath);
                needsUpdate = true;
                print('✅ Migrated from old path: $mediaPath -> $fullPath');
              } catch (e) {
                print('⚠️ Failed to migrate $mediaPath: $e');
                newMediaPaths.add(fullPath); // Use new path anyway
                needsUpdate = true;
              }
            } else {
              print('❌ Missing file: $mediaPath (expected at: $fullPath)');
              // Keep the new path format for record
              newMediaPaths.add(fullPath);
              needsUpdate = true;
            }
          } else if (mediaPath.contains('/tmp/') || mediaPath.contains('/cache/')) {
            // File is in temporary location, copy to permanent storage
            final timestamp = DateTime.now().millisecondsSinceEpoch;
            final newFilename = 'migrated_${timestamp}_$filename';
            final permanentPath = '${appDir.path}/$newFilename';

            try {
              await file.copy(permanentPath);
              newMediaPaths.add(permanentPath);
              needsUpdate = true;
              print('✅ Migrated from temp: $mediaPath -> $permanentPath');
            } catch (e) {
              print('⚠️ Failed to migrate $mediaPath: $e');
              newMediaPaths.add(fullPath); // Keep current path
            }
          } else if (isOldFormat) {
            // File exists but path is in old format, update to new format
            newMediaPaths.add(fullPath);
            needsUpdate = true;
            print('📝 Updated path format: $mediaPath -> $fullPath');
          } else {
            // File is already in correct format and location
            newMediaPaths.add(fullPath);
          }
        }

        // Update post if any paths changed
        if (needsUpdate) {
          final updatedPost = post.copyWith(mediaPaths: newMediaPaths);
          await _db.updatePost(updatedPost);
          print('📝 Updated post ${post.id} with new media paths');
        }
      }

      print('✨ Media migration check complete');
    } catch (e) {
      print('❌ Error during media migration: $e');
    }
  }

  /// Log media storage statistics
  static Future<void> logMediaStats() async {
    try {
      final posts = await _db.getAllPosts();
      final appDir = await getApplicationDocumentsDirectory();

      int totalMedia = 0;
      int existingMedia = 0;
      int missingMedia = 0;
      int tmpMedia = 0;

      for (var post in posts) {
        for (var mediaPath in post.mediaPaths) {
          totalMedia++;
          final file = File(mediaPath);

          if (file.existsSync()) {
            existingMedia++;
            if (mediaPath.contains('/tmp/') || mediaPath.contains('/cache/')) {
              tmpMedia++;
            }
          } else {
            missingMedia++;
          }
        }
      }

      print('📊 Media Statistics:');
      print('   Total media files: $totalMedia');
      print('   Existing files: $existingMedia');
      print('   Missing files: $missingMedia');
      print('   In temporary storage: $tmpMedia');
      print('   App documents directory: ${appDir.path}');
    } catch (e) {
      print('❌ Error logging media stats: $e');
    }
  }
}
