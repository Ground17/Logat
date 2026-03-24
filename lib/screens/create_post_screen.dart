import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:native_exif/native_exif.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:location/location.dart';
import 'package:intl/intl.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:video_player/video_player.dart';
import 'package:reorderable_grid_view/reorderable_grid_view.dart';
import '../models/post.dart';
import '../database/database_helper.dart';
import '../widgets/video_player_widget.dart';
import '../widgets/video_thumbnail_widget.dart';
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

  List<String> _mediaPaths = []; // Temporary paths (before saving)
  bool _isPosting = false;
  double? _latitude;
  double? _longitude;
  DateTime? _postDate;
  String? _selectedTag;
  List<String> _keywords = [];
  bool _loadingKeywords = false;
  final _keywordController = TextEditingController();
  static const int maxMediaCount = 20;
  static const int maxKeywords = 10;

  @override
  void initState() {
    super.initState();

    // Handle initial media paths from shared intent
    if (widget.initialMediaPaths != null && widget.initialMediaPaths!.isNotEmpty) {
      _copySharedFilesToDocuments(widget.initialMediaPaths!);
    }
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
    _keywordController.dispose();
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
    if (_mediaPaths.length >= maxMediaCount) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Maximum $maxMediaCount media files allowed')),
        );
      }
      return;
    }

    final permission = await PhotoManager.requestPermissionExtend();
    if (!permission.isAuth && !permission.hasAccess) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Photo library access denied')),
        );
      }
      return;
    }

    final selected = await Navigator.push<List<AssetEntity>>(
      context,
      MaterialPageRoute(
        builder: (_) => _PhotoPickerScreen(
          maxCount: maxMediaCount - _mediaPaths.length,
        ),
      ),
    );

    if (selected == null || selected.isEmpty) return;

    final oldLength = _mediaPaths.length;

    for (final asset in selected) {
      final file = await asset.file;
      if (file != null) {
        setState(() => _mediaPaths.add(file.path));
      }
    }

    if (oldLength == 0 && _mediaPaths.isNotEmpty) {
      await _extractLocationFromImage(_mediaPaths.first);
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

  void _addKeyword(String kw) {
    final trimmed = kw.trim();
    if (trimmed.isEmpty || _keywords.contains(trimmed)) return;
    if (_keywords.length >= maxKeywords) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Max $maxKeywords keywords')),
      );
      return;
    }
    setState(() {
      _keywords.add(trimmed);
      _keywordController.clear();
    });
  }

  Future<void> _suggestKeywordsWithAi() async {
    final title = _titleController.text.trim();
    final caption = _captionController.text.trim();
    final location = _locationController.text.trim();
    if (title.isEmpty && caption.isEmpty && location.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add a title or caption first')),
      );
      return;
    }

    setState(() => _loadingKeywords = true);
    try {
      final prompt = '''
Post info:
- Title: ${title.isEmpty ? '(none)' : title}
- Caption: ${caption.isEmpty ? '(none)' : caption}
- Location: ${location.isEmpty ? '(none)' : location}

Suggest 5 concise keyword tags (single words or short phrases) for this post.
Return ONLY a JSON array of strings, e.g. ["travel","sunset","friends"]
''';
      final url = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=$GEMINI_KEYS',
      );
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [
            {
              'role': 'user',
              'parts': [
                {'text': prompt}
              ],
            }
          ],
          'generationConfig': {
            'temperature': 0.5,
            'responseMimeType': 'application/json',
          },
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final text =
            data['candidates'][0]['content']['parts'][0]['text'] as String;
        final cleaned = text
            .replaceAll(RegExp(r'```json\s*'), '')
            .replaceAll(RegExp(r'```\s*'), '')
            .trim();
        final suggestions = jsonDecode(cleaned) as List<dynamic>;
        if (mounted) {
          _showKeywordSuggestions(
              suggestions.map((s) => s.toString()).toList());
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('AI suggestion failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingKeywords = false);
    }
  }

  void _showKeywordSuggestions(List<String> suggestions) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => _KeywordSuggestionsSheet(
        suggestions: suggestions,
        existing: _keywords,
        onAdd: (kw) {
          if (!_keywords.contains(kw) && _keywords.length < maxKeywords) {
            setState(() => _keywords.add(kw));
          }
        },
      ),
    );
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
        keywords: _keywords,
      );

      await _db.createPost(post);

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
                  const SizedBox(height: 16),

                  // Keyword Tags
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Keywords (${_keywords.length}/$maxKeywords)',
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w500),
                          ),
                          const Spacer(),
                          _loadingKeywords
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2),
                                )
                              : TextButton.icon(
                                  onPressed: _suggestKeywordsWithAi,
                                  icon: const Icon(Icons.auto_awesome,
                                      size: 16),
                                  label: const Text('AI Suggest'),
                                ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Current keywords as chips
                      if (_keywords.isNotEmpty)
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: _keywords
                              .map((kw) => Chip(
                                    label: Text('#$kw'),
                                    deleteIcon: const Icon(Icons.close,
                                        size: 14),
                                    onDeleted: () =>
                                        setState(() => _keywords.remove(kw)),
                                  ))
                              .toList(),
                        ),
                      if (_keywords.isNotEmpty)
                        const SizedBox(height: 8),
                      // Input row
                      if (_keywords.length < maxKeywords)
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _keywordController,
                                decoration: const InputDecoration(
                                  hintText: 'Add keyword...',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 10),
                                ),
                                onSubmitted: _addKeyword,
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton.filled(
                              onPressed: () =>
                                  _addKeyword(_keywordController.text),
                              icon: const Icon(Icons.add),
                            ),
                          ],
                        ),
                    ],
                  ),
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

