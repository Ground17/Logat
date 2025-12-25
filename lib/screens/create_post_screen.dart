import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:native_exif/native_exif.dart';
import '../models/comment.dart';
import '../models/like.dart';
import '../models/post.dart';
import '../database/database_helper.dart';
import '../services/ai_service.dart';
import '../services/settings_service.dart';
import '../models/app_settings.dart';

class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({Key? key}) : super(key: key);

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final _captionController = TextEditingController();
  final _locationController = TextEditingController();
  final DatabaseHelper _db = DatabaseHelper.instance;
  final ImagePicker _picker = ImagePicker();

  List<String> _mediaPaths = [];
  bool _isPosting = false;
  bool _enableAiReactions = true;
  double? _latitude;
  double? _longitude;
  static const int maxMediaCount = 20;

  @override
  void dispose() {
    _captionController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _pickMedia(ImageSource source, {bool isVideo = false}) async {
    try {
      if (_mediaPaths.length >= maxMediaCount) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Maximum $maxMediaCount media files allowed')),
          );
        }
        return;
      }

      final XFile? media = isVideo
          ? await _picker.pickVideo(source: ImageSource.gallery)
          : await _picker.pickImage(source: source);

      if (media != null) {
        setState(() {
          _mediaPaths.add(media.path);
        });

        // Extract location from first media file
        if (_mediaPaths.length == 1 && !isVideo) {
          await _extractLocationFromImage(media.path);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to select media: $e')),
        );
      }
    }
  }

  Future<void> _extractLocationFromImage(String imagePath) async {
    try {
      final exif = await Exif.fromPath(imagePath);
      final coordinates = await exif.getLatLong();

      if (coordinates != null) {
        setState(() {
          _latitude = coordinates.latitude;
          _longitude = coordinates.longitude;
        });

        // Optionally, you can reverse geocode to get location name
        // For now, just show coordinates
        if (mounted) {
          _locationController.text = '${coordinates.latitude.toStringAsFixed(6)}, ${coordinates.longitude.toStringAsFixed(6)}';
        }
      }

      await exif.close();
    } catch (e) {
      // No GPS data in image, that's okay
      print('No GPS data in image: $e');
    }
  }

  Future<void> _pickMultipleMedia() async {
    try {
      if (_mediaPaths.length >= maxMediaCount) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Maximum $maxMediaCount media files allowed')),
          );
        }
        return;
      }

      final List<XFile> medias = await _picker.pickMultipleMedia(
        limit: maxMediaCount - _mediaPaths.length,
      );

      if (medias.isNotEmpty) {
        final oldLength = _mediaPaths.length;
        setState(() {
          _mediaPaths.addAll(medias.map((m) => m.path));
        });

        // Extract location from first media file if this is the first selection
        if (oldLength == 0 && medias.isNotEmpty) {
          final firstPath = medias.first.path;
          if (!firstPath.toLowerCase().endsWith('.mp4') &&
              !firstPath.toLowerCase().endsWith('.mov')) {
            await _extractLocationFromImage(firstPath);
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to select media: $e')),
        );
      }
    }
  }

  void _removeMedia(int index) {
    setState(() {
      _mediaPaths.removeAt(index);
    });
  }

  Future<void> _createPost() async {
    if (_mediaPaths.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select at least one photo or video')),
        );
      }
      return;
    }

    setState(() => _isPosting = true);

    try {
      final post = Post(
        mediaPaths: _mediaPaths,
        caption: _captionController.text.isEmpty ? null : _captionController.text,
        location: _locationController.text.isEmpty ? null : _locationController.text,
        latitude: _latitude,
        longitude: _longitude,
        enableAiReactions: _enableAiReactions,
      );

      final postId = await _db.createPost(post);
      final createdPost = await _db.getPost(postId);

      if (createdPost != null && _enableAiReactions) {
        _generateAiReactions(createdPost);
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Post created successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create post: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isPosting = false);
      }
    }
  }

  Future<void> _generateAiReactions(Post post) async {
    final settings = await SettingsService.loadSettings();
    final personas = await _db.getAllPersonas();
    final enabledPersonas = personas
        .where((p) => settings.enabledPersonaIds.contains(p.id))
        .toList();

    final random = Random();

    for (var persona in enabledPersonas) {
      // Use persona-specific like probability
      final shouldLike = random.nextDouble() < persona.likeProbability;

      if (shouldLike) {
        final likeDecision = await AiService.shouldLikePost(
          persona: persona,
          post: post,
        );

        if (likeDecision) {
          await _db.createLike(Like(
            postId: post.id!,
            aiPersonaId: persona.id!,
          ));
        }
      }

      // Use persona-specific comment probability
      if (random.nextDouble() < persona.commentProbability) {
        final comment = await AiService.generateComment(
          persona: persona,
          post: post,
        );

        await _db.createComment(Comment(
          postId: post.id!,
          aiPersonaId: persona.id!,
          content: comment,
        ));
      }

      await Future.delayed(const Duration(milliseconds: 300));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Post'),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
            // Media Grid
            if (_mediaPaths.isEmpty)
              Container(
                height: 200,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.add_photo_alternate, size: 64, color: Colors.grey),
                    const SizedBox(height: 16),
                    const Text(
                      'Add photos or videos',
                      style: TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Up to $maxMediaCount files',
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
              )
            else
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: _mediaPaths.length,
                itemBuilder: (context, index) {
                  final path = _mediaPaths[index];
                  final isVideo = path.toLowerCase().endsWith('.mp4') ||
                      path.toLowerCase().endsWith('.mov');

                  return Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: isVideo
                            ? Container(
                                color: Colors.black,
                                child: const Center(
                                  child: Icon(
                                    Icons.play_circle_outline,
                                    size: 40,
                                    color: Colors.white,
                                  ),
                                ),
                              )
                            : Image.file(
                                File(path),
                                fit: BoxFit.cover,
                                width: double.infinity,
                                height: double.infinity,
                              ),
                      ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: IconButton(
                          onPressed: () => _removeMedia(index),
                          icon: const Icon(Icons.close, color: Colors.white),
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.black54,
                            padding: const EdgeInsets.all(4),
                            minimumSize: const Size(28, 28),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 4,
                        left: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '${index + 1}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),

            const SizedBox(height: 16),

            // Media Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickMultipleMedia,
                    icon: const Icon(Icons.photo_library),
                    label: const Text('Gallery'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickMedia(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Camera'),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Caption
            TextField(
              controller: _captionController,
              decoration: const InputDecoration(
                labelText: 'Caption',
                hintText: 'Write something about this post...',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),

            // Location
            TextField(
              controller: _locationController,
              decoration: const InputDecoration(
                labelText: 'Location',
                hintText: 'Where was this taken?',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.location_on),
              ),
            ),
            const SizedBox(height: 24),

            // AI Reactions Toggle
            Card(
              child: SwitchListTile(
                value: _enableAiReactions,
                onChanged: (value) {
                  setState(() => _enableAiReactions = value);
                },
                title: const Text('Enable AI Reactions'),
                subtitle: const Text(
                  'Allow AI friends to like and comment on this post',
                ),
                secondary: const Icon(Icons.smart_toy),
              ),
            ),

            if (_enableAiReactions) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue, size: 20),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'AI friends will react based on your settings',
                        style: TextStyle(color: Colors.blue, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ],
                ],
              ),
            ),
          ),
          // Bottom Share Button
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isPosting ? null : _createPost,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey,
                ),
                child: _isPosting
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text(
                        'Share Post',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
