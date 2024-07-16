import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

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
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text("Logat"),
        Text("Logat is a service that uses device location information to record and share your daily life as simply as possible.\n"
            "Location information allows you to write Logat more colorfully, but it is not required. You can freely adjust how to write location information in settings within the application.\n\n"
            "To start, please read and agree with the following."),
        CheckboxListTile(
            value: isPrivacyPolicy,
            title: RichText(
                text: TextSpan(
                    text: 'Privacy Policy',
                    recognizer: TapGestureRecognizer()
                      ..onTap = () {
                        print('Privacy Policy');
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
              recognizer: TapGestureRecognizer()
                ..onTap = () {
                print('Terms of Use');
              })),
          onChanged: (value) {
            setState(() {
              isTermsOfUse = value;
            });
          }),
        ElevatedButton(
          style: ButtonStyle(
              backgroundColor: MaterialStateProperty.all<Color>(Colors.blue[800]!),
          ),
          onPressed: () {

          },
          child: new Text('I got it!',
              style: new TextStyle(fontSize: 20.0, color: Colors.white)),
        ),
      ],
    );
  }
}