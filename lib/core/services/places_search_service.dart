/*
 * Guardian - Authenticated Google Places search.
 *
 * Places requests go through the Guardian API so the server-only Google Maps
 * Platform key is never embedded in the mobile client.
 */

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:guardian/core/services/aws_auth_service.dart';
import 'package:guardian/core/utils/logger.dart';
import 'package:latlong2/latlong.dart';
import 'package:uuid/uuid.dart';

class PlacePrediction {
  final String placeId;
  final String description;
  final String mainText;
  final String? secondaryText;
  final int? distanceMeters;

  const PlacePrediction({
    required this.placeId,
    required this.description,
    required this.mainText,
    this.secondaryText,
    this.distanceMeters,
  });

  factory PlacePrediction.fromGuardianJson(Map<String, dynamic> json) {
    return PlacePrediction(
      placeId: json['place_id']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      mainText: json['main_text']?.toString() ?? 'Place',
      secondaryText: json['secondary_text']?.toString(),
      distanceMeters: (json['distance_meters'] as num?)?.round(),
    );
  }
}

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

  factory PlaceDetails.fromGuardianJson(Map<String, dynamic> json) {
    return PlaceDetails(
      placeId: json['place_id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Place',
      address: json['address']?.toString() ?? '',
      location: LatLng(
        (json['latitude'] as num).toDouble(),
        (json['longitude'] as num).toDouble(),
      ),
    );
  }
}

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

class PlacesSearchNotifier extends StateNotifier<PlacesSearchState> {
  PlacesSearchNotifier() : super(const PlacesSearchState());

  String _sessionToken = const Uuid().v4();

  Future<void> searchPlaces(String query, {LatLng? location}) async {
    final trimmed = query.trim();
    if (trimmed.length < 2) {
      state = state.copyWith(predictions: [], isSearching: false);
      return;
    }

    state = state.copyWith(isSearching: true, errorMessage: null);
    try {
      final response = await AwsAuthService.instance.post(
        '/maps/places/autocomplete',
        {
          'query': trimmed,
          'region_code': 'IN',
          'session_token': _sessionToken,
          if (location != null) 'latitude': location.latitude,
          if (location != null) 'longitude': location.longitude,
          if (location != null) 'radius_meters': 30000,
        },
      );
      final raw = response['predictions'];
      final predictions = raw is List
          ? raw
              .whereType<Map>()
              .map(
                (entry) => PlacePrediction.fromGuardianJson(
                  Map<String, dynamic>.from(entry),
                ),
              )
              .where((entry) => entry.placeId.isNotEmpty)
              .toList()
          : <PlacePrediction>[];
      state = state.copyWith(
        predictions: predictions,
        isSearching: false,
        errorMessage: null,
      );
    } catch (error) {
      Logger.warning('Google Places search unavailable: $error');
      state = state.copyWith(
        isSearching: false,
        predictions: const [],
        errorMessage: 'Place search is temporarily unavailable.',
      );
    }
  }

  Future<PlaceDetails?> getPlaceDetails(
    String placeId, {
    PlacePrediction? prediction,
  }) async {
    state = state.copyWith(isLoadingDetails: true, errorMessage: null);
    try {
      final response = await AwsAuthService.instance.post(
        '/maps/places/details',
        {
          'place_id': placeId,
          'session_token': _sessionToken,
        },
      );
      final details = PlaceDetails.fromGuardianJson(response);
      state = state.copyWith(
        selectedPlace: details,
        isLoadingDetails: false,
        errorMessage: null,
      );
      // A details request completes one autocomplete billing/search session.
      _sessionToken = const Uuid().v4();
      return details;
    } catch (error) {
      Logger.warning('Google Place Details unavailable: $error');
      state = state.copyWith(
        isLoadingDetails: false,
        errorMessage: 'Place details are temporarily unavailable.',
      );
      return null;
    }
  }

  void clearSearch() {
    _sessionToken = const Uuid().v4();
    state = const PlacesSearchState();
  }
}

final placesSearchProvider =
    StateNotifierProvider<PlacesSearchNotifier, PlacesSearchState>((ref) {
  return PlacesSearchNotifier();
});
