import 'package:flutter/material.dart';


class AddEditClusterScreen extends StatefulWidget {
  const AddEditClusterScreen({Key? key, required this.clusterId, required this.postIds}) : super(key: key);

  final String clusterId;
  final List<String> postIds;
  @override
  _ShowClusterState createState() => _ShowClusterState();
  // late String docId;
}

class _ShowClusterState extends State<AddEditClusterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

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
        title: const Text('Log in'),
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
                    return 'Please enter your email.';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _descriptionController,
                maxLength: 10,
                decoration: const InputDecoration(labelText: 'Description'),
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