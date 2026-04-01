import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'diary_home_screen.dart';

const _keyConsentAccepted = 'consent_accepted';

class ConsentScreen extends StatefulWidget {
  const ConsentScreen({super.key});

  static Future<bool> hasAccepted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyConsentAccepted) ?? false;
  }

  @override
  State<ConsentScreen> createState() => _ConsentScreenState();
}

class _ConsentScreenState extends State<ConsentScreen> {
  bool _tosChecked = false;
  bool _privacyChecked = false;

  bool get _canProceed => _tosChecked && _privacyChecked;

  Future<void> _accept() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyConsentAccepted, true);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const DiaryHomeScreen()),
    );
  }

  void _openLink(String url, String title) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _WebViewPage(url: url, title: title),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28.0, vertical: 32.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Spacer(),
              // Logo / App name
              Row(
                children: [
                  Icon(Icons.auto_stories_rounded,
                      size: 36, color: colorScheme.primary),
                  const SizedBox(width: 12),
                  Text(
                    'Logat',
                    style: textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                'Before you get started',
                style: textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Please review and agree to the following to use Logat.',
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 32),
              // ToS checkbox
              _ConsentTile(
                checked: _tosChecked,
                onChanged: (v) => setState(() => _tosChecked = v ?? false),
                child: RichText(
                  text: TextSpan(
                    style: textTheme.bodyMedium,
                    children: [
                      const TextSpan(text: 'I have read and agree to the '),
                      TextSpan(
                        text: 'Terms of Service',
                        style: TextStyle(
                          color: colorScheme.primary,
                          decoration: TextDecoration.underline,
                        ),
                        recognizer: TapGestureRecognizer()
                          ..onTap = () => _openLink(
                                'https://ground171717.blogspot.com/2026/03/terms-of-service-logat.html',
                                'Terms of Service',
                              ),
                      ),
                      const TextSpan(text: '.'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Privacy Policy checkbox
              _ConsentTile(
                checked: _privacyChecked,
                onChanged: (v) => setState(() => _privacyChecked = v ?? false),
                child: RichText(
                  text: TextSpan(
                    style: textTheme.bodyMedium,
                    children: [
                      const TextSpan(text: 'I have read and agree to the '),
                      TextSpan(
                        text: 'Privacy Policy',
                        style: TextStyle(
                          color: colorScheme.primary,
                          decoration: TextDecoration.underline,
                        ),
                        recognizer: TapGestureRecognizer()
                          ..onTap = () => _openLink(
                                'https://ground171717.blogspot.com/2026/03/privacy-policy-logat.html',
                                'Privacy Policy',
                              ),
                      ),
                      const TextSpan(text: '.'),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _canProceed ? _accept : null,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Get Started',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WebViewPage extends StatefulWidget {
  const _WebViewPage({required this.url, required this.title});

  final String url;
  final String title;

  @override
  State<_WebViewPage> createState() => _WebViewPageState();
}

class _WebViewPageState extends State<_WebViewPage> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: WebViewWidget(controller: _controller),
    );
  }
}

class _ConsentTile extends StatelessWidget {
  const _ConsentTile({
    required this.checked,
    required this.onChanged,
    required this.child,
  });

  final bool checked;
  final ValueChanged<bool?> onChanged;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Checkbox(value: checked, onChanged: onChanged),
        const SizedBox(width: 4),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 12.0),
            child: child,
          ),
        ),
      ],
    );
  }
}

