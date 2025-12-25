enum AiProvider { gemini, openai }

class AiPersona {
  final int? id;
  final String name;
  final String avatar;
  final String role;
  final String personality;
  final String systemPrompt;
  final String? bio;
  final AiProvider aiProvider;
  final double commentProbability;
  final double likeProbability;

  AiPersona({
    this.id,
    required this.name,
    required this.avatar,
    required this.role,
    required this.personality,
    required this.systemPrompt,
    this.bio,
    this.aiProvider = AiProvider.gemini,
    this.commentProbability = 0.5,
    this.likeProbability = 0.7,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'avatar': avatar,
      'role': role,
      'personality': personality,
      'systemPrompt': systemPrompt,
      'bio': bio,
      'aiProvider': aiProvider.index,
      'commentProbability': commentProbability,
      'likeProbability': likeProbability,
    };
  }

  factory AiPersona.fromMap(Map<String, dynamic> map) {
    return AiPersona(
      id: map['id'] as int?,
      name: map['name'] as String,
      avatar: map['avatar'] as String,
      role: map['role'] as String,
      personality: map['personality'] as String,
      systemPrompt: map['systemPrompt'] as String,
      bio: map['bio'] as String?,
      aiProvider: AiProvider.values[map['aiProvider'] as int? ?? 0],
      commentProbability: map['commentProbability'] as double? ?? 0.5,
      likeProbability: map['likeProbability'] as double? ?? 0.7,
    );
  }

  AiPersona copyWith({
    int? id,
    String? name,
    String? avatar,
    String? role,
    String? personality,
    String? systemPrompt,
    String? bio,
    AiProvider? aiProvider,
    double? commentProbability,
    double? likeProbability,
  }) {
    return AiPersona(
      id: id ?? this.id,
      name: name ?? this.name,
      avatar: avatar ?? this.avatar,
      role: role ?? this.role,
      personality: personality ?? this.personality,
      systemPrompt: systemPrompt ?? this.systemPrompt,
      bio: bio ?? this.bio,
      aiProvider: aiProvider ?? this.aiProvider,
      commentProbability: commentProbability ?? this.commentProbability,
      likeProbability: likeProbability ?? this.likeProbability,
    );
  }
}
