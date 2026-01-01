enum AiModel {
  gemini3FlashPreview,
  gemini3ProPreview,
  gpt51,
  gpt52,
}

extension AiModelExtension on AiModel {
  String get displayName {
    switch (this) {
      case AiModel.gemini3FlashPreview:
        return 'Gemini 3 Flash Preview';
      case AiModel.gemini3ProPreview:
        return 'Gemini 3 Pro Preview';
      case AiModel.gpt51:
        return 'GPT-5.1';
      case AiModel.gpt52:
        return 'GPT-5.2';
    }
  }

  String get modelId {
    switch (this) {
      case AiModel.gemini3FlashPreview:
        return 'gemini-3-flash-preview';
      case AiModel.gemini3ProPreview:
        return 'gemini-3-pro-preview';
      case AiModel.gpt51:
        return 'gpt-5.1';
      case AiModel.gpt52:
        return 'gpt-5.2';
    }
  }

  bool get isGemini {
    return this == AiModel.gemini3FlashPreview || this == AiModel.gemini3ProPreview;
  }

  bool get isOpenAI {
    return this == AiModel.gpt51 || this == AiModel.gpt52;
  }
}

class AiPersona {
  final int? id;
  final String name;
  final String avatar;
  final String role;
  final String personality;
  final String systemPrompt;
  final String? bio;
  final AiModel aiModel;
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
    this.aiModel = AiModel.gemini3FlashPreview,
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
      'aiModel': aiModel.index,
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
      aiModel: AiModel.values[map['aiModel'] as int? ?? 0],
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
    AiModel? aiModel,
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
      aiModel: aiModel ?? this.aiModel,
      commentProbability: commentProbability ?? this.commentProbability,
      likeProbability: likeProbability ?? this.likeProbability,
    );
  }
}
