import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({required Key key}) : super(key: key);

  @override
  _MyLoginStates createState() => _MyLoginStates();
}

class _MyLoginStates extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  Widget _showBody() {
    return Container(
      padding: EdgeInsets.all(16.0),
      child: new Form(
        key: _formKey,
        child: ListView(
          shrinkWrap: true,
          children: <Widget>[

          ],
        ),
      )
    );
  }

  void _validateAndSubmit() {

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
        title: Text("Log In"),
      ),
      body: _showBody(),
    );
  }
}