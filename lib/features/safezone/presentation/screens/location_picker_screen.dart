/*
 * Guardian 2.0 - Women's Safety App
 * © 2025 All Rights Reserved - Kunal Singh
 * 
 * Location Picker Screen - Select any location on the OpenStreetMap
 */

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:guardian/app/theme/app_theme.dart';
import 'package:guardian/core/providers/location_provider.dart';
import 'package:geocoding/geocoding.dart';

/// Result from the location picker
class PickedLocation {
  final double latitude;
  final double longitude;
  final String? address;

  const PickedLocation({
    required this.latitude,
    required this.longitude,
    this.address,
  });
}

/// Location picker screen for selecting a location on the map
class LocationPickerScreen extends ConsumerStatefulWidget {
  final LatLng? initialLocation;
  final String title;

  const LocationPickerScreen({
    super.key,
    this.initialLocation,
    this.title = 'Select Location',
  });

  @override
  ConsumerState<LocationPickerScreen> createState() =>
      _LocationPickerScreenState();
}

class _LocationPickerScreenState extends ConsumerState<LocationPickerScreen> {
  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();
  LatLng? _selectedLocation;
  String? _address;
  bool _isLoadingAddress = false;
  bool _isSearching = false;
  List<Location> _searchResults = [];
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _selectedLocation = widget.initialLocation;
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final locationState = ref.watch(locationProvider);

    // Default to current location or a fallback
    final initialPosition = widget.initialLocation ??
        (locationState.hasLocation
            ? LatLng(locationState.position!.latitude,
                locationState.position!.longitude)
            : const LatLng(18.5204, 73.8567)); // Pune fallback

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          if (_selectedLocation != null)
            TextButton(
              onPressed: _confirmLocation,
              child: const Text('CONFIRM',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Container(
            padding: const EdgeInsets.all(12),
            color: Theme.of(context).scaffoldBackgroundColor,
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search for a place or address',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchResults = [];
                          });
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.white,
              ),
              onChanged: _onSearchChanged,
            ),
          ),

          // Search results or map
          Expanded(
            child: Stack(
              children: [
                // OpenStreetMap
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: initialPosition,
                    initialZoom: 15,
                    onTap: (tapPosition, point) => _onMapTapped(point),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.company.guardian',
                    ),
                    if (_selectedLocation != null)
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: _selectedLocation!,
                            width: 44,
                            height: 44,
                            child: const Icon(
                              Icons.location_pin,
                              color: Colors.pink,
                              size: 40,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),

                // Search results overlay
                if (_searchResults.isNotEmpty || _isSearching)
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      constraints: const BoxConstraints(maxHeight: 250),
                      margin: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: const [
                          BoxShadow(color: Colors.black26, blurRadius: 4)
                        ],
                      ),
                      child: _isSearching
                          ? const Center(
                              child: Padding(
                                padding: EdgeInsets.all(16),
                                child: CircularProgressIndicator(),
                              ),
                            )
                          : ListView.builder(
                              shrinkWrap: true,
                              itemCount: _searchResults.length,
                              itemBuilder: (context, index) {
                                final location = _searchResults[index];
                                return ListTile(
                                  leading: const Icon(Icons.location_on),
                                  title: Text(_searchController.text),
                                  subtitle: Text(
                                    '${location.latitude.toStringAsFixed(5)}, ${location.longitude.toStringAsFixed(5)}',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  onTap: () => _selectSearchResult(location),
                                );
                              },
                            ),
                    ),
                  ),

                // Center marker hint
                if (_selectedLocation == null && _searchResults.isEmpty)
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.touch_app,
                            size: 48,
                            color: AppColors.primary.withValues(alpha: 0.7)),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: const [
                              BoxShadow(color: Colors.black26, blurRadius: 4)
                            ],
                          ),
                          child: const Text('Search or tap on the map'),
                        ),
                      ],
                    ),
                  ),

                // Current location button
                Positioned(
                  right: 16,
                  bottom: _selectedLocation != null ? 180 : 16,
                  child: FloatingActionButton.small(
                    heroTag: 'current_location',
                    onPressed: locationState.hasLocation
                        ? () => _moveToLocation(
                              LatLng(locationState.position!.latitude,
                                  locationState.position!.longitude),
                            )
                        : null,
                    child: const Icon(Icons.my_location),
                  ),
                ),

                // Bottom info card
                if (_selectedLocation != null)
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 16,
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.location_on,
                                    color: AppColors.primary),
                                const SizedBox(width: 8),
                                const Text(
                                  'Selected Location',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            if (_isLoadingAddress)
                              const Row(
                                children: [
                                  SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2)),
                                  SizedBox(width: 8),
                                  Text('Getting address...'),
                                ],
                              )
                            else if (_address != null)
                              Text(_address!,
                                  style: TextStyle(color: Colors.grey[600]))
                            else
                              Text(
                                '${_selectedLocation!.latitude.toStringAsFixed(6)}, ${_selectedLocation!.longitude.toStringAsFixed(6)}',
                                style: TextStyle(
                                    color: Colors.grey[600],
                                    fontFamily: 'monospace'),
                              ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: _confirmLocation,
                                icon: const Icon(Icons.check),
                                label: const Text('Use This Location'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _onSearchChanged(String query) {
    _searchDebounce?.cancel();

    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() => _isSearching = true);

    _searchDebounce = Timer(const Duration(milliseconds: 800), () async {
      try {
        final locations = await locationFromAddress(query);
        if (mounted) {
          setState(() {
            _searchResults = locations;
            _isSearching = false;
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _searchResults = [];
            _isSearching = false;
          });
        }
      }
    });
  }

  void _selectSearchResult(Location location) {
    final position = LatLng(location.latitude, location.longitude);
    setState(() {
      _searchResults = [];
    });
    _searchController.clear();
    _moveToLocation(position);
  }

  void _onMapTapped(LatLng position) {
    setState(() {
      _selectedLocation = position;
      _address = null;
      _searchResults = [];
    });
    _searchController.clear();
    _getAddressFromLatLng(position);
  }

  Future<void> _getAddressFromLatLng(LatLng position) async {
    setState(() => _isLoadingAddress = true);

    try {
      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty && mounted) {
        final place = placemarks.first;
        final addressParts = <String>[];

        if (place.name != null && place.name!.isNotEmpty)
          addressParts.add(place.name!);
        if (place.subLocality != null && place.subLocality!.isNotEmpty)
          addressParts.add(place.subLocality!);
        if (place.locality != null && place.locality!.isNotEmpty)
          addressParts.add(place.locality!);
        if (place.administrativeArea != null &&
            place.administrativeArea!.isNotEmpty) {
          addressParts.add(place.administrativeArea!);
        }

        setState(() {
          _address = addressParts.take(3).join(', ');
        });
      }
    } catch (e) {
      // Silently fail - just use coordinates
    } finally {
      if (mounted) setState(() => _isLoadingAddress = false);
    }
  }

  void _moveToLocation(LatLng position) {
    try {
      _mapController.move(position, 16);
    } catch (_) {}
    _onMapTapped(position);
  }

  void _confirmLocation() {
    if (_selectedLocation != null) {
      Navigator.pop(
        context,
        PickedLocation(
          latitude: _selectedLocation!.latitude,
          longitude: _selectedLocation!.longitude,
          address: _address,
        ),
      );
    }
  }
}
