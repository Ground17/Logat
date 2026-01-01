import '../utils/path_helper.dart';

class Post {
  final int? id;
  final String? title; // Post title (required if no media/location)
  final List<String> mediaPaths; // Multiple media paths (photos/videos) - stored as full paths in memory
  final String? caption;
  final String? locationName; // Location name/address (e.g., "Statue of Liberty")
  final double? latitude;
  final double? longitude;
  final DateTime? postDate; // The date when the post content happened (vs createdAt which is when posted)
  final String? tag; // Color tag: null, 'red', 'orange', 'yellow', 'green', 'blue', 'purple'
  final int viewCount;
  final int likeCount;
  final bool enableAiReactions; // Whether AI can react to this post
  final DateTime createdAt;
  final DateTime updatedAt;

  Post({
    this.id,
    this.title,
    required this.mediaPaths,
    this.caption,
    this.locationName,
    this.latitude,
    this.longitude,
    this.postDate,
    this.tag,
    this.viewCount = 0,
    this.likeCount = 0,
    this.enableAiReactions = true,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    // Convert full paths to filenames for storage to avoid iOS simulator UUID issues
    final filenames = PathHelper.pathsToFilenames(mediaPaths);

    return {
      'id': id,
      'title': title,
      'mediaPaths': filenames.isEmpty ? '' : filenames.join('|||'), // Store only filenames
      'caption': caption,
      'locationName': locationName,
      'latitude': latitude,
      'longitude': longitude,
      'postDate': postDate?.toIso8601String(),
      'tag': tag,
      'viewCount': viewCount,
      'likeCount': likeCount,
      'enableAiReactions': enableAiReactions ? 1 : 0,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  /// Create Post from database map (async to reconstruct full paths from filenames)
  static Future<Post> fromMap(Map<String, dynamic> map) async {
    final mediaPathsString = map['mediaPaths'] as String;
    final filenames = mediaPathsString.isEmpty ? <String>[] : mediaPathsString.split('|||');

    // Reconstruct full paths from filenames
    final fullPaths = await PathHelper.filenamesToPaths(filenames);

    return Post(
      id: map['id'] as int?,
      title: map['title'] as String?,
      mediaPaths: fullPaths,
      caption: map['caption'] as String?,
      locationName: map['locationName'] as String?,
      latitude: map['latitude'] as double?,
      longitude: map['longitude'] as double?,
      postDate: map['postDate'] != null ? DateTime.parse(map['postDate'] as String) : null,
      tag: map['tag'] as String?,
      viewCount: map['viewCount'] as int? ?? 0,
      likeCount: map['likeCount'] as int? ?? 0,
      enableAiReactions: map['enableAiReactions'] == 1,
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: DateTime.parse(map['updatedAt'] as String? ?? map['createdAt'] as String),
    );
  }

  Post copyWith({
    int? id,
    String? title,
    List<String>? mediaPaths,
    String? caption,
    String? locationName,
    double? latitude,
    double? longitude,
    DateTime? postDate,
    String? tag,
    int? viewCount,
    int? likeCount,
    bool? enableAiReactions,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Post(
      id: id ?? this.id,
      title: title ?? this.title,
      mediaPaths: mediaPaths ?? this.mediaPaths,
      caption: caption ?? this.caption,
      locationName: locationName ?? this.locationName,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      postDate: postDate ?? this.postDate,
      tag: tag ?? this.tag,
      viewCount: viewCount ?? this.viewCount,
      likeCount: likeCount ?? this.likeCount,
      enableAiReactions: enableAiReactions ?? this.enableAiReactions,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
