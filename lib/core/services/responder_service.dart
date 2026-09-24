import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:guardian/core/services/aws_auth_service.dart';

class ResponderMission {
  final String missionId;
  final String incidentId;
  final String status;
  final DateTime? invitedAt;
  final DateTime? updatedAt;
  final DateTime? invitationExpiresAt;
  final String deliveryStatus;
  final double? approximateLatitude;
  final double? approximateLongitude;

  const ResponderMission({
    required this.missionId,
    required this.incidentId,
    required this.status,
    required this.invitedAt,
    required this.updatedAt,
    required this.invitationExpiresAt,
    required this.deliveryStatus,
    required this.approximateLatitude,
    required this.approximateLongitude,
  });

  factory ResponderMission.fromJson(Map<String, dynamic> json) {
    final location = json['approximate_location'] as Map?;
    final expiry = (json['invitation_expires_at'] as num?)?.toInt();
    return ResponderMission(
      missionId: json['mission_id'] as String,
      incidentId: json['incident_id'] as String,
      status: json['status'] as String? ?? 'UNKNOWN',
      invitedAt: DateTime.tryParse(json['invited_at'] as String? ?? ''),
      updatedAt: DateTime.tryParse(json['updated_at'] as String? ?? ''),
      invitationExpiresAt: expiry == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(expiry * 1000, isUtc: true),
      deliveryStatus:
          json['invitation_delivery_status'] as String? ?? 'UNKNOWN',
      approximateLatitude: (location?['latitude'] as num?)?.toDouble(),
      approximateLongitude: (location?['longitude'] as num?)?.toDouble(),
    );
  }

  bool get isTerminal =>
      const {'COMPLETED', 'WITHDRAWN', 'CANCELLED', 'EXPIRED'}.contains(status);
}

enum LocationFreshnessQuality { fresh, aging, stale, unavailable }

class AuthorizedMissionLocation {
  final double latitude;
  final double longitude;
  final double? accuracy;
  final DateTime expiresAt;
  final DateTime? capturedAt;
  final DateTime? receivedAt;
  final double? ageSeconds;
  final String source;
  final String freshness;

  const AuthorizedMissionLocation({
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    required this.expiresAt,
    this.capturedAt,
    this.receivedAt,
    this.ageSeconds,
    this.source = 'DEVICE_GPS',
    this.freshness = 'FRESH',
  });

  LocationFreshnessQuality get quality {
    final lower = freshness.toLowerCase();
    if (lower == 'fresh') return LocationFreshnessQuality.fresh;
    if (lower == 'aging') return LocationFreshnessQuality.aging;
    if (lower == 'stale') {
      if (ageSeconds != null && ageSeconds! <= 120.0) {
        return LocationFreshnessQuality.aging;
      }
      return LocationFreshnessQuality.stale;
    }
    if (lower == 'unavailable') return LocationFreshnessQuality.unavailable;
    if (ageSeconds == null) return LocationFreshnessQuality.unavailable;
    if (ageSeconds! <= 30.0) return LocationFreshnessQuality.fresh;
    if (ageSeconds! <= 120.0) return LocationFreshnessQuality.aging;
    return LocationFreshnessQuality.stale;
  }

  bool get isFresh => quality == LocationFreshnessQuality.fresh;
  bool get isAging => quality == LocationFreshnessQuality.aging;
  bool get isStale => quality == LocationFreshnessQuality.stale;
  bool get isUnavailable => quality == LocationFreshnessQuality.unavailable;

  factory AuthorizedMissionLocation.fromJson(Map<String, dynamic> response) {
    final expiry = (response['grant_expires_at'] as num).toInt();
    final capStr = response['captured_at'] as String?;
    final recStr = response['received_at'] as String?;
    return AuthorizedMissionLocation(
      latitude: (response['latitude'] as num).toDouble(),
      longitude: (response['longitude'] as num).toDouble(),
      accuracy: (response['accuracy'] as num?)?.toDouble(),
      expiresAt:
          DateTime.fromMillisecondsSinceEpoch(expiry * 1000, isUtc: true),
      capturedAt: capStr != null ? DateTime.tryParse(capStr) : null,
      receivedAt: recStr != null ? DateTime.tryParse(recStr) : null,
      ageSeconds: (response['age_seconds'] as num?)?.toDouble(),
      source: response['source'] as String? ?? 'DEVICE_GPS',
      freshness: response['freshness'] as String? ?? 'FRESH',
    );
  }
}

