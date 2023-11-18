import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';
import 'package:image_picker/image_picker.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:native_exif/native_exif.dart';
import 'firebase_options.dart';
import 'package:logat/ad_helper.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

Future<FirebaseApp> _initFirebase() {
  return Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
}

Future<InitializationStatus> _initGoogleMobileAds() {
  return MobileAds.instance.initialize();
}

void main() async {
  // await _initFirebase();
  // await _initGoogleMobileAds();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  // This widget is the root of your application.
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
      home: const MyHomePage(title: 'Logat',),
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
  static final _kAdIndex = 0;
  NativeAd? _ad;

  late Completer<GoogleMapController> _controller = Completer<GoogleMapController>();
  static const CameraPosition _kGooglePlex = CameraPosition(
    target: LatLng(37.42796133580664, -122.085749655962),
    zoom: 14.4746,
  );

  static const CameraPosition _kLake = CameraPosition(
      bearing: 192.8334901395799,
      target: LatLng(37.43296265331129, -122.08832357078792),
      tilt: 59.440717697143555,
      zoom: 19.151926040649414);

  Future<void> _goToTheLake() async {
    final GoogleMapController controller = await _controller.future;
    await controller.animateCamera(CameraUpdate.newCameraPosition(_kLake));
  }

  int _selectedIndex = 0;
  late final List<Widget> _widgetOptions;

  int _getDestinationItemIndex(int rawIndex) {
    if (rawIndex >= _kAdIndex && _ad != null) {
      return rawIndex - 1;
    }
    return rawIndex;
  }

  void _getImage() async {
    final ImagePicker picker = ImagePicker();
    final List<XFile> images = await picker.pickMultiImage();
    for (int i = 0; i < images.length; i++) {
      final exif = await Exif.fromPath(images[i].path!);
      final latlong = await exif.getLatLong();
      print("${latlong?.latitude}, ${latlong?.longitude}");
    }
  }

  @override
  void initState() {
    super.initState();

    _ad = NativeAd(
      adUnitId: AdHelper.nativeAdUnitId,
      factoryId: 'listTile',
      request: const AdRequest(),
      listener: NativeAdListener(
        onAdLoaded: (ad) {
          setState(() {
            _ad = ad as NativeAd;
          });
        },
        onAdFailedToLoad: (ad, error) {
          // Releases an ad resource when it fails to load
          ad.dispose();
          print('Ad load failed (code=${error.code} message=${error.message})');
        },
      ),
    );

    _ad?.load();

    _widgetOptions = <Widget>[
      GoogleMap(
        mapType: MapType.normal,
        initialCameraPosition: _kGooglePlex,
        onMapCreated: (GoogleMapController controller) {
          _controller = Completer<GoogleMapController>();
          _controller.complete(controller);
        },
        myLocationEnabled: true,
        myLocationButtonEnabled: false,
      ),
      Container(),
      const Text(
        'My profile',
        style: optionStyle,
      ),
    ];
  }

  @override
  void dispose() {
    _ad?.dispose();

    super.dispose();
  }

  static const TextStyle optionStyle =
    TextStyle(fontSize: 30, fontWeight: FontWeight.bold);

  Widget discoverListView() {
    return ListView.builder(
        itemCount: (_ad != null ? 1 : 0) + 4,
        itemBuilder: (context, index) {
            if (_ad != null && index == _kAdIndex) {
                return Container(
                  height: 72.0,
                  alignment: Alignment.center,
                  child: AdWidget(ad: _ad!),
                );
            } else {
                // TODO: Get adjusted item index from _getDestinationItemIndex()
                return const ListTile(title: Text("Examples"),);
            }
        },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: <Widget>[
          IconButton(
            icon: const Icon(
              Icons.notifications,
              color: Colors.blue,
            ),
            tooltip: "Notification",
            onPressed: () async {

            },
          ),
          IconButton(
            icon: const Icon(
              Icons.search,
              color: Colors.blue,
            ),
            tooltip: "Search",
            onPressed: () async {

            },
          ),
        ],
      ),
      body: Center(
        child: _widgetOptions.elementAt(_selectedIndex),
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        showUnselectedLabels: false,
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.map),
            label: 'Main',
          ),
          // BottomNavigationBarItem(
          //   icon: Icon(Icons.linear_scale),
          //   label: 'Points',
          // ),
          BottomNavigationBarItem(
            icon: Icon(Icons.add_circle_outline),
            label: "",
          ),
          // BottomNavigationBarItem(
          //   icon: Icon(Icons.explore),
          //   label: 'Discover',
          // ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'You',
          ),
        ],
        currentIndex: _selectedIndex,
        onTap: showSheet,
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey,
      ),
      floatingActionButton: Wrap(
        direction: Axis.vertical,
        children: <Widget>[
          Visibility(
            visible: _selectedIndex == 0,
            child: Container(
                margin: const EdgeInsets.all(10),
                child: FloatingActionButton(
                  onPressed: () {
                    _currentLocation();
                  },
                  child: const Icon(Icons.near_me),
                )
            ),
          ),
          Container(
              margin: const EdgeInsets.all(10),
              child: FloatingActionButton(
                onPressed: () {
                  _goToTheLake();
                },
                child: const Icon(Icons.tune),
              )
          ),
        ],
      ),
    );
  }

  var location = Location();
  late bool _serviceEnabled;
  late PermissionStatus _permissionGranted;
  late LocationData _locationData;

  void _currentLocation() async {
    final GoogleMapController controller = await _controller.future;
    LocationData? currentLocation;
    try {
      _serviceEnabled = await location.serviceEnabled();
      if (!_serviceEnabled) {
        _serviceEnabled = await location.requestService();
        if (!_serviceEnabled) {
          return;
        }
      }

      _permissionGranted = await location.hasPermission();
      if (_permissionGranted == PermissionStatus.denied) {
        _permissionGranted = await location.requestPermission();
        if (_permissionGranted != PermissionStatus.granted) {
          return;
        }
      }

      currentLocation = await location.getLocation();
    } on Exception {
      currentLocation = null;
    }

    controller.animateCamera(CameraUpdate.newCameraPosition(
      CameraPosition(
        bearing: 0,
        target: LatLng(currentLocation?.latitude as double, currentLocation?.longitude as double),
        zoom: 17.0,
      ),
    ));
  }


  void showSheet(int index) {
    if (index != 1) {
      setState(() {
        _selectedIndex = index;
      });
      return;
    }

    showModalBottomSheet<void>(
      context: context,
      builder: (BuildContext context) {
        return SizedBox(
          height: 200,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Text('Modal BottomSheet'),
                ElevatedButton(
                  child: const Text('Close BottomSheet'),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void showMessage(String title, String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text(title),
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
}
