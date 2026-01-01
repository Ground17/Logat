import 'dart:io';
import 'package:flutter/material.dart';

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

  /// Check if avatar is a file path
  bool _isImagePath(String text) {
    return text.contains('/') &&
           (text.endsWith('.png') ||
            text.endsWith('.jpg') ||
            text.endsWith('.jpeg') ||
            text.endsWith('.webp'));
  }

  @override
  Widget build(BuildContext context) {
    final isImage = _isImagePath(avatar);

    if (isImage) {
      final fileExists = File(avatar).existsSync();

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
            File(avatar),
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return _buildErrorWidget(context);
            },
          ),
        ),
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

  /// Check if avatar is a file path
  bool _isImagePath(String text) {
    return text.contains('/') &&
           (text.endsWith('.png') ||
            text.endsWith('.jpg') ||
            text.endsWith('.jpeg') ||
            text.endsWith('.webp'));
  }

  @override
  Widget build(BuildContext context) {
    final isImage = _isImagePath(avatar);

    if (isImage) {
      final fileExists = File(avatar).existsSync();

      // Display image avatar
      return CircleAvatar(
        radius: radius,
        backgroundColor: backgroundColor ?? Theme.of(context).primaryColor.withValues(alpha: 0.1),
        backgroundImage: fileExists ? FileImage(File(avatar)) : null,
        child: !fileExists
            ? Icon(
                Icons.image_not_supported,
                size: radius,
                color: Colors.grey,
              )
            : null,
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
