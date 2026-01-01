import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/post.dart';
import '../database/database_helper.dart';
import '../widgets/video_player_widget.dart';
import 'post_detail_screen.dart';
import 'create_post_screen.dart';
import 'friends_screen.dart';
import 'settings_screen.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({Key? key}) : super(key: key);

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

enum ViewMode { list, map }

enum SortOrder { dateDesc, dateAsc, viewCount }

enum DateFilterType { postDate, createdAt, updatedAt }

class _FeedScreenState extends State<FeedScreen> {
  final DatabaseHelper _db = DatabaseHelper.instance;
  List<Post> _allPosts = [];
  List<Post> _posts = [];
  bool _isLoading = true;
  ViewMode _viewMode = ViewMode.list;
  final GlobalKey<_MapViewState> _mapViewKey = GlobalKey<_MapViewState>();

  // Advanced filters (AND conditions)
  bool _filterLikedPosts = false;
  bool _filterSimilarDate = false;
  Set<String> _selectedTags = {};
  bool _filterWithLocation = false;
  bool _filterWithMedia = false;
  DateTime? _dateRangeStart;
  DateTime? _dateRangeEnd;

  // Sort order
  SortOrder _sortOrder = SortOrder.dateDesc;

  // Date filter type
  DateFilterType _dateFilterType = DateFilterType.postDate;

