import 'package:shared_preferences/shared_preferences.dart';

class DiaryFilter {
  final String searchText;
  final bool similarDate; // selectedDate ±7 days (year-agnostic)
  final bool favoritesOnly;
  final bool hasLocation;
  final bool hasMedia;

  const DiaryFilter({
    this.searchText = '',
    this.similarDate = false,
    this.favoritesOnly = false,
    this.hasLocation = false,
    this.hasMedia = false,
  });

  DiaryFilter copyWith({
    String? searchText,
    bool? similarDate,
    bool? favoritesOnly,
    bool? hasLocation,
    bool? hasMedia,
  }) {
    return DiaryFilter(
      searchText: searchText ?? this.searchText,
      similarDate: similarDate ?? this.similarDate,
      favoritesOnly: favoritesOnly ?? this.favoritesOnly,
      hasLocation: hasLocation ?? this.hasLocation,
      hasMedia: hasMedia ?? this.hasMedia,
    );
  }

  static const _keySearch = 'df_search';
  static const _keySimilarDate = 'df_similar_date';
  static const _keyFavoritesOnly = 'df_favorites_only';
  static const _keyHasLocation = 'df_has_location';
  static const _keyHasMedia = 'df_has_media';

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keySearch, searchText);
    await prefs.setBool(_keySimilarDate, similarDate);
    await prefs.setBool(_keyFavoritesOnly, favoritesOnly);
    await prefs.setBool(_keyHasLocation, hasLocation);
    await prefs.setBool(_keyHasMedia, hasMedia);
  }

  static Future<DiaryFilter> load() async {
    final prefs = await SharedPreferences.getInstance();
    return DiaryFilter(
      searchText: prefs.getString(_keySearch) ?? '',
      similarDate: prefs.getBool(_keySimilarDate) ?? false,
      favoritesOnly: prefs.getBool(_keyFavoritesOnly) ?? false,
      hasLocation: prefs.getBool(_keyHasLocation) ?? false,
      hasMedia: prefs.getBool(_keyHasMedia) ?? false,
    );
  }

  bool get isEmpty =>
      searchText.isEmpty &&
      !similarDate &&
      !favoritesOnly &&
      !hasLocation &&
      !hasMedia;
}
