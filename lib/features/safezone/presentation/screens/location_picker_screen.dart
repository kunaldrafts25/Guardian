import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geocoding/geocoding.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmaps;
import 'package:guardian/app/theme/app_theme.dart';
import 'package:guardian/core/providers/location_provider.dart';
import 'package:guardian/core/services/places_search_service.dart';
import 'package:latlong2/latlong.dart';

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
  gmaps.GoogleMapController? _mapController;
  final TextEditingController _searchController = TextEditingController();
  LatLng? _selectedLocation;
  String? _address;
  bool _isLoadingAddress = false;
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _selectedLocation = widget.initialLocation;
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final locationState = ref.watch(locationProvider);
    final searchState = ref.watch(placesSearchProvider);
    final initialPosition = widget.initialLocation ??
        (locationState.hasLocation
            ? LatLng(
                locationState.position!.latitude,
                locationState.position!.longitude,
              )
            : const LatLng(18.5204, 73.8567));

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          if (_selectedLocation != null)
            TextButton(
              onPressed: _confirmLocation,
              child: const Text(
                'CONFIRM',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
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
                          ref.read(placesSearchProvider.notifier).clearSearch();
                          setState(() {});
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
              ),
              onChanged: _onSearchChanged,
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                gmaps.GoogleMap(
                  initialCameraPosition: gmaps.CameraPosition(
                    target: gmaps.LatLng(
                      initialPosition.latitude,
                      initialPosition.longitude,
                    ),
                    zoom: 15,
                  ),
                  onMapCreated: (controller) => _mapController = controller,
                  onTap: (point) => _onMapTapped(
                    LatLng(point.latitude, point.longitude),
                  ),
                  myLocationEnabled: locationState.hasLocation,
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: false,
                  mapToolbarEnabled: false,
                  markers: {
                    if (_selectedLocation != null)
                      gmaps.Marker(
                        markerId: const gmaps.MarkerId('selected-safe-zone'),
                        position: gmaps.LatLng(
                          _selectedLocation!.latitude,
                          _selectedLocation!.longitude,
                        ),
                        infoWindow: gmaps.InfoWindow(
                          title: _address ?? 'Selected location',
                        ),
                      ),
                  },
                ),
                if (searchState.predictions.isNotEmpty ||
                    searchState.isSearching ||
                    searchState.errorMessage != null)
                  Positioned(
                    top: 0,
                    left: 12,
                    right: 12,
                    child: Material(
                      elevation: 4,
                      borderRadius: BorderRadius.circular(10),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 280),
                        child: searchState.isSearching
                            ? const Padding(
                                padding: EdgeInsets.all(20),
                                child: Center(
                                  child: CircularProgressIndicator(),
                                ),
                              )
                            : searchState.errorMessage != null &&
                                    searchState.predictions.isEmpty
                                ? Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Text(searchState.errorMessage!),
                                  )
                                : ListView.builder(
                                    shrinkWrap: true,
                                    itemCount: searchState.predictions.length,
                                    itemBuilder: (context, index) {
                                      final prediction =
                                          searchState.predictions[index];
                                      return ListTile(
                                        leading: const Icon(Icons.location_on),
                                        title: Text(prediction.mainText),
                                        subtitle: prediction.secondaryText ==
                                                null
                                            ? null
                                            : Text(
                                                prediction.secondaryText!,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                        onTap: () =>
                                            _selectPrediction(prediction),
                                      );
                                    },
                                  ),
                      ),
                    ),
                  ),
                if (_selectedLocation == null &&
                    searchState.predictions.isEmpty &&
                    !searchState.isSearching)
                  Center(
                    child: IgnorePointer(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.touch_app,
                            size: 48,
                            color: AppColors.primary.withValues(alpha: 0.7),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: const [
                                BoxShadow(
                                  color: Colors.black26,
                                  blurRadius: 4,
                                )
                              ],
                            ),
                            child: const Text('Search or tap on the map'),
                          ),
                        ],
                      ),
                    ),
                  ),
                Positioned(
                  right: 16,
                  bottom: _selectedLocation != null ? 180 : 16,
                  child: FloatingActionButton.small(
                    heroTag: 'current_location',
                    onPressed: locationState.hasLocation
                        ? () => _moveToLocation(
                              LatLng(
                                locationState.position!.latitude,
                                locationState.position!.longitude,
                              ),
                            )
                        : null,
                    child: const Icon(Icons.my_location),
                  ),
                ),
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
                                Icon(
                                  Icons.location_on,
                                  color: AppColors.primary,
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  'Selected Location',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
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
                                      strokeWidth: 2,
                                    ),
                                  ),
                                  SizedBox(width: 8),
                                  Text('Getting address...'),
                                ],
                              )
                            else if (_address != null)
                              Text(_address!)
                            else
                              Text(
                                '${_selectedLocation!.latitude.toStringAsFixed(6)}, '
                                '${_selectedLocation!.longitude.toStringAsFixed(6)}',
                                style: const TextStyle(
                                  fontFamily: 'monospace',
                                ),
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
    if (query.trim().length < 2) {
      ref.read(placesSearchProvider.notifier).clearSearch();
      setState(() {});
      return;
    }
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      final current = ref.read(locationProvider).position;
      ref.read(placesSearchProvider.notifier).searchPlaces(
            query,
            location: current == null
                ? null
                : LatLng(current.latitude, current.longitude),
          );
    });
    setState(() {});
  }

  Future<void> _selectPrediction(PlacePrediction prediction) async {
    final details = await ref
        .read(placesSearchProvider.notifier)
        .getPlaceDetails(prediction.placeId, prediction: prediction);
    if (!mounted || details == null) return;
    _searchController.clear();
    ref.read(placesSearchProvider.notifier).clearSearch();
    setState(() {
      _selectedLocation = details.location;
      _address = details.address.isEmpty ? details.name : details.address;
    });
    await _moveCamera(details.location, 16);
  }

  void _onMapTapped(LatLng position) {
    ref.read(placesSearchProvider.notifier).clearSearch();
    _searchController.clear();
    setState(() {
      _selectedLocation = position;
      _address = null;
    });
    unawaited(_getAddressFromLatLng(position));
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
        final parts = <String>[
          if (place.name?.isNotEmpty == true) place.name!,
          if (place.subLocality?.isNotEmpty == true) place.subLocality!,
          if (place.locality?.isNotEmpty == true) place.locality!,
          if (place.administrativeArea?.isNotEmpty == true)
            place.administrativeArea!,
        ];
        setState(() => _address = parts.take(3).join(', '));
      }
    } catch (_) {
      // Coordinates remain usable if platform reverse geocoding is unavailable.
    } finally {
      if (mounted) setState(() => _isLoadingAddress = false);
    }
  }

  Future<void> _moveCamera(LatLng position, double zoom) async {
    await _mapController?.animateCamera(
      gmaps.CameraUpdate.newLatLngZoom(
        gmaps.LatLng(position.latitude, position.longitude),
        zoom,
      ),
    );
  }

  void _moveToLocation(LatLng position) {
    setState(() {
      _selectedLocation = position;
      _address = null;
    });
    unawaited(_moveCamera(position, 16));
    unawaited(_getAddressFromLatLng(position));
  }

  void _confirmLocation() {
    final location = _selectedLocation;
    if (location == null) return;
    Navigator.pop(
      context,
      PickedLocation(
        latitude: location.latitude,
        longitude: location.longitude,
        address: _address,
      ),
    );
  }
}
