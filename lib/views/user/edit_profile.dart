import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:logat/utils/utils_login.dart';
import 'package:logat/views/auth/login.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../../main.dart';

class EditProfileScreen extends StatefulWidget {
  @override
  _EditProfileScreenState createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  @override
  void initState() {
    super.initState();
  }

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