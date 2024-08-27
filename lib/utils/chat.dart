import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:image_picker/image_picker.dart';
import '../key.dart';

import 'package:http/http.dart' as http;

class ChatMessage {
  ChatMessage({required this.isUser, required this.text});

  bool isUser = true;
  String text = "";
  // List<String>? imageLinks = [];
}

class ChatScreen extends StatefulWidget {
  ChatScreen({Key? key, required this.initialString,}) : super(key: key);

  final String initialString;

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final List<ChatMessage> _messages = [];

  @override
  void initState() {
    super.initState();
    _textController.text += widget.initialString;
  }

  Future<Uint8List> fetchImageAsUint8List(String url) async {
    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      return response.bodyBytes;
    } else {
      throw Exception('Failed to load image');
    }
  }

  void _sendMessage(String prompt) async {
    if (prompt.isEmpty) {
      return;
    }

    setState(() {
      _messages.add(ChatMessage(isUser: true, text: prompt));
    });

    // Access your API key as an environment variable (see "Set up your API key" above)
    const apiKey = GEMINI_KEYS;

    // The Gemini 1.5 models are versatile and work with both text-only and multimodal prompts
    final model = GenerativeModel(model: 'gemini-1.5-flash', apiKey: apiKey,);
    // final imageParts = [];
    // final chat = model.startChat(history: [
    //   Content.multi([prompt, DataPart('image/jpeg', image)]),
    //   Content.model([TextPart('Great to meet you. What would you like to know?')])
    // ]);

    List<Content> history = [];

    if (_messages.isNotEmpty) {
      for (int i = 0; i < _messages.length; i ++) {
        List<Part> parts = [];
        parts.add(TextPart(_messages[i].text));
        /// 추후 이미지 추가 가능성 있음

        if (_messages[i].isUser) {
          history.add(Content.multi(parts as Iterable<Part>));
        } else {
          history.add(Content.model(parts as Iterable<Part>));
        }
      }
    }

    final chat = model.startChat(history: history);

    var content = Content.text(prompt);
    var response = chat.sendMessageStream(content);
    _textController.clear();

    _messages.add(ChatMessage(isUser: false, text: ""));

    await for (final chunk in response) {
      setState(() {
        _messages.last.text += chunk.text ?? "";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AI Chat')),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: _messages.length,
              padding: const EdgeInsets.all(16.0),
              itemBuilder: (context, index) {
                return Align(
                  alignment: _messages[index].isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.all(16.0),
                    decoration: BoxDecoration(
                      color: _messages[index].isUser ? Colors.blue : Colors.black54,
                      borderRadius: BorderRadius.circular(20.0),
                    ),
                    child: MarkdownBody(data: _messages[index].text, selectable: true,),
                  ),
                );
              }
            ),
          ),
           Container(
            margin: const EdgeInsets.all(10,),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                    ),
                    controller: _textController,
                    maxLines: 3,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: () {
                    _sendMessage(_textController.text);
                    _textController.text = '';
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
