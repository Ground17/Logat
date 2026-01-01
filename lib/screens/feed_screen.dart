import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';
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

  // Search
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadPosts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
      filtered = filtered.where((post) => likedPostIds.contains(post.id)).toList();
    }

    // Apply similar date filter (today ±7 days in other years)
    if (_filterSimilarDate) {
      final now = DateTime.now();
      filtered = filtered.where((post) {
        final postDate = post.postDate ?? post.createdAt;
        // Check if the post is within ±7 days of today's month/day in any year
        final daysDiff = (postDate.month - now.month).abs() * 30 + (postDate.day - now.day).abs();
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
      filtered = filtered.where((post) =>
        post.latitude != null && post.longitude != null
      ).toList();
    }

    // Apply media filter
    if (_filterWithMedia) {
      filtered = filtered.where((post) => post.mediaPaths.isNotEmpty).toList();
    }

    // Apply date range filter
    if (_dateRangeStart != null && _dateRangeEnd != null) {
      filtered = filtered.where((post) {
        final postDate = post.postDate ?? post.createdAt;
        return postDate.isAfter(_dateRangeStart!) &&
               postDate.isBefore(_dateRangeEnd!.add(const Duration(days: 1)));
      }).toList();
    }

    // Apply sorting
    switch (_sortOrder) {
      case SortOrder.dateDesc:
        filtered.sort((a, b) {
          final aDate = a.postDate ?? a.createdAt;
          final bDate = b.postDate ?? b.createdAt;
          return bDate.compareTo(aDate);
        });
        break;
      case SortOrder.dateAsc:
        filtered.sort((a, b) {
          final aDate = a.postDate ?? a.createdAt;
          final bDate = b.postDate ?? b.createdAt;
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
                  controller: _searchController,
                  decoration: const InputDecoration(
                    labelText: 'Search by title',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) {
                    setDialogState(() {
                      _searchQuery = value;
                    });
                  },
                ),
                const SizedBox(height: 16),
                const Text('Filters (AND conditions):', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),

                // Liked posts filter
                CheckboxListTile(
                  dense: true,
                  title: const Text('Liked posts'),
                  value: _filterLikedPosts,
                  onChanged: (value) {
                    setDialogState(() {
                      _filterLikedPosts = value ?? false;
                    });
                  },
                ),

                // Similar date filter
                CheckboxListTile(
                  dense: true,
                  title: const Text('Similar date (±7 days, other years)'),
                  value: _filterSimilarDate,
                  onChanged: (value) {
                    setDialogState(() {
                      _filterSimilarDate = value ?? false;
                    });
                  },
                ),

                // Location filter
                CheckboxListTile(
                  dense: true,
                  title: const Text('Has location'),
                  value: _filterWithLocation,
                  onChanged: (value) {
                    setDialogState(() {
                      _filterWithLocation = value ?? false;
                    });
                  },
                ),

                // Media filter
                CheckboxListTile(
                  dense: true,
                  title: const Text('Has photo/video'),
                  value: _filterWithMedia,
                  onChanged: (value) {
                    setDialogState(() {
                      _filterWithMedia = value ?? false;
                    });
                  },
                ),

                const SizedBox(height: 8),
                const Text('Tags:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  children: [
                    _buildTagChip('red', Colors.red, setDialogState),
                    _buildTagChip('orange', Colors.orange, setDialogState),
                    _buildTagChip('yellow', Colors.yellow, setDialogState),
                    _buildTagChip('green', Colors.green, setDialogState),
                    _buildTagChip('blue', Colors.blue, setDialogState),
                    _buildTagChip('purple', Colors.purple, setDialogState),
                  ],
                ),

                const SizedBox(height: 12),
                const Text('Date Range:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _dateRangeStart ?? DateTime.now(),
                            firstDate: DateTime(2000),
                            lastDate: DateTime.now(),
                          );
                          if (picked != null) {
                            setDialogState(() {
                              _dateRangeStart = picked;
                            });
                          }
                        },
                        icon: const Icon(Icons.calendar_today, size: 16),
                        label: Text(
                          _dateRangeStart != null
                              ? '${_dateRangeStart!.year}-${_dateRangeStart!.month.toString().padLeft(2, '0')}-${_dateRangeStart!.day.toString().padLeft(2, '0')}'
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
                            initialDate: _dateRangeEnd ?? DateTime.now(),
                            firstDate: _dateRangeStart ?? DateTime(2000),
                            lastDate: DateTime.now(),
                          );
                          if (picked != null) {
                            setDialogState(() {
                              _dateRangeEnd = picked;
                            });
                          }
                        },
                        icon: const Icon(Icons.calendar_today, size: 16),
                        label: Text(
                          _dateRangeEnd != null
                              ? '${_dateRangeEnd!.year}-${_dateRangeEnd!.month.toString().padLeft(2, '0')}-${_dateRangeEnd!.day.toString().padLeft(2, '0')}'
                              : 'End',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ),
                  ],
                ),
                if (_dateRangeStart != null || _dateRangeEnd != null)
                  TextButton.icon(
                    onPressed: () {
                      setDialogState(() {
                        _dateRangeStart = null;
                        _dateRangeEnd = null;
                      });
                    },
                    icon: const Icon(Icons.clear, size: 16),
                    label: const Text('Clear dates', style: TextStyle(fontSize: 12)),
                  ),

                const SizedBox(height: 12),
                const Text('Sort by:', style: TextStyle(fontWeight: FontWeight.bold)),
                RadioListTile<SortOrder>(
                  dense: true,
                  title: const Text('Date (newest first)'),
                  value: SortOrder.dateDesc,
                  groupValue: _sortOrder,
                  onChanged: (value) {
                    setDialogState(() {
                      _sortOrder = value!;
                    });
                  },
                ),
                RadioListTile<SortOrder>(
                  dense: true,
                  title: const Text('Date (oldest first)'),
                  value: SortOrder.dateAsc,
                  groupValue: _sortOrder,
                  onChanged: (value) {
                    setDialogState(() {
                      _sortOrder = value!;
                    });
                  },
                ),
                RadioListTile<SortOrder>(
                  dense: true,
                  title: const Text('View count'),
                  value: SortOrder.viewCount,
                  groupValue: _sortOrder,
                  onChanged: (value) {
                    setDialogState(() {
                      _sortOrder = value!;
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
                  _searchQuery = '';
                  _searchController.clear();
                  _filterLikedPosts = false;
                  _filterSimilarDate = false;
                  _selectedTags.clear();
                  _filterWithLocation = false;
                  _filterWithMedia = false;
                  _dateRangeStart = null;
                  _dateRangeEnd = null;
                  _sortOrder = SortOrder.dateDesc;
                });
                setState(() {
                  _applyFiltersAndSort();
                });
              },
              child: const Text('Reset'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                setState(() {
                  _applyFiltersAndSort();
                });
                Navigator.pop(context);
              },
              child: const Text('Apply'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTagChip(String tag, Color color, StateSetter setDialogState) {
    final isSelected = _selectedTags.contains(tag);
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
            _selectedTags.add(tag);
          } else {
            _selectedTags.remove(tag);
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
              _viewMode == ViewMode.list ? Icons.map : Icons.list,
            ),
            onPressed: () {
              setState(() {
                _viewMode = _viewMode == ViewMode.list ? ViewMode.map : ViewMode.list;
              });
            },
            tooltip: _viewMode == ViewMode.list ? 'Map View' : 'List View',
          ),
          IconButton(
            icon: Icon(
              Icons.filter_list,
              color: _hasActiveFilters() ? Colors.blue : null,
            ),
            onPressed: _showFilterDialog,
          ),
          IconButton(
            icon: const Icon(Icons.people),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const FriendsScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
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
                      const Icon(Icons.photo_library, size: 64, color: Colors.grey),
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
                              final result = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => PostDetailScreen(
                                    post: _posts[index],
                                  ),
                                ),
                              );
                              // Reload if post was edited or deleted
                              if (result == true) {
                                _loadPosts();
                              }
                            },
                          );
                        },
                      ),
                    )
                  : MapView(
                      key: _mapViewKey,
                      posts: _posts.where((p) => p.latitude != null && p.longitude != null).toList(),
                      onPostTap: (post) async {
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => PostDetailScreen(post: post),
                          ),
                        );
                        if (result == true) {
                          _loadPosts();
                        }
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
                  heroTag: 'addPost',
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const CreatePostScreen()),
                    );
                    _loadPosts();
                  },
                  child: const Icon(Icons.add),
                ),
              ],
            )
          : FloatingActionButton(
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const CreatePostScreen()),
                );
                _loadPosts();
              },
              child: const Icon(Icons.add),
            ),
    );
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
              15,
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

