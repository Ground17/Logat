import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';

import '../../utils/gemini_api.dart';
import '../../utils/maps_api.dart';
import '../../utils/structure.dart';


class AddEditPostScreen extends StatefulWidget {
  const AddEditPostScreen({Key? key, required this.logData}) : super(key: key);

  final List<Map<String, Object>> logData;
  @override
  _AddEditPostState createState() => _AddEditPostState();
}
// state.uri.queryParameters['data'] = [{postId: '', ...}, {postId: "asdf", ...}]

enum AddEditMode {
  Add, Edit
}

class _AddEditPostState extends State<AddEditPostScreen> {
  final List<TextEditingController> _titleControllers = [];
  final List<TextEditingController> _descriptionControllers = [];
  final List<TextEditingController> _addressControllers = [];

  var screenMode = AddEditMode.Add;

  List<LocData> _logData = [];

  @override
  void initState() {
    super.initState();

    for (int i = 0; i < widget.logData.length; i++) {
      _logData.add(LocData.fromJson(widget.logData[i]));
      _titleControllers.add(TextEditingController());
      _descriptionControllers.add(TextEditingController());
      _addressControllers.add(TextEditingController());
    }

    for (int i = 0; i < widget.logData.length; i++) {
      _titleControllers[i].text = widget.logData[i]['title'] as String;
      _descriptionControllers[i].text = widget.logData[i]['description'] as String;
      _addressControllers[i].text = widget.logData[i]['address'] as String;
    }
  }

