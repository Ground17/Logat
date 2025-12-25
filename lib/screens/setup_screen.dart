import 'package:flutter/material.dart';
import '../models/ai_persona.dart';
import '../models/app_settings.dart';
import '../database/database_helper.dart';
import '../services/settings_service.dart';
import 'feed_screen.dart';

class SetupScreen extends StatefulWidget {
  const SetupScreen({Key? key}) : super(key: key);

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final DatabaseHelper _db = DatabaseHelper.instance;
  List<AiPersona> _allPersonas = [];
  Set<int> _selectedPersonaIds = {1, 2, 3, 4, 5, 6};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPersonas();
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
      aiProvider: AiProvider.gemini,
      commentProbability: 0.5,
      likeProbability: 0.7,
      isFirstTime: false,
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
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Let\'s set up your AI friends!',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Select which AI personas will interact with your posts. You can configure each persona\'s settings later.',
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 24),

                  // AI Persona Selection with Info
                  const Text(
                    'Select AI Friends',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  ..._allPersonas.map((persona) {
                    final isSelected = _selectedPersonaIds.contains(persona.id);
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
                            secondary: Text(
                              persona.avatar,
                              style: const TextStyle(fontSize: 32),
                            ),
                            title: Text(persona.name),
                            subtitle: Text(persona.role),
                          ),
                          if (isSelected) ...[
                            const Divider(height: 1),
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    persona.personality,
                                    style: const TextStyle(fontSize: 13, color: Colors.grey),
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      const Icon(Icons.auto_awesome, size: 14, color: Colors.grey),
                                      const SizedBox(width: 6),
                                      Text(
                                        persona.aiProvider == AiProvider.gemini ? 'Gemini' : 'OpenAI',
                                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                                      ),
                                      const SizedBox(width: 16),
                                      const Icon(Icons.comment, size: 14, color: Colors.grey),
                                      const SizedBox(width: 6),
                                      Text(
                                        '${(persona.commentProbability * 100).toInt()}%',
                                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                                      ),
                                      const SizedBox(width: 16),
                                      const Icon(Icons.favorite, size: 14, color: Colors.grey),
                                      const SizedBox(width: 6),
                                      Text(
                                        '${(persona.likeProbability * 100).toInt()}%',
                                        style: const TextStyle(fontSize: 12, color: Colors.grey),
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
                    color: Theme.of(context).primaryColor.withOpacity(0.1),
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

                  const SizedBox(height: 32),

                  // Continue Button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _selectedPersonaIds.isEmpty
                          ? null
                          : _saveAndContinue,
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
                  const SizedBox(height: 16),
                ],
              ),
            ),
    );
  }
}