  // Search
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadFiltersFromPreferences();
    _loadPosts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _saveFiltersToPreferences();
    super.dispose();
  }

  Future<void> _loadFiltersFromPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _searchQuery = prefs.getString('searchQuery') ?? '';
        _searchController.text = _searchQuery;
        _filterLikedPosts = prefs.getBool('filterLikedPosts') ?? false;
        _filterSimilarDate = prefs.getBool('filterSimilarDate') ?? false;
        _filterWithLocation = prefs.getBool('filterWithLocation') ?? false;
        _filterWithMedia = prefs.getBool('filterWithMedia') ?? false;
        _sortOrder = SortOrder
            .values[prefs.getInt('sortOrder') ?? SortOrder.dateDesc.index];
        _dateFilterType = DateFilterType.values[
            prefs.getInt('dateFilterType') ?? DateFilterType.postDate.index];

        // 저장된 태그 복원
        final savedTags = prefs.getStringList('selectedTags');
        if (savedTags != null) {
          _selectedTags = savedTags.toSet();
        }

        // 저장된 날짜 범위 복원
        final startDate = prefs.getString('dateRangeStart');
        final endDate = prefs.getString('dateRangeEnd');
        if (startDate != null) {
          _dateRangeStart = DateTime.parse(startDate);
        }
        if (endDate != null) {
          _dateRangeEnd = DateTime.parse(endDate);
        }
      });
    } catch (e) {
      print('필터 복원 중 오류: $e');
    }
  }

  Future<void> _saveFiltersToPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('searchQuery', _searchQuery);
      await prefs.setBool('filterLikedPosts', _filterLikedPosts);
      await prefs.setBool('filterSimilarDate', _filterSimilarDate);
      await prefs.setBool('filterWithLocation', _filterWithLocation);
      await prefs.setBool('filterWithMedia', _filterWithMedia);
      await prefs.setInt('sortOrder', _sortOrder.index);
      await prefs.setInt('dateFilterType', _dateFilterType.index);
      await prefs.setStringList('selectedTags', _selectedTags.toList());

      // 날짜 범위 저장
      if (_dateRangeStart != null) {
        await prefs.setString(
            'dateRangeStart', _dateRangeStart!.toIso8601String());
      } else {
        await prefs.remove('dateRangeStart');
      }
      if (_dateRangeEnd != null) {
        await prefs.setString('dateRangeEnd', _dateRangeEnd!.toIso8601String());
      } else {
        await prefs.remove('dateRangeEnd');
      }
    } catch (e) {
      print('필터 저장 중 오류: $e');
    }
  }

  Future<void> _loadPosts() async {
    setState(() => _isLoading = true);
    final posts = await _db.getAllPosts();
    setState(() {
      _allPosts = posts;
      _applyFiltersAndSort();
      _isLoading = false;
    });
  }

  Future<void> _applyFiltersAndSort() async {
    List<Post> filtered = List.from(_allPosts);

    // Apply search filter (title)
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((post) {
        final title = post.title?.toLowerCase() ?? '';
        return title.contains(_searchQuery.toLowerCase());
      }).toList();
    }

    // Apply liked posts filter
    if (_filterLikedPosts) {
      final likedPostIds = <int>{};
      for (var post in filtered) {
        final likes = await _db.getLikesByPost(post.id!);
        if (likes.any((like) => like.isUser)) {
          likedPostIds.add(post.id!);
        }
      }
      filtered =
          filtered.where((post) => likedPostIds.contains(post.id)).toList();
    }

    // Apply similar date filter (today ±7 days in other years)
    if (_filterSimilarDate) {
      final now = DateTime.now();
      filtered = filtered.where((post) {
        final postDate = post.postDate ?? post.createdAt;
        // Check if the post is within ±7 days of today's month/day in any year
        final daysDiff = (postDate.month - now.month).abs() * 30 +
            (postDate.day - now.day).abs();
        return daysDiff <= 7 && postDate.year != now.year;
      }).toList();
    }

    // Apply tag filter
    if (_selectedTags.isNotEmpty) {
      filtered = filtered.where((post) {
        return post.tag != null && _selectedTags.contains(post.tag);
      }).toList();
    }

    // Apply location filter
    if (_filterWithLocation) {
      filtered = filtered
          .where((post) => post.latitude != null && post.longitude != null)
          .toList();
    }

    // Apply media filter
    if (_filterWithMedia) {
      filtered = filtered.where((post) => post.mediaPaths.isNotEmpty).toList();
    }

    // Apply date range filter
    if (_dateRangeStart != null && _dateRangeEnd != null) {
      filtered = filtered.where((post) {
        DateTime dateToCheck;
        switch (_dateFilterType) {
          case DateFilterType.postDate:
            dateToCheck = post.postDate ?? post.createdAt;
            break;
          case DateFilterType.createdAt:
            dateToCheck = post.createdAt;
            break;
          case DateFilterType.updatedAt:
            dateToCheck = post.updatedAt ?? post.createdAt;
            break;
        }
        return dateToCheck.isAfter(_dateRangeStart!) &&
            dateToCheck.isBefore(_dateRangeEnd!.add(const Duration(days: 1)));
      }).toList();
    }

    // Apply sorting
    switch (_sortOrder) {
      case SortOrder.dateDesc:
        filtered.sort((a, b) {
          DateTime aDate;
          DateTime bDate;
          switch (_dateFilterType) {
            case DateFilterType.postDate:
              aDate = a.postDate ?? a.createdAt;
              bDate = b.postDate ?? b.createdAt;
              break;
            case DateFilterType.createdAt:
              aDate = a.createdAt;
              bDate = b.createdAt;
              break;
            case DateFilterType.updatedAt:
              aDate = a.updatedAt ?? a.createdAt;
              bDate = b.updatedAt ?? b.createdAt;
              break;
          }
          return bDate.compareTo(aDate);
        });
        break;
      case SortOrder.dateAsc:
        filtered.sort((a, b) {
          DateTime aDate;
          DateTime bDate;
          switch (_dateFilterType) {
            case DateFilterType.postDate:
              aDate = a.postDate ?? a.createdAt;
              bDate = b.postDate ?? b.createdAt;
              break;
            case DateFilterType.createdAt:
              aDate = a.createdAt;
              bDate = b.createdAt;
              break;
            case DateFilterType.updatedAt:
              aDate = a.updatedAt ?? a.createdAt;
              bDate = b.updatedAt ?? b.createdAt;
              break;
          }
          return aDate.compareTo(bDate);
        });
        break;
      case SortOrder.viewCount:
        filtered.sort((a, b) => b.viewCount.compareTo(a.viewCount));
        break;
    }

    setState(() {
      _posts = filtered;
    });
  }

  void _showFilterDialog() {
    // 임시 변수로 현재 필터 설정값 복사
    String tempSearchQuery = _searchQuery;
    bool tempFilterLikedPosts = _filterLikedPosts;
    bool tempFilterSimilarDate = _filterSimilarDate;
    Set<String> tempSelectedTags = Set.from(_selectedTags);
    bool tempFilterWithLocation = _filterWithLocation;
    bool tempFilterWithMedia = _filterWithMedia;
    DateTime? tempDateRangeStart = _dateRangeStart;
    DateTime? tempDateRangeEnd = _dateRangeEnd;
    DateFilterType tempDateFilterType = _dateFilterType;
    SortOrder tempSortOrder = _sortOrder;

    final tempSearchController = TextEditingController(text: _searchQuery);
    bool isControllerDisposed = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Filter & Sort Posts'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Search
                TextField(
                  controller: tempSearchController,
                  decoration: const InputDecoration(
                    labelText: 'Search by title',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) {
                    setDialogState(() {
                      tempSearchQuery = value;
                    });
                  },
                ),
                const SizedBox(height: 16),
                const Text('Filters (AND conditions):',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),

                // Liked posts filter
                CheckboxListTile(
                  dense: true,
                  title: const Text('Liked posts'),
                  value: tempFilterLikedPosts,
                  onChanged: (value) {
                    setDialogState(() {
                      tempFilterLikedPosts = value ?? false;
                    });
                  },
                ),

                // Similar date filter
                CheckboxListTile(
                  dense: true,
                  title: const Text('Similar date (±7 days, other years)'),
                  value: tempFilterSimilarDate,
                  onChanged: (value) {
                    setDialogState(() {
                      tempFilterSimilarDate = value ?? false;
                    });
                  },
                ),

                // Location filter
                CheckboxListTile(
                  dense: true,
                  title: const Text('Has location'),
                  value: tempFilterWithLocation,
                  onChanged: (value) {
                    setDialogState(() {
                      tempFilterWithLocation = value ?? false;
                    });
                  },
                ),

                // Media filter
                CheckboxListTile(
                  dense: true,
                  title: const Text('Has photo/video'),
                  value: tempFilterWithMedia,
                  onChanged: (value) {
                    setDialogState(() {
                      tempFilterWithMedia = value ?? false;
                    });
                  },
                ),

                const SizedBox(height: 8),
                const Text('Tags:',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  children: [
                    _buildTagChip(
                        'red', Colors.red, tempSelectedTags, setDialogState),
                    _buildTagChip('orange', Colors.orange, tempSelectedTags,
                        setDialogState),
                    _buildTagChip('yellow', Colors.yellow, tempSelectedTags,
                        setDialogState),
                    _buildTagChip('green', Colors.green, tempSelectedTags,
                        setDialogState),
                    _buildTagChip(
                        'blue', Colors.blue, tempSelectedTags, setDialogState),
                    _buildTagChip('purple', Colors.purple, tempSelectedTags,
                        setDialogState),
                  ],
                ),

                const SizedBox(height: 12),
                // Date Filter Type Selection
                const Text('Date Filter Type:',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                Column(
                  children: [
                    RadioListTile<DateFilterType>(
                      dense: true,
                      title: const Text('Post Date'),
                      value: DateFilterType.postDate,
                      groupValue: tempDateFilterType,
                      onChanged: (value) {
                        setDialogState(() {
                          tempDateFilterType = value!;
                        });
                      },
                    ),
                    RadioListTile<DateFilterType>(
                      dense: true,
                      title: const Text('Created Date'),
                      value: DateFilterType.createdAt,
                      groupValue: tempDateFilterType,
                      onChanged: (value) {
                        setDialogState(() {
                          tempDateFilterType = value!;
                        });
                      },
                    ),
                    RadioListTile<DateFilterType>(
                      dense: true,
                      title: const Text('Updated Date'),
                      value: DateFilterType.updatedAt,
                      groupValue: tempDateFilterType,
                      onChanged: (value) {
                        setDialogState(() {
                          tempDateFilterType = value!;
                        });
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text('Date Range:',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: tempDateRangeStart ?? DateTime.now(),
                            firstDate: DateTime(2000),
                            lastDate: DateTime.now(),
                          );
                          if (picked != null) {
                            setDialogState(() {
                              tempDateRangeStart = picked;
                            });
                          }
                        },
                        icon: const Icon(Icons.calendar_today, size: 16),
                        label: Text(
                          tempDateRangeStart != null
                              ? '${tempDateRangeStart!.year}-${tempDateRangeStart!.month.toString().padLeft(2, '0')}-${tempDateRangeStart!.day.toString().padLeft(2, '0')}'
                              : 'Start',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: tempDateRangeEnd ?? DateTime.now(),
                            firstDate: tempDateRangeStart ?? DateTime(2000),
                            lastDate: DateTime.now(),
                          );
                          if (picked != null) {
                            setDialogState(() {
                              tempDateRangeEnd = picked;
                            });
                          }
                        },
                        icon: const Icon(Icons.calendar_today, size: 16),
                        label: Text(
                          tempDateRangeEnd != null
                              ? '${tempDateRangeEnd!.year}-${tempDateRangeEnd!.month.toString().padLeft(2, '0')}-${tempDateRangeEnd!.day.toString().padLeft(2, '0')}'
                              : 'End',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ),
                  ],
                ),
                if (tempDateRangeStart != null || tempDateRangeEnd != null)
                  TextButton.icon(
                    onPressed: () {
                      setDialogState(() {
                        tempDateRangeStart = null;
                        tempDateRangeEnd = null;
                      });
                    },
                    icon: const Icon(Icons.clear, size: 16),
                    label: const Text('Clear dates',
                        style: TextStyle(fontSize: 12)),
                  ),

                const SizedBox(height: 12),
                const Text('Sort by:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                RadioListTile<SortOrder>(
                  dense: true,
                  title: const Text('Date (newest first)'),
                  value: SortOrder.dateDesc,
                  groupValue: tempSortOrder,
                  onChanged: (value) {
                    setDialogState(() {
                      tempSortOrder = value!;
                    });
                  },
                ),
                RadioListTile<SortOrder>(
                  dense: true,
                  title: const Text('Date (oldest first)'),
                  value: SortOrder.dateAsc,
                  groupValue: tempSortOrder,
                  onChanged: (value) {
                    setDialogState(() {
                      tempSortOrder = value!;
                    });
                  },
                ),
                RadioListTile<SortOrder>(
                  dense: true,
                  title: const Text('View count'),
                  value: SortOrder.viewCount,
                  groupValue: tempSortOrder,
                  onChanged: (value) {
                    setDialogState(() {
                      tempSortOrder = value!;
                    });
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                setDialogState(() {
                  tempSearchQuery = '';
                  tempSearchController.clear();
                  tempFilterLikedPosts = false;
                  tempFilterSimilarDate = false;
                  tempSelectedTags.clear();
                  tempFilterWithLocation = false;
                  tempFilterWithMedia = false;
                  tempDateRangeStart = null;
                  tempDateRangeEnd = null;
                  tempDateFilterType = DateFilterType.postDate;
                  tempSortOrder = SortOrder.dateDesc;
                });
              },
              child: const Text('Reset'),
            ),
            TextButton(
              onPressed: () {
                if (!isControllerDisposed) {
                  tempSearchController.dispose();
                  isControllerDisposed = true;
                }
                Navigator.pop(context);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                // Apply 버튼을 눌렀을 때만 실제 상태에 반영
                setState(() {
                  _searchQuery = tempSearchQuery;
                  _searchController.text = tempSearchQuery;
                  _filterLikedPosts = tempFilterLikedPosts;
                  _filterSimilarDate = tempFilterSimilarDate;
                  _selectedTags = Set.from(tempSelectedTags);
                  _filterWithLocation = tempFilterWithLocation;
                  _filterWithMedia = tempFilterWithMedia;
                  _dateRangeStart = tempDateRangeStart;
                  _dateRangeEnd = tempDateRangeEnd;
                  _dateFilterType = tempDateFilterType;
                  _sortOrder = tempSortOrder;
                  _applyFiltersAndSort();
                });
                _saveFiltersToPreferences();
                if (!isControllerDisposed) {
                  tempSearchController.dispose();
                  isControllerDisposed = true;
                }
                Navigator.pop(context);
              },
              child: const Text('Apply'),
            ),
          ],
        ),
      ),
    ).then((_) {
      // 다이얼로그가 닫힐 때 tempSearchController가 dispose되지 않았다면 dispose
      if (!isControllerDisposed) {
        tempSearchController.dispose();
      }
    });
  }

  Widget _buildTagChip(String tag, Color color, Set<String> selectedTags,
      StateSetter setDialogState) {
    final isSelected = selectedTags.contains(tag);
    return FilterChip(
      label: Text(tag, style: const TextStyle(fontSize: 12)),
      selected: isSelected,
      selectedColor: color.withValues(alpha: 0.3),
      checkmarkColor: Colors.white,
      backgroundColor: color.withValues(alpha: 0.1),
      side: BorderSide(color: color),
      onSelected: (selected) {
        setDialogState(() {
          if (selected) {
            selectedTags.add(tag);
          } else {
            selectedTags.remove(tag);
          }
        });
      },
    );
  }

  bool _hasActiveFilters() {
    return _searchQuery.isNotEmpty ||
        _filterLikedPosts ||
        _filterSimilarDate ||
        _selectedTags.isNotEmpty ||
        _filterWithLocation ||
        _filterWithMedia ||
        _dateRangeStart != null ||
        _dateRangeEnd != null ||
        _sortOrder != SortOrder.dateDesc;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text('Logat'),
          actions: [
            IconButton(
              icon: Icon(
                Icons.filter_list,
                color: _hasActiveFilters() ? Colors.blue : null,
              ),
              onPressed: _showFilterDialog,
            ),
            IconButton(
              icon: const Icon(Icons.notifications),
              onPressed: () {
                // TODO: Implement notifications screen and functionality
              },
            ),
            IconButton(
              icon: const Icon(Icons.chat_bubble_outline),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const FriendsScreen()),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.settings),
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const SettingsScreen()),
                );
                _loadPosts();
              },
            ),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _posts.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.photo_library,
                            size: 64, color: Colors.grey),
                        const SizedBox(height: 16),
                        const Text(
                          'Share your first post!',
                          style: TextStyle(fontSize: 18, color: Colors.grey),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Your AI friends will react to it',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                : _viewMode == ViewMode.list
                    ? RefreshIndicator(
                        onRefresh: _loadPosts,
                        child: ListView.builder(
                          itemCount: _posts.length,
                          itemBuilder: (context, index) {
                            return PostCard(
                              post: _posts[index],
                              onTap: () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => PostDetailScreen(
                                      post: _posts[index],
                                    ),
                                  ),
                                );
                                // Always reload to reflect view count and other changes
                                _loadPosts();
                              },
                            );
                          },
                        ),
                      )
                    : MapView(
                        key: _mapViewKey,
                        posts: _posts
                            .where((p) =>
                                p.latitude != null && p.longitude != null)
                            .toList(),
                        onPostTap: (post) async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  PostDetailScreen(post: post),
                            ),
                          );
                          // Always reload to reflect view count and other changes
                          _loadPosts();
                        },
                      ),
        floatingActionButton: _viewMode == ViewMode.map
            ? Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  FloatingActionButton(
                    heroTag: 'myLocation',
                    onPressed: () {
                      // Get the current MapView state and move to my location
                      // This will be handled by calling the map controller
                      _moveToMyLocation();
                    },
                    child: const Icon(Icons.my_location),
                  ),
                  const SizedBox(width: 16),
                  FloatingActionButton(
                    heroTag: 'viewModeToggle',
                    onPressed: () {
                      setState(() {
                        _viewMode = _viewMode == ViewMode.list
                            ? ViewMode.map
                            : ViewMode.list;
                      });
                    },
                    child: Icon(
                      _viewMode == ViewMode.list ? Icons.map : Icons.list,
                    ),
                  ),
                  const SizedBox(width: 16),
                  FloatingActionButton(
                    heroTag: 'addPost',
                    onPressed: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const CreatePostScreen()),
                      );
                      _loadPosts();
                    },
                    child: const Icon(Icons.add),
                  ),
                ],
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  FloatingActionButton(
                    heroTag: 'viewModeToggle',
                    onPressed: () {
                      setState(() {
                        _viewMode = _viewMode == ViewMode.list
                            ? ViewMode.map
                            : ViewMode.list;
                      });
                    },
                    child: Icon(
                      _viewMode == ViewMode.list ? Icons.map : Icons.list,
                    ),
                  ),
                  const SizedBox(width: 16),
                  FloatingActionButton(
                    heroTag: 'addPost',
                    onPressed: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const CreatePostScreen()),
                      );
                      _loadPosts();
                    },
                    child: const Icon(Icons.add),
                  ),
                ],
              ));
  }

  void _moveToMyLocation() async {
    // Access the map controller from MapView using the GlobalKey
    final mapController = _mapViewKey.currentState?._mapController;
    if (mapController != null) {
      try {
        // Get current location using the Location package
        final location = await _getCurrentLocation();
        if (location != null && mounted) {
          mapController.animateCamera(
            CameraUpdate.newLatLngZoom(
              LatLng(location.latitude!, location.longitude!),
              12,
            ),
          );
        }
      } catch (e) {
        print('Failed to get location: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to get current location')),
          );
        }
      }
    }
  }

  Future<LocationData?> _getCurrentLocation() async {
    try {
      final locationService = Location();

      bool serviceEnabled = await locationService.serviceEnabled();
      if (!serviceEnabled) {
        serviceEnabled = await locationService.requestService();
        if (!serviceEnabled) return null;
      }

      var permissionGranted = await locationService.hasPermission();
      if (permissionGranted == PermissionStatus.denied) {
        permissionGranted = await locationService.requestPermission();
        if (permissionGranted != PermissionStatus.granted) {
          return null;
        }
      }

      return await locationService.getLocation();
    } catch (e) {
      print('Location error: $e');
      return null;
    }
  }
}

