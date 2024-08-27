import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/adapters.dart';
import 'package:logat/utils/structure.dart';
import 'package:logat/views/auth/init_page.dart';

import 'home.dart';

// import 'package:google_mobile_ads/google_mobile_ads.dart';

// Future<FirebaseApp> _initFirebase() {
//   return Firebase.initializeApp(
//     options: DefaultFirebaseOptions.currentPlatform,
//   );
// }
//
// Future<InitializationStatus> _initGoogleMobileAds() {
//   return MobileAds.instance.initialize();
// }

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  //
  // try {
  //   await _initFirebase();
  //   await _initGoogleMobileAds();
  // } on FirebaseAuthException catch (e) {
  //   switch (e.code) {
  //     case "operation-not-allowed":
  //       print("Anonymous auth hasn't been enabled for this project.");
  //       break;
  //     default:
  //       print("Unknown error.");
  //   }
  // }
  await Hive.initFlutter();

  Hive.registerAdapter(LocDataAdapter());
  Hive.registerAdapter(LocAdapter());

  Box box = await Hive.openBox("setting");

  runApp(MyApp(isNotInit: box.get('initial', defaultValue: false)));
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key, required this.isNotInit}) : super(key: key);

  final bool isNotInit;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      key: key,
      title: 'Logat',
      theme: ThemeData(
        brightness: Brightness.light,
        useMaterial3: true,
        colorSchemeSeed: Colors.blue[800],
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
        colorSchemeSeed: Colors.blue[800],
      ),
      themeMode: ThemeMode.system,
      home: isNotInit ? const MyHomePage() : const InitPage(),
      debugShowCheckedModeBanner: false,
    );
  }
}