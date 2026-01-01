import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

/// Reusable widget for displaying persona avatars
/// Handles both emoji and image file avatars
class AvatarWidget extends StatelessWidget {
  final String avatar;
  final double size;
  final Color? backgroundColor;

  const AvatarWidget({
    super.key,
    required this.avatar,
    this.size = 40,
    this.backgroundColor,
  });

  /// Check if avatar is a file path (either full path or just filename)
  bool _isImagePath(String text) {
    return (text.contains('/') || text.startsWith('avatar_')) &&
           (text.endsWith('.png') ||
            text.endsWith('.jpg') ||
            text.endsWith('.jpeg') ||
            text.endsWith('.webp'));
  }

  /// Get full file path from avatar string
  Future<String> _getFullPath(String avatar) async {
    // If it's already a full path, return it
    if (avatar.contains('/')) {
      return avatar;
    }
    // Otherwise, combine with app documents directory
    final appDir = await getApplicationDocumentsDirectory();
    return '${appDir.path}/$avatar';
  }

  @override
  Widget build(BuildContext context) {
    final isImage = _isImagePath(avatar);

    if (isImage) {
      return FutureBuilder<String>(
        future: _getFullPath(avatar),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            // Loading
            return Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: backgroundColor ?? Theme.of(context).primaryColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: SizedBox(
                  width: size * 0.4,
                  height: size * 0.4,
                  child: const CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            );
          }

          final fullPath = snapshot.data!;
          final fileExists = File(fullPath).existsSync();

          if (!fileExists) {
            // File doesn't exist, show placeholder with error
            return Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: backgroundColor ?? Theme.of(context).primaryColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.red.withValues(alpha: 0.3),
                  width: 2,
                ),
              ),
              child: Icon(
                Icons.image_not_supported,
                size: size * 0.5,
                color: Colors.grey,
              ),
            );
          }

          // Display image avatar
          return Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: backgroundColor ?? Theme.of(context).primaryColor.withValues(alpha: 0.2),
                width: 1,
              ),
            ),
            child: ClipOval(
              child: Image.file(
                File(fullPath),
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return _buildErrorWidget(context);
                },
              ),
            ),
          );
        },
      );
    } else {
      // Display emoji avatar
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: backgroundColor ?? Theme.of(context).primaryColor.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Text(
            avatar,
            style: TextStyle(fontSize: size * 0.5),
          ),
        ),
      );
    }
  }

  Widget _buildErrorWidget(BuildContext context) {
    return Container(
      color: backgroundColor ?? Theme.of(context).primaryColor.withValues(alpha: 0.1),
      child: Icon(
        Icons.broken_image,
        size: size * 0.5,
        color: Colors.grey,
      ),
    );
  }
}

/// Circle avatar variant for use in CircleAvatar widgets
class CircleAvatarWidget extends StatelessWidget {
  final String avatar;
  final double radius;
  final Color? backgroundColor;

  const CircleAvatarWidget({
    super.key,
    required this.avatar,
    this.radius = 20,
    this.backgroundColor,
  });

  /// Check if avatar is a file path (either full path or just filename)
  bool _isImagePath(String text) {
    return (text.contains('/') || text.startsWith('avatar_')) &&
           (text.endsWith('.png') ||
            text.endsWith('.jpg') ||
            text.endsWith('.jpeg') ||
            text.endsWith('.webp'));
  }

  /// Get full file path from avatar string
  Future<String> _getFullPath(String avatar) async {
    // If it's already a full path, return it
    if (avatar.contains('/')) {
      return avatar;
    }
    // Otherwise, combine with app documents directory
    final appDir = await getApplicationDocumentsDirectory();
    return '${appDir.path}/$avatar';
  }

  @override
  Widget build(BuildContext context) {
    final isImage = _isImagePath(avatar);

    if (isImage) {
      return FutureBuilder<String>(
        future: _getFullPath(avatar),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            // Loading
            return CircleAvatar(
              radius: radius,
              backgroundColor: backgroundColor ?? Theme.of(context).primaryColor.withValues(alpha: 0.1),
              child: SizedBox(
                width: radius * 0.8,
                height: radius * 0.8,
                child: const CircularProgressIndicator(strokeWidth: 2),
              ),
            );
          }

          final fullPath = snapshot.data!;
          final fileExists = File(fullPath).existsSync();

          // Display image avatar
          return CircleAvatar(
            radius: radius,
            backgroundColor: backgroundColor ?? Theme.of(context).primaryColor.withValues(alpha: 0.1),
            backgroundImage: fileExists ? FileImage(File(fullPath)) : null,
            child: !fileExists
                ? Icon(
                    Icons.image_not_supported,
                    size: radius,
                    color: Colors.grey,
                  )
                : null,
          );
        },
      );
    } else {
      // Display emoji avatar
      return CircleAvatar(
        radius: radius,
        backgroundColor: backgroundColor ?? Theme.of(context).primaryColor.withValues(alpha: 0.1),
        child: Text(
          avatar,
          style: TextStyle(fontSize: radius * 1.2),
        ),
      );
    }
  }
}
