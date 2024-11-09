import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/adapters.dart';
import 'package:location/location.dart';
import 'package:image_picker/image_picker.dart';
import 'package:logat/utils/chat.dart';
import 'package:logat/utils/gemini_api.dart';
import 'package:logat/utils/maps_api.dart';
import 'package:logat/utils/structure.dart';

import 'package:logat/views/etc/chaser_setting.dart';
import 'package:logat/views/post/add_edit_post.dart';
import 'package:logat/views/etc/setting.dart';
import 'package:native_exif/native_exif.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:share_plus/share_plus.dart';

final appLinks = AppLinks(); // AppLinks is singleton

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key,}) : super(key: key);

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

  DateTime _lastLocationUpdated = DateTime.now();
  late double _latitude = 37.42796133580664; // 지도상의 위치
  late double _longitude = -122.085749655962; // 지도상의 위치

  late double myLatitude = 37.42796133580664; // 최근 나의 위치
  late double myLongitude = -122.085749655962; // 최근 나의 위치

  List<Map<String, dynamic>> enemies = [];

  Timer? _calTimer;
  Timer? _apiTimer;

  late Completer<GoogleMapController> _controller = Completer<GoogleMapController>();

  static LatLng _kInitialPlace = LatLng(37.42796133580664, -122.085749655962);

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

  StreamSubscription? uriSub;

  late DateTime _startTime;

  int _catchCount = 0;

  int radar = 1000; // m 단위, radar가 10초에 10m씩 늘어나게 설계

  void setEnemyDirection() async {
    if (await checkLocationAvailable()) {
      final me = await location.getLocation();

      // getGeocoding();

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
                print("${enemies[i]['coord']!['lat']}, ${enemies[i]['coord']!['long']}, ${functionCall.args['latitude']}, ${functionCall.args['longitude']}");
                if (functionCall.args['latitude'] != null && functionCall.args['longitude'] != null ) {
                  enemies[i]['route'] = await getDirection(enemies[i]['coord']!['lat'], enemies[i]['coord']!['long'], functionCall.args['latitude'] as double, functionCall.args['longitude'] as double, mode: enemies[i]['mode'] as String);
                } else {
                  enemies[i]['route'] = await getDirection(enemies[i]['coord']!['lat'], enemies[i]['coord']!['long'], me.latitude ?? 0, me.longitude ?? 0, mode: enemies[i]['mode'] as String);
                }
                // print("route");
                // print(enemies[i]['route']);
                break;
              default:
                break;
            }
          } catch (e) {
            print(e);
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
  }

  void _startTimer() {
    int update_second = 1; // 얼마나 업데이트되는지 설정
    double walking = 1.4 * update_second;
    double driving = 20.0 * update_second;
    _calTimer = Timer.periodic(Duration(seconds: update_second), (timer) async {
      // 여기에 10초마다 실행할 코드를 작성. (소규모 위치 업데이트)
      radar += update_second;

      DateTime now = DateTime.now();

      int secondsSinceEpoch = now.millisecondsSinceEpoch ~/ 1000;

      for (int i = 0; i < enemies.length; i++) {
        if (enemies[i]['route'].length > 0) {
          while (enemies[i]['route'].length > 0 && secondsSinceEpoch > enemies[i]['route'][0]['end_time']) {
            enemies[i]['route'].removeAt(0);
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
        } else {
          double d = calculateDistance(enemies[i]['coord']['lat'], enemies[i]['coord']['long'], myLatitude, myLongitude);

          double a = enemies[i]['mode'] == "Walking" ? walking : driving;
          double b = d - a;

          if (b >= 0) {
            enemies[i]['coord']['lat'] = (a * myLatitude + b * enemies[i]['coord']['lat']) / d;
            enemies[i]['coord']['long'] = (a * myLongitude + b * enemies[i]['coord']['long']) / d;
          }
        }

        _makeMarkers();

        if (calculateDistance(enemies[i]['coord']['lat'], enemies[i]['coord']['long'], myLatitude, myLongitude) < radar) { // 잡힐 경우 (radar 반경 이내)
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
      setEnemyDirection();
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

  // double? _receivedLat;
  // double? _receivedLong;

  late StreamSubscription _intentSub;
  var _sharedFiles = <SharedMediaFile>[];

  StreamSubscription? _locationSub;

  void _manageSharedFiles() async {
    if (_sharedFiles.isNotEmpty) {
      if (_sharedFiles.length > 100) {
        _sharedFiles = _sharedFiles.getRange(0, 100).toList();
      }

      final now = DateTime.now().toIso8601String();
      final List<Map<String, Object>> jsonData = [];

      for (final f in _sharedFiles) {
        final exif = await Exif.fromPath(f.path);
        final latlong = await exif.getLatLong();
        final date = await exif.getOriginalDate();

        jsonData.add({
          'title': date?.toIso8601String() ?? now,
          'description': '',
          'date': date?.toIso8601String() ?? now,
          'location': {'lat': latlong?.latitude ?? _latitude, 'long': latlong?.longitude ?? _longitude},
          'address': '',
          'path': f.path,
        });
      }

      bool? update = await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => AddEditPostScreen(logData: jsonData)),
      );

      if (update ?? false) {
        _makeMarkers();
      }
    }
  }

  @override
  void initState() {
    super.initState();

    // Listen to media sharing coming from outside the app while the app is in the memory.
    _intentSub = ReceiveSharingIntent.instance.getMediaStream().listen((value) async {
      _sharedFiles.clear();
      _sharedFiles.addAll(value);

      print(_sharedFiles.map((f) => f.toMap()));

      _manageSharedFiles();
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

      _manageSharedFiles();
    });

    uriSub = appLinks.uriLinkStream.listen((uri) async {
      String? lat = uri.queryParameters['lat'];
      String? long = uri.queryParameters['long'];

      if (lat != null && long != null) {
        try {
          _markers.add(
              Marker(
                markerId: MarkerId("Received"),
                position: LatLng(double.parse(lat), double.parse(long)),
                onTap: () {
                  showSheetWithLocation(title: "Received Location", location: Loc(lat: double.parse(lat), long: double.parse(long)),);
                },
                icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueMagenta),
              )
          );

          setState(() {});

          final GoogleMapController controller = await _controller.future;
          controller.animateCamera(CameraUpdate.newCameraPosition(
            CameraPosition(
              bearing: 0,
              target: LatLng(double.parse(lat), double.parse(long)),
              zoom: 13.0,
            ),
          ));
          showSheetWithLocation(title: "Received Location", location: Loc(lat: double.parse(lat), long: double.parse(long)),);
        } catch (e) {
          print(e);
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
    Box box = Hive.box("setting");
    bool autosave = box.get("location_autosave", defaultValue: false);
    print(autosave);

    _latitude = box.get('myLatitude', defaultValue: _latitude);
    _longitude = box.get('myLongitude', defaultValue: _longitude);

    setState(() {
      _kInitialPlace = LatLng(_latitude, _longitude);
    });

    checkAutoSave(autosave);
  }

  void checkAutoSave(bool autosave) async {
    if (autosave) {
      checkLocationAvailable().then((value) {
        if (value) {
          _locationSub = location.onLocationChanged.listen((event) async {
            DateTime now = DateTime.now();
            Duration delta = now.difference(recentSaved);
            // print(delta.inMinutes);
            if (delta.inMinutes > 9) {
              Box logBox = await Hive.openBox<LocData>('log');
              await logBox.add(LocData(
                title: now.toIso8601String(),
                description: '',
                date: now.toIso8601String(),
                location: Loc(lat: event.latitude ?? 0, long: event.longitude ?? 0),
                address: '',
                path: '',
              ));
              recentSaved = now;
              _makeMarkers();
            }
          });
        }
      });
    } else {
      _locationSub?.cancel();
    }
  }

  DateTime recentSaved = DateTime.now();

  @override
  void dispose() {
    _locationSub?.cancel();
    _intentSub.cancel();
    _searchController.dispose();
    _calTimer?.cancel(); // Timer 해제
    _apiTimer?.cancel(); // Timer 해제
    uriSub?.cancel();
    // _ad?.dispose();

    super.dispose();
  }

  List<Marker> _markers = [];

  static const TextStyle optionStyle =
  TextStyle(fontSize: 30, fontWeight: FontWeight.bold);

  void _makeMarkers() async {
    Box<LocData> box = await Hive.openBox<LocData>('log');
    final values = box.values;

    _markers.clear();
    if (enemies.isEmpty) {
      for (final value in values) {
        // print(value);
        _markers.add(
            Marker(
              markerId: MarkerId(value.key.toString()),
              onTap: () {
                showSheetWithLocation(title: value.title ?? "", description: value.description ?? "", address: value.address ?? "", location: value.location ?? Loc(lat: 0, long: 0), date: value.date ?? "", path: value.path, key: value.key);
              },
              onDragEnd: null,
              position: LatLng(value.location?.lat ?? _latitude, value.location?.long ?? _longitude),
            )
        );
      }
    } else {
      for (final enemy in enemies) {
        _markers.add(
            Marker(
              markerId: MarkerId("enemy #${enemy.hashCode}"),
              position: LatLng(enemy['coord']['lat'], enemy['coord']['long']),
              icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
            )
        );
      }
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
        preferredSize: const Size.fromHeight(200), // AppBar 높이 조절
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
                      title: Text(_suggestions[index]['text']!, style: const TextStyle(color: Colors.black45),),
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
        initialCameraPosition: CameraPosition(
          target: _kInitialPlace,
          zoom: 13.0,
        ),
        onMapCreated: (GoogleMapController controller) async {
          _controller = Completer<GoogleMapController>();
          _controller.complete(controller);
          _makeMarkers();

          _currentLocation(moveCamera: true);
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
        onCameraMove: (cameraPosition) async {
          _latitude = cameraPosition.target.latitude;
          _longitude = cameraPosition.target.longitude;

          DateTime now = DateTime.now();

          if (now.difference(_lastLocationUpdated).inSeconds > 4) {
            try {
              Box box = await Hive.openBox("setting");

              box.put('myLatitude', _latitude);
              box.put('myLongitude', _longitude);
            } catch (e) {
              print(e);
            }

            _lastLocationUpdated = DateTime.now();
          }
        },
        myLocationEnabled: true,
        myLocationButtonEnabled: false,
        zoomControlsEnabled: false,
        compassEnabled: false,
      ),
      floatingActionButton: Wrap(
        direction: Axis.vertical,
        children: <Widget>[
          Container(
              margin: const EdgeInsets.all(5),
              child: FloatingActionButton.small(
                heroTag: "share",
                onPressed: () {
                  Share.share("Please tell me where you are. I'm in here:\n"
                      "https://logat-release.web.app?lat=$_latitude&long=$_longitude");
                },
                child: const Icon(Icons.share),
              )
          ),
          Container(
              margin: const EdgeInsets.all(5),
              child: FloatingActionButton.small(
                heroTag: "near_me",
                onPressed: () {
                  _currentLocation(moveCamera: true);
                },
                child: const Icon(Icons.near_me),
              )
          ),
          Container(
              margin: const EdgeInsets.all(5),
              child: FloatingActionButton.small(
                heroTag: "ai",
                onPressed: () {
                  showSheetGemini();
                },
                child: const Icon(Icons.auto_awesome),
              )
          ),
          Container(
              margin: const EdgeInsets.all(5),
              child: FloatingActionButton.small(
                heroTag: "add",
                onPressed: () {
                  showSheet();
                },
                child: const Icon(Icons.add),
              )
          ),
          Container(
              margin: const EdgeInsets.all(5),
              child: FloatingActionButton.small(
                heroTag: "setting",
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => SettingScreen(autosave: checkAutoSave)),
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
          height: 250,
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
                      final List<XFile> images = await picker.pickMultiImage(maxHeight: 1024, maxWidth: 1024,);

                      final now = DateTime.now().toIso8601String();
                      final List<Map<String, Object>> jsonData = [];

                      for (int i = 0; i < images.length; i++) {
                        final exif = await Exif.fromPath(images[i].path);
                        final latlong = await exif.getLatLong();
                        final date = await exif.getOriginalDate();
                        jsonData.add({
                          'title': date?.toIso8601String() ?? now,
                          'description': '',
                          'date': date?.toIso8601String() ?? now,
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
                      final XFile? photo = await picker.pickImage(source: ImageSource.camera, maxWidth: 1024, maxHeight: 1024,);

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
              ],
            ),
          ),
        );
      },
    );
  }

  Future<List<String>> _getMarkersInputToAI() async {
    List<String> markersInput = [];

    Box<LocData> box = await Hive.openBox<LocData>('log');
    List<LocData> values = box.values.toList();

    for (int i = 0; i < 3; i++) {
      if (i >= values.length) {
        break;
      }

      String temp = "";
      int index = -1;
      for (int j = 0; j < values.length; j++) {
        if ((values[j].date?.compareTo(temp) ?? 0) > 0) {
          temp = values[j].date ?? "";
          index = j;
        }
      }

      if (index != -1) {
        final data = await getReverseGeocoding(values[index].location?.lat ?? 0.0, values[index].location?.long ?? 0.0);
        markersInput.add("${data.isNotEmpty ? '${data[0]['text']} ' : ''}(when: ${values[index].date}, latitude: ${values[index].location?.lat ?? 0.0}, longitude: ${values[index].location?.long ?? 0.0})");
        values.removeAt(index);
      }
    }

    return markersInput;
  }

  void showSheetGemini() {
    showModalBottomSheet<void>(
      context: context,
      builder: (BuildContext _context) {
        return SizedBox(
          height: 250,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                ElevatedButton(
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.auto_awesome),
                      SizedBox(width: 10,),
                      Text('Ask to AI with current map location and logs', softWrap: true, overflow: TextOverflow.ellipsis,),
                    ],
                  ),
                  onPressed: () async {
                    if (await checkLocationAvailable()) {
                      Navigator.pop(_context);

                      List<String> markersInput = await _getMarkersInputToAI();

                      if (markersInput.isEmpty) {
                        showMessage("No data is available.");
                        return;
                      }

                      String now = DateTime.now().toIso8601String();
                      final data = await getReverseGeocoding(_latitude, _longitude);
                      final currentAddress = data.isNotEmpty ? '${data[0]['text']} ' : '';
                      final prompt = '\n\nprevious location I visited: $markersInput\n'
                          'current location of me: $currentAddress(when: $now, latitude: $_latitude, long: $_longitude)';

                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => ChatScreen(initialString: prompt,)),
                      );
                    } else {
                      showMessage("I can't find the current location, please check the location settings.");
                    }
                  },
                ),
                ElevatedButton(
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.auto_awesome),
                      SizedBox(width: 10,),
                      Text('Get next place recommendation', softWrap: true, overflow: TextOverflow.ellipsis,),
                    ],
                  ),
                  onPressed: () async {
                    Navigator.of(_context).pop();

                    showMessageWithCancel("We recommend the place by providing the existing visit logs to Google Gemini and Google Maps. Do you want to continue?", () async {
                      final chat = addressModel.startChat();

                      List<String> markersInput = await _getMarkersInputToAI();

                      if (markersInput.isEmpty) {
                        showMessage("No data is available.");
                        return;
                      }

                      String now = DateTime.now().toIso8601String();
                      final data = await getReverseGeocoding(_latitude, _longitude);
                      final currentAddress = data.isNotEmpty ? '${data[0]['text']} ' : '';
                      final prompt = 'Find the address of where we need to go next by using the given information below. '
                          'Please recommend a place to visit nearby or recommend a place related to the anniversary using the date. '
                          'Think step by step and explain reason in as much detail as possible. '
                          'You should not mention the place I went to before again.'
                          '\n\nprevious location I visited: $markersInput\n';
                          // 'current location of me: $currentAddress(when: $now, latitude: $_latitude, long: $_longitude)';

                      var response = await chat.sendMessage(Content.text(prompt));

                      final functionCalls = response.functionCalls.toList();
                      if (functionCalls.isNotEmpty) {
                        final functionCall = functionCalls.first;
                        try {
                          switch (functionCall.name) {
                            case 'getAddress':
                              if (functionCall.args['address'] != null) {
                                final data = await getGeocoding(functionCall.args['address'].toString());
                                if (data.isNotEmpty) {
                                  _goToThePosition(data[0]['lat'] as double, data[0]['long'] as double);
                                  showSheetWithLocation(title: "Recommended Location", location: Loc(lat: data[0]['lat'] as double, long: data[0]['long'] as double), description: functionCall.args['reason'].toString());

                                  setState(() {
                                    _markers.add(
                                        Marker(
                                          markerId: MarkerId("Recommended"),
                                          position: LatLng(data[0]['lat'] as double, data[0]['long'] as double),
                                          onTap: () {
                                            showSheetWithLocation(title: "Recommended Location", location: Loc(lat: data[0]['lat'] as double, long: data[0]['long'] as double), description: functionCall.args['reason'].toString());
                                          },
                                          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
                                        )
                                    );
                                  });
                                  break;
                                }
                              }
                            default:
                              showMessage("An error occurred while calling the model.");
                              break;
                          }
                        } catch (e) {
                          print(e);
                          showMessage("An error occurred while calling the model.");
                        }
                      }
                    });
                  },
                ),
                // ElevatedButton(
                //   child: const Row(
                //     mainAxisSize: MainAxisSize.min,
                //     children: [
                //       Icon(Icons.auto_awesome),
                //       SizedBox(width: 10,),
                //       Text('Hide-and-seek with AI', softWrap: true, overflow: TextOverflow.ellipsis,),
                //     ],
                //   ),
                //   onPressed: () async {
                //     if (await checkLocationAvailable()) {
                //       Navigator.pop(_context);
                //
                //       final result = await Navigator.push(
                //         context,
                //         MaterialPageRoute(builder: (context) => ChaserSettingScreen(lat: _latitude, long: _longitude,)),
                //       );
                //
                //       if (result != null) {
                //         setState(() {
                //           enemies = result;
                //         });
                //
                //         _startTime = DateTime.now();
                //         setEnemyDirection(); // timer가 수행해야 할 함수 호출: timer 내 코드가 맨 처음에는 수행되지 않음
                //         _startTimer();
                //       }
                //     } else {
                //       showMessage("I can't find the current location, please check the location settings.");
                //     }
                //   },
                // ),
              ],
            ),
          ),
        );
      },
    );
  }

  void showSheetWithLocation({required String title, String description="", String address="", required Loc location, String date="", String? path="", dynamic key}) async {
    if (address == "") {
      try {
        final data = await getReverseGeocoding(location.lat ?? 0.0, location.long ?? 0.0);
        if (data.isNotEmpty) {
          address = data[0]['text']!;
        }
      } catch (e) {
        print(e);
      }
    }

    if (date == "") {
      date = DateTime.now().toIso8601String();
    }

    showModalBottomSheet<void>(
      context: context,
      builder: (BuildContext _context) {
        return SizedBox(
          height: 250,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                ListTile(
                  leading: Visibility(
                    visible: path != "" && File(path!).existsSync(),
                    child: GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => EnlargedImage(imageUrl: path),
                          ),
                        );
                      },
                      child: Hero(
                        tag: 'imageHero',
                        child: Image.file(File(path!), width: 50, height: 50),
                      ),
                    )
                  ),
                  title: Text(title),
                  subtitle: Text("$description\n$address\n$date"),
                  dense: true,
                  isThreeLine: true,
                ),
                ListTile(
                  title: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.delete),
                        onPressed: () {
                          showMessageWithCancel("Do you want to delete this log?", () async {
                            Navigator.of(_context).pop();

                            try {
                              if (key != null) {
                                Box<LocData> box = await Hive.openBox<LocData>('log');
                                box.delete(key);
                              }

                              if (path != "") {
                                await File(path).delete();
                              }
                            } catch (e) {
                              print(e);
                            }

                            _makeMarkers();
                          });
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: () {
                          showMessageWithCancel("Do you want to edit this log?", () async {
                            Navigator.of(_context).pop();

                            try {
                              final List<Map<String, Object>> jsonData = [{
                                'title': title,
                                'description': description,
                                'date': date,
                                'location': {'lat': location.lat, 'long': location.long},
                                'address': address,
                                'path': path,
                              }];

                              if (jsonData.isNotEmpty) {
                                bool? update = await Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => AddEditPostScreen(logData: jsonData)),
                                );

                                if (update ?? false) {
                                  try {
                                    if (key != null) {
                                      Box<LocData> box = await Hive.openBox<LocData>('log');
                                      box.delete(key);
                                    }
                                  } catch (e) {
                                    print(e);
                                  }

                                  _makeMarkers();
                                }
                              }
                            } catch (e) {
                              print(e);
                            }
                          });
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.auto_awesome),
                        onPressed: () {
                          showMessageWithCancel("We'll send this log to Gemini and Gemini will give you a good feedback. Do you want it?", () async {
                            try {
                              final List<Part> parts = [];
                              if (path != "") {
                                parts.add(DataPart('image/jpeg', File(path).readAsBytesSync()));
                              }

                              parts.add(TextPart("Express your feelings about this post as positively as possible"));
                              final response = await model.generateContent([
                                Content.multi(parts as Iterable<Part>)
                              ]);
                              showMessage(response.text ?? "Sorry. We can't get a message from Gemini due to inner error.");
                            } catch (e) {
                              print(e);
                              showMessage("Sorry. We can't get a message from Gemini due to inner error.");
                            }
                          });
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.share),
                        onPressed: () {
                          Share.share("Please tell me where you are. I'm in here:\n"
                              "https://logat-release.web.app?lat=${location.lat}&long=${location.long}");
                        },
                      ),
                    ],
                  ),
                  dense: true,
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

class EnlargedImage extends StatelessWidget {
  final String imageUrl;

  const EnlargedImage({super.key, required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Image'),
      ),
      body: InteractiveViewer(
        child: Center(
          child: Hero(
            tag: 'imageHero', // 동일한 tag 값
            child: Image.file(File(imageUrl)),
          ),
        ),
      )
    );
  }
}