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

  static const Duration heartbeatInterval = Duration(seconds: 60);

  ResponderHeartbeatNotifier({ResponderService? service})
      : _service = service ?? ResponderService.instance,
        super(const ResponderAvailabilityState());

  /// Explicitly toggle availability
  Future<void> setAvailability(bool available) async {
    if (state.isAvailable == available) return;

    if (!available) {
      await stopHeartbeat();
    } else {
      await startHeartbeat();
    }
  }

  /// Start availability heartbeat
  Future<void> startHeartbeat() async {
    _heartbeatTimer?.cancel();
    state = state.copyWith(isAvailable: true, lastError: null);

    // Send immediate first heartbeat
    await _sendHeartbeatTick(isActive: true);

    // Repeat every 60 seconds
    _heartbeatTimer = Timer.periodic(heartbeatInterval, (_) {
      _sendHeartbeatTick(isActive: true);
    });
  }

  /// Stop availability heartbeat and inform backend immediately
  Future<void> stopHeartbeat() async {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;

    state = state.copyWith(
      isAvailable: false,
      isSendingHeartbeat: false,
      availabilityExpiresAt: null,
    );

    // Send final deactivation heartbeat if location is known
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
      Logger.warning('Failed to send deactivation heartbeat: $e');
    }
  }

  Future<void> _sendHeartbeatTick({required bool isActive}) async {
    if (!state.isAvailable && isActive) return;

    state = state.copyWith(isSendingHeartbeat: true);
    try {
      final loc = await _resolveCurrentLocation();
      if (loc == null) {
        state = state.copyWith(
          isSendingHeartbeat: false,
          lastError: 'Location unavailable for responder heartbeat',
        );
        return;
      }

      final res = await _service.sendHeartbeat(
        latitude: loc.latitude,
        longitude: loc.longitude,
        isActive: isActive,
      );

      final now = DateTime.now();
      final expirySeconds = (res['availability_expires_at'] as num?)?.toInt();
      final expiryDate = expirySeconds != null
          ? DateTime.fromMillisecondsSinceEpoch(expirySeconds * 1000,
              isUtc: true)
          : now.add(const Duration(seconds: 300));

      state = state.copyWith(
        isSendingHeartbeat: false,
        lastHeartbeatSentAt: now,
        availabilityExpiresAt: expiryDate,
        lastError: null,
      );
      Logger.info('✅ Responder heartbeat dispatched successfully');
    } catch (e) {
      Logger.warning('Responder heartbeat failed: $e');
      state = state.copyWith(
        isSendingHeartbeat: false,
        lastError: e.toString(),
      );
    }
  }

  Future<Position?> _resolveCurrentLocation() async {
    // 1. Try native foreground service cached location
    final cached = await SafetyServiceBridge().getLastServiceLocation();
    if (cached != null) {
      final lat = cached.latitude;
      final lng = cached.longitude;
      final acc = cached.accuracy;
      final timeMs = cached.capturedAt?.millisecondsSinceEpoch ?? 0;
      final age = DateTime.now().millisecondsSinceEpoch - timeMs;
      if (age < 120000) {
        return Position(
          latitude: lat,
          longitude: lng,
          accuracy: acc,
          altitude: 0,
          heading: 0,
          speed: 0,
          speedAccuracy: 0,
          altitudeAccuracy: 0,
          headingAccuracy: 0,
          timestamp: cached.capturedAt ?? DateTime.now(),
        );
      }
    }

    // 2. Query Geolocator with fallback to last known
    try {
      final perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        return null;
      }
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 5),
        ),
      );
    } catch (_) {
      return await Geolocator.getLastKnownPosition();
    }
  }

  @override
  void dispose() {
    _heartbeatTimer?.cancel();
    super.dispose();
  }
}

final responderHeartbeatProvider = StateNotifierProvider<
    ResponderHeartbeatNotifier, ResponderAvailabilityState>((ref) {
  return ResponderHeartbeatNotifier();
});
