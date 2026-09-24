/*
 * Guardian 2.0 - Women's Safety App
 * © 2025 All Rights Reserved - Kunal Singh
 * 
 * Map Screen - Location display with privacy modes & Stitch safe navigation HUD
 */

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:guardian/app/theme/app_theme.dart';
import 'package:guardian/core/models/safe_zone_model.dart';
import 'package:guardian/core/providers/location_provider.dart';
import 'package:guardian/core/providers/safe_zone_provider.dart';
import 'package:guardian/core/providers/safe_route_provider.dart';
import 'package:guardian/core/services/places_search_service.dart';
import 'package:guardian/core/providers/settings_provider.dart' as settings;
import 'package:guardian/app/routes.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:guardian/core/config/map_routing_config.dart';

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  final MapController _mapController = MapController();
  bool _audioNavEnabled = true;
  bool _showDeviationBanner = false;

  static const LatLng _defaultPosition =
      LatLng(18.5204, 73.8567); // Default fallback coordinates

  @override
  Widget build(BuildContext context) {
    final locationState = ref.watch(locationProvider);
    final locationMode = ref.watch(settings.locationModeProvider);
    final modeInfo = getLocationModeInfo(locationMode);
    final safeZoneState = ref.watch(safeZoneProvider);
    final routeState = ref.watch(safeRouteProvider);
    final routePolylines = ref.watch(routePolylinesProvider);
    final routeMarkers = ref.watch(routeMarkersProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Update camera when location changes
    if (locationState.hasLocation) {
      _updateCameraPosition(
          locationState.position!.latitude, locationState.position!.longitude);
    }

    // Build safe zone circles
    final List<CircleMarker> circles = _buildSafeZoneCircles(safeZoneState);

    // Build markers including safe zone centers and route markers
    final List<Marker> markers = [
      ..._buildMarkers(locationState, safeZoneState, isDark),
      ...routeMarkers,
    ];

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Safety Map & Safe Routes',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: -0.2,
              ),
            ),
            Text(
              safeZoneState.isInSafeZone
                  ? 'Safe Zone: ${safeZoneState.currentZone?.name ?? "Protected"}'
                  : 'OpenStreetMap • Offline Cached',
              style: theme.textTheme.bodySmall?.copyWith(
                fontSize: 11,
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondary,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh Location',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {
              ref.read(locationProvider.notifier).refreshLocation();
            },
          ),
          IconButton(
            tooltip: 'Safe Zones',
            icon: const Icon(Icons.shield_outlined),
            onPressed: () => context.push(Routes.safeZones),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Stack(
        children: [
          // OpenStreetMap Full Canvas
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: locationState.hasLocation
                  ? LatLng(locationState.position!.latitude,
                      locationState.position!.longitude)
                  : _defaultPosition,
              initialZoom: 15,
            ),
            children: [
              TileLayer(
                urlTemplate: MapRoutingConfig.tilesUrl,
                userAgentPackageName: 'com.company.guardian',
              ),
              CircleLayer(circles: circles),
              PolylineLayer(polylines: routePolylines),
              MarkerLayer(markers: markers),
            ],
          ),

          // Top Header Overlay: Maneuver Card if navigating, or Floating Privacy Pill if idle
          Positioned(
            top: 14,
            left: 16,
            right: 16,
            child: routeState.hasRoute
                ? _buildManeuverHUDCard(context, ref, routeState, isDark)
                : _buildFloatingModePill(
                    context,
                    ref,
                    locationMode,
                    modeInfo,
                    isDark,
                  ),
          ),

          // Off-Route Deviation Alert Banner (Stitch Screen 11)
          if (routeState.hasRoute && _showDeviationBanner)
            Positioned(
              top: 110,
              left: 16,
              right: 16,
              child: _buildDeviationAlertBanner(context, isDark),
            ),

          // Floating Quick Actions Column (Right Side - Stitch Screen 10)
          if (!routeState.hasRoute)
            Positioned(
              right: 16,
              top: 86,
              child: Column(
                children: [
                  _buildFloatingMapButton(
                    icon: Icons.my_location_rounded,
                    tooltip: 'Recenter to current location',
                    isDark: isDark,
                    onTap: () {
                      if (locationState.hasLocation) {
                        _mapController.move(
                          LatLng(locationState.position!.latitude,
                              locationState.position!.longitude),
                          16,
                        );
                      } else {
                        ref.read(locationProvider.notifier).refreshLocation();
                      }
                    },
                  ),
                  const SizedBox(height: 10),
                  _buildFloatingMapButton(
                    icon: Icons.directions_walk_rounded,
                    tooltip: 'Get Safe Walking Route',
                    isDark: isDark,
                    onTap: () => _showSafeRouteDialog(context),
                  ),
                  const SizedBox(height: 10),
                  _buildFloatingMapButton(
                    icon: Icons.search_rounded,
                    tooltip: 'Search Destination',
                    isDark: isDark,
                    onTap: () => _showDestinationSearchDialog(context, ref),
                  ),
                ],
              ),
            ),

          // Route Loading Indicator
          if (routeState.isLoading)
            Positioned(
              top: 86,
              left: 20,
              right: 80,
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.surfaceDark : AppColors.surface,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: isDark ? AppColors.borderDark : AppColors.border,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: isDark ? AppColors.brandDark : AppColors.brand,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Finding safe walking corridor...',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? AppColors.textPrimaryDark
                              : AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Bottom Info HUD - Navigation HUD or Default Safe Zone HUD
          Positioned(
            left: 16,
            right: 16,
            bottom: 20,
            child: routeState.hasRoute
                ? _buildRouteNavigationHUD(context, ref, routeState, isDark)
                : _buildSafeZoneSummaryHUD(context, ref, safeZoneState, isDark),
          ),
        ],
      ),
    );
  }

  /// Stitch Screen 11: Top Maneuver HUD Card for turn-by-turn navigation
  Widget _buildManeuverHUDCard(
    BuildContext context,
    WidgetRef ref,
    SafeRouteState routeState,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF244D3C),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF173A2C),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          // Maneuver Turn Direction Icon
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.2),
              ),
            ),
            child: const Icon(
              Icons.directions_walk_rounded,
              size: 26,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 12),
          // Instructions & Corridor Telemetry
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      routeState.currentRoute?.distance ?? 'Route active',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        routeState.currentRoute?.duration ?? 'Walking route',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFDDE9E1),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  routeState.destinationName ?? routeState.currentRoute?.endAddress ?? 'Pedestrian destination',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                const Row(
                  children: [
                    Icon(Icons.directions_walk_rounded,
                        size: 11, color: Color(0xFF82B89D)),
                    SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        'Pedestrian walking route • OpenStreetMap',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10,
                          color: Color(0xFFDDE9E1),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Audio Voice Navigation Toggle & Quick SOS Button
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              InkWell(
                onTap: () {
                  setState(() {
                    _audioNavEnabled = !_audioNavEnabled;
                  });
                },
                borderRadius: BorderRadius.circular(999),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _audioNavEnabled
                        ? Icons.volume_up_rounded
                        : Icons.volume_off_rounded,
                    size: 16,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              InkWell(
                onTap: () => context.push(Routes.emergency),
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.emergency,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'SOS',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Stitch Screen 11: Off-route deviation alert banner
  Widget _buildDeviationAlertBanner(BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF422B14) : const Color(0xFFFAF1E3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.warningDark : AppColors.warning,
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(
            Icons.warning_amber_rounded,
            size: 20,
            color: isDark ? AppColors.warningDark : AppColors.warning,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Off Designated Safe Corridor',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: isDark ? AppColors.warningDark : AppColors.warning,
                  ),
                ),
                Text(
                  'Auto-check in 28s • Deviation logged',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _showDeviationBanner = false;
              });
            },
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('I am safe'),
          ),
        ],
      ),
    );
  }

  /// Floating Privacy Mode pill (Stitch Screen 10)
  Widget _buildFloatingModePill(
    BuildContext context,
    WidgetRef ref,
    LocationMode mode,
    Map<String, dynamic> modeInfo,
    bool isDark,
  ) {
    final modeColor = _getModeColor(mode, isDark);

    return InkWell(
      onTap: () => _showModeSelector(context, ref),
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isDark
              ? AppColors.surfaceDark.withValues(alpha: 0.95)
              : AppColors.surface.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: isDark ? AppColors.borderDark : AppColors.border,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: modeColor.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(_getModeIcon(mode), size: 16, color: modeColor),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    modeInfo['name']?.toString() ?? 'Privacy Mode',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isDark
                          ? AppColors.textPrimaryDark
                          : AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    modeInfo['description']?.toString() ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.surfaceMutedDark
                    : AppColors.surfaceMuted,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                children: [
                  Text(
                    'Change',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isDark ? AppColors.brandDark : AppColors.brand,
                    ),
                  ),
                  const SizedBox(width: 2),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 9,
                    color: isDark ? AppColors.brandDark : AppColors.brand,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Floating circular button on map
  Widget _buildFloatingMapButton({
    required IconData icon,
    required String tooltip,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return Material(
      color: isDark
          ? AppColors.surfaceDark.withValues(alpha: 0.95)
          : AppColors.surface.withValues(alpha: 0.95),
      shape: const CircleBorder(),
      elevation: 4,
      shadowColor: Colors.black.withValues(alpha: 0.15),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: isDark ? AppColors.borderDark : AppColors.border,
            ),
          ),
          child: Icon(
            icon,
            size: 20,
            color: isDark ? AppColors.brandDark : AppColors.brand,
          ),
        ),
      ),
    );
  }

  Color _getModeColor(LocationMode mode, bool isDark) {
    switch (mode) {
      case LocationMode.ghost:
        return isDark ? AppColors.textSecondaryDark : AppColors.textSecondary;
      case LocationMode.smart:
        return isDark ? AppColors.warningDark : AppColors.warning;
      case LocationMode.guardian:
        return isDark ? AppColors.brandDark : AppColors.brand;
    }
  }

  IconData _getModeIcon(LocationMode mode) {
    switch (mode) {
      case LocationMode.ghost:
        return Icons.visibility_off_rounded;
      case LocationMode.smart:
        return Icons.auto_awesome_rounded;
      case LocationMode.guardian:
        return Icons.verified_user_rounded;
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
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.borderDark : AppColors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Location Privacy Mode',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Choose when and how your live GPS coordinates are shared.',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 16),
                _buildModeOption(
                  context,
                  ref,
                  LocationMode.ghost,
                  'Ghost Mode',
                  'Share location strictly during emergency SOS activations.',
                  Icons.visibility_off_rounded,
                  isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondary,
                ),
                _buildModeOption(
                  context,
                  ref,
                  LocationMode.smart,
                  'Smart Mode',
                  'Auto-share at night or when travelling outside safe zones.',
                  Icons.auto_awesome_rounded,
                  isDark ? AppColors.warningDark : AppColors.warning,
                ),
                _buildModeOption(
                  context,
                  ref,
                  LocationMode.guardian,
                  'Guardian Mode',
                  'Always visible to your configured emergency circle.',
                  Icons.verified_user_rounded,
                  isDark ? AppColors.brandDark : AppColors.brand,
                ),
              ],
            ),
          ),
        );
      },
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () {
          ref
              .read(settings.locationModeProvider.notifier)
              .setLocationMode(modeValue);
          Navigator.pop(context);
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? color.withValues(alpha: 0.1)
                : (isDark
                    ? AppColors.surfaceMutedDark
                    : AppColors.surfaceMuted),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? color : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: isDark
                            ? AppColors.textPrimaryDark
                            : AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                Icon(Icons.check_circle_rounded, color: color, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  /// Stitch Screen 11: Turn-by-turn Navigation HUD & Summary Sheet
  Widget _buildRouteNavigationHUD(
    BuildContext context,
    WidgetRef ref,
    SafeRouteState routeState,
    bool isDark,
  ) {
    final route = routeState.currentRoute!;
    final brand = isDark ? AppColors.brandDark : AppColors.brand;

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(
          color: isDark ? AppColors.borderDark : AppColors.border,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top telemetry bar: Time, Distance, Circle status
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(
                      route.duration,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                        color: brand,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '(${route.distance})',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.brandContainerDark
                        : AppColors.brandContainer,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: brand,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'Circle Tracking',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: brand,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Deterrent Card (Stitch Screen 11)
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.surfaceMutedDark
                    : AppColors.surfaceMuted,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isDark ? AppColors.borderDark : AppColors.border,
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.campaign_outlined,
                      size: 20, color: AppColors.emergency),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Audible Deterrent Siren Ready',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          'Tap for instant 105dB strobe & audio alarm',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark
                                ? AppColors.textSecondaryDark
                                : AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  OutlinedButton(
                    onPressed: () => context.push(Routes.emergency),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.emergency,
                      side: const BorderSide(color: AppColors.emergency),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      minimumSize: Size.zero,
                    ),
                    child: const Text('ARM',
                        style: TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w800)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Primary Action Button: "I Have Arrived Safely" (Stitch Screen 11)
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: () {
                  ref.read(safeRouteProvider.notifier).clearRoute();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text(
                            'Safe arrival confirmed! Trusted circle notified.')),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: brand,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 2,
                ),
                icon: const Icon(Icons.check_circle_rounded, size: 20),
                label: const Text(
                  'I Have Arrived Safely',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
              ),
            ),
            const SizedBox(height: 8),

            // Secondary Actions Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: () {
                    ref.read(safeRouteProvider.notifier).clearRoute();
                  },
                  child: const Text('End Navigation'),
                ),
                TextButton.icon(
                  onPressed: () {
                    final destination = ref.read(safeRouteProvider).destination;
                    if (destination == null) return;
                    final uri = Uri.parse(
                      'https://www.google.com/maps/dir/?api=1&destination='
                      '${destination.latitude},${destination.longitude}&travelmode=walking',
                    );
                    launchUrl(uri, mode: LaunchMode.externalApplication);
                  },
                  icon: const Icon(Icons.open_in_new_rounded, size: 14),
                  label: const Text('Google/Apple Maps'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Default Safe Zone & Quick Destinations Summary HUD (Stitch Screen 10)
  Widget _buildSafeZoneSummaryHUD(
    BuildContext context,
    WidgetRef ref,
    SafeZoneState safeZoneState,
    bool isDark,
  ) {
    final brand = isDark ? AppColors.brandDark : AppColors.brand;

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(
          color: isDark ? AppColors.borderDark : AppColors.border,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: safeZoneState.isInSafeZone
                        ? (isDark
                            ? AppColors.brandContainerDark
                            : AppColors.brandContainer)
                        : (isDark
                            ? const Color(0xFF422B14)
                            : const Color(0xFFFAF1E3)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    safeZoneState.isInSafeZone
                        ? Icons.shield_rounded
                        : Icons.explore_outlined,
                    color: safeZoneState.isInSafeZone
                        ? brand
                        : (isDark ? AppColors.warningDark : AppColors.warning),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        safeZoneState.isInSafeZone
                            ? 'Inside Safe Zone'
                            : 'Outside Safe Zones',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        safeZoneState.isInSafeZone
                            ? 'Monitored at ${safeZoneState.currentZone?.name ?? "Protected Area"}'
                            : '${safeZoneState.zones.length} safe zones configured',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: safeZoneState.isInSafeZone
                        ? (isDark
                            ? AppColors.brandContainerDark
                            : AppColors.brandContainer)
                        : (isDark
                            ? const Color(0xFF422B14)
                            : const Color(0xFFFAF1E3)),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    safeZoneState.isInSafeZone ? 'Protected' : 'Monitoring',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: safeZoneState.isInSafeZone
                          ? brand
                          : (isDark
                              ? AppColors.warningDark
                              : AppColors.warning),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Quick destination safe route triggers
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showSafeRouteDialog(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      side: BorderSide(
                        color: isDark ? AppColors.borderDark : AppColors.border,
                      ),
                    ),
                    icon: Icon(Icons.directions_walk_rounded,
                        size: 18, color: brand),
                    label: Text(
                      'Safe Route',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: brand,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => context.push(Routes.safeZones),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      side: BorderSide(
                        color: isDark ? AppColors.borderDark : AppColors.border,
                      ),
                    ),
                    icon: Icon(Icons.shield_outlined,
                        size: 18,
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondary),
                    label: Text(
                      'Safe Zones',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: isDark
                            ? AppColors.textPrimaryDark
                            : AppColors.textPrimary,
                      ),
                    ),
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
              ? const Color(0xFF39705A).withValues(alpha: 0.18)
              : const Color(0xFF244D3C).withValues(alpha: 0.08),
          borderColor: isCurrentZone
              ? const Color(0xFF39705A)
              : const Color(0xFF244D3C).withValues(alpha: 0.6),
          borderStrokeWidth: isCurrentZone ? 2.5 : 1.5,
        ),
      );
    }

    return circles;
  }

  /// Build markers including user location beacon and safe zone centers (Zero Blue)
  List<Marker> _buildMarkers(
    LocationState locationState,
    SafeZoneState safeZoneState,
    bool isDark,
  ) {
    final markers = <Marker>[];

    // Add user location pulsing beacon (Zero Blue!)
    if (locationState.hasLocation) {
      markers.add(
        Marker(
          point: LatLng(locationState.position!.latitude,
              locationState.position!.longitude),
          width: 48,
          height: 48,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Outer radar aura
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: (isDark ? AppColors.brandDark : AppColors.brand)
                      .withValues(alpha: 0.22),
                ),
              ),
              // Inner solid badge
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: isDark ? AppColors.brandDark : AppColors.brand,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.25),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Add safe zone markers
    for (final zone in safeZoneState.zones) {
      if (!zone.isActive) continue;

      final isCurrent = safeZoneState.currentZone?.id == zone.id;
      final zoneColor = isCurrent
          ? const Color(0xFF39705A)
          : (isDark ? AppColors.brandDark : AppColors.brand);

      markers.add(
        Marker(
          point: LatLng(zone.latitude, zone.longitude),
          width: 36,
          height: 36,
          child: Container(
            decoration: BoxDecoration(
              color: zoneColor,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(
              _getZoneTypeIcon(zone.type),
              color: Colors.white,
              size: 18,
            ),
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
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.borderDark : AppColors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Get Safe Walking Route',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Calculates pedestrian walking routes using OpenStreetMap data.',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Saved Safe Zones',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isDark
                        ? AppColors.textPrimaryDark
                        : AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Consumer(
                  builder: (context, ref, child) {
                    final zones = ref.watch(safeZoneProvider).zones;
                    final locationState = ref.watch(locationProvider);

                    if (zones.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline_rounded,
                                size: 16,
                                color: isDark
                                    ? AppColors.textSecondaryDark
                                    : AppColors.textSecondary),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'No saved locations yet. Add safe places first.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark
                                      ? AppColors.textSecondaryDark
                                      : AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    return Column(
                      children: zones.take(4).map((zone) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: InkWell(
                            onTap: () {
                              Navigator.pop(context);

                              if (!locationState.hasLocation) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text(
                                          'Current location not available yet.')),
                                );
                                return;
                              }

                              ref.read(safeRouteProvider.notifier).fetchRoute(
                                    origin: LatLng(
                                      locationState.position!.latitude,
                                      locationState.position!.longitude,
                                    ),
                                    destination:
                                        LatLng(zone.latitude, zone.longitude),
                                    destinationName: zone.name,
                                  );
                            },
                            borderRadius: BorderRadius.circular(14),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? AppColors.surfaceMutedDark
                                    : AppColors.surfaceMuted,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Row(
                                children: [
                                  Icon(_getZoneTypeIcon(zone.type),
                                      size: 18,
                                      color: isDark
                                          ? AppColors.brandDark
                                          : AppColors.brand),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      zone.name,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: isDark
                                            ? AppColors.textPrimaryDark
                                            : AppColors.textPrimary,
                                      ),
                                    ),
                                  ),
                                  Icon(
                                    Icons.arrow_forward_rounded,
                                    size: 16,
                                    color: isDark
                                        ? AppColors.brandDark
                                        : AppColors.brand,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: () {
                    Navigator.pop(context);
                    _showDestinationSearchDialog(context, ref);
                  },
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: isDark ? AppColors.borderDark : AppColors.border,
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.search_rounded,
                            size: 18,
                            color:
                                isDark ? AppColors.brandDark : AppColors.brand),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Search custom address or place',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? AppColors.textPrimaryDark
                                  : AppColors.textPrimary,
                            ),
                          ),
                        ),
                        Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 12,
                          color: isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondary,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  IconData _getZoneTypeIcon(SafeZoneType type) {
    switch (type) {
      case SafeZoneType.home:
        return Icons.home_rounded;
      case SafeZoneType.work:
        return Icons.work_rounded;
      case SafeZoneType.school:
        return Icons.school_rounded;
      case SafeZoneType.gym:
        return Icons.fitness_center_rounded;
      case SafeZoneType.custom:
        return Icons.place_rounded;
    }
  }

  /// Destination search modal with autocomplete
  void _showDestinationSearchDialog(BuildContext context, WidgetRef ref) {
    final searchController = TextEditingController();
    Timer? debounce;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => Consumer(
          builder: (context, ref, child) {
            final searchState = ref.watch(placesSearchProvider);
            final locationState = ref.watch(locationProvider);
            final isDark = Theme.of(context).brightness == Brightness.dark;

            return Column(
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.borderDark : AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TextField(
                    controller: searchController,
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: 'Search destination or landmark',
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded),
                              onPressed: () {
                                searchController.clear();
                                ref
                                    .read(placesSearchProvider.notifier)
                                    .clearSearch();
                              },
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                          color:
                              isDark ? AppColors.borderDark : AppColors.border,
                        ),
                      ),
                    ),
                    onChanged: (value) {
                      debounce?.cancel();
                      debounce = Timer(const Duration(milliseconds: 400), () {
                        final location = locationState.hasLocation
                            ? LatLng(locationState.position!.latitude,
                                locationState.position!.longitude)
                            : null;
                        ref
                            .read(placesSearchProvider.notifier)
                            .searchPlaces(value, location: location);
                      });
                    },
                  ),
                ),
                const SizedBox(height: 8),
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
                      else if (searchState.predictions.isEmpty &&
                          searchController.text.isNotEmpty)
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Text(
                              'No places found matching search.',
                              style: TextStyle(
                                color: isDark
                                    ? AppColors.textSecondaryDark
                                    : AppColors.textSecondary,
                              ),
                            ),
                          ),
                        )
                      else
                        ...searchState.predictions.map((prediction) => ListTile(
                              leading: Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? AppColors.surfaceMutedDark
                                      : AppColors.surfaceMuted,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.location_on_outlined,
                                  size: 18,
                                  color: isDark
                                      ? AppColors.brandDark
                                      : AppColors.brand,
                                ),
                              ),
                              title: Text(
                                prediction.mainText,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600),
                              ),
                              subtitle: prediction.secondaryText != null
                                  ? Text(
                                      prediction.secondaryText!,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: isDark
                                            ? AppColors.textSecondaryDark
                                            : AppColors.textSecondary,
                                      ),
                                    )
                                  : null,
                              onTap: () async {
                                final details = await ref
                                    .read(placesSearchProvider.notifier)
                                    .getPlaceDetails(prediction.placeId);

                                if (details != null &&
                                    locationState.hasLocation) {
                                  if (!context.mounted) return;
                                  Navigator.pop(context);

                                  ref
                                      .read(safeRouteProvider.notifier)
                                      .fetchRoute(
                                        origin: LatLng(
                                          locationState.position!.latitude,
                                          locationState.position!.longitude,
                                        ),
                                        destination: details.location,
                                        destinationName: details.name,
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
      debounce?.cancel();
      searchController.dispose();
    });
  }
}
