import 'package:flutter/material.dart';
import '../models/ai_persona.dart';
import '../models/app_settings.dart';
import '../database/database_helper.dart';
import '../services/settings_service.dart';
import '../widgets/avatar_widget.dart';
import 'feed_screen.dart';

class SetupScreen extends StatefulWidget {
  const SetupScreen({Key? key}) : super(key: key);

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final DatabaseHelper _db = DatabaseHelper.instance;
  final TextEditingController _userProfileController = TextEditingController();
  List<AiPersona> _allPersonas = [];
  Set<int> _selectedPersonaIds = {1, 2, 3, 4, 5, 6};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPersonas();
  }

  @override
  void dispose() {
    _userProfileController.dispose();
    super.dispose();
  }

  Future<void> _loadPersonas() async {
    final personas = await _db.getAllPersonas();
    setState(() {
      _allPersonas = personas;
      _isLoading = false;
    });
  }

  Future<void> _saveAndContinue() async {
    // Use default values from AppSettings
    final settings = AppSettings(
      enabledPersonaIds: _selectedPersonaIds.toList(),
      commentProbability: 0.5,
      likeProbability: 0.7,
      isFirstTime: false,
      userProfile: _userProfileController.text.trim(),
    );

    await SettingsService.saveSettings(settings);

    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const FeedScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Welcome to Logat'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Let\'s set up your AI friends!',
                          style: TextStyle(
                              fontSize: 24, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Tell us about yourself and select AI friends to interact with your posts.',
                          style: TextStyle(color: Colors.grey),
                        ),
                        const SizedBox(height: 24),

                        // User Profile Section
                        const Text(
                          'About You',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Tell your AI friends about yourself so they can give better reactions',
                          style: TextStyle(color: Colors.grey, fontSize: 13),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _userProfileController,
                          decoration: const InputDecoration(
                            labelText: 'Your Profile',
                            hintText:
                                'E.g., I love traveling, photography, and trying new food...',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.person),
                          ),
                          maxLines: 3,
                        ),
                        const SizedBox(height: 24),

                        // AI Persona Selection with Info
                        const Text(
                          'Select AI Friends',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 12),
                        ..._allPersonas.map((persona) {
                          final isSelected =
                              _selectedPersonaIds.contains(persona.id);
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: Column(
                              children: [
                                CheckboxListTile(
                                  value: isSelected,
                                  onChanged: (value) {
                                    setState(() {
                                      if (value == true) {
                                        _selectedPersonaIds.add(persona.id!);
                                      } else {
                                        _selectedPersonaIds.remove(persona.id);
                                      }
                                    });
                                  },
                                  secondary: AvatarWidget(
                                    avatar: persona.avatar,
                                    size: 48,
                                  ),
                                  title: Row(
                                    children: [
                                      Text(persona.name),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.blue,
                                          borderRadius:
                                              BorderRadius.circular(4),
                                        ),
                                        child: const Text(
                                          'AI',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  subtitle: Text(persona.role),
                                ),
                                if (isSelected) ...[
                                  const Divider(height: 1),
                                  Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          persona.personality,
                                          style: const TextStyle(
                                              fontSize: 13, color: Colors.grey),
                                        ),
                                        const SizedBox(height: 12),
                                        Row(
                                          children: [
                                            Icon(
                                              persona.aiModel.isGemini
                                                  ? Icons.auto_awesome
                                                  : Icons.chat_bubble_outline,
                                              size: 14,
                                              color: Colors.grey,
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              persona.aiModel.displayName,
                                              style: const TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey),
                                            ),
                                            const SizedBox(width: 16),
                                            const Icon(Icons.comment,
                                                size: 14, color: Colors.grey),
                                            const SizedBox(width: 6),
                                            Text(
                                              '${(persona.commentProbability * 100).toInt()}%',
                                              style: const TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey),
                                            ),
                                            const SizedBox(width: 16),
                                            const Icon(Icons.favorite,
                                                size: 14, color: Colors.grey),
                                            const SizedBox(width: 6),
                                            Text(
                                              '${(persona.likeProbability * 100).toInt()}%',
                                              style: const TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          );
                        }).toList(),

                        const SizedBox(height: 24),

                        // Info Card
                        Card(
                          color:
                              Theme.of(context).primaryColor.withOpacity(0.1),
                          child: const Padding(
                            padding: EdgeInsets.all(16),
                            child: Row(
                              children: [
                                Icon(Icons.info_outline, color: Colors.blue),
                                SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'Each AI friend has unique settings. You can customize them later in Settings.',
                                    style: TextStyle(fontSize: 13),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Fixed button at bottom
                Container(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed:
                          _selectedPersonaIds.isEmpty ? null : _saveAndContinue,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).primaryColor,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text(
                        'Get Started',
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
