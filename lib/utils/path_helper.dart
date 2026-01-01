import 'dart:io';
import 'package:path_provider/path_provider.dart';

/// Utility class for managing media file paths
/// Stores only filenames in database to avoid iOS simulator UUID issues
class PathHelper {
  /// Extract filename from full path
  static String getFilename(String fullPath) {
    return fullPath.split('/').last;
  }

  /// Reconstruct full path from filename using current app directory
  static Future<String> getFullPath(String filename) async {
    final appDir = await getApplicationDocumentsDirectory();
    return '${appDir.path}/$filename';
  }

  /// Convert list of full paths to filenames
  static List<String> pathsToFilenames(List<String> fullPaths) {
    return fullPaths.map((p) => getFilename(p)).toList();
  }

  /// Convert list of filenames to full paths
  static Future<List<String>> filenamesToPaths(List<String> filenames) async {
    final appDir = await getApplicationDocumentsDirectory();
    return filenames.map((f) => '${appDir.path}/$f').toList();
  }

  /// Check if a path looks like a filename (no directory separators)
  static bool isFilename(String pathOrFilename) {
    return !pathOrFilename.contains('/') && !pathOrFilename.contains('\\');
  }

  /// Check if file exists at the given path
  static Future<bool> fileExists(String fullPath) async {
    return File(fullPath).existsSync();
  }

  /// Migrate a full path to filename if needed
  /// Returns the filename if path contains directory separators, otherwise returns as-is
  static String migrateToFilename(String pathOrFilename) {
    if (isFilename(pathOrFilename)) {
      return pathOrFilename;
    }
    return getFilename(pathOrFilename);
  }

  /// Copy file to app documents directory and return the filename
  static Future<String> copyToAppDirectory(String sourcePath) async {
    final appDir = await getApplicationDocumentsDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final basename = getFilename(sourcePath);
    final filename = 'post_${timestamp}_$basename';
    final destinationPath = '${appDir.path}/$filename';

    await File(sourcePath).copy(destinationPath);
    return filename;
  }
}
