/*
 * Guardian 2.0 - Women's Safety App
 * © 2025 All Rights Reserved - Kunal Singh
 * 
 * Map Screen - Location display with privacy modes
 */

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:guardian/app/theme/app_theme.dart';
import 'package:guardian/core/models/user_model.dart';
import 'package:guardian/core/models/safe_zone_model.dart';
import 'package:guardian/core/providers/location_provider.dart';
import 'package:guardian/core/providers/safe_zone_provider.dart';
import 'package:guardian/core/providers/safe_route_provider.dart';
import 'package:guardian/core/services/places_search_service.dart';
import 'package:guardian/core/providers/settings_provider.dart' as settings;
import 'package:guardian/app/routes.dart';

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  final MapController _mapController = MapController();
  
  static const LatLng _defaultPosition = LatLng(18.5204, 73.8567); // Default to Pune, India

  @override
  Widget build(BuildContext context) {
    final locationState = ref.watch(locationProvider);
    final locationMode = ref.watch(settings.locationModeProvider);
    final modeInfo = getLocationModeInfo(locationMode);
    final safeZoneState = ref.watch(safeZoneProvider);
    final routeState = ref.watch(safeRouteProvider);
    final routePolylines = ref.watch(routePolylinesProvider);
    final routeMarkers = ref.watch(routeMarkersProvider);

    // Update camera when location changes
    if (locationState.hasLocation) {
      _updateCameraPosition(locationState.position!.latitude, locationState.position!.longitude);
    }

    // Build safe zone circles
    final List<CircleMarker> circles = _buildSafeZoneCircles(safeZoneState);
    
    // Build markers including safe zone centers and route markers
    final List<Marker> markers = [
      ..._buildMarkers(locationState, safeZoneState),
      ...routeMarkers,
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Safety Map'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.read(locationProvider.notifier).refreshLocation();
            },
          ),
          IconButton(
            icon: const Icon(Icons.layers),
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        children: [
          // Location Mode Banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: _getModeColor(locationMode).withOpacity(0.1),
            child: Row(
              children: [
                Icon(_getModeIcon(locationMode), color: _getModeColor(locationMode)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        modeInfo['name'] ?? 'Unknown',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: _getModeColor(locationMode),
                        ),
                      ),
                      Text(
                        modeInfo['description'] ?? '',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () => _showModeSelector(context, ref),
                  child: const Text('Change'),
                ),
              ],
            ),
          ),
          
          // Google Map
          Expanded(
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: locationState.hasLocation
                        ? LatLng(locationState.position!.latitude, locationState.position!.longitude)
                        : _defaultPosition,
                    initialZoom: 15,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.company.guardian',
                    ),
                    CircleLayer(circles: circles),
                    PolylineLayer(polylines: routePolylines),
                    MarkerLayer(markers: markers),
                  ],
                ),
                
                // Bottom info card - show route info or default card
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 16,
                  child: routeState.hasRoute
                      ? _buildRouteInfoCard(context, ref, routeState)
                      : _buildDefaultInfoCard(context, ref, safeZoneState),
                ),
                
                // Loading indicator for route
                if (routeState.isLoading)
                  Positioned(
                    top: 16,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                              SizedBox(width: 8),
                              Text('Finding safe route...'),
                            ],
                          ),
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

  Color _getModeColor(LocationMode mode) {
    switch (mode) {
      case LocationMode.ghost:
        return Colors.grey;
      case LocationMode.smart:
        return Colors.blue;
      case LocationMode.guardian:
        return AppColors.guardian;
    }
  }

  IconData _getModeIcon(LocationMode mode) {
    switch (mode) {
      case LocationMode.ghost:
        return Icons.visibility_off;
      case LocationMode.smart:
        return Icons.auto_awesome;
      case LocationMode.guardian:
        return Icons.visibility;
    }
  }

  void _updateCameraPosition(double lat, double lng) {
    try {
      _mapController.move(LatLng(lat, lng), 15);
    } catch (_) {}
  }

  void _showModeSelector(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Location Privacy Mode',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              _buildModeOption(
                context,
                ref,
                LocationMode.ghost,
                'Ghost Mode',
                'Share location only during emergencies',
                Icons.visibility_off,
                Colors.grey,
              ),
              _buildModeOption(
                context,
                ref,
                LocationMode.smart,
                'Smart Mode',
                'Auto-share at night or in risky areas',
                Icons.auto_awesome,
                Colors.blue,
              ),
              _buildModeOption(
                context,
                ref,
                LocationMode.guardian,
                'Guardian Mode',
                'Always visible to trusted contacts',
                Icons.visibility,
                AppColors.guardian,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModeOption(
    BuildContext context,
    WidgetRef ref,
    LocationMode modeValue,
    String title,
    String description,
    IconData icon,
    Color color,
  ) {
    final currentMode = ref.watch(settings.locationModeProvider);
    final isSelected = currentMode == modeValue;
    
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(title),
      subtitle: Text(description),
      trailing: isSelected ? Icon(Icons.check_circle, color: color) : null,
      onTap: () {
        ref.read(settings.locationModeProvider.notifier).setLocationMode(modeValue);
        Navigator.pop(context);
      },
    );
  }

  /// Build the route info card when a route is active
  Widget _buildRouteInfoCard(BuildContext context, WidgetRef ref, SafeRouteState routeState) {
    final route = routeState.currentRoute!;
    
    return Card(
      color: AppColors.success.withValues(alpha: 0.1),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.directions_walk, color: AppColors.success),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Route to ${routeState.destinationName ?? "Destination"}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Row(
                        children: [
                          const Icon(Icons.access_time, size: 14, color: Colors.grey),
                          const SizedBox(width: 4),
                          Text(
                            route.duration,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(width: 12),
                          const Icon(Icons.straighten, size: 14, color: Colors.grey),
                          const SizedBox(width: 4),
                          Text(
                            route.distance,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    ref.read(safeRouteProvider.notifier).clearRoute();
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  // TODO: Start navigation mode
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Navigation mode coming soon!')),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.navigation),
                label: const Text('Start Navigation'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build the default info card (no route active)
  Widget _buildDefaultInfoCard(BuildContext context, WidgetRef ref, SafeZoneState safeZoneState) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.guardian.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.shield, color: AppColors.guardian),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Safe Zones',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        '${safeZoneState.zones.length} zones • ${safeZoneState.isInSafeZone ? "In safe zone" : "Outside zones"}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: safeZoneState.isInSafeZone ? AppColors.success : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showSafeRouteDialog(context),
                    icon: const Icon(Icons.route, size: 18),
                    label: const Text('Safe Route'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => context.push(Routes.safeZones),
                    icon: const Icon(Icons.shield, size: 18),
                    label: const Text('Safe Zones'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Build circles for safe zones visualization
  List<CircleMarker> _buildSafeZoneCircles(SafeZoneState safeZoneState) {
    final circles = <CircleMarker>[];
    
    for (final zone in safeZoneState.zones) {
      if (!zone.isActive) continue;
      
      final isCurrentZone = safeZoneState.currentZone?.id == zone.id;
      
      circles.add(
        CircleMarker(
          point: LatLng(zone.latitude, zone.longitude),
          radius: zone.radius,
          useRadiusInMeter: true,
          color: isCurrentZone 
              ? AppColors.success.withValues(alpha: 0.2)
              : AppColors.primary.withValues(alpha: 0.15),
          borderColor: isCurrentZone ? AppColors.success : AppColors.primary,
          borderStrokeWidth: 2,
        ),
      );
    }
    
    return circles;
  }

  /// Build markers including user location and safe zone centers
  List<Marker> _buildMarkers(LocationState locationState, SafeZoneState safeZoneState) {
    final markers = <Marker>[];
    
    // Add user location marker
    if (locationState.hasLocation) {
      markers.add(
        Marker(
          point: LatLng(locationState.position!.latitude, locationState.position!.longitude),
          width: 44,
          height: 44,
          child: const Icon(
            Icons.my_location,
            color: Colors.blueAccent,
            size: 34,
          ),
        ),
      );
    }
    
    // Add safe zone markers
    for (final zone in safeZoneState.zones) {
      if (!zone.isActive) continue;
      
      final isCurrent = safeZoneState.currentZone?.id == zone.id;
      markers.add(
        Marker(
          point: LatLng(zone.latitude, zone.longitude),
          width: 36,
          height: 36,
          child: Icon(
            Icons.shield,
            color: isCurrent ? AppColors.success : AppColors.primary,
            size: 32,
          ),
        ),
      );
    }
    
    return markers;
  }

  /// Show safe route destination picker dialog
  void _showSafeRouteDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Get Safe Route',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                'Navigate safely with well-lit paths and populated areas',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 16),
              // Quick destinations
              Text(
                'Quick Destinations',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Consumer(
                builder: (context, ref, child) {
                  final zones = ref.watch(safeZoneProvider).zones;
                  final locationState = ref.watch(locationProvider);
                  
                  if (zones.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Column(
                        children: [
                          const Text('No saved locations. Add Safe Zones first.'),
                          const SizedBox(height: 8),
                          TextButton.icon(
                            onPressed: () {
                              Navigator.pop(context);
                              context.push(Routes.safeZones);
                            },
                            icon: const Icon(Icons.add),
                            label: const Text('Add Safe Zone'),
                          ),
                        ],
                      ),
                    );
                  }
                  
                  return Column(
                    children: zones.take(3).map((zone) => ListTile(
                      leading: Icon(_getZoneTypeIcon(zone.type)),
                      title: Text(zone.name),
                      subtitle: Text('${zone.radius.toInt()}m radius'),
                      trailing: const Icon(Icons.directions, color: AppColors.primary),
                      onTap: () {
                        Navigator.pop(context);
                        
                        if (!locationState.hasLocation) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Current location not available')),
                          );
                          return;
                        }
                        
                        // Fetch route using Directions API
                        ref.read(safeRouteProvider.notifier).fetchRoute(
                          origin: LatLng(
                            locationState.position!.latitude,
                            locationState.position!.longitude,
                          ),
                          destination: LatLng(zone.latitude, zone.longitude),
                          destinationName: zone.name,
                        );
                        
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Getting route to ${zone.name}...')),
                        );
                      },
                    )).toList(),
                  );
                },
              ),
              const SizedBox(height: 8),
              const Divider(),
              // Custom destination search
              ListTile(
                leading: const Icon(Icons.search),
                title: const Text('Search destination'),
                subtitle: const Text('Enter an address or place'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  Navigator.pop(context);
                  _showDestinationSearchDialog(context, ref);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getZoneTypeIcon(SafeZoneType type) {
    switch (type) {
      case SafeZoneType.home:
        return Icons.home;
      case SafeZoneType.work:
        return Icons.work;
      case SafeZoneType.school:
        return Icons.school;
      case SafeZoneType.gym:
        return Icons.fitness_center;
      case SafeZoneType.custom:
        return Icons.place;
    }
  }

  /// Show destination search dialog with autocomplete
  void _showDestinationSearchDialog(BuildContext context, WidgetRef ref) {
    final searchController = TextEditingController();
    Timer? debounce;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => Consumer(
          builder: (context, ref, child) {
            final searchState = ref.watch(placesSearchProvider);
            final locationState = ref.watch(locationProvider);

            return Column(
              children: [
                // Handle bar
                Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // Search input
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TextField(
                    controller: searchController,
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: 'Search for a destination',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                searchController.clear();
                                ref.read(placesSearchProvider.notifier).clearSearch();
                              },
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onChanged: (value) {
                      // Debounce search
                      debounce?.cancel();
                      debounce = Timer(const Duration(milliseconds: 500), () {
                        final location = locationState.hasLocation
                            ? LatLng(locationState.position!.latitude, locationState.position!.longitude)
                            : null;
                        ref.read(placesSearchProvider.notifier).searchPlaces(value, location: location);
                      });
                    },
                  ),
                ),
                const SizedBox(height: 8),
                // Results
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    children: [
                      if (searchState.isSearching)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(32),
                            child: CircularProgressIndicator(),
                          ),
                        )
                      else if (searchState.predictions.isEmpty && searchController.text.isNotEmpty)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(32),
                            child: Text('No results found'),
                          ),
                        )
                      else
                        ...searchState.predictions.map((prediction) => ListTile(
                          leading: const Icon(Icons.location_on),
                          title: Text(prediction.mainText),
                          subtitle: prediction.secondaryText != null
                              ? Text(prediction.secondaryText!, maxLines: 1, overflow: TextOverflow.ellipsis)
                              : null,
                          onTap: () async {
                            // Get place details
                            final details = await ref
                                .read(placesSearchProvider.notifier)
                                .getPlaceDetails(prediction.placeId);

                            if (details != null && locationState.hasLocation) {
                              Navigator.pop(context);

                              // Fetch route
                              ref.read(safeRouteProvider.notifier).fetchRoute(
                                origin: LatLng(
                                  locationState.position!.latitude,
                                  locationState.position!.longitude,
                                ),
                                destination: details.location,
                                destinationName: details.name,
                              );

                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Getting route to ${details.name}...')),
                              );
                            }
                          },
                        )),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    ).then((_) {
      // Clean up
      debounce?.cancel();
      searchController.dispose();
    });
  }
}
