import 'dart:io';
import 'dart:math';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:native_exif/native_exif.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:location/location.dart';
import 'package:intl/intl.dart';
import 'package:video_player/video_player.dart';
import 'package:reorderable_grid_view/reorderable_grid_view.dart';
import '../models/comment.dart';
import '../models/like.dart';
import '../models/post.dart';
import '../database/database_helper.dart';
import '../services/ai_service.dart';
import '../services/ai_task_queue_service.dart';
import '../widgets/video_player_widget.dart';
import '../widgets/video_thumbnail_widget.dart';
import '../services/settings_service.dart';
import '../widgets/address_search_field.dart';
import '../utils/tag_helper.dart';
import 'location_picker_screen.dart';
import '../key.dart';

class CreatePostScreen extends StatefulWidget {
  final List<String>? initialMediaPaths;

  const CreatePostScreen({
    Key? key,
    this.initialMediaPaths,
  }) : super(key: key);

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final _titleController = TextEditingController();
  final _captionController = TextEditingController();
  final _locationController = TextEditingController();
  final DatabaseHelper _db = DatabaseHelper.instance;
  final ImagePicker _picker = ImagePicker();
  final Location _location = Location();

  List<String> _mediaPaths = []; // 임시 경로 (저장 전)
  bool _isPosting = false;
  bool _enableAiReactions = true;
  double? _latitude;
  double? _longitude;
  DateTime? _postDate;
  String? _selectedTag;
  static const int maxMediaCount = 20;

  @override
  void initState() {
    super.initState();
    _loadDefaultSettings();

    // Handle initial media paths from shared intent
    if (widget.initialMediaPaths != null && widget.initialMediaPaths!.isNotEmpty) {
      _copySharedFilesToDocuments(widget.initialMediaPaths!);
    }
  }

  Future<void> _loadDefaultSettings() async {
    final settings = await SettingsService.loadSettings();
    setState(() {
      _enableAiReactions = settings.enableAiReactions;
    });
  }

  Future<void> _copySharedFilesToDocuments(List<String> sharedPaths) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final copiedPaths = <String>[];

      for (final sharedPath in sharedPaths) {
        try {
          final sourceFile = File(sharedPath);
          if (!await sourceFile.exists()) {
            print('⚠️ Shared file not found: $sharedPath');
            continue;
          }

          // Generate unique filename
          final timestamp = DateTime.now().millisecondsSinceEpoch;
          final extension = sharedPath.split('.').last;
          final fileName = 'shared_${timestamp}_${copiedPaths.length}.$extension';
          final destPath = '${appDir.path}/$fileName';

          // Copy file to Documents directory
          await sourceFile.copy(destPath);
          copiedPaths.add(destPath);
          print('📸 Copied shared file to Documents: $destPath');
        } catch (e) {
          print('❌ Failed to copy shared file: $e');
        }
      }

