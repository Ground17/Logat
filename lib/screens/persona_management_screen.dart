import 'package:flutter/material.dart';
import '../models/ai_persona.dart';
import '../database/database_helper.dart';
import '../widgets/avatar_widget.dart';
import 'edit_persona_screen.dart';

class PersonaManagementScreen extends StatefulWidget {
  final int? initialPersonaId;

  const PersonaManagementScreen({Key? key, this.initialPersonaId}) : super(key: key);

  @override
  State<PersonaManagementScreen> createState() => _PersonaManagementScreenState();
}

class _PersonaManagementScreenState extends State<PersonaManagementScreen> {
  final DatabaseHelper _db = DatabaseHelper.instance;
  List<AiPersona> _personas = [];
  bool _isLoading = true;

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
    setState(() {
      _personas = personas;
      _isLoading = false;
    });
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
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: _personas.length,
              itemBuilder: (context, index) {
                final persona = _personas[index];
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  child: ListTile(
                    leading: CircleAvatarWidget(
                      avatar: persona.avatar,
                      radius: 20,
                    ),
                    title: Text(persona.name),
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
                                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                                ),
                              ],
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.comment, size: 14, color: Colors.grey),
                                const SizedBox(width: 4),
                                Text(
                                  '${(persona.commentProbability * 100).toInt()}%',
                                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                                ),
                              ],
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.favorite, size: 14, color: Colors.grey),
                                const SizedBox(width: 4),
                                Text(
                                  '${(persona.likeProbability * 100).toInt()}%',
                                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit),
                          onPressed: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => EditPersonaScreen(persona: persona),
                              ),
                            );
                            _loadPersonas();
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _deletePersona(persona),
                        ),
                      ],
                    ),
                  ),
                );
              },
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
