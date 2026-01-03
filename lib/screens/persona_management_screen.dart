import 'package:flutter/material.dart';
import '../models/ai_persona.dart';
import '../models/app_settings.dart';
import '../database/database_helper.dart';
import '../services/settings_service.dart';
import '../widgets/avatar_widget.dart';
import 'edit_persona_screen.dart';

class PersonaManagementScreen extends StatefulWidget {
  final int? initialPersonaId;

  const PersonaManagementScreen({Key? key, this.initialPersonaId})
      : super(key: key);

  @override
  State<PersonaManagementScreen> createState() =>
      _PersonaManagementScreenState();
}

class _PersonaManagementScreenState extends State<PersonaManagementScreen> {
  final DatabaseHelper _db = DatabaseHelper.instance;
  List<AiPersona> _personas = [];
  Set<int> _selectedPersonaIds = {};
  bool _isLoading = true;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _loadPersonas();

    // If initialPersonaId is provided, open edit screen after loading
    if (widget.initialPersonaId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _openEditScreen(widget.initialPersonaId!);
      });
    }
  }

  Future<void> _loadPersonas() async {
    setState(() => _isLoading = true);
    final personas = await _db.getAllPersonas();
    final settings = await SettingsService.loadSettings();
    setState(() {
      _personas = personas;
      _selectedPersonaIds = settings.enabledPersonaIds.toSet();
      _isLoading = false;
      _hasChanges = false;
    });
  }

  Future<void> _saveSettings() async {
    final settings = await SettingsService.loadSettings();
    final updatedSettings = AppSettings(
      enabledPersonaIds: _selectedPersonaIds.toList(),
      commentProbability: settings.commentProbability,
      likeProbability: settings.likeProbability,
      isFirstTime: false,
      userProfile: settings.userProfile,
    );

    await SettingsService.saveSettings(updatedSettings);

    setState(() => _hasChanges = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Persona settings saved')),
      );
    }
  }

  Future<void> _openEditScreen(int personaId) async {
    if (_personas.isEmpty) return;

    final persona = _personas.firstWhere(
      (p) => p.id == personaId,
      orElse: () => _personas.first,
    );

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditPersonaScreen(persona: persona),
      ),
    );
    _loadPersonas();
  }

  Future<void> _deletePersona(AiPersona persona) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Persona'),
        content: Text('Are you sure you want to delete ${persona.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _db.deletePersona(persona.id!);
      _loadPersonas();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${persona.name} deleted')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Personas'),
        actions: [
          if (_hasChanges)
            TextButton(
              onPressed: _saveSettings,
              child: const Text(
                'Save',
                style: TextStyle(color: Colors.white),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Description
                Container(
                  padding: const EdgeInsets.all(16),
                  color: Theme.of(context)
                      .colorScheme
                      .surfaceContainerHighest
                      .withValues(alpha: 0.3),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline,
                          size: 20, color: Colors.grey[600]),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Enable or disable AI personas. Only enabled personas will interact with your posts.',
                          style:
                              TextStyle(fontSize: 13, color: Colors.grey[600]),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: _personas.length,
                    itemBuilder: (context, index) {
                      final persona = _personas[index];
                      final isEnabled =
                          _selectedPersonaIds.contains(persona.id);
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        child: Column(
                          children: [
                            CheckboxListTile(
                              value: isEnabled,
                              onChanged: (value) {
                                setState(() {
                                  if (value == true) {
                                    _selectedPersonaIds.add(persona.id!);
                                  } else {
                                    _selectedPersonaIds.remove(persona.id);
                                  }
                                  _hasChanges = true;
                                });
                              },
                              secondary: CircleAvatarWidget(
                                avatar: persona.avatar,
                                radius: 20,
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
                                      borderRadius: BorderRadius.circular(4),
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
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(persona.role),
                                  const SizedBox(height: 4),
                                  Wrap(
                                    spacing: 12,
                                    runSpacing: 4,
                                    children: [
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            persona.aiModel.isGemini
                                                ? Icons.auto_awesome
                                                : Icons.chat_bubble_outline,
                                            size: 14,
                                            color: Colors.grey,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            persona.aiModel.displayName,
                                            style: const TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey),
                                          ),
                                        ],
                                      ),
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.comment,
                                              size: 14, color: Colors.grey),
                                          const SizedBox(width: 4),
                                          Text(
                                            '${(persona.commentProbability * 100).toInt()}%',
                                            style: const TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey),
                                          ),
                                        ],
                                      ),
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.favorite,
                                              size: 14, color: Colors.grey),
                                          const SizedBox(width: 4),
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
                                ],
                              ),
                            ),
                            // Edit and Delete buttons
                            Padding(
                              padding: const EdgeInsets.only(
                                  left: 72, right: 16, bottom: 8),
                              child: Row(
                                children: [
                                  TextButton.icon(
                                    icon: const Icon(Icons.edit, size: 18),
                                    label: const Text('Edit'),
                                    onPressed: () async {
                                      await Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              EditPersonaScreen(
                                                  persona: persona),
                                        ),
                                      );
                                      _loadPersonas();
                                    },
                                  ),
                                  const SizedBox(width: 8),
                                  TextButton.icon(
                                    icon: const Icon(Icons.delete, size: 18),
                                    label: const Text('Delete'),
                                    style: TextButton.styleFrom(
                                        foregroundColor: Colors.red),
                                    onPressed: () => _deletePersona(persona),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const EditPersonaScreen(),
            ),
          );
          _loadPersonas();
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
