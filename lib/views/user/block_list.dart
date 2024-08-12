// 설정 타고 들어가면 볼 수 있음
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';


class BlockListScreen extends StatefulWidget {
  const BlockListScreen({Key? key}) : super(key: key);

  @override
  _BlockListScreenState createState() => _BlockListScreenState();
}

class _BlockListScreenState extends State<BlockListScreen> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).primaryColor,
        leading: IconButton(
          icon: Icon(
              Platform.isAndroid ? Icons.arrow_back : CupertinoIcons.back,
              color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text("Settings", style: TextStyle(color: Colors.white),),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(0, 10, 0, 0),
        shrinkWrap: true,
        children: const [

        ],
      ),
    );
  }

  void showMessage(String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        content: Text(message),
        actions: <TextButton>[
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('Close'),
          )
        ],
      ),
    );
  }

  void showMessageWithCancel(String message, Function f) {
    showDialog(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        content: Text(message),
        actions: <TextButton>[
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              f();
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}