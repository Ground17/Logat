import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import '../models/ai_persona.dart';
import '../database/database_helper.dart';
import '../services/ai_service.dart';

class EditPersonaScreen extends StatefulWidget {
  final AiPersona? persona;

  const EditPersonaScreen({Key? key, this.persona}) : super(key: key);

  @override
  State<EditPersonaScreen> createState() => _EditPersonaScreenState();
}

class _EditPersonaScreenState extends State<EditPersonaScreen> {
  final DatabaseHelper _db = DatabaseHelper.instance;
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _avatarController;
  late TextEditingController _roleController;
  late TextEditingController _personalityController;
  late TextEditingController _systemPromptController;
  late TextEditingController _bioController;

  late AiModel _selectedModel;
  late double _commentProbability;
  late double _likeProbability;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final persona = widget.persona;

    _nameController = TextEditingController(text: persona?.name ?? '');
    _avatarController = TextEditingController(text: persona?.avatar ?? '😊');
    _roleController = TextEditingController(text: persona?.role ?? '');
    _personalityController = TextEditingController(text: persona?.personality ?? '');
    _systemPromptController = TextEditingController(text: persona?.systemPrompt ?? '');
    _bioController = TextEditingController(text: persona?.bio ?? '');

    _selectedModel = persona?.aiModel ?? AiModel.gemini3FlashPreview;
    _commentProbability = persona?.commentProbability ?? 0.5;
    _likeProbability = persona?.likeProbability ?? 0.7;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _avatarController.dispose();
    _roleController.dispose();
    _personalityController.dispose();
    _systemPromptController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  /// Check if text is a file path
  bool _isImagePath(String text) {
    return text.contains('/') && 
           (text.endsWith('.png') || text.endsWith('.jpg') || text.endsWith('.jpeg') || text.endsWith('.webp'));
  }

