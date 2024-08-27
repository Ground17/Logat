import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:logat/main.dart';

import '../../home.dart';
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
        minimum: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            children: [
              const SizedBox(height: 10,),
              const Row(
                children: [
                  Image(
                    image: AssetImage('assets/logat_logo.png',),
                    height: 48.0,
                  ),
                  SizedBox(width: 10,),
                  Text("Logat", style: TextStyle(fontSize: 24),),
                ],
              ),
              SizedBox(height: 10,),
              const Text("Logat is a service that uses device location information to record and share your daily life as simply as possible.\n"
                  "Location information allows you to write Logat more colorfully. You can freely adjust how to write location information in settings within the application.\n"
                  "In addition, the app is using the Google Gemini to get a recommendation of location and Google Maps API to search for addresses and routes that users want.\n\n"
                  "To start, please read and agree with the following."),
              CheckboxListTile(
                  value: isPrivacyPolicy,
                  title: GestureDetector(
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const WebViewApp(url: "https://logat-release.web.app/privacy_policy")));
                    },
                    child: const Text('Privacy Policy', style: TextStyle(color: Colors.blue),),
                  ),
                  onChanged: (value) {
                    setState(() {
                      isPrivacyPolicy = value;
                    });
                  }),
              CheckboxListTile(
                  value: isTermsOfUse,
                  title: GestureDetector(
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const WebViewApp(url: "https://logat-release.web.app/terms_of_use")));
                    },
                    child: const Text('Terms of Use', style: TextStyle(color: Colors.blue),),
                  ),
                  onChanged: (value) {
                    setState(() {
                      isTermsOfUse = value;
                    });
                  }
              ),
              Container(
                  padding: const EdgeInsets.all(8),
                  child: Row(
                      children: [
                        Expanded(
                            child: ElevatedButton(
                              style: ButtonStyle(
                                backgroundColor: (isPrivacyPolicy ?? false) && (isTermsOfUse ?? false) ? WidgetStateProperty.all<Color>(Theme.of(context).primaryColor) : WidgetStateProperty.all<Color>(Colors.grey),
                              ),
                              onPressed: () async {
                                if ((isPrivacyPolicy ?? false) && (isTermsOfUse ?? false)) {
                                  Box box = await Hive.openBox("setting");
                                  await box.put('initial', true);

                                  Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (context) => const MyHomePage()),);
                                }
                              },
                              child: const Text('I got it!',
                                  style: TextStyle(fontSize: 20.0, color: Colors.white)),
                            )
                        )
                      ]
                  )
              )
            ],
          ), // 반동 효과
        ),
      ),
    );
  }
}