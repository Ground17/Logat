import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../models/ai_persona.dart';
import '../models/app_settings.dart';
import '../database/database_helper.dart';
import '../services/settings_service.dart';
import 'persona_management_screen.dart';
import 'tag_settings_screen.dart';
import 'webview_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final DatabaseHelper _db = DatabaseHelper.instance;
  List<AiPersona> _allPersonas = [];
  bool _isLoading = true;
  AiImageModel _preferredImageModel = AiImageModel.gemini;

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
      _preferredImageModel = settings.preferredImageModel;
      _isLoading = false;
    });
  }

  Future<void> _saveImageModelPreference(AiImageModel model) async {
    final settings = await SettingsService.loadSettings();
    await SettingsService.saveSettings(settings.copyWith(
      preferredImageModel: model,
    ));
    setState(() {
      _preferredImageModel = model;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                            builder: (context) =>
                                const PersonaManagementScreen(),
                          ),
                        );
                        _loadSettings();
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.label),
                      title: const Text('Tag Settings'),
                      subtitle: const Text('Customize tag names'),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const TagSettingsScreen(),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    child: Column(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.image),
                          title: const Text('AI Image Generation Model'),
                          subtitle: Text(
                            _preferredImageModel == AiImageModel.openai
                                ? 'Currently using OpenAI (GPT Image 1.5)'
                                : 'Currently using Google Gemini',
                          ),
                        ),
                        const Divider(height: 1),
                        RadioListTile<AiImageModel>(
                          title:
                              const Text('Google Gemini 3 Pro Image Preview'),
                          value: AiImageModel.gemini,
                          groupValue: _preferredImageModel,
                          onChanged: (value) {
                            if (value != null) {
                              _saveImageModelPreference(value);
                            }
                          },
                        ),
                        RadioListTile<AiImageModel>(
                          title: const Text('OpenAI (GPT Image 1.5)'),
                          value: AiImageModel.openai,
                          groupValue: _preferredImageModel,
                          onChanged: (value) {
                            if (value != null) {
                              _saveImageModelPreference(value);
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.description),
                      title: const Text('Terms of Use'),
                      subtitle: const Text('View terms of use'),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const WebViewScreen(
                              url: 'https://logat-release.web.app/terms_of_use',
                              title: 'Terms of Use',
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.privacy_tip),
                      title: const Text('Privacy Policy'),
                      subtitle: const Text('View privacy policy'),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const WebViewScreen(
                              url:
                                  'https://logat-release.web.app/privacy_policy',
                              title: 'Privacy Policy',
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.info),
                      title: const Text('License Information'),
                      subtitle: const Text('View license information'),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () {
                        showLicensePage(
                          context: context,
                          applicationName: 'Logat',
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Debug Section
                  if (kDebugMode)
                    Card(
                      color: Colors.orange.withValues(alpha: 0.1),
                      child: ListTile(
                        leading:
                            const Icon(Icons.bug_report, color: Colors.orange),
                        title: const Text('Debug: View Database Contents'),
                        subtitle:
                            const Text('Print all database data to console'),
                        onTap: () async {
                          await _db.printAllDatabaseContents();
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                    'Database contents printed to console. Check your IDE logs.'),
                                duration: Duration(seconds: 3),
                              ),
                            );
                          }
                        },
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}
