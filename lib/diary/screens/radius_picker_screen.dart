import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../models/location_filter.dart';

class RadiusPickerScreen extends StatefulWidget {
  const RadiusPickerScreen({super.key, this.initialFilter});

  final LocationFilter? initialFilter;

  @override
  State<RadiusPickerScreen> createState() => _RadiusPickerScreenState();
}

class _RadiusPickerScreenState extends State<RadiusPickerScreen> {
  late LatLng _center;
  late double _radiusKm;

  @override
  void initState() {
    super.initState();
    if (widget.initialFilter != null) {
      _center =
          LatLng(widget.initialFilter!.latitude, widget.initialFilter!.longitude);
      _radiusKm = widget.initialFilter!.radiusKm;
    } else {
      _center = const LatLng(37.5665, 126.9780);
      _radiusKm = 5.0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('위치 반경 설정'),
        actions: [
          TextButton(
            onPressed: () {
              final filter = LocationFilter(
                label:
                    '${_center.latitude.toStringAsFixed(3)}, ${_center.longitude.toStringAsFixed(3)} · ${_radiusKm.toStringAsFixed(0)}km',
                latitude: _center.latitude,
                longitude: _center.longitude,
                radiusKm: _radiusKm,
              );
              Navigator.pop(context, filter);
            },
            child: const Text('확인'),
          ),
        ],
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _center,
              zoom: _zoomForRadius(_radiusKm),
            ),
            onTap: (latLng) => setState(() => _center = latLng),
            markers: {
              Marker(
                markerId: const MarkerId('center'),
                position: _center,
              ),
            },
            circles: {
              Circle(
                circleId: const CircleId('radius'),
                center: _center,
                radius: _radiusKm * 1000,
                fillColor: Colors.blue.withValues(alpha: 0.15),
                strokeColor: Colors.blue,
                strokeWidth: 2,
              ),
            },
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('반경: ${_radiusKm.toStringAsFixed(1)} km'),
                    Slider(
                      value: _radiusKm,
                      min: 1,
                      max: 50,
                      divisions: 49,
                      label: '${_radiusKm.toStringAsFixed(0)} km',
                      onChanged: (v) => setState(() => _radiusKm = v),
                    ),
                    Text(
                      '지도를 탭해서 중심 위치를 선택하세요',
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                    const SizedBox(height: 4),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  double _zoomForRadius(double radiusKm) {
    if (radiusKm <= 2) return 13;
    if (radiusKm <= 5) return 11;
    if (radiusKm <= 15) return 9;
    if (radiusKm <= 30) return 8;
    return 7;
  }
}
