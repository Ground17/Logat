import 'dart:io';
import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';


class ChaserSettingScreen extends StatefulWidget {
  const ChaserSettingScreen({Key? key, required this.lat, required this.long}) : super(key: key);

  final double lat;
  final double long;

  @override
  _ChaserSettingState createState() => _ChaserSettingState();
}

class _ChaserSettingState extends State<ChaserSettingScreen> {
  @override
  void initState() {
    super.initState();
  }

  final List<Map<String, Object>> _enemies = [{'mode': 'Driving'}];
  List<String> dropDownList = ['Driving', 'Walking'];

  int _distance = 10;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).primaryColor,
        title: const Text("Setting of AI", style: TextStyle(color: Colors.white),),
      ),
      body: ListView(
        shrinkWrap: true,
        children: [
          const ListTile(
            leading: Icon(Icons.auto_awesome),
            title: Text("The game will end when the AI approaches to you. The area of the AI starts at 1 km and increases by 1 m per second."),
          ),
          ListTile(
            title: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Expanded(
                  child: Text("Number of AI enemies: "),
                ),
                IconButton(
                  icon: const Icon(Icons.remove),
                  onPressed: () {
                    setState(() {
                      if (_enemies.length > 1) {
                        _enemies.removeLast();
                      }
                    });
                  },
                ),
                Text('${_enemies.length}'),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () {
                    setState(() {
                      if (_enemies.length < 7) {
                        _enemies.add({'mode': 'Driving'});
                      }
                    });
                  },
                ),
              ],
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (int index = 0; index < _enemies.length; index++) Row(
                  children: [
                    const SizedBox(width: 10),
                    Column(
                      children: [
                        Text("AI #${index + 1}"),
                        DropdownButton<String>(
                          value: _enemies[index]['mode'].toString(),
                          icon: const Icon(Icons.arrow_downward),
                          style: const TextStyle(color: Colors.deepPurple),
                          underline: Container(
                            height: 2,
                            color: Colors.deepPurpleAccent,
                          ),
                          onChanged: (String? value) {
                            // This is called when the user selects an item.
                            setState(() {
                              _enemies[index]['mode'] = value!;
                            });
                          },
                          items: dropDownList.map<DropdownMenuItem<String>>((String value) {
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Text(value),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                    const SizedBox(width: 10),
                  ],
                ),
              ],
            ),
          ),
          ListTile(
            title: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Expanded(
                  child: Text("Initial distance of enemies (km): "),
                ),
                IconButton(
                  icon: const Icon(Icons.remove),
                  onPressed: () {
                    setState(() {
                      if (_distance > 10) {
                        _distance--;
                      }
                    });
                  },
                ),
                Text('$_distance'),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () {
                    setState(() {
                      if (_distance < 200) {
                        _distance++;
                      }
                    });
                  },
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(8),
        child: Row(
          children: [
            Expanded(
              child: ElevatedButton(
                style: ButtonStyle(
                  backgroundColor: WidgetStateProperty.all<Color>(Theme.of(context).primaryColor),
                ),
                onPressed: () async {
                  for (int i = 0; i < _enemies.length; i++) {
                    _enemies[i]['coord'] = generateRandomLatLng(widget.lat, widget.long, _distance.toDouble());
                    _enemies[i]['route'] = [];
                  }

                  if (context.mounted) {
                    Navigator.pop(context, _enemies);
                  }
                },
                child: const Text('Set',
                    style: TextStyle(fontSize: 20.0, color: Colors.white)),
              ),
            ),
          ],
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
}

Map<String, double> generateRandomLatLng(double lat, double long, double radiusInKiloMeters) {
  final random = Random();
  final psi1 = lat * (pi / 180); // 라디안으로 변환
  final lambda1 = long * (pi / 180);

  // 임의의 방향과 거리 생성
  final brng = random.nextDouble() * 2 * pi;
  final dr = radiusInKiloMeters / 6371; // 지구 반지름은 약 6371km

  // 하버사인 공식 이용
  final sinpsi2 = sin(psi1) * cos(dr) + cos(psi1) * sin(dr) * cos(brng);
  final psi2 = asin(sinpsi2);
  final lambda2 = lambda1 + atan2(sin(brng) * sin(dr) * cos(psi1), cos(dr) - sin(psi1) * sin(psi2));

  // 라디안을 도로 변환
  return {'lat': psi2 * (180 / pi), 'long': lambda2 * (180 / pi)};
}

double calculateDistance(double startLat, double startLong, double endLat, double endLong) {
  const R = 6371e3; // 지구 반지름 (미터)

  final psi1 = startLat * (pi / 180);
  final psi2 = endLat * (pi / 180);
  final deltaPsi = (endLat - startLat) * (pi / 180);
  final deltaLambda = (endLong - startLong) * (pi / 180);

  final a = sin(deltaPsi/2) * sin(deltaPsi/2) +
            cos(psi1) * cos(psi2) *
            sin(deltaLambda/2) * sin(deltaLambda/2);
  final c = 2 * atan2(sqrt(a), sqrt(1-a));

  return R * c;
}