class PostCard extends StatefulWidget {
  final Post post;
  final VoidCallback onTap;

  const PostCard({
    Key? key,
    required this.post,
    required this.onTap,
  }) : super(key: key);

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  int _currentMediaIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: InkWell(
        onTap: widget.onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Media PageView (only show if media exists)
            if (widget.post.mediaPaths.isNotEmpty)
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  // 이미지나 동영상을 탭하면 post_detail_screen으로 이동
                  widget.onTap();
                },
                child: Stack(
                  children: [
                    AspectRatio(
                      aspectRatio: 1,
                      child: PageView.builder(
                        itemCount: widget.post.mediaPaths.length,
                        onPageChanged: (index) {
                          setState(() {
                            _currentMediaIndex = index;
                          });
                        },
                        itemBuilder: (context, index) {
                          final mediaPath = widget.post.mediaPaths[index];
                          final isVideo =
                              mediaPath.toLowerCase().endsWith('.mp4') ||
                                  mediaPath.toLowerCase().endsWith('.mov');
                          final fileExists = File(mediaPath).existsSync();

                          if (!fileExists) {
                            return Container(
                              color: Colors.grey[300],
                              child: const Center(
                                child: Icon(Icons.broken_image,
                                    size: 64, color: Colors.grey),
                              ),
                            );
                          }

                          return isVideo
                              ? VideoPlayerWidget(videoPath: mediaPath)
                              : Image.file(
                                  File(mediaPath),
                                  fit: BoxFit.cover,
                                );
                        },
                      ),
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${_currentMediaIndex + 1}/${widget.post.mediaPaths.length}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                    // Page indicator dots
                    if (widget.post.mediaPaths.length > 1)
                      Positioned(
                        bottom: 8,
                        left: 0,
                        right: 0,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(
                            widget.post.mediaPaths.length,
                            (index) => Container(
                              width: 6,
                              height: 6,
                              margin: const EdgeInsets.symmetric(horizontal: 2),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: _currentMediaIndex == index
                                    ? Colors.white
                                    : Colors.white.withValues(alpha: 0.4),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.post.title != null &&
                      widget.post.title!.isNotEmpty) ...[
                    Text(
                      widget.post.title!,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                  ],
                  Row(
                    children: [
                      FutureBuilder<bool>(
                        future: DatabaseHelper.instance
                            .getLikesByPost(widget.post.id!)
                            .then((likes) => likes.any((like) => like.isUser)),
                        builder: (context, snapshot) {
                          final isLiked = snapshot.data ?? false;
                          return Icon(
                            isLiked ? Icons.favorite : Icons.favorite_border,
                            size: 20,
                            color: isLiked ? Colors.red : Colors.grey,
                          );
                        },
                      ),
                      const SizedBox(width: 4),
                      Text('${widget.post.likeCount}'),
                      const SizedBox(width: 16),
                      const Icon(Icons.chat_bubble_outline, size: 20),
                      const SizedBox(width: 4),
                      FutureBuilder<int>(
                        future: DatabaseHelper.instance
                            .getCommentsByPost(widget.post.id!)
                            .then((comments) => comments.length),
                        builder: (context, snapshot) {
                          return Text('${snapshot.data ?? 0}');
                        },
                      ),
                      const SizedBox(width: 16),
                      const Icon(Icons.visibility,
                          size: 20, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text('${widget.post.viewCount}'),
                    ],
                  ),
                  if (widget.post.caption != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      widget.post.caption!,
                      style: const TextStyle(fontSize: 14),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  if (widget.post.locationName != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.location_on,
                            size: 14, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(
                          widget.post.locationName!,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    _formatDate(widget.post.createdAt),
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays > 0) {
      return '${diff.inDays}d ago';
    } else if (diff.inHours > 0) {
      return '${diff.inHours}h ago';
    } else if (diff.inMinutes > 0) {
      return '${diff.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}

class MapView extends StatefulWidget {
  final List<Post> posts;
  final Function(Post) onPostTap;

  const MapView({
    Key? key,
    required this.posts,
    required this.onPostTap,
  }) : super(key: key);

  @override
  State<MapView> createState() => _MapViewState();
}

class _MapViewState extends State<MapView> {
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};

  @override
  void initState() {
    super.initState();
    _createMarkers();
  }

  @override
  void didUpdateWidget(MapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.posts != widget.posts) {
      _createMarkers();
    }
  }

  void _createMarkers() {
    final markers = <Marker>{};

    for (var post in widget.posts) {
      if (post.latitude != null && post.longitude != null) {
        markers.add(
          Marker(
            markerId: MarkerId('post_${post.id}'),
            position: LatLng(post.latitude!, post.longitude!),
            onTap: () => widget.onPostTap(post),
            infoWindow: InfoWindow(
              title: post.caption ?? 'Post',
              snippet: post.locationName,
            ),
          ),
        );
      }
    }

    setState(() {
      _markers = markers;
    });
  }

  LatLngBounds _calculateBounds() {
    // 지구 반지름 기준 거리: 약 6,371km / 111km per degree ≈ 57도
    const double earthRadiusThreshold = 57;

    double minLat = widget.posts.first.latitude!;
    double maxLat = widget.posts.first.latitude!;
    double minLng = widget.posts.first.longitude!;
    double maxLng = widget.posts.first.longitude!;

    for (var post in widget.posts) {
      if (post.latitude! < minLat) minLat = post.latitude!;
      if (post.latitude! > maxLat) maxLat = post.latitude!;
      if (post.longitude! < minLng) minLng = post.longitude!;
      if (post.longitude! > maxLng) maxLng = post.longitude!;

      // 범위가 지구 반지름 이상이면 바로 첫 번째 게시물 기준으로 반환
      final latDiff = maxLat - minLat;
      final lngDiff = maxLng - minLng;
      if (latDiff > earthRadiusThreshold || lngDiff > earthRadiusThreshold) {
        final padding = 0.05; // 약 5km
        return LatLngBounds(
          southwest: LatLng(
            widget.posts.first.latitude! - padding,
            widget.posts.first.longitude! - padding,
          ),
          northeast: LatLng(
            widget.posts.first.latitude! + padding,
            widget.posts.first.longitude! + padding,
          ),
        );
      }
    }

    return LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.posts.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.location_off, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No posts with location',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            SizedBox(height: 8),
            Text(
              'Posts with location data will appear on the map',
              style: TextStyle(color: Colors.grey, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    // Calculate center position
    double centerLat = 0;
    double centerLng = 0;
    for (var post in widget.posts) {
      centerLat += post.latitude!;
      centerLng += post.longitude!;
    }
    centerLat /= widget.posts.length;
    centerLng /= widget.posts.length;

    return GoogleMap(
      initialCameraPosition: CameraPosition(
        target: LatLng(centerLat, centerLng),
        zoom: 12,
      ),
      markers: _markers,
      myLocationButtonEnabled: false,
      myLocationEnabled: true,
      zoomControlsEnabled: true,
      mapToolbarEnabled: true,
      onMapCreated: (controller) {
        _mapController = controller;

        // Fit bounds to show all markers
        if (widget.posts.length > 1) {
          Future.delayed(const Duration(milliseconds: 500), () {
            _mapController?.animateCamera(
              CameraUpdate.newLatLngBounds(_calculateBounds(), 50),
            );
          });
        }
      },
    );
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }
}
