/*
 * Guardian 2.0 - Women's Safety App
 * © 2025 All Rights Reserved - Kunal Singh
 * 
 * Places Search Service - Google Places API integration
 */

import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:guardian/core/utils/logger.dart';

/// A place prediction from Places API autocomplete
class PlacePrediction {
  final String placeId;
  final String description;
  final String mainText;
  final String? secondaryText;

  const PlacePrediction({
    required this.placeId,
    required this.description,
    required this.mainText,
    this.secondaryText,
  });

  factory PlacePrediction.fromJson(Map<String, dynamic> json) {
    final structuredFormatting = json['structured_formatting'] as Map<String, dynamic>?;
    return PlacePrediction(
      placeId: json['place_id'] as String,
      description: json['description'] as String,
      mainText: structuredFormatting?['main_text'] as String? ?? json['description'] as String,
      secondaryText: structuredFormatting?['secondary_text'] as String?,
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

/// Places search notifier
class PlacesSearchNotifier extends StateNotifier<PlacesSearchState> {
  PlacesSearchNotifier() : super(const PlacesSearchState());

  String get _apiKey {
    try {
      return dotenv.env['GOOGLE_MAPS_API_KEY_WEB'] ?? '';
    } catch (e) {
      return '';
    }
  }

  /// Search for places using autocomplete
  Future<void> searchPlaces(String query, {LatLng? location}) async {
    if (query.isEmpty) {
      state = state.copyWith(predictions: [], isSearching: false);
      return;
    }

    state = state.copyWith(isSearching: true, errorMessage: null);

    try {
      final apiKey = _apiKey;
      if (apiKey.isEmpty) {
        throw Exception('API key not configured');
      }

      var url = 'https://maps.googleapis.com/maps/api/place/autocomplete/json'
          '?input=${Uri.encodeComponent(query)}'
          '&key=$apiKey';

      // Add location bias if available
      if (location != null) {
        url += '&location=${location.latitude},${location.longitude}'
            '&radius=50000';  // 50km radius
      }

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['status'] == 'OK') {
          final predictions = (data['predictions'] as List)
              .map((p) => PlacePrediction.fromJson(p))
              .toList();
          
          state = state.copyWith(
            predictions: predictions,
            isSearching: false,
          );
        } else if (data['status'] == 'ZERO_RESULTS') {
          state = state.copyWith(predictions: [], isSearching: false);
        } else {
          throw Exception(data['status']);
        }
      } else {
        throw Exception('Failed to search places');
      }
    } catch (e) {
      Logger.error('Places search error', e);
      state = state.copyWith(
        isSearching: false,
        errorMessage: e.toString(),
      );
    }
  }

  /// Get place details including coordinates
  Future<PlaceDetails?> getPlaceDetails(String placeId) async {
    state = state.copyWith(isLoadingDetails: true, errorMessage: null);

    try {
      final apiKey = _apiKey;
      if (apiKey.isEmpty) {
        throw Exception('API key not configured');
      }

      final url = 'https://maps.googleapis.com/maps/api/place/details/json'
          '?place_id=$placeId'
          '&fields=name,formatted_address,geometry'
          '&key=$apiKey';

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['status'] == 'OK') {
          final result = data['result'];
          final location = result['geometry']['location'];
          
          final details = PlaceDetails(
            placeId: placeId,
            name: result['name'] ?? '',
            address: result['formatted_address'] ?? '',
            location: LatLng(location['lat'], location['lng']),
          );
          
          state = state.copyWith(
            selectedPlace: details,
            isLoadingDetails: false,
          );
          
          return details;
        } else {
          throw Exception(data['status']);
        }
      } else {
        throw Exception('Failed to get place details');
      }
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