class PostCard extends StatelessWidget {
  final Post post;
  final VoidCallback onTap;

  const PostCard({
    Key? key,
    required this.post,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final firstMediaPath = post.mediaPaths.isNotEmpty ? post.mediaPaths.first : '';
    final isVideo = firstMediaPath.toLowerCase().endsWith('.mp4') ||
        firstMediaPath.toLowerCase().endsWith('.mov');

    // Debug: Check file existence
    final fileExists = File(firstMediaPath).existsSync();
    print('🖼️ Feed PostCard - Path: $firstMediaPath');
    print('🖼️ Feed PostCard - File exists: $fileExists');

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Main media with indicator
            Stack(
              children: [
                if (fileExists)
                  AspectRatio(
                    aspectRatio: 1,
                    child: fileExists && isVideo
                        ? VideoPlayerWidget(videoPath: firstMediaPath)
                        : Image.file(
                          File(firstMediaPath),
                          fit: BoxFit.cover,
                        ),
                  ),
                if (post.mediaPaths.length > 1)
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
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.collections,
                            size: 16,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${post.mediaPaths.length}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.favorite, size: 20, color: Colors.red),
                      const SizedBox(width: 4),
                      Text('${post.likeCount}'),
                      const SizedBox(width: 16),
                      const Icon(Icons.chat_bubble_outline, size: 20),
                      const SizedBox(width: 4),
                      FutureBuilder<int>(
                        future: DatabaseHelper.instance
                            .getCommentsByPost(post.id!)
                            .then((comments) => comments.length),
                        builder: (context, snapshot) {
                          return Text('${snapshot.data ?? 0}');
                        },
                      ),
                      const SizedBox(width: 16),
                      const Icon(Icons.visibility, size: 20, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text('${post.viewCount}'),
                    ],
                  ),
                  if (post.caption != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      post.caption!,
                      style: const TextStyle(fontSize: 14),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  if (post.locationName != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.location_on, size: 14, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(
                          post.locationName!,
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
                    _formatDate(post.createdAt),
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
    double minLat = widget.posts.first.latitude!;
    double maxLat = widget.posts.first.latitude!;
    double minLng = widget.posts.first.longitude!;
    double maxLng = widget.posts.first.longitude!;

    for (var post in widget.posts) {
      if (post.latitude! < minLat) minLat = post.latitude!;
      if (post.latitude! > maxLat) maxLat = post.latitude!;
      if (post.longitude! < minLng) minLng = post.longitude!;
      if (post.longitude! > maxLng) maxLng = post.longitude!;
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
