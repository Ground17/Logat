import 'ai_persona.dart';

class AppSettings {
  final List<int> enabledPersonaIds;
  final AiProvider aiProvider;
  final double commentProbability;
  final double likeProbability;
  final bool isFirstTime;

  AppSettings({
    required this.enabledPersonaIds,
    required this.aiProvider,
    required this.commentProbability,
    required this.likeProbability,
    this.isFirstTime = true,
  });

  factory AppSettings.defaultSettings() {
    return AppSettings(
      enabledPersonaIds: [1, 2, 3, 4, 5, 6],
      aiProvider: AiProvider.gemini,
      commentProbability: 0.5,
      likeProbability: 0.7,
      isFirstTime: true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'enabledPersonaIds': enabledPersonaIds.join(','),
      'aiProvider': aiProvider.index,
      'commentProbability': commentProbability,
      'likeProbability': likeProbability,
      'isFirstTime': isFirstTime ? 1 : 0,
    };
  }

  factory AppSettings.fromMap(Map<String, dynamic> map) {
    return AppSettings(
      enabledPersonaIds: (map['enabledPersonaIds'] as String)
          .split(',')
          .where((s) => s.isNotEmpty)
          .map((s) => int.parse(s))
          .toList(),
      aiProvider: AiProvider.values[map['aiProvider'] as int],
      commentProbability: map['commentProbability'] as double,
      likeProbability: map['likeProbability'] as double,
      isFirstTime: map['isFirstTime'] == 1,
    );
  }

  AppSettings copyWith({
    List<int>? enabledPersonaIds,
    AiProvider? aiProvider,
    double? commentProbability,
    double? likeProbability,
    bool? isFirstTime,
  }) {
    return AppSettings(
      enabledPersonaIds: enabledPersonaIds ?? this.enabledPersonaIds,
      aiProvider: aiProvider ?? this.aiProvider,
      commentProbability: commentProbability ?? this.commentProbability,
      likeProbability: likeProbability ?? this.likeProbability,
      isFirstTime: isFirstTime ?? this.isFirstTime,
    );
  }
}
