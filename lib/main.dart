import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
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

/// The route configuration.
final GoRouter _router = GoRouter(
  routes: <RouteBase>[
    GoRoute(
      path: '/',
      builder: (BuildContext context, GoRouterState state) {
        // return FirebaseAuth.instance.currentUser != null ? const MyHomePage(title: 'Logat',) : const InitPage();
        Box box = Hive.box("setting");

        // if (state.uri.queryParameters['lat'] != null && state.uri.queryParameters['long'] != null) {
        //   return box.get('initial', defaultValue: false) ? MyHomePage(lat: double.parse(state.uri.queryParameters['lat']!), long: double.parse(state.uri.queryParameters['long']!)) : const InitPage(); // received location -> state.uri.queryParameters['lat'], state.uri.queryParameters['long']
        // }

        return box.get('initial', defaultValue: false) ? MyHomePage() : const InitPage();
      },
      routes: <RouteBase>[
        // GoRoute(
        //   path: 'login',
        //   builder: (BuildContext context, GoRouterState state) {
        //     return const LoginScreen();
        //   },
        // ),
        // GoRoute(
        //   path: 'home',
        //   redirect: (BuildContext context, GoRouterState state) {
        //     return null;
        //   },
        // ),
        // GoRoute(
        //   path: 'user/:userId',
        //   builder: (BuildContext context, GoRouterState state) {
        //     return ProfileScreen(userId: state.pathParameters['userId'] ?? FirebaseAuth.instance.currentUser?.uid ?? "");
        //   },
        //   routes: <RouteBase>[
        //     GoRoute(
        //       path: 'edit',
        //       builder: (BuildContext context, GoRouterState state) {
        //         return const EditProfileScreen();
        //       },
        //     ),
        //   ]
        // ),
        // GoRoute(
        //   path: 'cluster/:mode',
        //   builder: (BuildContext context, GoRouterState state) {
        //     switch (state.pathParameters['mode']) { // state.uri.queryParameters['data'] = [{postId: "asdf"}, {postId: "asdf"}, ...]
        //       case 'add':
        //         return AddEditClusterScreen(clusterId: '', postIds: jsonDecode(state.uri.queryParameters['data'] ?? '[]'),);
        //
        //       default:
        //         break;
        //     }
        //     return ShowClusterScreen(clusterId: state.pathParameters['mode'] ?? "");
        //   },
        //   routes: <RouteBase>[
        //     GoRoute(
        //       path: ':edit',
        //       builder: (BuildContext context, GoRouterState state) { // state.uri.queryParameters['data'] = [{postId: "asdf"}, {postId: "asdf"}, ...]
        //         return AddEditClusterScreen(clusterId: state.pathParameters['mode'] ?? '', postIds: jsonDecode(state.uri.queryParameters['data'] ?? '[]'),);
        //       },
        //     ),
        //   ],
        // ),
        // GoRoute(
        //   path: 'search',
        //   builder: (BuildContext context, GoRouterState state) {
        //     return const SearchScreen();
        //   },
        // ),
        // GoRoute(
        //   path: 'notification',
        //   builder: (BuildContext context, GoRouterState state) {
        //     return const NotificationScreen();
        //   },
        // ),
        // GoRoute(
        //   path: 'following',
        //   builder: (BuildContext context, GoRouterState state) {
        //     return const FollowingListScreen();
        //   },
        // ),
        // GoRoute(
        //   path: 'setting',
        //   builder: (BuildContext context, GoRouterState state) {
        //     return const SettingScreen();
        //   },
        //   // routes: <RouteBase>[
        //   //   GoRoute(
        //   //     path: 'block',
        //   //     builder: (BuildContext context, GoRouterState state) {
        //   //       return const BlockListScreen();
        //   //     },
        //   //   ),
        //   // ]
        // ),
      ],
    ),
    GoRoute(
      path: '/initial',
      builder: (BuildContext context, GoRouterState state) {
        // return FirebaseAuth.instance.currentUser != null ? const MyHomePage(title: 'Logat',) : const InitPage();
        Box box = Hive.box("setting");
        return box.get('initial', defaultValue: false) ? MyHomePage() : const InitPage();
      },
    )
  ],
);

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

  await Hive.openBox("setting");

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      routerConfig: _router,
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
      debugShowCheckedModeBanner: false, // just use for screenshot to submit
    );
  }
}