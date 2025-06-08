/*
 * Guardian - Women's Safety App
 * © 2025 All Rights Reserved - Kunal Singh
 * Contact: kunalsingh2514@gmail.com
 */

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:guardian/core/constants/app_colors.dart';
import 'package:guardian/core/constants/app_typography.dart';
import 'package:guardian/core/di/service_locator.dart';
import 'package:guardian/core/utils/logger.dart';
import 'package:guardian/core/widgets/custom_app_bar.dart';
import 'package:guardian/core/widgets/loading_indicator.dart';
import 'package:guardian/features/safe_zones/data/models/safe_zone_model.dart';
import 'package:guardian/features/safe_zones/data/safe_zone_repository.dart';
import 'package:guardian/features/safe_zones/presentation/screens/add_rating_screen.dart';
import 'package:guardian/features/safe_zones/presentation/widgets/rating_card.dart';
import 'package:guardian/features/safe_zones/presentation/widgets/safety_stats_card.dart';
import 'package:intl/intl.dart';

class SafeZoneDetailsScreen extends StatefulWidget {
  final SafeZone zone;

  const SafeZoneDetailsScreen({
    super.key,
    required this.zone,
  });

  @override
  State<SafeZoneDetailsScreen> createState() => _SafeZoneDetailsScreenState();
}

class _SafeZoneDetailsScreenState extends State<SafeZoneDetailsScreen> {
  final SafeZoneRepository _repository = sl<SafeZoneRepository>();
  final Completer<GoogleMapController> _mapController = Completer();

  late SafeZone _zone;
  bool _isLoading = false;
  bool _isMapReady = false;

  Set<Marker> _markers = {};
  Set<Circle> _circles = {};

  @override
  void initState() {
    super.initState();
    _zone = widget.zone;
    _updateMapMarkers();
  }

  Future<void> _refreshZone() async {
    try {
      setState(() {
        _isLoading = true;
      });

      final zone = await _repository.getSafeZone(_zone.id);

      if (zone != null) {
        setState(() {
          _zone = zone;
        });

        _updateMapMarkers();
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      Logger.error('Failed to refresh zone', e);

      setState(() {
        _isLoading = false;
      });
    }
  }

  void _updateMapMarkers() {
    final zoneLatitude = _zone.location['latitude'] ?? 0.0;
    final zoneLongitude = _zone.location['longitude'] ?? 0.0;
    final position = LatLng(zoneLatitude, zoneLongitude);

    setState(() {
      _markers = {
        Marker(
          markerId: MarkerId(_zone.id),
          position: position,
          infoWindow: InfoWindow(
            title: _zone.name,
            snippet: _zone.description ?? 'Safe zone',
          ),
        ),
      };

      _circles = {
        Circle(
          circleId: CircleId(_zone.id),
          center: position,
          radius: _zone.radius,
          fillColor: _getSafetyColor(_zone.averageRating).withOpacity(0.2),
          strokeColor: _getSafetyColor(_zone.averageRating),
          strokeWidth: 1,
        ),
      };
    });

    if (_isMapReady) {
      _moveToZone();
    }
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController.complete(controller);
    setState(() {
      _isMapReady = true;
    });

    _moveToZone();
  }

  Future<void> _moveToZone() async {
    if (!_isMapReady) return;

    final zoneLatitude = _zone.location['latitude'] ?? 0.0;
    final zoneLongitude = _zone.location['longitude'] ?? 0.0;
    final position = LatLng(zoneLatitude, zoneLongitude);

    final controller = await _mapController.future;
    controller.animateCamera(
      CameraUpdate.newLatLngZoom(position, 15),
    );
  }

  Future<void> _navigateToAddRating() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => AddRatingScreen(zoneId: _zone.id),
      ),
    );

    if (result == true) {
      await _refreshZone();
    }
  }

  Color _getSafetyColor(double rating) {
    if (rating >= 4.0) {
      return Colors.green;
    } else if (rating >= 3.0) {
      return Colors.lightGreen;
    } else if (rating >= 2.0) {
      return Colors.yellow;
    } else if (rating >= 1.0) {
      return Colors.orange;
    } else {
      return Colors.red;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: _zone.name,
      ),
      body: _isLoading
          ? const Center(child: LoadingIndicator())
          : _buildContent(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _navigateToAddRating,
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.rate_review),
        label: const Text('Add Rating'),
      ),
    );
  }

  Widget _buildContent() {
    return Column(
      children: [
        // Map
        SizedBox(
          height: 200,
          child: GoogleMap(
            initialCameraPosition: CameraPosition(
              target: LatLng(
                _zone.location['latitude'] ?? 0.0,
                _zone.location['longitude'] ?? 0.0,
              ),
              zoom: 15,
            ),
            onMapCreated: _onMapCreated,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            mapToolbarEnabled: false,
            zoomControlsEnabled: false,
            markers: _markers,
            circles: _circles,
          ),
        ),

        // Zone Details
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Zone Info
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _zone.name,
                                  style: AppTypography.heading3,
                                ),
                                if (_zone.address != null) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    _zone.address!,
                                    style: AppTypography.caption.copyWith(
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          if (_zone.isVerified)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.success.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: AppColors.success),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.verified,
                                    size: 16,
                                    color: AppColors.success,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Verified',
                                    style: AppTypography.caption.copyWith(
                                      color: AppColors.success,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                      if (_zone.description != null) ...[
                        const SizedBox(height: 16),
                        Text(
                          _zone.description!,
                          style: AppTypography.bodyLarge,
                        ),
                      ],
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _zone.tags.map((tag) {
                          return Chip(
                            label: Text(tag),
                            backgroundColor: AppColors.primary.withOpacity(0.1),
                            labelStyle: AppTypography.caption.copyWith(
                              color: AppColors.primary,
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Created on ${DateFormat('MMM dd, yyyy').format(_zone.createdAt)}',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),

                const Divider(),

                // Safety Stats
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: SafetyStatsCard(
                    averageRating: _zone.averageRating,
                    ratingCount: _zone.ratings.length,
                    timeContext: _zone.predominantTimeContext,
                  ),
                ),

                const Divider(),

                // Ratings
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text(
                    'Ratings & Reviews',
                    style: AppTypography.heading4.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

                _zone.ratings.isEmpty
                    ? _buildEmptyRatings()
                    : ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(16),
                        itemCount: _zone.ratings.length,
                        itemBuilder: (context, index) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: RatingCard(
                              rating: _zone.ratings[index],
                            ),
                          );
                        },
                      ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyRatings() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.rate_review_outlined,
              size: 64,
              color: AppColors.primary,
            ),
            const SizedBox(height: 16),
            Text(
              'No Ratings Yet',
              style: AppTypography.heading4.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Be the first to rate this safe zone',
              style: AppTypography.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _navigateToAddRating,
              icon: const Icon(Icons.star),
              label: const Text('Add Rating'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
