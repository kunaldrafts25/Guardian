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

class AuthorizedMissionLocation {
  final double latitude;
  final double longitude;
  final double? accuracy;
  final DateTime expiresAt;

  const AuthorizedMissionLocation({
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    required this.expiresAt,
  });
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

  Future<AuthorizedMissionLocation> getAuthorizedLocation(
    ResponderMission mission,
  ) async {
    final grant = await _storage.read(key: _grantKey(mission.missionId));
    if (grant == null || grant.isEmpty) {
      throw StateError(
        'The navigation grant is unavailable. Reopen the original acceptance on this device.',
      );
    }
    final response = await _api.post(
      '/incidents/${Uri.encodeComponent(mission.incidentId)}/authorized-location',
      {'navigation_grant': grant},
    );
    final expiry = (response['grant_expires_at'] as num).toInt();
    return AuthorizedMissionLocation(
      latitude: (response['latitude'] as num).toDouble(),
      longitude: (response['longitude'] as num).toDouble(),
      accuracy: (response['accuracy'] as num?)?.toDouble(),
      expiresAt:
          DateTime.fromMillisecondsSinceEpoch(expiry * 1000, isUtc: true),
    );
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