class MissionAcceptance {
  final ResponderMission mission;
  final bool grantAvailable;

  const MissionAcceptance(this.mission, this.grantAvailable);
}

class ResponderService {
  ResponderService._();
  static final instance = ResponderService._();

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  AwsAuthService get _api => AwsAuthService.instance;

  Future<List<ResponderMission>> listInvitations() async {
    final response = await _api.get('/responders/invitations');
    return _decodeList(response['invitations']);
  }

  Future<List<ResponderMission>> listMissions() async {
    final response = await _api.get('/responders/missions');
    return _decodeList(response['missions']);
  }

  Future<ResponderMission> getMission(String missionId) async {
    final response = await _api.get(
      '/missions/${Uri.encodeComponent(missionId)}',
    );
    return ResponderMission.fromJson(response);
  }

  Future<MissionAcceptance> acceptInvitation(String incidentId) async {
    final response = await _api.post(
      '/incidents/${Uri.encodeComponent(incidentId)}/accept',
      const {},
    );
    final mission = ResponderMission.fromJson(
      Map<String, dynamic>.from(response['mission'] as Map),
    );
    final grant = response['navigation_grant'] as String?;
    if (grant != null && grant.isNotEmpty) {
      await _storage.write(key: _grantKey(mission.missionId), value: grant);
    }
    return MissionAcceptance(mission, grant != null && grant.isNotEmpty);
  }

  Future<ResponderMission> transition(
    String missionId,
    String status,
  ) async {
    final response = await _api.put(
      '/missions/${Uri.encodeComponent(missionId)}/status',
      {'status': status},
    );
    final mission = ResponderMission.fromJson(response);
    if (mission.isTerminal || mission.status == 'ARRIVED') {
      await _storage.delete(key: _grantKey(missionId));
    }
    return mission;
  }

  Future<Map<String, dynamic>> sendHeartbeat({
    required double latitude,
    required double longitude,
    required bool isActive,
  }) async {
    return await _api.post('/responders/heartbeat', {
      'latitude': latitude,
      'longitude': longitude,
      'is_active': isActive,
    });
  }

  Future<String> renewGrant(String missionId) async {
    final response = await _api.post(
      '/missions/${Uri.encodeComponent(missionId)}/renew-grant',
      const {},
    );
    final newGrant = response['navigation_grant'] as String;
    await _storage.write(key: _grantKey(missionId), value: newGrant);
    return newGrant;
  }

  Future<AuthorizedMissionLocation> getAuthorizedLocation(
    ResponderMission mission,
  ) async {
    var grant = await _storage.read(key: _grantKey(mission.missionId));
    if (grant == null || grant.isEmpty) {
      if (mission.status == 'ACCEPTED' || mission.status == 'EN_ROUTE') {
        grant = await renewGrant(mission.missionId);
      } else {
        throw StateError(
          'The navigation grant is unavailable. Reopen the original acceptance on this device.',
        );
      }
    }
    try {
      final response = await _api.post(
        '/incidents/${Uri.encodeComponent(mission.incidentId)}/authorized-location',
        {'navigation_grant': grant},
      );
      return AuthorizedMissionLocation.fromJson(response);
    } catch (e) {
      if (mission.status == 'ACCEPTED' || mission.status == 'EN_ROUTE') {
        final renewedGrant = await renewGrant(mission.missionId);
        final retryResponse = await _api.post(
          '/incidents/${Uri.encodeComponent(mission.incidentId)}/authorized-location',
          {'navigation_grant': renewedGrant},
        );
        return AuthorizedMissionLocation.fromJson(retryResponse);
      }
      rethrow;
    }
  }

  List<ResponderMission> _decodeList(Object? value) {
    final items = value as List<dynamic>? ?? const [];
    return items
        .whereType<Map>()
        .map((item) =>
            ResponderMission.fromJson(Map<String, dynamic>.from(item)))
        .toList(growable: false);
  }

  String _grantKey(String missionId) =>
      'guardian_mission_grant_${base64Url.encode(utf8.encode(missionId))}';
}
