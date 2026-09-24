import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:guardian/core/services/responder_service.dart';
import 'package:guardian/core/services/safety_service_bridge.dart';
import 'package:guardian/core/utils/logger.dart';

class ResponderAvailabilityState {
  final bool isAvailable;
  final bool isSendingHeartbeat;
  final DateTime? lastHeartbeatSentAt;
  final DateTime? availabilityExpiresAt;
  final String? lastError;

  const ResponderAvailabilityState({
    this.isAvailable = false,
    this.isSendingHeartbeat = false,
    this.lastHeartbeatSentAt,
    this.availabilityExpiresAt,
    this.lastError,
  });

  bool get isExpired {
    if (!isAvailable || availabilityExpiresAt == null) return true;
    return DateTime.now().isAfter(availabilityExpiresAt!);
  }

  ResponderAvailabilityState copyWith({
    bool? isAvailable,
    bool? isSendingHeartbeat,
    DateTime? lastHeartbeatSentAt,
    DateTime? availabilityExpiresAt,
    String? lastError,
  }) {
    return ResponderAvailabilityState(
      isAvailable: isAvailable ?? this.isAvailable,
      isSendingHeartbeat: isSendingHeartbeat ?? this.isSendingHeartbeat,
      lastHeartbeatSentAt: lastHeartbeatSentAt ?? this.lastHeartbeatSentAt,
      availabilityExpiresAt:
          availabilityExpiresAt ?? this.availabilityExpiresAt,
      lastError: lastError,
    );
  }
}

class ResponderHeartbeatNotifier
    extends StateNotifier<ResponderAvailabilityState> {
  final ResponderService _service;
  Timer? _heartbeatTimer;
  StreamSubscription<Position>? _positionStream;

  // P2-01: Throttle time-based heartbeat to 15 mins to save battery
  static const Duration heartbeatInterval = Duration(minutes: 15);

  ResponderHeartbeatNotifier({ResponderService? service})
      : _service = service ?? ResponderService.instance,
        super(const ResponderAvailabilityState());

  Future<void> setAvailability(bool available) async {
    if (state.isAvailable == available) return;
    if (!available) {
      await stopHeartbeat();
    } else {
      await startHeartbeat();
    }
  }

  Future<void> startHeartbeat() async {
    _heartbeatTimer?.cancel();
    await _positionStream?.cancel();
    state = state.copyWith(isAvailable: true, lastError: null);

    await _sendHeartbeatTick(isActive: true);

    _heartbeatTimer = Timer.periodic(heartbeatInterval, (_) {
      _sendHeartbeatTick(isActive: true);
    });

    // P2-01: Add distance filter (500m) for responsive but battery-friendly updates
    final locationSettings = const LocationSettings(
      accuracy: LocationAccuracy.medium,
      distanceFilter: 500,
    );
    
    _positionStream = Geolocator.getPositionStream(locationSettings: locationSettings).listen((Position position) {
      _service.sendHeartbeat(
        latitude: position.latitude,
        longitude: position.longitude,
        isActive: true,
      ).then((_) {
        if (mounted) {
          state = state.copyWith(
            lastHeartbeatSentAt: DateTime.now(),
            availabilityExpiresAt: DateTime.now().add(const Duration(minutes: 30)),
          );
        }
      });
    });
  }

  Future<void> stopHeartbeat() async {
    _heartbeatTimer?.cancel();
    await _positionStream?.cancel();
    _heartbeatTimer = null;
    _positionStream = null;

    state = state.copyWith(
      isAvailable: false,
      isSendingHeartbeat: false,
      availabilityExpiresAt: null,
    );

    try {
      final loc = await _resolveCurrentLocation();
      if (loc != null) {
        await _service.sendHeartbeat(
          latitude: loc.latitude,
          longitude: loc.longitude,
          isActive: false,
        );
      }
    } catch (e) {
      Logger.e('Failed to send deactivation heartbeat: $e');
    }
  }

  Future<void> _sendHeartbeatTick({required bool isActive}) async {
    if (!mounted) return;
    state = state.copyWith(isSendingHeartbeat: true, lastError: null);
    try {
      final loc = await _resolveCurrentLocation();
      if (loc == null) throw Exception('Location unavailable');

      await _service.sendHeartbeat(
        latitude: loc.latitude,
        longitude: loc.longitude,
        isActive: isActive,
      );

      if (mounted) {
        state = state.copyWith(
          isSendingHeartbeat: false,
          lastHeartbeatSentAt: DateTime.now(),
          availabilityExpiresAt:
              DateTime.now().add(const Duration(minutes: 30)),
        );
      }
    } catch (e) {
      if (mounted) {
        state = state.copyWith(
          isSendingHeartbeat: false,
          lastError: e.toString(),
        );
      }
    }
  }

  Future<Position?> _resolveCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return null;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return null;
      }
      if (permission == LocationPermission.deniedForever) return null;

      return await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.medium);
    } catch (_) {
      return null;
    }
  }
}
