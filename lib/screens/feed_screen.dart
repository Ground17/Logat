import 'dart:io';
import 'package:flutter/material.dart';
import '../models/post.dart';
import '../database/database_helper.dart';
import 'post_detail_screen.dart';
import 'create_post_screen.dart';
import 'friends_screen.dart';
import 'settings_screen.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({Key? key}) : super(key: key);

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

enum PostFilter { all, recent, withLocation }

class _FeedScreenState extends State<FeedScreen> {
  final DatabaseHelper _db = DatabaseHelper.instance;
  List<Post> _allPosts = [];
  List<Post> _posts = [];
  bool _isLoading = true;
  PostFilter _currentFilter = PostFilter.all;

  @override
  void initState() {
    super.initState();
    _loadPosts();
  }

  Future<void> _loadPosts() async {
    setState(() => _isLoading = true);
    final posts = await _db.getAllPosts();
    setState(() {
      _allPosts = posts;
      _applyFilter();
      _isLoading = false;
    });
  }

  void _applyFilter() {
    switch (_currentFilter) {
      case PostFilter.all:
        _posts = List.from(_allPosts);
        break;
      case PostFilter.recent:
        final now = DateTime.now();
        final sevenDaysAgo = now.subtract(const Duration(days: 7));
        _posts = _allPosts.where((post) => post.createdAt.isAfter(sevenDaysAgo)).toList();
        break;
      case PostFilter.withLocation:
        _posts = _allPosts.where((post) => post.latitude != null && post.longitude != null).toList();
        break;
    }
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filter Posts'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<PostFilter>(
              value: PostFilter.all,
              groupValue: _currentFilter,
              onChanged: (value) {
                setState(() {
                  _currentFilter = value!;
                  _applyFilter();
                });
                Navigator.pop(context);
              },
              title: const Text('All Posts'),
            ),
            RadioListTile<PostFilter>(
              value: PostFilter.recent,
              groupValue: _currentFilter,
              onChanged: (value) {
                setState(() {
                  _currentFilter = value!;
                  _applyFilter();
                });
                Navigator.pop(context);
              },
              title: const Text('Recent (Last 7 Days)'),
            ),
            RadioListTile<PostFilter>(
              value: PostFilter.withLocation,
              groupValue: _currentFilter,
              onChanged: (value) {
                setState(() {
                  _currentFilter = value!;
                  _applyFilter();
                });
                Navigator.pop(context);
              },
              title: const Text('With Location'),
            ),
          ],
        ),
      ),
    );
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
              color: _currentFilter != PostFilter.all ? Colors.blue : null,
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
              : RefreshIndicator(
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
                ),
      floatingActionButton: FloatingActionButton(
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
    final firstMediaPath = post.mediaPaths.first;
    final isVideo = firstMediaPath.toLowerCase().endsWith('.mp4') ||
        firstMediaPath.toLowerCase().endsWith('.mov');

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
                AspectRatio(
                  aspectRatio: 1,
                  child: isVideo
                      ? Container(
                          color: Colors.black,
                          child: const Center(
                            child: Icon(
                              Icons.play_circle_outline,
                              size: 64,
                              color: Colors.white,
                            ),
                          ),
                        )
                      : File(firstMediaPath).existsSync()
                          ? Image.file(
                              File(firstMediaPath),
                              fit: BoxFit.cover,
                            )
                          : Container(
                              color: Colors.grey[300],
                              child: const Center(
                                child: Icon(Icons.broken_image, size: 64),
                              ),
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
                  if (post.location != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.location_on, size: 14, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(
                          post.location!,
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