// ─── Custom photo/video picker ─────────────────────────────────────────────

class _PhotoPickerScreen extends StatefulWidget {
  const _PhotoPickerScreen({required this.maxCount});
  final int maxCount;

  @override
  State<_PhotoPickerScreen> createState() => _PhotoPickerScreenState();
}

class _PhotoPickerScreenState extends State<_PhotoPickerScreen> {
  List<AssetPathEntity> _albums = [];
  AssetPathEntity? _currentAlbum;
  List<AssetEntity> _assets = [];
  final Set<String> _selected = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadAlbums();
  }

  Future<void> _loadAlbums() async {
    final albums = await PhotoManager.getAssetPathList(
      type: RequestType.common,
      filterOption: FilterOptionGroup(
        imageOption: const FilterOption(needTitle: false),
        videoOption: const FilterOption(needTitle: false),
      ),
    );
    if (albums.isEmpty) return;
    setState(() {
      _albums = albums;
      _currentAlbum = albums.first;
      _loading = false;
    });
    await _loadAssets(albums.first);
  }

  Future<void> _loadAssets(AssetPathEntity album) async {
    final count = await album.assetCountAsync;
    final assets = await album.getAssetListRange(start: 0, end: count);
    if (mounted) setState(() => _assets = assets);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _albums.isEmpty
            ? const Text('Gallery')
            : DropdownButton<AssetPathEntity>(
                value: _currentAlbum,
                underline: const SizedBox.shrink(),
                items: _albums
                    .map((a) => DropdownMenuItem(value: a, child: Text(a.name)))
                    .toList(),
                onChanged: (a) {
                  if (a == null) return;
                  setState(() {
                    _currentAlbum = a;
                    _assets = [];
                  });
                  _loadAssets(a);
                },
              ),
        actions: [
          if (_selected.isNotEmpty)
            TextButton(
              onPressed: _confirm,
              child: Text('Add (${_selected.length})'),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 2,
                crossAxisSpacing: 2,
              ),
              itemCount: _assets.length,
              itemBuilder: (ctx, i) {
                final asset = _assets[i];
                final isSelected = _selected.contains(asset.id);
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      if (isSelected) {
                        _selected.remove(asset.id);
                      } else if (_selected.length < widget.maxCount) {
                        _selected.add(asset.id);
                      }
                    });
                  },
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      FutureBuilder<Uint8List?>(
                        future: asset.thumbnailDataWithSize(
                            const ThumbnailSize(300, 300)),
                        builder: (ctx, snap) {
                          if (snap.data == null) {
                            return Container(color: Colors.grey[200]);
                          }
                          return Image.memory(snap.data!, fit: BoxFit.cover);
                        },
                      ),
                      if (asset.type == AssetType.video)
                        const Align(
                          alignment: Alignment.bottomLeft,
                          child: Padding(
                            padding: EdgeInsets.all(4),
                            child: Icon(Icons.videocam,
                                color: Colors.white, size: 18),
                          ),
                        ),
                      if (isSelected)
                        Container(
                          color: Colors.blue.withValues(alpha: 0.4),
                          child: const Center(
                            child: Icon(Icons.check_circle,
                                color: Colors.white, size: 32),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  Future<void> _confirm() async {
    final entities = _assets
        .where((a) => _selected.contains(a.id))
        .toList();
    Navigator.pop(context, entities);
  }
}

// ─── Keyword suggestions bottom sheet ─────────────────────────────────────

class _KeywordSuggestionsSheet extends StatefulWidget {
  const _KeywordSuggestionsSheet({
    required this.suggestions,
    required this.existing,
    required this.onAdd,
  });

  final List<String> suggestions;
  final List<String> existing;
  final void Function(String) onAdd;

  @override
  State<_KeywordSuggestionsSheet> createState() =>
      _KeywordSuggestionsSheetState();
}

class _KeywordSuggestionsSheetState extends State<_KeywordSuggestionsSheet> {
  late final Set<String> _added = Set.from(widget.existing);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'AI Suggested Keywords',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: widget.suggestions.map((kw) {
              final isAdded = _added.contains(kw);
              return FilterChip(
                label: Text('#$kw'),
                selected: isAdded,
                onSelected: (selected) {
                  if (selected && !isAdded) {
                    widget.onAdd(kw);
                    setState(() => _added.add(kw));
                  }
                },
                selectedColor:
                    Theme.of(context).colorScheme.primaryContainer,
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Done'),
            ),
          ),
        ],
      ),
    );
  }
}
