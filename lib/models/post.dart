class Post {
  final int? id;
  final List<String> mediaPaths; // Multiple media paths (photos/videos)
  final String? caption;
  final String? location;
  final double? latitude;
  final double? longitude;
  final int viewCount;
  final int likeCount;
  final bool enableAiReactions; // Whether AI can react to this post
  final DateTime createdAt;
  final DateTime updatedAt;

  Post({
    this.id,
    required this.mediaPaths,
    this.caption,
    this.location,
    this.latitude,
    this.longitude,
    this.viewCount = 0,
    this.likeCount = 0,
    this.enableAiReactions = true,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'mediaPaths': mediaPaths.join('|||'), // Use ||| as separator
      'caption': caption,
      'location': location,
      'latitude': latitude,
      'longitude': longitude,
      'viewCount': viewCount,
      'likeCount': likeCount,
      'enableAiReactions': enableAiReactions ? 1 : 0,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory Post.fromMap(Map<String, dynamic> map) {
    return Post(
      id: map['id'] as int?,
      mediaPaths: (map['mediaPaths'] as String).split('|||'),
      caption: map['caption'] as String?,
      location: map['location'] as String?,
      latitude: map['latitude'] as double?,
      longitude: map['longitude'] as double?,
      viewCount: map['viewCount'] as int? ?? 0,
      likeCount: map['likeCount'] as int? ?? 0,
      enableAiReactions: map['enableAiReactions'] == 1,
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: DateTime.parse(map['updatedAt'] as String? ?? map['createdAt'] as String),
    );
  }

  Post copyWith({
    int? id,
    List<String>? mediaPaths,
    String? caption,
    String? location,
    double? latitude,
    double? longitude,
    int? viewCount,
    int? likeCount,
    bool? enableAiReactions,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Post(
      id: id ?? this.id,
      mediaPaths: mediaPaths ?? this.mediaPaths,
      caption: caption ?? this.caption,
      location: location ?? this.location,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      viewCount: viewCount ?? this.viewCount,
      likeCount: likeCount ?? this.likeCount,
      enableAiReactions: enableAiReactions ?? this.enableAiReactions,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
