import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class DiaryFilter {
  final String searchText;
  final bool similarDate; // selectedDate ±7 days (year-agnostic)
  final bool favoritesOnly;
  final bool hasLocation;
  final bool hasPhoto;
  final bool hasVideo;
  final bool isMilestoneDay; // Only N×100 day milestone events
  final Set<int> colorFilters; // Color.value set; empty = no color filter

  const DiaryFilter({
    this.searchText = '',
    this.similarDate = false,
    this.favoritesOnly = false,
    this.hasLocation = false,
    this.hasPhoto = false,
    this.hasVideo = false,
    this.isMilestoneDay = false,
    this.colorFilters = const {},
  });

  DiaryFilter copyWith({
    String? searchText,
    bool? similarDate,
    bool? favoritesOnly,
    bool? hasLocation,
    bool? hasPhoto,
    bool? hasVideo,
    bool? isMilestoneDay,
    Set<int>? colorFilters,
  }) {
    return DiaryFilter(
      searchText: searchText ?? this.searchText,
      similarDate: similarDate ?? this.similarDate,
      favoritesOnly: favoritesOnly ?? this.favoritesOnly,
      hasLocation: hasLocation ?? this.hasLocation,
      hasPhoto: hasPhoto ?? this.hasPhoto,
      hasVideo: hasVideo ?? this.hasVideo,
      isMilestoneDay: isMilestoneDay ?? this.isMilestoneDay,
      colorFilters: colorFilters ?? this.colorFilters,
    );
  }

  static const _keySearch = 'df_search';
  static const _keySimilarDate = 'df_similar_date';
  static const _keyFavoritesOnly = 'df_favorites_only';
  static const _keyHasLocation = 'df_has_location';
  static const _keyHasPhoto = 'df_has_photo';
  static const _keyHasVideo = 'df_has_video';
  static const _keyIsMilestoneDay = 'df_milestone_day';
  static const _keyColorFilters = 'df_color_filters';

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keySearch, searchText);
    await prefs.setBool(_keySimilarDate, similarDate);
    await prefs.setBool(_keyFavoritesOnly, favoritesOnly);
    await prefs.setBool(_keyHasLocation, hasLocation);
    await prefs.setBool(_keyHasPhoto, hasPhoto);
    await prefs.setBool(_keyHasVideo, hasVideo);
    await prefs.setBool(_keyIsMilestoneDay, isMilestoneDay);
    await prefs.setString(_keyColorFilters, jsonEncode(colorFilters.toList()));
  }

  static Future<DiaryFilter> load() async {
    final prefs = await SharedPreferences.getInstance();
    Set<int> colorFilters = const {};
    final colorJson = prefs.getString(_keyColorFilters);
    if (colorJson != null) {
      try {
        colorFilters = (jsonDecode(colorJson) as List).cast<int>().toSet();
      } catch (_) {}
    }
    return DiaryFilter(
      searchText: prefs.getString(_keySearch) ?? '',
      similarDate: prefs.getBool(_keySimilarDate) ?? false,
      favoritesOnly: prefs.getBool(_keyFavoritesOnly) ?? false,
      hasLocation: prefs.getBool(_keyHasLocation) ?? false,
      hasPhoto: prefs.getBool(_keyHasPhoto) ?? false,
      hasVideo: prefs.getBool(_keyHasVideo) ?? false,
      isMilestoneDay: prefs.getBool(_keyIsMilestoneDay) ?? false,
      colorFilters: colorFilters,
    );
  }

  bool get isEmpty =>
      searchText.isEmpty &&
      !similarDate &&
      !favoritesOnly &&
      !hasLocation &&
      !hasPhoto &&
      !hasVideo &&
      !isMilestoneDay &&
      colorFilters.isEmpty;
}
