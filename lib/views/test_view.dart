import 'dart:io';
import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:image_picker/image_picker.dart';
import 'package:native_exif/native_exif.dart';

import '../key.dart';

class TestPage extends StatefulWidget {
  const TestPage({Key? key, required this.title}) : super(key: key);

  final String title;

  @override
  State<TestPage> createState() => _MyTestState();
}

class _MyTestState extends State<TestPage> {
  Widget image = Container();
  @override
  void initState() {
    super.initState();
    testCode();
  }

  void testCode() async {
    print("asdf");
    final storageRef = FirebaseStorage.instance.ref();
    final isImageRef_URL = storageRef.child("test/thumb/4324234_1024x1024.jpeg");
    final isImageRef = storageRef.child("test/thumb/4324234_1024x1024.jpeg");

    try {
      // const oneMegabyte = 1024 * 1024;
      var time;

      print(await FirebaseAuth.instance.currentUser?.getIdToken());

      // image getDownloadURL time
      time = DateTime.now();
      setState(() {
        image = Image.network('https://storage.googleapis.com/logat-release.appspot.com/test/4324234.jpg',);
      });
      print("getNormalURL:");
      print((DateTime.now().difference(time)));

      // // image getDownloadURL time
      // time = DateTime.now();
      // String url = await isImageRef_URL.getDownloadURL();
      // setState(() {
      //   image = Image.network(url);
      // });
      // print("getDownloadURL:");
      // print((DateTime.now().difference(time)));
      //
      // print(url);

      // // image getData time
      // time = DateTime.now();
      // final Uint8List? data = await isImageRef.getData();
      // setState(() {
      //   image = Image.memory(data!);
      // });
      // print("getData:");
      // print((DateTime.now().difference(time)));
    } on FirebaseException catch (e) {
      print(FirebaseAuth.instance.currentUser);
      print(e);
      // Handle any errors.
    }
  }

  double lat = 0;
  double long = 0;

  Future<Uint8List> _getImage() async {
    final ImagePicker picker = ImagePicker();
    final List<XFile> images = await picker.pickMultiImage();
    for (int i = 0; i < images.length; i++) {
      final exif = await Exif.fromPath(images[i].path);
      final latlong = await exif.getLatLong();
      lat = latlong?.latitude ?? 0;
      long = latlong?.longitude ?? 0;
      print("${latlong?.latitude}, ${latlong?.longitude}");
    }

    return images[0].readAsBytes();
  }

  void _testGemini() async {
    // Access your API key as an environment variable (see "Set up your API key" above)
    const apiKey = GEMINI_KEYS;

    // The Gemini 1.5 models are versatile and work with both text-only and multimodal prompts
    final model = GenerativeModel(model: 'gemini-1.5-flash', apiKey: apiKey,);
    final image = await _getImage();
    final prompt = TextPart("이 사진을 설명해줄래? 참고로 이 사진의 위도는 ${lat}이고, 경도는 ${long}이야.");
    // final imageParts = [];
    final response = await model.generateContent([
      Content.multi([prompt, DataPart('image/jpeg', image)])
    ]);
    print(response.text);
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        IconButton(
          icon: const Icon(
            Icons.notifications,
            color: Colors.blue,
          ),
          tooltip: "Notification",
          onPressed: () async {
            _testGemini();
          },
        ),
        image,
      ],
    );
  }
}