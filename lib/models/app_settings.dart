class AppSettings {
  final List<int> enabledPersonaIds;
  final double commentProbability;
  final double likeProbability;
  final bool isFirstTime;
  final String userProfile; // User's bio/profile for AI context
  final bool enableAiReactions; // Default setting for enabling AI reactions on new posts

  AppSettings({
    required this.enabledPersonaIds,
    required this.commentProbability,
    required this.likeProbability,
    this.isFirstTime = true,
    this.userProfile = '',
    this.enableAiReactions = true,
  });

  factory AppSettings.defaultSettings() {
    return AppSettings(
      enabledPersonaIds: [1, 2, 3, 4, 5, 6],
      commentProbability: 0.5,
      likeProbability: 0.7,
      isFirstTime: true,
      userProfile: '',
      enableAiReactions: true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'enabledPersonaIds': enabledPersonaIds.join(','),
      'commentProbability': commentProbability,
      'likeProbability': likeProbability,
      'isFirstTime': isFirstTime ? 1 : 0,
      'userProfile': userProfile,
      'enableAiReactions': enableAiReactions ? 1 : 0,
    };
  }

  factory AppSettings.fromMap(Map<String, dynamic> map) {
    return AppSettings(
      enabledPersonaIds: (map['enabledPersonaIds'] as String)
          .split(',')
          .where((s) => s.isNotEmpty)
          .map((s) => int.parse(s))
          .toList(),
      commentProbability: map['commentProbability'] as double,
      likeProbability: map['likeProbability'] as double,
      isFirstTime: map['isFirstTime'] == 1,
      userProfile: map['userProfile'] as String? ?? '',
      enableAiReactions: map['enableAiReactions'] == 1 || map['enableAiReactions'] == null,
    );
  }

  AppSettings copyWith({
    List<int>? enabledPersonaIds,
    double? commentProbability,
    double? likeProbability,
    bool? isFirstTime,
    String? userProfile,
    bool? enableAiReactions,
  }) {
    return AppSettings(
      enabledPersonaIds: enabledPersonaIds ?? this.enabledPersonaIds,
      commentProbability: commentProbability ?? this.commentProbability,
      likeProbability: likeProbability ?? this.likeProbability,
      isFirstTime: isFirstTime ?? this.isFirstTime,
      userProfile: userProfile ?? this.userProfile,
      enableAiReactions: enableAiReactions ?? this.enableAiReactions,
    );
  }
}
