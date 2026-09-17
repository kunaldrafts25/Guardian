/*
 * Guardian 2.0 - Women's Safety App
 * © 2025 All Rights Reserved - Kunal Singh
 * 
 * Places Search Service - OpenStreetMap Nominatim (Free, No API key needed)
 */

import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'package:guardian/core/utils/logger.dart';

/// A place prediction / result
class PlacePrediction {
  final String placeId;
  final String description;
  final String mainText;
  final String? secondaryText;
  final LatLng? location;

  const PlacePrediction({
    required this.placeId,
    required this.description,
    required this.mainText,
    this.secondaryText,
    this.location,
  });

  factory PlacePrediction.fromOsmJson(Map<String, dynamic> json) {
    final displayName = json['display_name'] as String? ?? '';
    final parts = displayName.split(',');
    final main = parts.isNotEmpty ? parts.first.trim() : displayName;
    final sec = parts.length > 1 ? parts.sublist(1).join(',').trim() : null;
    final lat = double.tryParse(json['lat']?.toString() ?? '');
    final lon = double.tryParse(json['lon']?.toString() ?? '');

    return PlacePrediction(
      placeId: json['place_id']?.toString() ??
          DateTime.now().microsecondsSinceEpoch.toString(),
      description: displayName,
      mainText: main,
      secondaryText: sec,
      location: (lat != null && lon != null) ? LatLng(lat, lon) : null,
    );
  }
}

/// Place details with coordinates
class PlaceDetails {
  final String placeId;
  final String name;
  final String address;
  final LatLng location;

  const PlaceDetails({
    required this.placeId,
    required this.name,
    required this.address,
    required this.location,
  });
}

/// Places search state
class PlacesSearchState {
  final bool isSearching;
  final List<PlacePrediction> predictions;
  final String? errorMessage;
  final PlaceDetails? selectedPlace;
  final bool isLoadingDetails;

  const PlacesSearchState({
    this.isSearching = false,
    this.predictions = const [],
    this.errorMessage,
    this.selectedPlace,
    this.isLoadingDetails = false,
  });

  PlacesSearchState copyWith({
    bool? isSearching,
    List<PlacePrediction>? predictions,
    String? errorMessage,
    PlaceDetails? selectedPlace,
    bool? isLoadingDetails,
  }) {
    return PlacesSearchState(
      isSearching: isSearching ?? this.isSearching,
      predictions: predictions ?? this.predictions,
      errorMessage: errorMessage,
      selectedPlace: selectedPlace ?? this.selectedPlace,
      isLoadingDetails: isLoadingDetails ?? this.isLoadingDetails,
    );
  }
}

/// Places search notifier using OpenStreetMap Nominatim (Free, no quota limits)
class PlacesSearchNotifier extends StateNotifier<PlacesSearchState> {
  PlacesSearchNotifier() : super(const PlacesSearchState());

  /// Search for places using OSM Nominatim API
  Future<void> searchPlaces(String query, {LatLng? location}) async {
    if (query.trim().isEmpty) {
      state = state.copyWith(predictions: [], isSearching: false);
      return;
    }

    state = state.copyWith(isSearching: true, errorMessage: null);

    try {
      var urlStr = 'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(query)}&format=json&addressdetails=1&limit=6';

      if (location != null) {
        // Bias search to near user
        final left = location.longitude - 0.5;
        final right = location.longitude + 0.5;
        final top = location.latitude + 0.5;
        final bottom = location.latitude - 0.5;
        urlStr += '&viewbox=$left,$top,$right,$bottom';
      }

      final response = await http.get(
        Uri.parse(urlStr),
        headers: {
          'User-Agent': 'GuardianSafetyApp/2.0 (contact@guardian-safety.app)',
          'Accept-Language': 'en',
        },
      ).timeout(const Duration(seconds: 6));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        final predictions = data
            .map((p) => PlacePrediction.fromOsmJson(p as Map<String, dynamic>))
            .toList();

        state = state.copyWith(
          predictions: predictions,
          isSearching: false,
        );
      } else {
        state = state.copyWith(isSearching: false, predictions: []);
      }
    } catch (e) {
      Logger.warning('OSM Places search error: $e');
      state = state.copyWith(
        isSearching: false,
        errorMessage: 'Search offline or unavailable',
      );
    }
  }

  /// Get place details including coordinates
  Future<PlaceDetails?> getPlaceDetails(String placeId, {PlacePrediction? prediction}) async {
    state = state.copyWith(isLoadingDetails: true, errorMessage: null);

    try {
      // If we already have coordinates from prediction, use it directly
      if (prediction != null && prediction.location != null) {
        final details = PlaceDetails(
          placeId: prediction.placeId,
          name: prediction.mainText,
          address: prediction.description,
          location: prediction.location!,
        );
        state = state.copyWith(
          selectedPlace: details,
          isLoadingDetails: false,
        );
        return details;
      }

      // Query Nominatim lookup
      final url = 'https://nominatim.openstreetmap.org/lookup?osm_ids=N$placeId,W$placeId,R$placeId&format=json';
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'User-Agent': 'GuardianSafetyApp/2.0 (contact@guardian-safety.app)',
        },
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        if (data.isNotEmpty) {
          final first = data[0];
          final lat = double.parse(first['lat']);
          final lon = double.parse(first['lon']);
          final details = PlaceDetails(
            placeId: placeId,
            name: first['name'] ?? first['display_name'],
            address: first['display_name'],
            location: LatLng(lat, lon),
          );
          state = state.copyWith(
            selectedPlace: details,
            isLoadingDetails: false,
          );
          return details;
        }
      }

      state = state.copyWith(isLoadingDetails: false);
      return null;
    } catch (e) {
      Logger.error('Place details error', e);
      state = state.copyWith(
        isLoadingDetails: false,
        errorMessage: e.toString(),
      );
      return null;
    }
  }

  /// Clear search results
  void clearSearch() {
    state = const PlacesSearchState();
  }
}

/// Places search provider
final placesSearchProvider = StateNotifierProvider<PlacesSearchNotifier, PlacesSearchState>((ref) {
  return PlacesSearchNotifier();
});