  /// Pick image from gallery
  Future<void> _pickImageFromGallery() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: ImageSource.gallery);

      if (pickedFile != null) {
        setState(() {
          _avatarController.text = pickedFile.path;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick image: $e')),
        );
      }
    }
  }

  /// Show custom edit prompt dialog
  void _showCustomEditPrompt(String imagePath) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Avatar'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Describe the edits you want to make:'),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                hintText: 'e.g., Make the background transparent, enhance colors',
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
              _editImageWithAI(imagePath, controller.text);
            },
            child: const Text('Apply Edit'),
          ),
        ],
      ),
    );
  }

  /// Edit image using AI
  Future<void> _editImageWithAI(String imagePath, String editPrompt) async {
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
            _avatarController.text = editedImagePath;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Avatar edited successfully!'),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to edit avatar. Please try again.'),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error editing avatar: $e'),
          ),
        );
      }
    }
  }

  void _showAvatarOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.emoji_emotions),
              title: const Text('Choose Emoji'),
              onTap: () {
                Navigator.pop(context);
                _showEmojiPicker();
              },
            ),
            ListTile(
              leading: const Icon(Icons.image),
              title: const Text('Pick from Gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickImageFromGallery();
              },
            ),
            ListTile(
              leading: const Icon(Icons.auto_awesome),
              title: const Text('Generate AI Avatar'),
              subtitle: const Text('Create avatar using AI image generation'),
              onTap: () {
                Navigator.pop(context);
                _generateAiAvatar();
              },
            ),
            if (_isImagePath(_avatarController.text))
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('Edit with AI'),
                subtitle: const Text('Modify current avatar image'),
                onTap: () {
                  Navigator.pop(context);
                  _showCustomEditPrompt(_avatarController.text);
                },
              ),
          ],
        ),
      ),
    );
  }

  void _showEmojiPicker() {
    final emojis = ['😊', '📸', '✈️', '🎮', '🍰', '💪', '🎨', '🎵', '📚', '🌟',
                    '🐱', '🐶', '🦊', '🐼', '🦁', '🐯', '🐻', '🐨', '🐰', '🦄'];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Choose an Emoji'),
        content: SizedBox(
          width: double.maxFinite,
          child: GridView.builder(
            shrinkWrap: true,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 5,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: emojis.length,
            itemBuilder: (context, index) {
              return InkWell(
                onTap: () {
                  setState(() {
                    _avatarController.text = emojis[index];
                  });
                  Navigator.pop(context);
                },
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      emojis[index],
                      style: const TextStyle(fontSize: 32),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _generateAiAvatar() async {
    final controller = TextEditingController();
    final description = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Generate AI Avatar'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Describe the avatar you want to generate:'),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                hintText: 'e.g., A friendly robot face, A cute cat character',
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
        // Generate image using DALL-E
        final imagePath = await AiService.generateAvatarImage(
          description: description,
        );

        if (mounted) {
          Navigator.pop(context); // Close loading dialog

          if (imagePath != null) {
            setState(() {
              _avatarController.text = imagePath;
            });

            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('AI avatar generated successfully!'),
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Failed to generate avatar image. Please try again.'),
              ),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          Navigator.pop(context); // Close loading dialog
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error generating avatar: $e'),
            ),
          );
        }
      }
    }
  }

  Future<void> _savePersona() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isSaving = true);

    try {
      final persona = AiPersona(
        id: widget.persona?.id,
        name: _nameController.text,
        avatar: _avatarController.text,
        role: _roleController.text,
        personality: _personalityController.text,
        systemPrompt: _systemPromptController.text,
        bio: _bioController.text.isEmpty ? null : _bioController.text,
        aiModel: _selectedModel,
        commentProbability: _commentProbability,
        likeProbability: _likeProbability,
      );

      if (widget.persona == null) {
        await _db.createPersona(persona);
      } else {
        await _db.updatePersona(persona);
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.persona == null
                ? 'Persona created successfully'
                : 'Persona updated successfully'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save persona: $e')),
        );
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.persona != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Persona' : 'Create Persona'),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        foregroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _savePersona,
            child: _isSaving
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    ),
                  )
                : Text(
                    'Save',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Basic Information
              const Text(
                'Basic Information',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Avatar Selection
              GestureDetector(
                onTap: _showAvatarOptions,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    children: [
                      // Avatar display - emoji or image
                      SizedBox(
                        width: 64,
                        height: 64,
                        child: _avatarController.text.isEmpty
                            ? Container(
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey.shade300),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.image),
                              )
                            : _isImagePath(_avatarController.text)
                                ? Container(
                                    decoration: BoxDecoration(
                                      border: Border.all(color: Colors.grey.shade300),
                                      borderRadius: BorderRadius.circular(8),
                                      image: DecorationImage(
                                        image: FileImage(File(_avatarController.text)),
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  )
                                : Container(
                                    decoration: BoxDecoration(
                                      border: Border.all(color: Colors.grey.shade300),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Center(
                                      child: Text(
                                        _avatarController.text,
                                        style: const TextStyle(fontSize: 40),
                                      ),
                                    ),
                                  ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Avatar',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _isImagePath(_avatarController.text)
                                  ? 'AI-generated avatar'
                                  : 'Tap to change emoji or generate AI avatar',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.edit),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _roleController,
                decoration: const InputDecoration(
                  labelText: 'Role',
                  border: OutlineInputBorder(),
                  helperText: 'e.g., Best Friend, Photographer',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a role';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _personalityController,
                decoration: const InputDecoration(
                  labelText: 'Personality',
                  border: OutlineInputBorder(),
                  helperText: 'Brief description of personality',
                ),
                maxLines: 2,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a personality description';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _bioController,
                decoration: const InputDecoration(
                  labelText: 'Bio (optional)',
                  border: OutlineInputBorder(),
                  helperText: 'Short bio for profile',
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _systemPromptController,
                decoration: const InputDecoration(
                  labelText: 'System Prompt',
                  border: OutlineInputBorder(),
                  helperText: 'Instructions for AI behavior',
                ),
                maxLines: 6,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a system prompt';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 24),

              // AI Settings
              const Text(
                'AI Settings',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),

              // AI Model Selection
              const Text(
                'AI Model',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              Card(
                child: Column(
                  children: [
                    RadioListTile<AiModel>(
                      value: AiModel.gemini3FlashPreview,
                      groupValue: _selectedModel,
                      onChanged: (value) {
                        setState(() => _selectedModel = value!);
                      },
                      title: const Text('Gemini 3 Flash Preview'),
                      subtitle: const Text('Fast and efficient'),
                    ),
                    const Divider(height: 1),
                    RadioListTile<AiModel>(
                      value: AiModel.gemini3ProPreview,
                      groupValue: _selectedModel,
                      onChanged: (value) {
                        setState(() => _selectedModel = value!);
                      },
                      title: const Text('Gemini 3 Pro Preview'),
                      subtitle: const Text('More capable'),
                    ),
                    const Divider(height: 1),
                    RadioListTile<AiModel>(
                      value: AiModel.gpt51,
                      groupValue: _selectedModel,
                      onChanged: (value) {
                        setState(() => _selectedModel = value!);
                      },
                      title: const Text('GPT-5.1'),
                      subtitle: const Text('OpenAI model'),
                    ),
                    const Divider(height: 1),
                    RadioListTile<AiModel>(
                      value: AiModel.gpt52,
                      groupValue: _selectedModel,
                      onChanged: (value) {
                        setState(() => _selectedModel = value!);
                      },
                      title: const Text('GPT-5.2'),
                      subtitle: const Text('Latest OpenAI model'),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Comment Probability
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Comment Probability',
                            style: TextStyle(fontWeight: FontWeight.w500),
                          ),
                          Text(
                            '${(_commentProbability * 100).toInt()}%',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Theme.of(context).primaryColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Slider(
                        value: _commentProbability,
                        min: 0.0,
                        max: 1.0,
                        divisions: 10,
                        label: '${(_commentProbability * 100).toInt()}%',
                        onChanged: (value) {
                          setState(() => _commentProbability = value);
                        },
                      ),
                      const Text(
                        'Chance of leaving a comment on posts',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Like Probability
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Like Probability',
                            style: TextStyle(fontWeight: FontWeight.w500),
                          ),
                          Text(
                            '${(_likeProbability * 100).toInt()}%',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Theme.of(context).primaryColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Slider(
                        value: _likeProbability,
                        min: 0.0,
                        max: 1.0,
                        divisions: 10,
                        label: '${(_likeProbability * 100).toInt()}%',
                        onChanged: (value) {
                          setState(() => _likeProbability = value);
                        },
                      ),
                      const Text(
                        'Chance of liking posts',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
