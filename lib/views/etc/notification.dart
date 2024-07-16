import 'package:flutter/material.dart';
import 'package:logat/utils/utils_login.dart';
import 'package:logat/views/auth/login.dart';

import '../../main.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({Key? key}) : super(key: key);

  @override
  _NotificationScreenState createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  @override
  Widget build(BuildContext context) {
    return Container(
      child: TextButton(
        onPressed: () async {
          if (await LoginMethod.signOut()) {
            if (!context.mounted) return;

            Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => LoginScreen()));
          }
        },
        child: const Text('Log out'),
      ),
    );
  }
}