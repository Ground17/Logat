import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../../main.dart';
import '../../utils/utils_login.dart';

class AddEditPostScreen extends StatefulWidget {
  const AddEditPostScreen({Key? key, required this.photoPaths, this.isAdd = true,}) : super(key: key);

  final List<String> photoPaths;
  final bool isAdd;
  @override
  _AddEditPostState createState() => _AddEditPostState();
  // late String docId;
}

enum AddEditMode {
  Add, Edit
}

class _AddEditPostState extends State<AddEditPostScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  var screenMode = AddEditMode.Add;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Log in'),
      ),
      body: Form(
        key: _formKey,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Title'),
                validator: (value) {
                  if (value == '') {
                    return 'Please enter title.';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _descriptionController,
                maxLength: 10,
                decoration: const InputDecoration(labelText: 'Description'),
              ),
              SizedBox(height: 16.0),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        if (_formKey.currentState == null || !_formKey.currentState!.validate()) {
                          return;
                        }

                        switch (screenMode) {
                          case AddEditMode.Add:

                            break;
                          case AddEditMode.Edit:

                            break;
                        }
                      },
                      child: Text('Add/Edit'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
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
            child: const Text('OK'),
          ),
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