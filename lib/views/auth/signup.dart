import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({required Key key}) : super(key: key);

  @override
  _MySignUpStates createState() => _MySignUpStates();
}

class _MySignUpStates extends State<SignUpScreen> {
  Widget _showBody() {
    return Container(
      padding: EdgeInsets.all(16.0),
      child: ListView(
        shrinkWrap: true,
        children: <Widget>[

        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).primaryColor,
        leading: IconButton(
          icon: Icon(Platform.isAndroid ? Icons.arrow_back : CupertinoIcons.back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text("도움말"),
      ),
      body: _showBody(),
    );
  }
}