import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../key.dart';

class AddressSearchField extends StatefulWidget {
  final TextEditingController controller;
  final Function(double lat, double lng, String address)? onLocationSelected;
  final VoidCallback? onClearAll;
  final bool hasCoordinates;

  const AddressSearchField({
    super.key,
    required this.controller,
    this.onLocationSelected,
    this.onClearAll,
    this.hasCoordinates = false,
  });

  @override
  State<AddressSearchField> createState() => _AddressSearchFieldState();
}

class _AddressSearchFieldState extends State<AddressSearchField> {
  List<PlaceResult> _searchResults = [];
  bool _isSearching = false;
  final _debounceTimer = ValueNotifier<int>(0);

  @override
  void dispose() {
    _debounceTimer.dispose();
    super.dispose();
  }

  Future<void> _searchPlaces(String query) async {
    if (query.isEmpty) {
      if (mounted) {
        setState(() {
          _searchResults = [];
          _isSearching = false;
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        _isSearching = true;
      });
    }

    try {
      // New Places API (New) endpoint
      final url = Uri.parse('https://places.googleapis.com/v1/places:autocomplete');

      print('🔍 Searching for: $query');

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'X-Goog-Api-Key': MAPS_API_KEY,
        },
        body: jsonEncode({
          'input': query,
          'languageCode': 'en',
        }),
      );

      print('📡 Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final suggestions = data['suggestions'] as List? ?? [];

        print('✅ Found ${suggestions.length} results');

        if (mounted) {
          setState(() {
            _searchResults = suggestions
                .where((s) => s['placePrediction'] != null)
                .map((s) {
                  final prediction = s['placePrediction'];
                  return PlaceResult(
                    placeId: prediction['placeId'] ?? prediction['place'] ?? '',
                    description: prediction['text']?['text'] ?? '',
                  );
                })
                .where((r) => r.placeId.isNotEmpty && r.description.isNotEmpty)
                .toList();
            _isSearching = false;
          });
        }
      } else {
        print('❌ HTTP Error: ${response.statusCode}');
        print('Response body: ${response.body}');
        if (mounted) {
          setState(() {
            _searchResults = [];
            _isSearching = false;
          });
        }
      }
    } catch (e) {
      print('❌ Address search error: $e');
      if (mounted) {
        setState(() {
          _searchResults = [];
          _isSearching = false;
        });
      }
    }
  }

  Future<void> _getPlaceDetails(String placeId) async {
    try {
      // New Places API (New) endpoint - add 'places/' prefix if not present
      final resourceName = placeId.startsWith('places/') ? placeId : 'places/$placeId';
      final url = Uri.parse('https://places.googleapis.com/v1/$resourceName');

      print('🔍 Getting place details for: $resourceName');

      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'X-Goog-Api-Key': MAPS_API_KEY,
          'X-Goog-FieldMask': 'location,formattedAddress',
        },
      );

      print('📡 Place details response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final location = data['location'];
        final address = data['formattedAddress'];

        print('✅ Got location: $location, address: $address');

        if (location != null && address != null) {
          widget.onLocationSelected?.call(
            location['latitude'],
            location['longitude'],
            address,
          );

          if (mounted) {
            setState(() {
              _searchResults = [];
            });
          }
        }
      } else {
        print('❌ Place details error: ${response.statusCode}');
        print('Response body: ${response.body}');
      }
    } catch (e) {
      print('❌ Place details error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: widget.controller,
          decoration: InputDecoration(
            labelText: 'Location (optional)',
            hintText: 'Search or enter custom location',
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.location_on),
            suffixIcon: _isSearching
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: Padding(
                      padding: EdgeInsets.all(12),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : widget.controller.text.isNotEmpty
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (widget.hasCoordinates)
                            Tooltip(
                              message: 'Has GPS coordinates',
                              child: Icon(
                                Icons.gps_fixed,
                                size: 18,
                                color: Colors.green.shade600,
                              ),
                            ),
                          IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              if (widget.hasCoordinates && widget.onClearAll != null) {
                                // Show confirmation if there are coordinates
                                showDialog<bool>(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text('Clear Location'),
                                    content: const Text(
                                      'This will clear both the address and GPS coordinates. Continue?',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(context, false),
                                        child: const Text('Cancel'),
                                      ),
                                      TextButton(
                                        onPressed: () => Navigator.pop(context, true),
                                        child: const Text('Clear'),
                                      ),
                                    ],
                                  ),
                                ).then((confirmed) {
                                  if (confirmed == true) {
                                    widget.controller.clear();
                                    widget.onClearAll?.call();
                                    setState(() {
                                      _searchResults = [];
                                    });
                                  }
                                });
                              } else {
                                widget.controller.clear();
                                widget.onClearAll?.call();
                                setState(() {
                                  _searchResults = [];
                                });
                              }
                            },
                          ),
                        ],
                      )
                    : null,
          ),
          onChanged: (value) {
            // Debounce search - only search if not manually editing
            Future.delayed(const Duration(milliseconds: 500), () {
              if (widget.controller.text == value) {
                _searchPlaces(value);
              }
            });
          },
        ),
        if (_searchResults.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            constraints: const BoxConstraints(maxHeight: 200),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(4),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _searchResults.length,
              itemBuilder: (context, index) {
                final result = _searchResults[index];
                return ListTile(
                  leading: const Icon(Icons.location_on, size: 20),
                  title: Text(
                    result.description,
                    style: const TextStyle(fontSize: 14),
                  ),
                  dense: true,
                  onTap: () {
                    widget.controller.text = result.description;
                    _getPlaceDetails(result.placeId);
                  },
                );
              },
            ),
          ),
        ],
        if (widget.controller.text.isNotEmpty && !widget.hasCoordinates)
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 12),
            child: Text(
              'Custom location (no GPS coordinates)',
              style: TextStyle(
                fontSize: 11,
                color: Colors.orange.shade700,
              ),
            ),
          ),
      ],
    );
  }
}

class PlaceResult {
  final String placeId;
  final String description;

  PlaceResult({
    required this.placeId,
    required this.description,
  });
}
