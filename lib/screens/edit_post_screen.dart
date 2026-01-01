import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:native_exif/native_exif.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:location/location.dart';
import 'package:intl/intl.dart';
import '../models/post.dart';
import '../database/database_helper.dart';
import '../services/ai_service.dart';
import '../widgets/address_search_field.dart';
import '../widgets/video_player_widget.dart';
import '../widgets/video_thumbnail_widget.dart';
import '../utils/tag_helper.dart';
import 'location_picker_screen.dart';
import '../key.dart';

class EditPostScreen extends StatefulWidget {
  final Post post;

  const EditPostScreen({super.key, required this.post});

  @override
  State<EditPostScreen> createState() => _EditPostScreenState();
}

class _EditPostScreenState extends State<EditPostScreen> {
  final _titleController = TextEditingController();
  final _captionController = TextEditingController();
  final _locationController = TextEditingController();
  final DatabaseHelper _db = DatabaseHelper.instance;
  final ImagePicker _picker = ImagePicker();
  final Location _location = Location();

  List<String> _mediaPaths = [];
  bool _isSaving = false;
  double? _latitude;
  double? _longitude;
  String? _selectedTag;
  DateTime? _postDate;
  static const int maxMediaCount = 20;

  @override
  void initState() {
    super.initState();
    _mediaPaths = List.from(widget.post.mediaPaths);
    _titleController.text = widget.post.title ?? '';
    _captionController.text = widget.post.caption ?? '';
    _locationController.text = widget.post.locationName ?? '';
    _latitude = widget.post.latitude;
    _longitude = widget.post.longitude;
    _selectedTag = widget.post.tag;
    _postDate = widget.post.postDate;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _captionController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _extractLocationFromImage(String imagePath) async {
    try {
      final exif = await Exif.fromPath(imagePath);
      final attributes = await exif.getAttributes();
      final coordinates = await exif.getLatLong();

      // Extract date from EXIF
      DateTime? exifDate;
      if (attributes != null) {
        final dateTimeOriginal = attributes['DateTimeOriginal'];
        if (dateTimeOriginal != null) {
          try {
            final dateStr = dateTimeOriginal.toString();
            final parts = dateStr.split(' ');
            if (parts.length >= 2) {
              final datePart = parts[0].replaceAll(':', '-');
              final timePart = parts[1];
              exifDate = DateTime.parse('${datePart}T$timePart');
            }
          } catch (e) {
            // Failed to parse EXIF date
          }
        }
      }

      // Ask user if they want to update location
      if (coordinates != null && mounted) {
        final shouldUpdateLocation = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Update Location?'),
            content: Text(
              'This photo contains GPS data:\n'
              'Latitude: ${coordinates.latitude.toStringAsFixed(6)}\n'
              'Longitude: ${coordinates.longitude.toStringAsFixed(6)}\n\n'
              'Do you want to use this location?',
            ),
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
            content: Text(
              'This photo was taken on:\n'
              '${DateFormat('yyyy-MM-dd HH:mm').format(dateToUse)}\n\n'
              'Do you want to use this date for the post?',
            ),
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
      // No GPS data or EXIF data in image
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
          _locationController.text = '${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)}';
        });
      }
    }
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

        await _reverseGeocode(locationData.latitude!, locationData.longitude!);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Current location updated!')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to get current location: $e')),
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
        // Copy to permanent storage
        final appDir = await getApplicationDocumentsDirectory();
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final extension = media.path.split('.').last;
        final fileName = 'post_$timestamp.$extension';
        final permanentPath = '${appDir.path}/$fileName';

        await File(media.path).copy(permanentPath);
        print('📸 Copied: ${media.path} -> $permanentPath');

        setState(() {
          _mediaPaths.add(permanentPath);
        });

        if (_mediaPaths.length == 1 && !isVideo) {
          await _extractLocationFromImage(permanentPath);
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
        final appDir = await getApplicationDocumentsDirectory();
        final List<String> permanentPaths = [];

        // Copy each media file to permanent storage
        for (var media in medias) {
          final timestamp = DateTime.now().millisecondsSinceEpoch;
          final extension = media.path.split('.').last;
          final fileName = 'post_${timestamp}_${permanentPaths.length}.$extension';
          final permanentPath = '${appDir.path}/$fileName';

          await File(media.path).copy(permanentPath);
          permanentPaths.add(permanentPath);
        }

        setState(() {
          _mediaPaths.addAll(permanentPaths);
        });

        if (oldLength == 0 && permanentPaths.isNotEmpty) {
          final firstPath = permanentPaths.first;
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
        final imagePath = await AiService.generateAvatarImage(
          description: description,
        );

        if (mounted) {
          Navigator.pop(context); // Close loading dialog

          if (imagePath != null) {
            setState(() {
              _mediaPaths.add(imagePath);
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
      final editedImagePath = await AiService.editAvatarImage(
        imagePath: imagePath,
        editPrompt: editPrompt,
      );

      if (mounted) {
        Navigator.pop(context); // Close loading dialog

        if (editedImagePath != null) {
          setState(() {
            _mediaPaths[imageIndex] = editedImagePath;
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

  Future<void> _savePost() async {
    // Validate: title is required if no media/location
    if (_mediaPaths.isEmpty &&
        _locationController.text.isEmpty &&
        _titleController.text.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please add a title, photo/video, or location')),
        );
      }
      return;
    }

    setState(() => _isSaving = true);

    try {
      final updatedPost = widget.post.copyWith(
        title: _titleController.text.isEmpty ? null : _titleController.text,
        mediaPaths: _mediaPaths,
        caption: _captionController.text.isEmpty ? null : _captionController.text,
        locationName: _locationController.text.isEmpty ? null : _locationController.text,
        latitude: _latitude,
        longitude: _longitude,
        tag: _selectedTag,
        postDate: _postDate,
        // enableAiReactions는 수정하지 않음 - 기존 값 유지
        updatedAt: DateTime.now(),
      );

      await _db.updatePost(updatedPost);

      if (mounted) {
        Navigator.pop(context, true); // Return true to indicate success
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Post updated successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update post: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Post'),
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
                            GestureDetector(
                              onTap: isVideo
                                  ? () {
                                      // Show video player dialog
                                      showDialog(
                                        context: context,
                                        builder: (context) => Dialog(
                                          backgroundColor: Colors.black,
                                          child: VideoPlayerWidget(videoPath: path),
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
                                  icon: const Icon(Icons.auto_awesome, color: Colors.white),
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
                                icon: const Icon(Icons.close, color: Colors.white),
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
                      suffixIcon: _mediaPaths.isEmpty && _locationController.text.isEmpty
                          ? const Icon(Icons.error_outline, color: Colors.orange)
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
                          hasCoordinates: _latitude != null && _longitude != null,
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
                            backgroundColor: Theme.of(context).primaryColor.withValues(alpha: 0.1),
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
                            backgroundColor: Theme.of(context).primaryColor.withValues(alpha: 0.1),
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
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
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
                                  color: _selectedTag == tag ? Colors.white : color,
                                ),
                              ),
                              selected: _selectedTag == tag,
                              selectedColor: color,
                              backgroundColor: color.withValues(alpha: 0.2),
                              onSelected: (selected) {
                                setState(() => _selectedTag = selected ? tag : null);
                              },
                            );
                          }),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
          // Bottom Save Button
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _savePost,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey,
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text(
                        'Save Changes',
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