      if (copiedPaths.isNotEmpty && mounted) {
        setState(() {
          _mediaPaths.addAll(copiedPaths);
        });

        print('📸 Initialized with ${copiedPaths.length} shared files');

        // Extract location and date from first media file
        await _extractLocationFromImage(copiedPaths.first);
      }
    } catch (e) {
      print('❌ Error copying shared files: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load shared files: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _captionController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _pickMedia(ImageSource source, {bool isVideo = false}) async {
    try {
      if (_mediaPaths.length >= maxMediaCount) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Maximum $maxMediaCount media files allowed')),
          );
        }
        return;
      }

      final XFile? media = isVideo
          ? await _picker.pickVideo(source: ImageSource.gallery)
          : await _picker.pickImage(source: source);

      if (media != null) {
        // Validate video duration (3 minutes max)
        if (isVideo) {
          final controller = VideoPlayerController.file(File(media.path));
          try {
            await controller.initialize();
            final duration = controller.value.duration;
            await controller.dispose();

            if (duration.inSeconds > 180) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Video must be 3 minutes or less'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
              return;
            }
          } catch (e) {
            await controller.dispose();
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Failed to validate video: $e')),
              );
            }
            return;
          }
        }

        // Store temporary path (will be copied to permanent storage only when posting)
        setState(() {
          _mediaPaths.add(media.path);
        });

        print('📸 Added to _mediaPaths (temp): ${_mediaPaths.length} files');

        // Extract location and date from first media file (both images and videos)
        if (_mediaPaths.length == 1) {
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
    // Return early if media is a video (only process images)
    if (imagePath.toLowerCase().endsWith('.mp4') ||
        imagePath.toLowerCase().endsWith('.mov')) {
      return;
    }

    try {
      final exif = await Exif.fromPath(imagePath);
      final coordinates = await exif.getLatLong();
      final attributes = await exif.getAttributes();

      print(attributes);

      // Extract date from EXIF
      DateTime? exifDate;
      if (attributes != null) {
        final dateTimeOriginal = attributes['DateTimeOriginal'];
        if (dateTimeOriginal != null) {
          try {
            // EXIF date format: "2024:01:15 14:30:45"
            final dateStr = dateTimeOriginal.toString();
            final parts = dateStr.split(' ');
            if (parts.length >= 2) {
              final datePart = parts[0].replaceAll(':', '-');
              final timePart = parts[1];
              exifDate = DateTime.parse('${datePart}T$timePart');
            }
          } catch (e) {
            // Failed to parse date
          }
        }
      }

      // Ask user if they want to update location
      if (coordinates != null && mounted) {
        final shouldUpdateLocation = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Update Location?'),
            content: Text('This photo contains GPS data:\n'
                '${coordinates.latitude.toStringAsFixed(6)}, ${coordinates.longitude.toStringAsFixed(6)}\n\n'
                'Do you want to use this location?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('No'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Yes'),
              ),
            ],
          ),
        );

        if (shouldUpdateLocation == true) {
          setState(() {
            _latitude = coordinates.latitude;
            _longitude = coordinates.longitude;
          });

          // Reverse geocode to get address
          if (mounted) {
            await _reverseGeocode(coordinates.latitude, coordinates.longitude);
          }
        }
      }

      // Ask user if they want to update date
      if (exifDate != null && mounted) {
        final dateToUse = exifDate;
        final shouldUpdateDate = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Update Date?'),
            content: Text('This photo was taken on:\n'
                '${DateFormat('yyyy-MM-dd HH:mm').format(dateToUse)}\n\n'
                'Do you want to use this date for the post?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('No'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Yes'),
              ),
            ],
          ),
        );

        if (shouldUpdateDate == true) {
          setState(() {
            _postDate = dateToUse;
          });
        }
      }

      await exif.close();
    } catch (e) {
      print(e);
      // No GPS/date data in image, that's okay
    }
  }

  Future<void> _reverseGeocode(double lat, double lng) async {
    try {
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/geocode/json?latlng=$lat,$lng&key=$MAPS_API_KEY&language=en',
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['results'].isNotEmpty) {
          final address = data['results'][0]['formatted_address'];
          if (mounted) {
            setState(() {
              _locationController.text = address;
            });
          }
        }
      }
    } catch (e) {
      // Fallback to coordinates if reverse geocoding fails
      if (mounted) {
        setState(() {
          _locationController.text =
              '${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)}';
        });
      }
    }
  }

  Future<void> _pickMultipleMedia() async {
    try {
      if (_mediaPaths.length >= maxMediaCount) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Maximum $maxMediaCount media files allowed')),
          );
        }
        return;
      }

      final List<XFile> medias = await _picker.pickMultipleMedia(
        limit: maxMediaCount - _mediaPaths.length,
      );

      if (medias.isNotEmpty) {
        final oldLength = _mediaPaths.length;

        // Store temporary paths (will be copied to permanent storage only when posting)
        setState(() {
          _mediaPaths.addAll(medias.map((m) => m.path));
        });

        print(
            '📸 Multiple - Added ${medias.length} files to _mediaPaths (temp): ${_mediaPaths.length} total files');

        // Extract location and date from first media file if this is the first selection (both images and videos)
        if (oldLength == 0 && medias.isNotEmpty) {
          final firstPath = medias.first.path;
          await _extractLocationFromImage(firstPath);
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
      if (index >= 0 && index < _mediaPaths.length) {
        _mediaPaths.removeAt(index);
      }
    });
  }

  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await _location.serviceEnabled();
      if (!serviceEnabled) {
        serviceEnabled = await _location.requestService();
        if (!serviceEnabled) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Location service is disabled')),
            );
          }
          return;
        }
      }

      PermissionStatus permissionGranted = await _location.hasPermission();
      if (permissionGranted == PermissionStatus.denied) {
        permissionGranted = await _location.requestPermission();
        if (permissionGranted != PermissionStatus.granted) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Location permission denied')),
            );
          }
          return;
        }
      }

      final locationData = await _location.getLocation();

      if (locationData.latitude != null && locationData.longitude != null) {
        setState(() {
          _latitude = locationData.latitude;
          _longitude = locationData.longitude;
        });

        // Reverse geocode to get address
        if (mounted) {
          await _reverseGeocode(
              locationData.latitude!, locationData.longitude!);
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Current location updated')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to get location: $e')),
        );
      }
    }
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _postDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );

    if (picked != null && mounted) {
      final TimeOfDay? timePicked = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_postDate ?? DateTime.now()),
      );

      if (timePicked != null) {
        setState(() {
          _postDate = DateTime(
            picked.year,
            picked.month,
            picked.day,
            timePicked.hour,
            timePicked.minute,
          );
        });
      }
    }
  }

  Future<void> _openLocationPicker() async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (context) => LocationPickerScreen(
          initialLatitude: _latitude,
          initialLongitude: _longitude,
        ),
      ),
    );

    if (result != null) {
      setState(() {
        _latitude = result['latitude'] as double?;
        _longitude = result['longitude'] as double?;
        if (result['address'] != null) {
          _locationController.text = result['address'] as String;
        }
      });
    }
  }

  /// Generate AI image from prompt
  Future<void> _generateAiImage() async {
    if (_mediaPaths.length >= maxMediaCount) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Maximum $maxMediaCount media files allowed')),
        );
      }
      return;
    }

    final controller = TextEditingController();
    final description = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Generate AI Image'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Describe the image you want to generate:'),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                hintText: 'e.g., A beautiful sunset over mountains',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Generate'),
          ),
        ],
      ),
    );

    if (description != null && description.isNotEmpty) {
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      try {
        final imageName = await AiService.generateAvatarImage(
          description: description,
        );

        if (mounted) {
          Navigator.pop(context); // Close loading dialog

          final appDir = await getApplicationDocumentsDirectory();

          if (imageName != null) {
            setState(() {
              _mediaPaths.add('${appDir.path}/$imageName');
            });

            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('AI image generated successfully!'),
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Failed to generate image. Please try again.'),
              ),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          Navigator.pop(context); // Close loading dialog
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error generating image: $e'),
            ),
          );
        }
      }
    }
  }

  /// Show dialog for custom edit prompt
  void _showEditPrompt(int imageIndex) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Image with AI'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Describe the edits you want to make:'),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                hintText: 'e.g., Make the background darker, add more contrast',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _editImageWithAI(imageIndex, controller.text);
            },
            child: const Text('Apply Edit'),
          ),
        ],
      ),
    );
  }

  /// Edit image using AI
  Future<void> _editImageWithAI(int imageIndex, String editPrompt) async {
    final imagePath = _mediaPaths[imageIndex];

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      final editedFileName = await AiService.editAvatarImage(
        imagePath: imagePath,
        editPrompt: editPrompt,
      );

      if (mounted) {
        Navigator.pop(context); // Close loading dialog

        final appDir = await getApplicationDocumentsDirectory();

        if (editedFileName != null) {
          setState(() {
            _mediaPaths[imageIndex] = '${appDir.path}/$editedFileName';
          });

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Image edited successfully!'),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to edit image. Please try again.'),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error editing image: $e'),
          ),
        );
      }
    }
  }

  Future<void> _createPost() async {
    // Validate: title is required if no media/location
    if (_mediaPaths.isEmpty &&
        _locationController.text.isEmpty &&
        _titleController.text.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Please add a title, photo/video, or location')),
        );
      }
      return;
    }

    setState(() => _isPosting = true);

    try {
      // Copy temporary media files to permanent storage
      final permanentPaths = <String>[];
      final appDir = await getApplicationDocumentsDirectory();

      for (var i = 0; i < _mediaPaths.length; i++) {
        try {
          final tempPath = _mediaPaths[i];
          if (!await File(tempPath).exists()) {
            print('⚠️ Temp file not found: $tempPath');
            continue;
          }

          // Check if file is already in Documents directory
          if (tempPath.startsWith(appDir.path)) {
            // File is already in Documents, no need to copy
            permanentPaths.add(tempPath);
            print('✓ File already in Documents: $tempPath');
          } else {
            // File is in temporary location, copy to Documents
            final timestamp = DateTime.now().millisecondsSinceEpoch;
            final extension = tempPath.split('.').last;
            final fileName = 'post_${timestamp}_$i.$extension';
            final permanentPath = '${appDir.path}/$fileName';

            await File(tempPath).copy(permanentPath);
            permanentPaths.add(permanentPath);
            print('📸 Copied to permanent storage: $permanentPath');
          }
        } catch (e) {
          print('❌ Failed to copy media: $e');
        }
      }

      final post = Post(
        title: _titleController.text.isEmpty ? null : _titleController.text,
        mediaPaths: permanentPaths,
        caption:
            _captionController.text.isEmpty ? null : _captionController.text,
        locationName:
            _locationController.text.isEmpty ? null : _locationController.text,
        latitude: _latitude,
        longitude: _longitude,
        postDate: _postDate,
        tag: _selectedTag,
        enableAiReactions: _enableAiReactions,
      );

      final postId = await _db.createPost(post);
      final createdPost = await _db.getPost(postId);

      // Update settings with current AI reactions preference
      final settings = await SettingsService.loadSettings();
      await SettingsService.saveSettings(settings.copyWith(
        enableAiReactions: _enableAiReactions,
      ));

      if (createdPost != null && _enableAiReactions) {
        await _enqueueAiReactionTask(createdPost);
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

  Future<void> _enqueueAiReactionTask(Post post) async {
    await AiTaskQueueService.instance.enqueueReactionTask(post.id!);
    // Process tasks in background (don't await)
    AiTaskQueueService.instance.processPendingTasks();
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
                          const Icon(Icons.add_photo_alternate,
                              size: 64, color: Colors.grey),
                          const SizedBox(height: 16),
                          const Text(
                            'Add photos or videos',
                            style: TextStyle(color: Colors.grey),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Up to $maxMediaCount files',
                            style: const TextStyle(
                                color: Colors.grey, fontSize: 12),
                          ),
                        ],
                      ),
                    )
                  else
                    ReorderableGridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                      ),
                      itemCount: _mediaPaths.length,
                      onReorder: (oldIndex, newIndex) {
                        setState(() {
                          final item = _mediaPaths.removeAt(oldIndex);
                          _mediaPaths.insert(newIndex, item);
                        });
                      },
                      itemBuilder: (context, index) {
                        final path = _mediaPaths[index];
                        final isVideo = path.toLowerCase().endsWith('.mp4') ||
                            path.toLowerCase().endsWith('.mov');

                        return Stack(
                          key: ValueKey(path),
                          children: [
                            GestureDetector(
                              onTap: isVideo
                                  ? () {
                                      // Show video player dialog
                                      showDialog(
                                        context: context,
                                        builder: (context) => Dialog(
                                          backgroundColor: Colors.black,
                                          child: VideoPlayerWidget(
                                              videoPath: path),
                                        ),
                                      );
                                    }
                                  : null,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: isVideo
                                    ? VideoThumbnailWidget(videoPath: path)
                                    : Image.file(
                                        File(path),
                                        fit: BoxFit.cover,
                                        width: double.infinity,
                                        height: double.infinity,
                                      ),
                              ),
                            ),
                            // Edit button for images only (top-right, before close button)
                            if (!isVideo)
                              Positioned(
                                top: 4,
                                right: 36,
                                child: IconButton(
                                  onPressed: () => _showEditPrompt(index),
                                  icon: const Icon(Icons.auto_awesome,
                                      color: Colors.white),
                                  style: IconButton.styleFrom(
                                    backgroundColor: Colors.black54,
                                    padding: const EdgeInsets.all(4),
                                    minimumSize: const Size(28, 28),
                                  ),
                                ),
                              ),
                            // Close button (top-right corner)
                            Positioned(
                              top: 4,
                              right: 4,
                              child: IconButton(
                                onPressed: () => _removeMedia(index),
                                icon: const Icon(Icons.close,
                                    color: Colors.white),
                                style: IconButton.styleFrom(
                                  backgroundColor: Colors.black54,
                                  padding: const EdgeInsets.all(4),
                                  minimumSize: const Size(28, 28),
                                ),
                              ),
                            ),
                            // Index indicator (bottom-left corner)
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
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _generateAiImage,
                          icon: const Icon(Icons.auto_awesome),
                          label: const Text('AI Image'),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Title
                  TextField(
                    controller: _titleController,
                    decoration: InputDecoration(
                      labelText: 'Title',
                      hintText: 'Enter post title...',
                      border: const OutlineInputBorder(),
                      suffixIcon: _mediaPaths.isEmpty &&
                              _locationController.text.isEmpty
                          ? const Icon(Icons.error_outline,
                              color: Colors.orange)
                          : null,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Caption
                  TextField(
                    controller: _captionController,
                    decoration: const InputDecoration(
                      labelText: 'Caption (optional)',
                      hintText: 'Write something about this post...',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 16),

                  // Date Picker
                  InkWell(
                    onTap: _selectDate,
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Post Date (optional)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.calendar_today),
                      ),
                      child: Text(
                        _postDate != null
                            ? DateFormat('yyyy-MM-dd HH:mm').format(_postDate!)
                            : 'Select date and time',
                        style: TextStyle(
                          color: _postDate != null ? null : Colors.grey,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Location with Address Search, Current Location, and Edit Button
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: AddressSearchField(
                          controller: _locationController,
                          hasCoordinates:
                              _latitude != null && _longitude != null,
                          onLocationSelected: (lat, lng, address) {
                            setState(() {
                              _latitude = lat;
                              _longitude = lng;
                              _locationController.text = address;
                            });
                          },
                          onClearAll: () {
                            setState(() {
                              _latitude = null;
                              _longitude = null;
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: IconButton(
                          onPressed: _getCurrentLocation,
                          icon: const Icon(Icons.my_location),
                          tooltip: 'Use current location',
                          style: IconButton.styleFrom(
                            backgroundColor: Theme.of(context)
                                .primaryColor
                                .withValues(alpha: 0.1),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: IconButton(
                          onPressed: _openLocationPicker,
                          icon: const Icon(Icons.edit_location),
                          tooltip: 'Edit location on map',
                          style: IconButton.styleFrom(
                            backgroundColor: Theme.of(context)
                                .primaryColor
                                .withValues(alpha: 0.1),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Tag Selector
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Tag (optional)',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ChoiceChip(
                            label: const Text('None'),
                            selected: _selectedTag == null,
                            onSelected: (selected) {
                              if (selected) {
                                setState(() => _selectedTag = null);
                              }
                            },
                          ),
                          ...TagHelper.availableTags.map((tag) {
                            final color = TagHelper.getTagColor(tag);
                            return ChoiceChip(
                              label: Text(
                                TagHelper.defaultTagNames[tag]!,
                                style: TextStyle(
                                  color: _selectedTag == tag
                                      ? Colors.white
                                      : color,
                                ),
                              ),
                              selected: _selectedTag == tag,
                              selectedColor: color,
                              backgroundColor: color.withOpacity(0.2),
                              onSelected: (selected) {
                                setState(
                                    () => _selectedTag = selected ? tag : null);
                              },
                            );
                          }),
                        ],
                      ),
                    ],
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
                          Icon(Icons.info_outline,
                              color: Colors.blue, size: 20),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'AI friends will react based on your settings',
                              style:
                                  TextStyle(color: Colors.blue, fontSize: 13),
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
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
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
