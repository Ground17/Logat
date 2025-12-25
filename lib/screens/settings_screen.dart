import 'package:flutter/material.dart';
import '../models/ai_persona.dart';
import '../models/app_settings.dart';
import '../database/database_helper.dart';
import '../services/settings_service.dart';
import 'persona_management_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final DatabaseHelper _db = DatabaseHelper.instance;
  List<AiPersona> _allPersonas = [];
  Set<int> _selectedPersonaIds = {};
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);

    final personas = await _db.getAllPersonas();
    final settings = await SettingsService.loadSettings();

    setState(() {
      _allPersonas = personas;
      _selectedPersonaIds = settings.enabledPersonaIds.toSet();
      _isLoading = false;
    });
  }

  Future<void> _saveSettings() async {
    setState(() => _isSaving = true);

    final settings = await SettingsService.loadSettings();
    final updatedSettings = AppSettings(
      enabledPersonaIds: _selectedPersonaIds.toList(),
      aiProvider: settings.aiProvider,
      commentProbability: settings.commentProbability,
      likeProbability: settings.likeProbability,
      isFirstTime: false,
    );

    await SettingsService.saveSettings(updatedSettings);

    setState(() => _isSaving = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Settings saved successfully')),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        actions: [
          if (!_isLoading)
            TextButton(
              onPressed: _isSaving ? null : _saveSettings,
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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Persona Management
                  const Text(
                    'AI Personas',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Manage your AI friends and their settings',
                    style: TextStyle(color: Colors.grey, fontSize: 14),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.people),
                      title: const Text('Manage Personas'),
                      subtitle: Text('${_allPersonas.length} personas'),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const PersonaManagementScreen(),
                          ),
                        );
                        _loadSettings();
                      },
                    ),
                  ),

                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 24),

                  // AI Persona Configuration
                  const Text(
                    'AI Friends Configuration',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Configure each AI persona individually',
                    style: TextStyle(color: Colors.grey, fontSize: 14),
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
                                  // AI Provider
                                  Row(
                                    children: [
                                      const Icon(Icons.auto_awesome, size: 16, color: Colors.grey),
                                      const SizedBox(width: 8),
                                      Text(
                                        'AI Provider: ${persona.aiProvider == AiProvider.gemini ? 'Gemini' : 'OpenAI'}',
                                        style: const TextStyle(fontSize: 13, color: Colors.grey),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),

                                  // Comment Probability
                                  Row(
                                    children: [
                                      const Icon(Icons.comment, size: 16, color: Colors.grey),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Comment: ${(persona.commentProbability * 100).toInt()}%',
                                          style: const TextStyle(fontSize: 13, color: Colors.grey),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),

                                  // Like Probability
                                  Row(
                                    children: [
                                      const Icon(Icons.favorite, size: 16, color: Colors.grey),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Like: ${(persona.likeProbability * 100).toInt()}%',
                                          style: const TextStyle(fontSize: 13, color: Colors.grey),
                                        ),
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

                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }
}
