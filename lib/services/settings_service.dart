import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_settings.dart';

class SettingsService {
  static const String _keyEnabledPersonas = 'enabled_personas';
  static const String _keyCommentProbability = 'comment_probability';
  static const String _keyLikeProbability = 'like_probability';
  static const String _keyIsFirstTime = 'is_first_time';
  static const String _keyUserProfile = 'user_profile';
  static const String _keyEnableAiReactions = 'enable_ai_reactions';
  static const String _keyPreferredImageModel = 'preferred_image_model';
  static const String _keyProfileImagePath = 'profile_image_path';

  static Future<AppSettings> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();

    final isFirstTime = prefs.getBool(_keyIsFirstTime) ?? true;

    if (isFirstTime) {
      return AppSettings.defaultSettings();
    }

    final personaIdsString = prefs.getString(_keyEnabledPersonas) ?? '1,2,3,4,5,6';
    final enabledPersonaIds = personaIdsString
        .split(',')
        .where((s) => s.isNotEmpty)
        .map((s) => int.parse(s))
        .toList();

    final commentProbability = prefs.getDouble(_keyCommentProbability) ?? 0.5;
    final likeProbability = prefs.getDouble(_keyLikeProbability) ?? 0.7;
    final userProfile = prefs.getString(_keyUserProfile) ?? '';
    final enableAiReactions = prefs.getBool(_keyEnableAiReactions) ?? true;
    final preferredImageModel = AiImageModel.values[prefs.getInt(_keyPreferredImageModel) ?? 0];
    final profileImagePath = prefs.getString(_keyProfileImagePath) ?? '';

    return AppSettings(
      enabledPersonaIds: enabledPersonaIds,
      commentProbability: commentProbability,
      likeProbability: likeProbability,
      isFirstTime: false,
      userProfile: userProfile,
      enableAiReactions: enableAiReactions,
      preferredImageModel: preferredImageModel,
      profileImagePath: profileImagePath,
    );
  }

  static Future<void> saveSettings(AppSettings settings) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(
      _keyEnabledPersonas,
      settings.enabledPersonaIds.join(','),
    );
    await prefs.setDouble(_keyCommentProbability, settings.commentProbability);
    await prefs.setDouble(_keyLikeProbability, settings.likeProbability);
    await prefs.setBool(_keyIsFirstTime, settings.isFirstTime);
    await prefs.setString(_keyUserProfile, settings.userProfile);
    await prefs.setBool(_keyEnableAiReactions, settings.enableAiReactions);
    await prefs.setInt(_keyPreferredImageModel, settings.preferredImageModel.index);
    await prefs.setString(_keyProfileImagePath, settings.profileImagePath);
  }

  static Future<bool> isFirstTime() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyIsFirstTime) ?? true;
  }

  static Future<void> markAsNotFirstTime() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyIsFirstTime, false);
  }
}
