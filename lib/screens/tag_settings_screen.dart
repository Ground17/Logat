import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../utils/tag_helper.dart';

class TagSettingsScreen extends StatefulWidget {
  const TagSettingsScreen({super.key});

  @override
  State<TagSettingsScreen> createState() => _TagSettingsScreenState();
}

class _TagSettingsScreenState extends State<TagSettingsScreen> {
  final DatabaseHelper _db = DatabaseHelper.instance;
  final Map<String, TextEditingController> _controllers = {};
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadTagNames();
  }

  @override
  void dispose() {
    for (var controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadTagNames() async {
    setState(() => _isLoading = true);

    final tagNames = await TagHelper.getAllTagNames();

    for (var tag in TagHelper.availableTags) {
      _controllers[tag] = TextEditingController(text: tagNames[tag]);
    }

    setState(() => _isLoading = false);
  }

  Future<void> _saveTagNames() async {
    setState(() => _isSaving = true);

    try {
      for (var entry in _controllers.entries) {
        final tag = entry.key;
        final controller = entry.value;
        final customName = controller.text.trim();

        if (customName.isNotEmpty && customName != TagHelper.defaultTagNames[tag]) {
          // Save custom name
          await _db.setTagCustomName(tag, customName);
        } else {
          // Delete custom name (use default)
          await _db.deleteTagCustomName(tag);
        }
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tag names saved successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save tag names: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _resetToDefaults() {
    setState(() {
      for (var entry in _controllers.entries) {
        final tag = entry.key;
        entry.value.text = TagHelper.defaultTagNames[tag]!;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tag Settings'),
        actions: [
          if (!_isLoading)
            TextButton(
              onPressed: _isSaving ? null : _saveTagNames,
              child: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text(
                      'Save',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.info_outline, size: 20),
                              const SizedBox(width: 8),
                              const Expanded(
                                child: Text(
                                  'Customize tag names',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Change the display names for color tags. Leave empty or use the default name to reset.',
                            style: TextStyle(fontSize: 13, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ...TagHelper.availableTags.map((tag) {
                    final color = TagHelper.getTagColor(tag);
                    final controller = _controllers[tag]!;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  color: color,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                tag.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: controller,
                            decoration: InputDecoration(
                              hintText: TagHelper.defaultTagNames[tag],
                              border: const OutlineInputBorder(),
                              suffixIcon: controller.text != TagHelper.defaultTagNames[tag]
                                  ? IconButton(
                                      icon: const Icon(Icons.refresh, size: 20),
                                      onPressed: () {
                                        setState(() {
                                          controller.text = TagHelper.defaultTagNames[tag]!;
                                        });
                                      },
                                      tooltip: 'Reset to default',
                                    )
                                  : null,
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _resetToDefaults,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Reset All to Defaults'),
                  ),
                ],
              ),
            ),
    );
  }
}
