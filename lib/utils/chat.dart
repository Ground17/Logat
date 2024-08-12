// import 'dart:typed_data';
//
// import 'package:flutter/material.dart';
// import 'package:google_generative_ai/google_generative_ai.dart';
// import 'package:image_picker/image_picker.dart';
// import '../key.dart';
//
// import 'package:http/http.dart' as http;
//
//
// class LatLong {
//   LatLong({this.lat, this.long, this.address});
//
//   late double? lat;
//   late double? long;
//   late String? address;
//
//   @override
//   String toString() {
//     return "${lat != null && long != null ? "latitude: $lat, longitude: $long, " : ""}${address != null ? "address: $address" : ""}";
//   }
// }
//
// class ChatMessage {
//   ChatMessage({required this.isUser, required this.text, this.imageLinks});
//
//   bool isUser = true;
//   String text = "";
//   List<String>? imageLinks = [];
// }
//
// class ChatScreen extends StatefulWidget {
//   ChatScreen({Key? key, required this.initImageLinks}) : super(key: key);
//
//   List<String> initImageLinks = [];
//
//   @override
//   _ChatScreenState createState() => _ChatScreenState();
// }
//
// class _ChatScreenState extends State<ChatScreen> {
//   final TextEditingController _textController = TextEditingController();
//   final List<ChatMessage> _messages = [];
//   final List<String> _imageLinks = [];
//
//   @override
//   void initState() {
//     _imageLinks.addAll(widget.initImageLinks);
//     super.initState();
//   }
//
//   Future<Uint8List> fetchImageAsUint8List(String url) async {
//     final response = await http.get(Uri.parse(url));
//
//     if (response.statusCode == 200) {
//       return response.bodyBytes;
//     } else {
//       throw Exception('Failed to load image');
//     }
//   }
//
//   void _sendMessage(String prompt) async {
//     if (prompt.isEmpty) {
//       return;
//     }
//
//     // Access your API key as an environment variable (see "Set up your API key" above)
//     const apiKey = GEMINI_KEYS;
//
//     // The Gemini 1.5 models are versatile and work with both text-only and multimodal prompts
//     final model = GenerativeModel(model: 'gemini-1.5-flash', apiKey: apiKey,);
//     // final imageParts = [];
//     // final chat = model.startChat(history: [
//     //   Content.multi([prompt, DataPart('image/jpeg', image)]),
//     //   Content.model([TextPart('Great to meet you. What would you like to know?')])
//     // ]);
//
//     List<Content> history = [];
//
//     if (_messages.isNotEmpty) {
//       for (int i = 0; i < _messages.length; i ++) {
//         final parts = [];
//         parts.add(TextPart(_messages[i].text));
//         if (_messages[i].imageLinks?.isNotEmpty ?? false) {
//           for (final link in _messages[i].imageLinks!) {
//             if (link.startsWith("http")) {
//               try {
//                 parts.add(DataPart('image/jpeg', await fetchImageAsUint8List(link)));
//               } catch (e) {
//                 print(e);
//               }
//               continue;
//             }
//             parts.add(DataPart('image/jpeg', XFile(link).readAsBytes() as Uint8List));
//           }
//         }
//
//         String locationMessage = "*** Location information ***\n";
//
//         if (_messages[i].isUser) {
//           history.add(Content.multi(parts as Iterable<Part>));
//         } else {
//           history.add(Content.model(parts as Iterable<Part>));
//         }
//       }
//     }
//     final chat = model.startChat(history: history);
//
//     var content = Content.text(prompt);
//     var response = chat.sendMessageStream(content);
//     _textController.clear();
//
//     _messages.add(ChatMessage(isUser: false, text: ""));
//
//     await for (final chunk in response) {
//       setState(() {
//         _messages.last.text += chunk.text ?? "";
//       });
//     }
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: const Text('Gemini Chat')),
//       body: Column(
//         children: [
//           Expanded(
//             child: ListView.builder(
//               itemCount: _messages.length,
//               itemBuilder: (context, index) {
//                 return Align(
//                   alignment: _messages[index].isUser ? Alignment.centerRight : Alignment.centerLeft,
//                   child: Container(
//                     padding: const EdgeInsets.all(16.0),
//                     decoration: BoxDecoration(
//                       color: _messages[index].isUser ? Colors.blue : Colors.grey[300],
//                       borderRadius: BorderRadius.circular(10.0),
//                     ),
//                     child: Text("text"),
//                   ),
//                 );
//                 if (_messages[index].isUser) {
//                   /// 오른쪽에 말풍선 구현
//                   return const ListTile(
//
//                   );
//                 }
//                 /// 왼쪽에 말풍선 구현
//                 return const ListTile(
//
//                 );
//               }
//             ),
//           ),
//           Row(
//             children: [
//               Expanded(
//                 child: TextField(
//                   controller: _textController,
//                 ),
//               ),
//               IconButton(
//                 icon: const Icon(Icons.send),
//                 onPressed: () {
//                   _sendMessage(_textController.text);
//                 },
//               ),
//             ],
//           ),
//         ],
//       ),
//     );
//   }
// }
