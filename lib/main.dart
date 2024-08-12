import 'dart:async';
import 'dart:convert';

// import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/adapters.dart';
import 'package:location/location.dart';
import 'package:image_picker/image_picker.dart';
import 'package:logat/utils/gemini_api.dart';
import 'package:logat/utils/maps_api.dart';
import 'package:logat/utils/structure.dart';

// import 'package:firebase_core/firebase_core.dart';
import 'package:logat/views/auth/login.dart';
import 'package:logat/views/auth/init_page.dart';
import 'package:logat/views/etc/chaser_setting.dart';
import 'package:logat/views/etc/notification.dart';
import 'package:logat/views/etc/search.dart';
import 'package:logat/views/post/add_edit_cluster.dart';
import 'package:logat/views/post/show_cluster.dart';
import 'package:logat/views/post/show_post.dart';
import 'package:logat/views/user/block_list.dart';
import 'package:logat/views/user/edit_profile.dart';
import 'package:logat/views/user/following_list.dart';
import 'package:logat/views/user/profile.dart';
import 'package:logat/views/post/add_edit_post.dart';
import 'package:logat/views/test_view.dart';
import 'package:logat/views/etc/setting.dart';
import 'package:native_exif/native_exif.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:logat/ad_helper.dart';

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
        return box.get('initial') != null ? const MyHomePage(title: 'Logat',) : const InitPage();
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
        return box.get('initial') != null ? const MyHomePage(title: 'Logat',) : const InitPage();
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
  await Hive.openBox<LocData>("log");
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
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key, required this.title}) : super(key: key);

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  // _kAdIndex indicates the index where a banner ad will be displayed, and it's used to calculate the item index from the _getDestinationItemIndex() method.
  static const _kAdIndex = 0;
  // NativeAd? _ad;

  Location location = Location();
  late bool _serviceEnabled;
  late PermissionStatus _permissionGranted;

  late double _latitude = 37.42796133580664;
  late double _longitude = -122.085749655962;

  late double myLatitude = 37.42796133580664;
  late double myLongitude = -122.085749655962;

  List<Map<String, dynamic>> enemies = [];

  Timer? _calTimer;
  Timer? _apiTimer;

  late Completer<GoogleMapController> _controller = Completer<GoogleMapController>();
  static const CameraPosition _kGooglePlex = CameraPosition(
    target: LatLng(37.42796133580664, -122.085749655962),
    zoom: 13.0,
  );

  Future<void> _goToThePosition(double lat, double long) async {
    final GoogleMapController controller = await _controller.future;
    await controller.animateCamera(
        CameraUpdate.newCameraPosition(
            CameraPosition(
              target: LatLng(lat, long),
              zoom: 13.0,
            )
        )
    );
  }

  Future<bool> checkLocationAvailable() async {
    try {
      _serviceEnabled = await location.serviceEnabled();
      if (!_serviceEnabled) {
        _serviceEnabled = await location.requestService();
        if (!_serviceEnabled) {
          return false;
        }
      }

      _permissionGranted = await location.hasPermission();
      if (_permissionGranted == PermissionStatus.denied) {
        _permissionGranted = await location.requestPermission();
        if (_permissionGranted != PermissionStatus.granted) {
          return false;
        }
      }

      return true;
    } on Exception {
      return false;
    }
  }

  Future<bool> _currentLocation({bool moveCamera = false}) async {
    final GoogleMapController controller = await _controller.future;
    LocationData? currentLocation;
    if (await checkLocationAvailable()) {
      try {
        currentLocation = await location.getLocation();
      } on Exception {
        currentLocation = null;
      }
    }

    if (currentLocation != null) {
      _latitude = currentLocation.latitude ?? 37.42796133580664;
      _longitude = currentLocation.longitude ?? -122.085749655962;

      if (moveCamera) {
        controller.animateCamera(CameraUpdate.newCameraPosition(
          CameraPosition(
            bearing: 0,
            target: LatLng(currentLocation.latitude as double, currentLocation.longitude as double),
            zoom: 13.0,
          ),
        ));
      }
      return true;
    }

    return false;
  }

  late DateTime _startTime;

  int _catchCount = 0;

  void _startTimer() {
    _calTimer = Timer.periodic(const Duration(seconds: 10), (timer) async {
      // 여기에 10초마다 실행할 코드를 작성. (소규모 위치 업데이트)
      DateTime now = DateTime.now();

      int secondsSinceEpoch = now.millisecondsSinceEpoch ~/ 1000;

      for (int i = 0; i < enemies.length; i++) {
        if (enemies[i]['route'].length > 0) {
          while (enemies[i]['route'].length > 0) {
            if (secondsSinceEpoch > enemies[i]['route']['end_time']) {
              enemies[i]['route'].removeAt(0);
              continue;
            }

            int a = secondsSinceEpoch - (enemies[i]['route'][0]['start_time'] as int); int b = (enemies[i]['route'][0]['end_time'] as int) - secondsSinceEpoch; // a : b로 내분
            if (a == 0) {
              enemies[i]['coord']['lat'] = enemies[i]['route'][0]['start_lat'];
              enemies[i]['coord']['long'] = enemies[i]['route'][0]['start_long'];
            } else if (b == 0) {
              enemies[i]['coord']['lat'] = enemies[i]['route'][0]['end_lat'];
              enemies[i]['coord']['long'] = enemies[i]['route'][0]['end_long'];
            } else {
              enemies[i]['coord']['lat'] = (a * enemies[i]['route'][0]['end_lat'] + b * enemies[i]['route'][0]['start_lat']) / (a + b);
              enemies[i]['coord']['long'] = (a * enemies[i]['route'][0]['end_long'] + b * enemies[i]['route'][0]['start_long']) / (a + b);
            }
          }
        } else {
          double d = calculateDistance(enemies[i]['coord']['lat'], enemies[i]['coord']['long'], myLatitude, myLongitude);
          double distanceTime = enemies[i]['mode'] == "Walking" ? d / 1.38 : d / 16.67;

          double a = enemies[i]['mode'] == "Walking" ? 1.38 : 16.67; double b = distanceTime - a; // a : b로 내분

          if (b >= 0) {
            enemies[i]['coord']['lat'] = (a * myLatitude + b * enemies[i]['coord']['lat']) / (a + b);
            enemies[i]['coord']['long'] = (a * myLongitude + b * enemies[i]['coord']['long']) / (a + b);
          }
        }

        _makeMarkers();

        if (calculateDistance(enemies[i]['coord']['lat'], enemies[i]['coord']['long'], myLatitude, myLongitude) < 1000) { // 잡힐 경우 (1km 이내)
          _catchCount++;
          if (_catchCount > 1) {
            _endGame();
          }
        } else {
          _catchCount = 0;
        }
      }
    });

    _apiTimer = Timer.periodic(const Duration(minutes: 5), (timer) async {
      // 여기에 5분마다 실행할 코드를 작성. (위치 업데이트)

      // You are a finder of someone. Find the coordinates of where you need to go by using the given coordinate information.'
      // current location of someone: ()
      // previous location of someone: ()
      // now where you are: ()
      if (await checkLocationAvailable()) {
        final me = await location.getLocation();

        for (int i = 0; i < enemies.length; i++) {
          final chat = coordModel.startChat();
          final prompt = 'You are a finder of someone. Find the coordinates of where you need to go by using the given coordinate information below. Think step by step.'
              'previous location of someone: (latitude: $myLatitude, long: $myLongitude)'
              'current location of someone: (latitude: ${me.latitude}, long: ${me.longitude})'
              'current location of you: (latitude: ${enemies[i]['coord']!['lat']}, long: ${enemies[i]['coord']!['long']})'
              'transportation: ${enemies[i]['mode']}';

          var response = await chat.sendMessage(Content.text(prompt));

          final functionCalls = response.functionCalls.toList();
          if (functionCalls.isNotEmpty) {
            final functionCall = functionCalls.first;
            try {
              switch (functionCall.name) {
                case 'getCoord':
                  if (functionCall.args['latitude'] != null && functionCall.args['longitude'] != null ) {
                    enemies[i]['route'] = await getDirection(enemies[i]['coord']!['lat'], enemies[i]['coord']!['long'], functionCall.args['latitude'] as double, functionCall.args['longitude'] as double, mode: enemies[i]['mode'] as String);
                  } else {
                    enemies[i]['route'] = await getDirection(enemies[i]['coord']!['lat'], enemies[i]['coord']!['long'], me.latitude ?? 0, me.longitude ?? 0, mode: enemies[i]['mode'] as String);
                  }
                  break;
                default:
                  break;
              }
            } catch (e) {
              enemies[i]['route'] = [];
            }
          }
        }

        if (me.latitude != null) {
          myLatitude = me.latitude!;
        }

        if (me.longitude != null) {
          myLongitude = me.longitude!;
        }
      } else {
        _endGame();
      }
    });
  }

  void _endGame() {
    DateTime _endTime = DateTime.now();
    Duration delta = _endTime.difference(_startTime);
    showMessage("The time you survived: ${delta.inSeconds}s");

    enemies.clear();
    _calTimer?.cancel(); // Timer 해제
    _apiTimer?.cancel(); // Timer 해제

    _makeMarkers();
  }

  late StreamSubscription _intentSub;
  var _sharedFiles = <SharedMediaFile>[];

  StreamSubscription? _locationSub;

  @override
  void initState() {
    super.initState();
    // Listen to media sharing coming from outside the app while the app is in the memory.
    _intentSub = ReceiveSharingIntent.instance.getMediaStream().listen((value) async {
      _sharedFiles.clear();
      _sharedFiles.addAll(value);

      print(_sharedFiles.map((f) => f.toMap()));


      if (_sharedFiles.isNotEmpty) {
        if (_sharedFiles.length > 100) {
          _sharedFiles = _sharedFiles.getRange(0, 100).toList();
        }

        final now = DateTime.now().toIso8601String();
        final jsonData = [];

        for (final f in _sharedFiles) {
          final exif = await Exif.fromPath(f.path);
          final latlong = await exif.getLatLong();

          jsonData.add({
            'title': now,
            'description': '',
            'date': now,
            'location': {'lat': latlong?.latitude ?? _latitude, 'long': latlong?.longitude ?? _longitude},
            'address': '',
            'path': f.path,
          });
        }


        bool? update = await Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => AddEditPostScreen(logData: jsonData as List<Map<String, Object>>)),
        );

        if (update ?? false) {
          _makeMarkers();
        }
      }
    }, onError: (err) {
      print("getIntentDataStream error: $err");
    });

    // Get the media sharing coming from outside the app while the app is closed.
    ReceiveSharingIntent.instance.getInitialMedia().then((value) async {
      _sharedFiles.clear();
      _sharedFiles.addAll(value);

      print(_sharedFiles.map((f) => f.toMap()));

      // Tell the library that we are done processing the intent.
      ReceiveSharingIntent.instance.reset();

      if (_sharedFiles.isNotEmpty) {
        if (_sharedFiles.length > 100) {
          _sharedFiles = _sharedFiles.getRange(0, 100).toList();
        }

        final now = DateTime.now().toIso8601String();
        final jsonData = [];

        for (final f in _sharedFiles) {
          final exif = await Exif.fromPath(f.path);
          final latlong = await exif.getLatLong();

          jsonData.add({
            'title': now,
            'description': '',
            'date': now,
            'location': {'lat': latlong?.latitude ?? _latitude, 'long': latlong?.longitude ?? _longitude},
            'address': '',
            'path': f.path,
          });
        }

        bool? update = await Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => AddEditPostScreen(logData: jsonData as List<Map<String, Object>>)),
        );

        if (update ?? false) {
          _makeMarkers();
        }
      }
    });

    // _ad = NativeAd(
    //   adUnitId: AdHelper.nativeAdUnitId,
    //   factoryId: 'listTile',
    //   request: const AdRequest(),
    //   listener: NativeAdListener(
    //     onAdLoaded: (ad) {
    //       setState(() {
    //         _ad = ad as NativeAd;
    //       });
    //     },
    //     onAdFailedToLoad: (ad, error) {
    //       // Releases an ad resource when it fails to load
    //       ad.dispose();
    //       print('Ad load failed (code=${error.code} message=${error.message})');
    //     },
    //   ),
    // );
    //
    // _ad?.load();


    Box settingBox = Hive.box('setting');
    Box logBox = Hive.box('setting');
    bool autosave = settingBox.get("location_autosave", defaultValue: false);

    if (autosave) {
      checkLocationAvailable().then((value) {
        if (value) {
          _locationSub = location.onLocationChanged.listen((event) async {
            DateTime now = DateTime.now();
            Duration delta = now.difference(recentSaved);
            if (delta.inMinutes > 10) {
              await logBox.add(LocData(
                title: now.toIso8601String(),
                description: '',
                date: now.toIso8601String(),
                location: Loc(lat: event.latitude ?? 0, long: event.longitude ?? 0),
                address: '',
                path: '',
              ));
            }
          });
        }
      });
    }

    _makeMarkers();
    _currentLocation(moveCamera: true);
  }

  DateTime recentSaved = DateTime.now();

  @override
  void dispose() {
    _locationSub?.cancel();
    _intentSub.cancel();
    _searchController.dispose();
    _calTimer?.cancel(); // Timer 해제
    _apiTimer?.cancel(); // Timer 해제
    // _ad?.dispose();

    super.dispose();
  }

  List<Marker> _markers = [];

  static const TextStyle optionStyle =
  TextStyle(fontSize: 30, fontWeight: FontWeight.bold);

  void _makeMarkers() {
    Box box = Hive.box<LocData>('log');
    final values = box.values;

    _markers.clear();
    for (final value in values) {
      print(value);
      _markers.add(
        Marker(
          markerId: MarkerId(value.key.toString()),
          // onTap: () {
          // },
          onDragEnd: null,
          position: LatLng(value.location?.lat ?? _latitude, value.location?.long ?? _longitude),
          infoWindow: InfoWindow(title: value.title, snippet: "${value.description != "" ? "${value.description}\n" : ""}${value.address != "" ? "${value.address}\n" : ""}${value.date}", onTap: () {
            showMessageWithCancel("Do you want to delete this log?", () {
              box.delete(value.key);
              _makeMarkers();
            });
          }),
        )
      );
    }

    for (final enemy in enemies) {
      _markers.add(
        Marker(
          markerId: MarkerId("enemy #${enemy.hashCode}"),
          position: LatLng(enemy['coord']['lat'], enemy['coord']['long']),
          rotation: 180.0,
        )
      );
    }

    setState(() {});
  }

  final TextEditingController _searchController = TextEditingController();
  List<Map<String, String>> _suggestions = [];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(150), // AppBar 높이 조절
        child: Column(
          children: [
            AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              title: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                    hintText: 'Search address',
                    filled: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide.none,
                    ),
                    suffixIcon: Visibility(
                      visible: _searchController.text != "",
                      child: IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _suggestions = [];
                          });
                        },
                      ),
                    )
                ),
                onChanged: (value) async {
                  if (value == "") {
                    setState(() {
                      _suggestions = [];
                    });
                    return;
                  }
                  _suggestions = await addressAutoComplete(value, _latitude, _longitude);
                  setState(() {});
                },
              ),
            ),
            Expanded(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _suggestions.length,
                itemBuilder: (context, index) {
                  return Container(
                    decoration: const BoxDecoration(
                      color: Colors.white,
                    ),
                    child: ListTile(
                      title: Text(_suggestions[index]['text']!),
                      onTap: () async {
                        Map<String, double>? data = await getGeocodingFromPlaceId(_suggestions[index]['placeId']!);
                        print(data);
                        _goToThePosition(data?['lat'] ?? 37.42796133580664, data?['long'] ?? -122.085749655962);
                      },
                      dense: true,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      body: GoogleMap(
        mapType: MapType.normal,
        initialCameraPosition: _kGooglePlex,
        onMapCreated: (GoogleMapController controller) {
          _controller = Completer<GoogleMapController>();
          _controller.complete(controller);
        },
        markers: Set.from(_markers),
        onLongPress: (coord) {
          _goToThePosition(coord.latitude, coord.longitude);
          showMessageWithCancel('Do you want to write to this map location?', () async {
            final now = DateTime.now().toIso8601String();
            final jsonData = [
              {
                'title': now,
                'description': '',
                'date': now,
                'location': {'lat': _latitude, 'long': _longitude},
                'address': '',
                'path': '',
              }
            ];
            bool? update = await Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => AddEditPostScreen(logData: jsonData)),
            );

            if (update ?? false) {
              _makeMarkers();
            }
          });
        },
        onCameraMove: (cameraPosition) {
          _latitude = cameraPosition.target.latitude;
          _longitude = cameraPosition.target.longitude;
        },
        myLocationEnabled: true,
        myLocationButtonEnabled: false,
        zoomControlsEnabled: false,
      ),
      floatingActionButton: Wrap(
        direction: Axis.vertical,
        children: <Widget>[
          Container(
              margin: const EdgeInsets.all(10),
              child: FloatingActionButton(
                heroTag: "near_me",
                onPressed: () {
                  _currentLocation(moveCamera: true);
                },
                child: const Icon(Icons.near_me),
              )
          ),
          Container(
              margin: const EdgeInsets.all(10),
              child: FloatingActionButton(
                heroTag: "add",
                onPressed: () {
                  showSheet();
                },
                child: const Icon(Icons.add),
              )
          ),
          Container(
              margin: const EdgeInsets.all(10),
              child: FloatingActionButton(
                heroTag: "setting",
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => SettingScreen()),
                  );
                },
                child: const Icon(Icons.settings),
              )
          ),
        ],
      ),
      bottomNavigationBar: Visibility(
        visible: enemies.isNotEmpty,
        child: ElevatedButton(
          child: const Text('Stop hide-and-seek'),
          onPressed: () async {
            _endGame();
          }
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

  // 현재 지도 위치 추가, 현재 위치 추가, 이미지 이용해서 추가
  void showSheet() {
    showModalBottomSheet<void>(
      context: context,
      builder: (BuildContext _context) {
        return SizedBox(
          height: 200,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                ElevatedButton(
                    child: const Text('Select from Gallery'),
                    onPressed: () async {
                      Navigator.pop(_context);

                      final ImagePicker picker = ImagePicker();
                      final List<XFile> images = await picker.pickMultiImage();

                      final now = DateTime.now().toIso8601String();
                      final List<Map<String, Object>> jsonData = [];

                      for (int i = 0; i < images.length; i++) {
                        final exif = await Exif.fromPath(images[i].path);
                        final latlong = await exif.getLatLong();
                        jsonData.add({
                          'title': now,
                          'description': '',
                          'date': now,
                          'location': {'lat': latlong?.latitude ?? _latitude, 'long': latlong?.longitude ?? _longitude},
                          'address': '',
                          'path': images[i].path,
                        });
                      }

                      if (jsonData.isNotEmpty) {
                        bool? update = await Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => AddEditPostScreen(logData: jsonData)),
                        );

                        if (update ?? false) {
                          _makeMarkers();
                        }
                      }
                    }
                ),
                ElevatedButton(
                    child: const Text('Take a picture with current map location'),
                    onPressed: () async {
                      Navigator.pop(_context);
                      final ImagePicker picker = ImagePicker();
                      final XFile? photo = await picker.pickImage(source: ImageSource.camera);

                      final now = DateTime.now().toIso8601String();
                      final jsonData = [{
                        'title': now,
                        'description': '',
                        'date': now,
                        'location': {'lat': _latitude, 'long': _longitude},
                        'address': '',
                        'path': photo?.path ?? '',
                      }];

                      bool? update = await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => AddEditPostScreen(logData: jsonData)),
                      );

                      if (update ?? false) {
                        _makeMarkers();
                      }
                    }
                ),
                ElevatedButton(
                  child: const Text('Add current map location'),
                  onPressed: () async {
                    Navigator.pop(_context);

                    final now = DateTime.now().toIso8601String();
                    final jsonData = [{
                      'title': now,
                      'description': '',
                      'date': now,
                      'location': {'lat': _latitude, 'long': _longitude},
                      'address': '',
                      'path': '',
                    }];

                    bool? update = await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => AddEditPostScreen(logData: jsonData)),
                    );

                    if (update ?? false) {
                      _makeMarkers();
                    }
                  },
                ),
                ElevatedButton(
                  child: const Text('Hide-and-seek with AI'),
                  onPressed: () async {
                    if (await checkLocationAvailable()) {
                      Navigator.pop(_context);

                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => ChaserSettingScreen(lat: _latitude, long: _longitude,)),
                      );

                      if (result != null) {
                        setState(() {
                          enemies = result;
                        });

                        _startTime = DateTime.now();
                        _startTimer();
                      }
                    } else {
                      showMessage("I can't find the current location, please check the location settings.");
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

// int _getDestinationItemIndex(int rawIndex) {
//   if (rawIndex >= _kAdIndex && _ad != null) {
//     return rawIndex - 1;
//   }
//   return rawIndex;
// }

// Widget discoverListView() {
//   return ListView.builder(
//       itemCount: (_ad != null ? 1 : 0) + 4,
//       itemBuilder: (context, index) {
//           if (_ad != null && index == _kAdIndex) {
//               return Container(
//                 height: 72.0,
//                 alignment: Alignment.center,
//                 child: AdWidget(ad: _ad!),
//               );
//           } else {
//               /// Get adjusted item index from _getDestinationItemIndex()
//               return const ListTile(title: Text("Examples"),);
//           }
//       },
//   );
// }
}