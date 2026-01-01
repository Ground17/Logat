import 'dart:io';
import 'package:flutter/material.dart';
import '../models/post.dart';
import '../models/comment.dart';
import '../models/like.dart';
import '../models/ai_persona.dart';
import '../database/database_helper.dart';
import '../widgets/avatar_widget.dart';
import '../widgets/video_player_widget.dart';
import 'chat_screen.dart';
import 'edit_post_screen.dart';

class PostDetailScreen extends StatefulWidget {
  final Post post;

  const PostDetailScreen({
    Key? key,
    required this.post,
  }) : super(key: key);

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  final DatabaseHelper _db = DatabaseHelper.instance;
  final TextEditingController _commentController = TextEditingController();
  List<Comment> _comments = [];
  List<Like> _likes = [];
  Map<int, AiPersona> _personas = {};
  bool _isLoading = true;
  bool _userLiked = false;
  late Post _post;

  @override
  void initState() {
    super.initState();
    _post = widget.post;
    _loadData();
    _incrementViewCount();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    // 포스트 정보 새로고침
    final updatedPost = await _db.getPost(_post.id!);
    if (updatedPost != null) {
      _post = updatedPost;
    }

    // 댓글과 좋아요 로드
    final comments = await _db.getCommentsByPost(_post.id!);
    final likes = await _db.getLikesByPost(_post.id!);

    // 사용자가 좋아요를 눌렀는지 확인
    final userLiked = likes.any((like) => like.isUser);

    // AI 페르소나 정보 로드
    final allPersonas = await _db.getAllPersonas();
    final personaMap = <int, AiPersona>{};
    for (var persona in allPersonas) {
      personaMap[persona.id!] = persona;
    }

    setState(() {
      _comments = comments;
      _likes = likes;
      _userLiked = userLiked;
      _personas = personaMap;
      _isLoading = false;
    });
  }

  Future<void> _toggleLike() async {
    if (_userLiked) {
      // Unlike
      await _db.deleteLike(_post.id!, isUser: true);
    } else {
      // Like
      await _db.createLike(Like(
        postId: _post.id!,
        isUser: true,
      ));
    }
    _loadData();
  }

  Future<void> _addComment() async {
    if (_commentController.text.trim().isEmpty) return;

    await _db.createComment(Comment(
      postId: _post.id!,
      isUser: true,
      content: _commentController.text.trim(),
    ));

    _commentController.clear();
    _loadData();
  }

  Future<void> _incrementViewCount() async {
    await _db.incrementViewCount(_post.id!);
  }

