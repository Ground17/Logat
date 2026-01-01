import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import '../key.dart';

class LocationPickerScreen extends StatefulWidget {
  final double? initialLatitude;
  final double? initialLongitude;

  const LocationPickerScreen({
    super.key,
    this.initialLatitude,
    this.initialLongitude,
  });

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  GoogleMapController? _mapController;
  LatLng _selectedLocation = const LatLng(37.7749, -122.4194); // Default: San Francisco
  final Set<Marker> _markers = {};
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialLatitude != null && widget.initialLongitude != null) {
      _selectedLocation = LatLng(widget.initialLatitude!, widget.initialLongitude!);
    }
    _updateMarker();
  }

  void _updateMarker() {
    setState(() {
      _markers.clear();
      _markers.add(
        Marker(
          markerId: const MarkerId('selected_location'),
          position: _selectedLocation,
          draggable: true,
          onDragEnd: (newPosition) {
            setState(() {
              _selectedLocation = newPosition;
            });
          },
        ),
      );
    });
  }

  void _onMapTap(LatLng position) {
    setState(() {
      _selectedLocation = position;
    });
    _updateMarker();
  }

  Future<List<AddressOption>> _reverseGeocode() async {
    setState(() => _isLoading = true);

    try {
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/geocode/json?latlng=${_selectedLocation.latitude},${_selectedLocation.longitude}&key=$MAPS_API_KEY&language=en',
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final results = data['results'] as List;

        if (results.isEmpty) {
          return [];
        }

        return results.map((result) {
          return AddressOption(
            address: result['formatted_address'] as String,
            types: List<String>.from(result['types']),
          );
        }).toList();
      }
    } catch (e) {
      print('Reverse geocoding error: $e');
    } finally {
      setState(() => _isLoading = false);
    }

    return [];
  }

  Future<void> _confirmLocation() async {
    final shouldUpdateAddress = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Location Selected'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('GPS Coordinates:', style: TextStyle(fontWeight: FontWeight.bold)),
            Text(
              'Lat: ${_selectedLocation.latitude.toStringAsFixed(6)}\n'
              'Lng: ${_selectedLocation.longitude.toStringAsFixed(6)}',
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 16),
            const Text('Do you want to update the address?'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'keep'),
            child: const Text('Keep Current'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'coords_only'),
            child: const Text('Coords Only'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, 'update'),
            child: const Text('Update Address'),
          ),
        ],
      ),
    );

    if (shouldUpdateAddress == null || shouldUpdateAddress == 'keep') return;

    if (shouldUpdateAddress == 'coords_only') {
      // Return coordinates only, keep existing address
      if (mounted) {
        Navigator.pop(context, {
          'latitude': _selectedLocation.latitude,
          'longitude': _selectedLocation.longitude,
          'address': null,
        });
      }
      return;
    }

    // Get address options
    final addresses = await _reverseGeocode();

    if (addresses.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to get address for this location')),
        );
      }
      return;
    }

    if (!mounted) return;

    // Show address selection dialog
    final selectedAddress = await showDialog<String>(
      context: context,
      builder: (context) => AddressSelectionDialog(addresses: addresses),
    );

    if (selectedAddress != null && mounted) {
      Navigator.pop(context, {
        'latitude': _selectedLocation.latitude,
        'longitude': _selectedLocation.longitude,
        'address': selectedAddress,
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Location'),
        actions: [
          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            TextButton(
              onPressed: _confirmLocation,
              child: const Text(
                'Done',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
      body: GoogleMap(
        initialCameraPosition: CameraPosition(
          target: _selectedLocation,
          zoom: 14,
        ),
        markers: _markers,
        onMapCreated: (controller) {
          _mapController = controller;
        },
        onTap: _onMapTap,
        myLocationEnabled: true,
        myLocationButtonEnabled: true,
        zoomControlsEnabled: true,
      ),
    );
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }
}

class AddressOption {
  final String address;
  final List<String> types;

  AddressOption({
    required this.address,
    required this.types,
  });
}

class AddressSelectionDialog extends StatelessWidget {
  final List<AddressOption> addresses;

  const AddressSelectionDialog({
    super.key,
    required this.addresses,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Select Address'),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: addresses.length,
          itemBuilder: (context, index) {
            final address = addresses[index];
            return ListTile(
              leading: const Icon(Icons.location_on),
              title: Text(address.address),
              subtitle: Text(
                address.types.join(', '),
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
              onTap: () => Navigator.pop(context, address.address),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}