  @override
  void dispose() {
    for (final c in _titleControllers) {
      c.dispose();
    }
    for (final c in _descriptionControllers) {
      c.dispose();
    }
    for (final c in _addressControllers) {
      c.dispose();
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) async {
        if (didPop) {
          return;
        }
        final bool shouldPop = await showMessageWithCancel("Are you sure you want to leave? Changes will not be saved.", () => {}) ?? false;
        if (context.mounted && shouldPop) {
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Theme.of(context).primaryColor,
          title: const Text('Add Log', style: TextStyle(color: Colors.white),),
        ),
        body: ListView.builder(
          itemCount: _logData.length,
          shrinkWrap: true,
          itemBuilder: (context, index) {
            return Column(
              children: [
                ListTile(
                  isThreeLine: true,
                  leading: Visibility(visible: (_logData[index].path ?? "") != "", child: Image.file(File(_logData[index].path!), width: 50, height: 50),),
                  title: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _titleControllers[index],
                          decoration: const InputDecoration(
                            hintText: 'Title',
                          ),
                          maxLength: 100,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.auto_awesome),
                        onPressed: () async {
                          await showMessageWithCancel("Create text based on what you've written so far. Do you want to continue? Existing title will be erased.", () async {
                            _titleControllers[index].text = "(Loading...)";
                            _titleControllers[index].text = (await getText(type: "title", sub: _descriptionControllers[index].text, date: _logData[index].date ?? "", location: Loc(lat: _logData[index].location?.lat ?? 0, long: _logData[index].location?.lat ?? 0), address: _logData[index].address ?? "", path: _logData[index].path ?? "")) ?? "";
                          });
                        },
                      ),
                    ],
                  ),
                  subtitle: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _descriptionControllers[index],
                              decoration: const InputDecoration(
                                hintText: '(Optional) Description',
                              ),
                              maxLines: 2,
                              maxLength: 3000,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.auto_awesome),
                            onPressed: () async {
                              await showMessageWithCancel("Create text based on what you've written so far. Do you want to continue? Existing description will be erased.", () async {
                                _descriptionControllers[index].text = "(Loading...)";
                                _descriptionControllers[index].text = (await getText(type: "description", sub: _titleControllers[index].text, date: _logData[index].date ?? "", location: Loc(lat: _logData[index].location?.lat ?? 0, long: _logData[index].location?.long ?? 0), address: _logData[index].address ?? "", path: _logData[index].path ?? "")) ?? "";
                              });
                            },
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _addressControllers[index],
                              decoration: const InputDecoration(
                                hintText: '(Optional) Address',
                              ),
                              maxLength: 100,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.search),
                            onPressed: () async {
                              await showMessageWithCancel("Create an address using the given latitude and longitude. Do you want to continue? Existing description will be erased.", () async {
                                _addressControllers[index].text = "(Loading...)";
                                List<Map<String, String>> data = await getReverseGeocoding(_logData[index].location?.lat ?? 0.0, _logData[index].location?.long ?? 0.0);
                                _addressControllers[index].text = data.isNotEmpty ? data[0]['text']! : "";
                              });
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.place, size: 17,),
                      onPressed: () async {
                        final changed = await showMessageWithMap(_logData[index].location?.lat ?? 0, _logData[index].location?.long ?? 0);
                        setState(() {
                          _logData[index].location?.lat = changed?['lat'] ?? 0;
                          _logData[index].location?.long = changed?['long'] ?? 0;
                        });
                      },
                    ),
                    Text("(${_logData[index].location?.lat}, ${_logData[index].location?.long})"),
                  ],
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.date_range, size: 17,),
                      onPressed: () async {
                        DateTime? selectedDate = await showDatePicker(
                          initialDate: DateTime.now(),
                          firstDate: DateTime(1970),
                          lastDate: DateTime(3000),
                          context: context,
                        );

                        TimeOfDay? selectedTime = await showTimePicker(
                          initialTime: TimeOfDay.now(),
                          context: context,
                        );

                        DateTime now = DateTime.now();

                        DateTime newDateTime = DateTime(
                          selectedDate?.year ?? now.year,
                          selectedDate?.month ?? now.month,
                          selectedDate?.day ?? now.day,
                          selectedTime?.hour ?? now.hour,
                          selectedTime?.minute ?? now.minute,
                        );

                        setState(() {
                          _logData[index].date = newDateTime.toIso8601String();
                        });
                      },
                    ),
                    Text("${_logData[index].date}"),
                  ],
                ),
              ],
            );
          }
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
                    final bool shouldPop = await showMessageWithCancel("Do you want to save on local device?", () async {
                      Directory appDocDir = await getApplicationDocumentsDirectory();
                      String appDocPath = appDocDir.path;
                      Box<LocData> box = await Hive.openBox<LocData>('log');

                      for (int i = 0; i < _logData.length; i++) {
                        _logData[i].title = _titleControllers[i].text;
                        _logData[i].description = _descriptionControllers[i].text;
                        _logData[i].address = _addressControllers[i].text;

                        if (_logData[i].key != null) {
                          await box.put(_logData[i].key, _logData[i]);
                          _logData.removeAt(i);
                          i--;
                          continue;
                        }

                        print(_logData[i].path);
                        if (_logData[i].path != null) {
                          try {
                            // 무조건 사진을 어플 디렉토리 내에 저장
                            String? filename = _logData[i].path!.split('/').lastOrNull;
                            File _image = File(_logData[i].path!);

                            if (filename != null) {
                              final file = File('$appDocPath/$filename');

                              // 파일 저장
                              await file.writeAsBytes(_image.readAsBytesSync());

                              _logData[i].path = '$appDocPath/$filename';
                              print('$appDocPath/$filename');
                            }
                          } catch (e) {
                            print(e);
                          }
                        }
                      }

                      if (_logData.isNotEmpty) {
                        await box.addAll(_logData);
                      }

                      print(box.values);
                    }, submit: true) ?? false;

                    if (context.mounted && shouldPop) {
                      Navigator.pop(context, true);
                    }
                  },
                  child: const Text('Save',
                      style: TextStyle(fontSize: 20.0, color: Colors.white)),
                ),
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

  Future<bool?> showMessageWithCancel(String message, Function f, {bool submit = false}) {
    return showDialog<bool?>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        content: Text(message),
        actions: <TextButton>[
          TextButton(
            onPressed: () {
              Navigator.pop(context, false);
            },
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              if (submit) { // submit의 경우 hive 업데이트를 먼저 해야 지도에 바로 반영됨.
                await f();
                Navigator.pop(context, true);
              } else {
                Navigator.pop(context, true);
                await f();
              }
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<Map<String, double>?> showMessageWithMap(double lat, double long) {
    double changedLat = lat; double changedLong = long;
    return showDialog<Map<String, double>?>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text("Select changed place"),
        content: Stack(
          children: [
            GoogleMap(
              mapType: MapType.normal,
              initialCameraPosition: CameraPosition(
                target: LatLng(lat, long),
                zoom: 13.0,
              ),
              onCameraMove: (cameraPosition) {
                changedLat = cameraPosition.target.latitude;
                changedLong = cameraPosition.target.longitude;
              },
              myLocationEnabled: true,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
            ),
            const Positioned(
              top: 0.0,
              left: 0.0,
              right: 0.0,
              bottom: 0.0,
              child: Icon(
                color: Colors.blue,
                Icons.circle,
                size: 10.0,
              ),
            ),
          ],
        ),
        actions: <TextButton>[
          TextButton(
            onPressed: () {
              Navigator.pop(context, {"lat": lat, "long": long});
            },
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context, {"lat": changedLat, "long": changedLong});
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}