  Future<void> _editPost() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => EditPostScreen(post: _post),
      ),
    );

    if (result == true) {
      // Reload data after edit
      _loadData();
    }
  }

  Future<void> _deletePost() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Post'),
        content: const Text('Are you sure you want to delete this post?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _db.deletePost(_post.id!);
      if (mounted) {
        Navigator.pop(context, true); // Return to feed and refresh
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Post deleted')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Post'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: _editPost,
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: _deletePost,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Media gallery (only show if media exists)
                  if (_post.mediaPaths.isNotEmpty)
                    SizedBox(
                      height: 400,
                      child: PageView.builder(
                        itemCount: _post.mediaPaths.length,
                        itemBuilder: (context, index) {
                          final mediaPath = _post.mediaPaths[index];
                          final isVideo = mediaPath.toLowerCase().endsWith('.mp4') ||
                              mediaPath.toLowerCase().endsWith('.mov');

                          return Stack(
                            children: [
                              isVideo
                                  ? VideoPlayerWidget(videoPath: mediaPath)
                                  : File(mediaPath).existsSync()
                                      ? Image.file(
                                          File(mediaPath),
                                          fit: BoxFit.cover,
                                          width: double.infinity,
                                        )
                                      : Container(
                                          color: Colors.grey[300],
                                          child: const Center(
                                            child: Icon(Icons.broken_image, size: 64),
                                          ),
                                        ),
                              if (_post.mediaPaths.length > 1)
                                Positioned(
                                  top: 16,
                                  right: 16,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.black54,
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Text(
                                      '${index + 1}/${_post.mediaPaths.length}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                    ),

                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title
                        if (_post.title != null && _post.title!.isNotEmpty) ...[
                          Text(
                            _post.title!,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // 좋아요, 댓글, 조회수 + 좋아요 버튼
                        Row(
                          children: [
                            IconButton(
                              icon: Icon(
                                _userLiked ? Icons.favorite : Icons.favorite_border,
                                color: _userLiked ? Colors.red : Colors.grey,
                              ),
                              onPressed: _toggleLike,
                            ),
                            Text(
                              '${_post.likeCount}',
                              style: const TextStyle(fontSize: 16),
                            ),
                            const SizedBox(width: 16),
                            const Icon(Icons.chat_bubble_outline),
                            const SizedBox(width: 4),
                            Text(
                              '${_comments.length}',
                              style: const TextStyle(fontSize: 16),
                            ),
                            const SizedBox(width: 24),
                            const Icon(Icons.visibility, color: Colors.grey),
                            const SizedBox(width: 4),
                            Text(
                              '${_post.viewCount}',
                              style: const TextStyle(fontSize: 16),
                            ),
                          ],
                        ),

                        if (_post.caption != null) ...[
                          const SizedBox(height: 16),
                          Text(
                            _post.caption!,
                            style: const TextStyle(fontSize: 16),
                          ),
                        ],

                        if (_post.locationName != null) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(Icons.location_on, size: 16, color: Colors.grey),
                              const SizedBox(width: 4),
                              Text(
                                _post.locationName!,
                                style: const TextStyle(color: Colors.grey),
                              ),
                            ],
                          ),
                        ],

                        const SizedBox(height: 8),
                        Text(
                          _formatDate(_post.createdAt),
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),

                        // Liked by
                        if (_likes.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          const Divider(),
                          const Text(
                            'Liked by',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            children: _likes.map((like) {
                              if (like.isUser) {
                                return const Chip(
                                  avatar: Icon(Icons.person, size: 16),
                                  label: Text('You'),
                                );
                              }
                              final persona = _personas[like.aiPersonaId];
                              if (persona == null) return const SizedBox.shrink();
                              return Chip(
                                avatar: AvatarWidget(
                                  avatar: persona.avatar,
                                  size: 24,
                                ),
                                label: Text(persona.name),
                              );
                            }).toList(),
                          ),
                        ],

                        // Comments
                        const SizedBox(height: 16),
                        const Divider(),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Comments',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '${_comments.length}',
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Comment input
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _commentController,
                                  decoration: const InputDecoration(
                                    hintText: 'Write a comment...',
                                    border: OutlineInputBorder(),
                                    contentPadding: EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                  ),
                                  maxLines: null,
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(Icons.send),
                                onPressed: _addComment,
                                color: Theme.of(context).primaryColor,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),

                        if (_comments.isEmpty)
                          const Center(
                            child: Padding(
                              padding: EdgeInsets.all(32),
                              child: Text(
                                'No comments yet',
                                style: TextStyle(color: Colors.grey),
                              ),
                            ),
                          )
                        else
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _comments.length,
                            itemBuilder: (context, index) {
                              final comment = _comments[index];

                              if (comment.isUser) {
                                return UserCommentCard(
                                  comment: comment,
                                  onDelete: () async {
                                    await _db.deleteComment(comment.id!);
                                    _loadData();
                                  },
                                  onUpdate: (newContent) async {
                                    final updatedComment = comment.copyWith(content: newContent);
                                    await _db.updateComment(updatedComment);
                                    _loadData();
                                  },
                                );
                              }

                              final persona = _personas[comment.aiPersonaId];
                              if (persona == null) return const SizedBox.shrink();

                              return CommentCard(
                                comment: comment,
                                persona: persona,
                                onDelete: () async {
                                  await _db.deleteComment(comment.id!);
                                  _loadData();
                                },
                                onTapPersona: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => ChatScreen(
                                        persona: persona,
                                      ),
                                    ),
                                  );
                                },
                              );
                            },
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

class UserCommentCard extends StatefulWidget {
  final Comment comment;
  final VoidCallback onDelete;
  final Function(String) onUpdate;

  const UserCommentCard({
    Key? key,
    required this.comment,
    required this.onDelete,
    required this.onUpdate,
  }) : super(key: key);

  @override
  State<UserCommentCard> createState() => _UserCommentCardState();
}

class _UserCommentCardState extends State<UserCommentCard> {
  bool _isEditing = false;
  late TextEditingController _editController;

  @override
  void initState() {
    super.initState();
    _editController = TextEditingController(text: widget.comment.content);
  }

  @override
  void dispose() {
    _editController.dispose();
    super.dispose();
  }

  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Comment'),
        content: const Text('Are you sure you want to delete this comment?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              widget.onDelete();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _saveEdit() {
    if (_editController.text.trim().isEmpty) return;
    widget.onUpdate(_editController.text.trim());
    setState(() => _isEditing = false);
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: Colors.blue[50],
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.person, size: 24, color: Colors.blue),
                const SizedBox(width: 8),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'You',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!_isEditing) ...[
                  IconButton(
                    icon: const Icon(Icons.edit, size: 18),
                    onPressed: () => setState(() => _isEditing = true),
                    tooltip: 'Edit',
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, size: 18),
                    onPressed: _confirmDelete,
                    color: Colors.red,
                    tooltip: 'Delete',
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            if (_isEditing) ...[
              TextField(
                controller: _editController,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'Edit your comment...',
                ),
                maxLines: 3,
                autofocus: true,
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () {
                      _editController.text = widget.comment.content;
                      setState(() => _isEditing = false);
                    },
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _saveEdit,
                    child: const Text('Save'),
                  ),
                ],
              ),
            ] else ...[
              Text(widget.comment.content),
              const SizedBox(height: 4),
              Text(
                _formatDate(widget.comment.createdAt),
                style: const TextStyle(
                  fontSize: 11,
                  color: Colors.grey,
                ),
              ),
            ],
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

class CommentCard extends StatelessWidget {
  final Comment comment;
  final AiPersona persona;
  final VoidCallback onTapPersona;
  final VoidCallback onDelete;

  const CommentCard({
    Key? key,
    required this.comment,
    required this.persona,
    required this.onTapPersona,
    required this.onDelete,
  }) : super(key: key);

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete AI Comment'),
        content: const Text('Are you sure you want to delete this AI comment?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              onDelete();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                InkWell(
                  onTap: onTapPersona,
                  child: Row(
                    children: [
                      AvatarWidget(
                        avatar: persona.avatar,
                        size: 40,
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            persona.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            persona.role,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.delete, size: 18),
                  onPressed: () => _confirmDelete(context),
                  color: Colors.red,
                  tooltip: 'Delete',
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(comment.content),
            const SizedBox(height: 4),
            Text(
              _formatDate(comment.createdAt),
              style: const TextStyle(
                fontSize: 11,
                color: Colors.grey,
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
