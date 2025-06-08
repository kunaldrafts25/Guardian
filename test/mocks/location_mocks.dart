/*
 * Guardian - Women's Safety App
 * © 2025 All Rights Reserved - Kunal Singh
 * Contact: kunalsingh2514@gmail.com
 */

import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:geolocator_platform_interface/geolocator_platform_interface.dart';
import 'package:mockito/mockito.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:permission_handler/permission_handler.dart';

// Mock GeolocatorPlatform
class MockGeolocatorPlatform extends Mock
    with MockPlatformInterfaceMixin
    implements GeolocatorPlatform {
  bool _locationServiceEnabled = true;
  LocationPermission _permission = LocationPermission.whileInUse;
  Position _currentPosition = Position(
    latitude: 37.7749,
    longitude: -122.4194,
    timestamp: DateTime.now(),
    accuracy: 4.0,
    altitude: 0.0,
    heading: 0.0,
    speed: 0.0,
    speedAccuracy: 0.0,
    altitudeAccuracy: 0.0,
    headingAccuracy: 0.0,
  );

  void setLocationServiceEnabled(bool enabled) {
    _locationServiceEnabled = enabled;
  }

  void setLocationPermission(LocationPermission permission) {
    _permission = permission;
  }

  void setCurrentPosition(Position position) {
    _currentPosition = position;
  }

  @override
  Future<bool> isLocationServiceEnabled() async => _locationServiceEnabled;

  @override
  Future<LocationPermission> checkPermission() async => _permission;

  @override
  Future<LocationPermission> requestPermission() async => _permission;

  @override
  Future<Position> getCurrentPosition({
    LocationSettings? locationSettings,
  }) async {
    if (!_locationServiceEnabled) {
      throw const LocationServiceDisabledException();
    }

    if (_permission == LocationPermission.denied) {
      throw const PermissionDeniedException('Location permission denied');
    }

    if (_permission == LocationPermission.deniedForever) {
      throw const PermissionDeniedException('Location permission permanently denied');
    }

    return _currentPosition;
  }

  @override
  Future<Position?> getLastKnownPosition({
    bool? forceLocationManager = false,
  }) async {
    if (!_locationServiceEnabled) {
      return null;
    }

    return _currentPosition;
  }

  final StreamController<Position> _positionStreamController = StreamController<Position>.broadcast();

  @override
  Stream<Position> getPositionStream({
    LocationSettings? locationSettings,
  }) {
    if (!_locationServiceEnabled) {
      _positionStreamController.addError(const LocationServiceDisabledException());
      return _positionStreamController.stream;
    }

    if (_permission == LocationPermission.denied || _permission == LocationPermission.deniedForever) {
      _positionStreamController.addError(const PermissionDeniedException('Location permission denied'));
      return _positionStreamController.stream;
    }

    // Add initial position
    _positionStreamController.add(_currentPosition);

    // Simulate position updates
    Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_positionStreamController.isClosed) {
        timer.cancel();
        return;
      }

      final newPosition = Position(
        latitude: _currentPosition.latitude + 0.0001,
        longitude: _currentPosition.longitude + 0.0001,
        timestamp: DateTime.now(),
        accuracy: _currentPosition.accuracy,
        altitude: _currentPosition.altitude,
        heading: _currentPosition.heading,
        speed: _currentPosition.speed,
        speedAccuracy: _currentPosition.speedAccuracy,
        altitudeAccuracy: _currentPosition.altitudeAccuracy,
        headingAccuracy: _currentPosition.headingAccuracy,
      );

      _currentPosition = newPosition;
      _positionStreamController.add(newPosition);
    });

    return _positionStreamController.stream;
  }

  @override
  double distanceBetween(
    double startLatitude,
    double startLongitude,
    double endLatitude,
    double endLongitude,
  ) {
    // Simple mock implementation
    const earthRadius = 6371000.0; // in meters

    // For testing purposes, return a simple calculation
    // In a real implementation, you would use the haversine formula
    final latDiff = (endLatitude - startLatitude).abs();
    final lngDiff = (endLongitude - startLongitude).abs();

    return earthRadius * (latDiff + lngDiff) * 0.01;
  }

  void dispose() {
    _positionStreamController.close();
  }
}

// Mock Permission class for testing
class MockPermissionHandler {
  final Map<Permission, PermissionStatus> _permissionStatuses = {};
  final Map<Permission, bool> _serviceStatuses = {};

  MockPermissionHandler() {
    // Set default values
    _permissionStatuses[Permission.location] = PermissionStatus.granted;
    _serviceStatuses[Permission.location] = true;
  }

  void setPermissionStatus(Permission permission, PermissionStatus status) {
    _permissionStatuses[permission] = status;
  }

  void setServiceStatus(Permission permission, bool enabled) {
    _serviceStatuses[permission] = enabled;
  }

  Future<PermissionStatus> checkPermissionStatus(Permission permission) async {
    return _permissionStatuses[permission] ?? PermissionStatus.denied;
  }

  Future<Map<Permission, PermissionStatus>> requestPermissions(List<Permission> permissions) async {
    final result = <Permission, PermissionStatus>{};
    for (final permission in permissions) {
      result[permission] = _permissionStatuses[permission] ?? PermissionStatus.granted;
    }
    return result;
  }

  Future<bool> openAppSettings() async {
    return true;
  }

  Future<bool> isLocationServiceEnabled() async {
    return _serviceStatuses[Permission.location] ?? false;
  }
}
