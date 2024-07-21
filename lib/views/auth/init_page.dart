import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../etc/webview.dart';

class InitPage extends StatefulWidget {
  const InitPage({Key? key}) : super(key: key);

  @override
  State<InitPage> createState() => _InitPageState();
}

class _InitPageState extends State<InitPage> {
  bool? isPrivacyPolicy = false;
  bool? isTermsOfUse = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        minimum: EdgeInsets.all(20),
        child: Column(
          children: [
            Row(),
            Text("Logat"),
            Text("Logat is a service that uses device location information to record and share your daily life as simply as possible.\n"
                "Location information allows you to write Logat more colorfully, but it is not required. You can freely adjust how to write location information in settings within the application.\n\n"
                "To start, please read and agree with the following."),
            CheckboxListTile(
                value: isPrivacyPolicy,
                title: RichText(
                  text: TextSpan(
                    text: 'Privacy Policy',
                    style: const TextStyle(color: Colors.blue),
                    recognizer: TapGestureRecognizer()
                      ..onTap = () {
                        print('Privacy Policy');
                        Navigator.of(context).push(MaterialPageRoute(builder: (context) => const WebViewApp(url: "https://logat-release.web.app/privacy_policy")));
                      })),
                onChanged: (value) {
                  setState(() {
                    isPrivacyPolicy = value;
                  });
                }),
            CheckboxListTile(
              value: isTermsOfUse,
              title: RichText(
                text: TextSpan(
                  text: 'Terms of Use',
                  style: const TextStyle(color: Colors.blue),
                  recognizer: TapGestureRecognizer()
                    ..onTap = () {
                      print('Terms of Use');
                      Navigator.of(context).push(MaterialPageRoute(builder: (context) => const WebViewApp(url: "https://logat-release.web.app/terms_of_use")));
                  })),
              onChanged: (value) {
                setState(() {
                  isTermsOfUse = value;
                });
              }),
            ElevatedButton(
              style: ButtonStyle(
                  backgroundColor: (isPrivacyPolicy ?? false) && (isTermsOfUse ?? false) ? WidgetStateProperty.all<Color>(Colors.blue) : WidgetStateProperty.all<Color>(Colors.grey),
              ),
              onPressed: () {
                if ((isPrivacyPolicy ?? false) && (isTermsOfUse ?? false)) {
                  context.go('/login');
                }
              },
              child: new Text('I got it!',
                  style: new TextStyle(fontSize: 20.0, color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}