import 'package:flutter/material.dart';
import '../models/ai_persona.dart';
import '../database/database_helper.dart';

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

  late AiProvider _selectedProvider;
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

    _selectedProvider = persona?.aiProvider ?? AiProvider.gemini;
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
              leading: const Icon(Icons.auto_awesome),
              title: const Text('Generate AI Avatar'),
              subtitle: const Text('Create avatar using AI image generation'),
              onTap: () {
                Navigator.pop(context);
                _generateAiAvatar();
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
                hintText: 'e.g., A friendly robot face',
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
      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      // For now, we'll use a placeholder emoji based on keywords
      // In a real implementation, you would call an AI image generation API
      String generatedEmoji = '🤖';

      if (description.toLowerCase().contains('robot')) generatedEmoji = '🤖';
      else if (description.toLowerCase().contains('cat')) generatedEmoji = '🐱';
      else if (description.toLowerCase().contains('dog')) generatedEmoji = '🐶';
      else if (description.toLowerCase().contains('star')) generatedEmoji = '⭐';
      else if (description.toLowerCase().contains('heart')) generatedEmoji = '❤️';
      else if (description.toLowerCase().contains('smile')) generatedEmoji = '😊';
      else if (description.toLowerCase().contains('cool')) generatedEmoji = '😎';

      await Future.delayed(const Duration(seconds: 1));

      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        setState(() {
          _avatarController.text = generatedEmoji;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('AI avatar generated! (Using emoji placeholder)'),
          ),
        );
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
        aiProvider: _selectedProvider,
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
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _savePersona,
            child: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text(
                    'Save',
                    style: TextStyle(color: Colors.white),
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
                      Text(
                        _avatarController.text,
                        style: const TextStyle(fontSize: 48),
                      ),
                      const SizedBox(width: 16),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Avatar',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text('Tap to change emoji or generate AI avatar'),
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

              // AI Provider
              Card(
                child: Column(
                  children: [
                    RadioListTile<AiProvider>(
                      value: AiProvider.gemini,
                      groupValue: _selectedProvider,
                      onChanged: (value) {
                        setState(() => _selectedProvider = value!);
                      },
                      title: const Text('Google Gemini'),
                      subtitle: const Text('Recommended'),
                    ),
                    const Divider(height: 1),
                    RadioListTile<AiProvider>(
                      value: AiProvider.openai,
                      groupValue: _selectedProvider,
                      onChanged: (value) {
                        setState(() => _selectedProvider = value!);
                      },
                      title: const Text('OpenAI GPT'),
                      subtitle: const Text('Alternative'),
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
