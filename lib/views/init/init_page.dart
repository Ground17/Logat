import 'package:flutter/material.dart';

class InitPage extends StatefulWidget {
  const InitPage({Key? key}) : super(key: key);

  @override
  State<InitPage> createState() => _InitPageState();
}

class _InitPageState extends State<InitPage> {
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
        ElevatedButton(
          style: ButtonStyle(
              backgroundColor: MaterialStateProperty.all<Color>(Colors.blue[800]!),
          ),
          onPressed: null,
          child: new Text('I got it!',
              style: new TextStyle(fontSize: 20.0, color: Colors.white)),
        ),
      ],
    );
  }
}