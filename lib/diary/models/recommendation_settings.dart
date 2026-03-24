/// AI diary recommendation settings managed by the user in settings
class RecommendationSettings {
  const RecommendationSettings({
    this.enabled = true,
    this.model = RecommendationModel.geminiFlash,
    this.format = RecommendationFormat.brief,
    this.promptStyle =
        'In a warm and natural tone, write a sentence that brings the moment in the photo to mind.',
    this.notificationEnabled = true,
    this.notificationHour = 20,
    this.notificationMinute = 0,
    this.backgroundIndexingEnabled = false,
  });

  final bool enabled;
  final RecommendationModel model;
  final RecommendationFormat format;

  /// Style instruction the user enters directly to guide the AI
  final String promptStyle;

  final bool notificationEnabled;
  final int notificationHour;
  final int notificationMinute;
  final bool backgroundIndexingEnabled;

  static const _keyEnabled = 'rec_enabled';
  static const _keyModel = 'rec_model';
  static const _keyFormat = 'rec_format';
  static const _keyPromptStyle = 'rec_prompt_style';
  static const _keyNotifEnabled = 'rec_notif_enabled';
  static const _keyNotifHour = 'rec_notif_hour';
  static const _keyNotifMinute = 'rec_notif_minute';
  static const _keyBgIndexing = 'rec_bg_indexing';

  Map<String, dynamic> toPrefsMap() => {
        _keyEnabled: enabled,
        _keyModel: model.name,
        _keyFormat: format.name,
        _keyPromptStyle: promptStyle,
        _keyNotifEnabled: notificationEnabled,
        _keyNotifHour: notificationHour,
        _keyNotifMinute: notificationMinute,
        _keyBgIndexing: backgroundIndexingEnabled,
      };

  static RecommendationSettings fromPrefsMap(Map<String, dynamic> map) {
    return RecommendationSettings(
      enabled: map[_keyEnabled] as bool? ?? true,
      model: RecommendationModel.values.firstWhere(
        (e) => e.name == map[_keyModel],
        orElse: () => RecommendationModel.geminiFlash,
      ),
      format: RecommendationFormat.values.firstWhere(
        (e) => e.name == map[_keyFormat],
        orElse: () => RecommendationFormat.brief,
      ),
      promptStyle: map[_keyPromptStyle] as String? ??
          'In a warm and natural tone, write a sentence that brings the moment in the photo to mind.',
      notificationEnabled: map[_keyNotifEnabled] as bool? ?? true,
      notificationHour: map[_keyNotifHour] as int? ?? 20,
      notificationMinute: map[_keyNotifMinute] as int? ?? 0,
      backgroundIndexingEnabled: map[_keyBgIndexing] as bool? ?? false,
    );
  }

  RecommendationSettings copyWith({
    bool? enabled,
    RecommendationModel? model,
    RecommendationFormat? format,
    String? promptStyle,
    bool? notificationEnabled,
    int? notificationHour,
    int? notificationMinute,
    bool? backgroundIndexingEnabled,
  }) {
    return RecommendationSettings(
      enabled: enabled ?? this.enabled,
      model: model ?? this.model,
      format: format ?? this.format,
      promptStyle: promptStyle ?? this.promptStyle,
      notificationEnabled: notificationEnabled ?? this.notificationEnabled,
      notificationHour: notificationHour ?? this.notificationHour,
      notificationMinute: notificationMinute ?? this.notificationMinute,
      backgroundIndexingEnabled:
          backgroundIndexingEnabled ?? this.backgroundIndexingEnabled,
    );
  }
}

enum RecommendationModel {
  geminiFlash;

  String get displayName {
    switch (this) {
      case geminiFlash:
        return 'Gemini Flash';
    }
  }

  String get modelId {
    switch (this) {
      case geminiFlash:
        return 'gemini-3-flash-preview';
    }
  }
}

enum RecommendationFormat {
  brief,
  detailed,
  creative;

  String get displayName {
    switch (this) {
      case brief:
        return 'Brief (1-2 sentences)';
      case detailed:
        return 'Detailed (3-5 sentences)';
      case creative:
        return 'Creative (poetic)';
    }
  }

  String get instruction {
    switch (this) {
      case brief:
        return 'briefly in 1-2 sentences';
      case detailed:
        return 'in detail with 3-5 sentences';
      case creative:
        return 'in a poetic and evocative way';
    }
  }
}

/// A single generated recommendation result
class DiaryRecommendation {
  const DiaryRecommendation({
    required this.title,
    required this.body,
    required this.source,
    this.eventId,
  });

  final String title;
  final String body;
  final RecommendationSource source;
  final String? eventId;
}

enum RecommendationSource {
  recentPhoto,
  onThisDay,
  locationCluster;

  String get label {
    switch (this) {
      case recentPhoto:
        return 'Recent photo';
      case onThisDay:
        return 'On this day';
      case locationCluster:
        return 'Frequent location';
    }
  }
}
