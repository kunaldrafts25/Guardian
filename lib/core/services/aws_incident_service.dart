/*
 * Guardian - Women's Safety App
 * AWS Serverless & Agentic Response Client
 */

import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:guardian/core/utils/logger.dart';
import 'package:guardian/core/services/aws_auth_service.dart';

/// Service interfacing with AWS API Gateway / Serverless Incident Handler
class AwsIncidentService {
  static final AwsIncidentService instance = AwsIncidentService._internal();

  factory AwsIncidentService() => instance;

  AwsIncidentService._internal();

  /// Default API base URL
  /// Can be set via --dart-define=AWS_API_ENDPOINT=https://...
  static const String _configuredEndpoint = String.fromEnvironment(
    'AWS_API_ENDPOINT',
    defaultValue: '',
  );

  String get baseUrl {
    if (_configuredEndpoint.isNotEmpty) {
      final endpoint = _configuredEndpoint.endsWith('/')
          ? _configuredEndpoint.substring(0, _configuredEndpoint.length - 1)
          : _configuredEndpoint;
      if (kReleaseMode && !endpoint.startsWith('https://')) {
        throw StateError('AWS_API_ENDPOINT must use HTTPS in release builds.');
      }
      return endpoint;
    }
    if (kReleaseMode) {
      throw StateError('AWS_API_ENDPOINT is required in release builds.');
    }
    // Auto-detect local development environments
    if (kIsWeb) {
      return 'http://localhost:8000';
    }
    if (Platform.isAndroid) {
      // Host machine Wi-Fi IP for physical multi-device live testing
      return 'http://192.168.0.103:8000';
    }
    return 'http://127.0.0.1:8000';
  }

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (AwsAuthService.instance.accessToken != null)
          'Authorization': 'Bearer ${AwsAuthService.instance.accessToken}',
      };

  /// Ingest a potential incident
  Future<Map<String, dynamic>> createIncident({
    required String eventId,
    required String eventType,
    Map<String, dynamic>? location,
    Map<String, dynamic>? motionData,
  }) async {
    final url = Uri.parse('$baseUrl/incidents');
    final body = jsonEncode({
      'event_id': eventId,
      'event_type': eventType,
      'location': location,
      'motion_data': motionData,
    });

    try {
      final response = await http
          .post(url, headers: _headers, body: body)
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200 || response.statusCode == 201) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      throw Exception(
          'Failed to create incident: HTTP ${response.statusCode} - ${response.body}');
    } catch (e) {
      Logger.error('AWS Incident Service: Error creating incident', e);
      rethrow;
    }
  }

  /// Get current incident status and agent decisions
  Future<Map<String, dynamic>> getIncident(String incidentId) async {
    final url = Uri.parse('$baseUrl/incidents/$incidentId');
    try {
      final response = await http
          .get(url, headers: _headers)
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      throw Exception('Failed to get incident: HTTP ${response.statusCode}');
    } catch (e) {
      Logger.error('AWS Incident Service: Error getting incident', e);
      rethrow;
    }
  }

  /// Update incident state (e.g., User confirms I'M OK or Contact Acknowledges)
  Future<Map<String, dynamic>> updateIncidentStatus(
    String incidentId,
    String newState, {
    String note = '',
  }) async {
    final url = Uri.parse('$baseUrl/incidents/$incidentId/status');
    final body = jsonEncode({
      'state': newState,
      'note': note,
    });

    try {
      final response = await http
          .put(url, headers: _headers, body: body)
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      throw Exception(
          'Failed to update incident status: HTTP ${response.statusCode} - ${response.body}');
    } catch (e) {
      Logger.error('AWS Incident Service: Error updating status', e);
      rethrow;
    }
  }

  /// Fetch immutable incident timeline audit trail
  Future<List<Map<String, dynamic>>> getIncidentTimeline(
      String incidentId) async {
    final url = Uri.parse('$baseUrl/incidents/$incidentId/timeline');
    try {
      final response = await http
          .get(url, headers: _headers)
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final list = data['timeline'] as List<dynamic>? ?? [];
        return list
            .map((item) => Map<String, dynamic>.from(item as Map))
            .toList();
      }
      return [];
    } catch (e) {
      Logger.error('AWS Incident Service: Error getting timeline', e);
      return [];
    }
  }

  /// Trigger autonomous Bedrock agent step manually
  Future<Map<String, dynamic>> triggerAgentStep(String incidentId) async {
    final url = Uri.parse('$baseUrl/incidents/$incidentId/agent-step');
    try {
      final response = await http
          .post(url, headers: _headers)
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      throw Exception('Failed to trigger agent step: ${response.statusCode}');
    } catch (e) {
      Logger.error('AWS Incident Service: Error triggering agent step', e);
      rethrow;
    }
  }

  Future<Map<String, dynamic>> escalateIncident(String incidentId) async {
    final response = await http
        .post(
          Uri.parse('$baseUrl/incidents/$incidentId/escalate'),
          headers: _headers,
        )
        .timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) {
      throw Exception(
          'Failed to escalate incident: HTTP ${response.statusCode} - ${response.body}');
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  /// Ask the production Bedrock safety companion.
  Future<String> askSafetyCompanion(
    String message, {
    String? incidentId,
  }) async {
    final response = await http
        .post(
          Uri.parse('$baseUrl/assistant/chat'),
          headers: _headers,
          body: jsonEncode({
            'message': message,
            if (incidentId != null) 'incident_id': incidentId,
          }),
        )
        .timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) {
      throw Exception(
          'Safety assistant unavailable: HTTP ${response.statusCode}');
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final answer = data['response'] as String?;
    if (answer == null || answer.trim().isEmpty) {
      throw Exception('Safety assistant returned no response');
    }
    return answer;
  }

  /// Query verified nearby responders within radius
  Future<List<Map<String, dynamic>>> getNearbyResponders(
    String incidentId, {
    double radiusMeters = 1200.0,
  }) async {
    final url = Uri.parse(
        '$baseUrl/incidents/$incidentId/nearby?radius_meters=$radiusMeters');
    try {
      final response = await http
          .get(url, headers: _headers)
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final list = data['nearby_responders'] as List<dynamic>? ?? [];
        return list
            .map((item) => Map<String, dynamic>.from(item as Map))
            .toList();
      }
      return [];
    } catch (e) {
      Logger.error('AWS Incident Service: Error getting nearby responders', e);
      return [];
    }
  }

  /// Accept rescue mission (Good Samaritan helper)
  Future<Map<String, dynamic>> acceptMission(
    String incidentId,
  ) async {
    final url = Uri.parse('$baseUrl/incidents/$incidentId/accept');

    try {
      final response = await http
          .post(url, headers: _headers)
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      throw Exception(
          'Failed to accept mission: HTTP ${response.statusCode} - ${response.body}');
    } catch (e) {
      Logger.error('AWS Incident Service: Error accepting mission', e);
      rethrow;
    }
  }

  /// Dispatch community alert (Anti-Solo Quorum check)
  Future<Map<String, dynamic>> dispatchCommunityAlert(String incidentId) async {
    final url = Uri.parse('$baseUrl/incidents/$incidentId/dispatch-community');
    try {
      final response = await http
          .post(url, headers: _headers)
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      throw Exception(
          'Failed to dispatch community: HTTP ${response.statusCode}');
    } catch (e) {
      Logger.error('AWS Incident Service: Error dispatching community', e);
      rethrow;
    }
  }

  /// Register active responder location heartbeat
  Future<Map<String, dynamic>> sendResponderHeartbeat({
    required double latitude,
    required double longitude,
    bool isActive = true,
  }) async {
    final url = Uri.parse('$baseUrl/responders/heartbeat');
    final body = jsonEncode({
      'latitude': latitude,
      'longitude': longitude,
      'is_active': isActive,
    });

    try {
      final response = await http
          .post(url, headers: _headers, body: body)
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      throw Exception('Failed to send heartbeat: HTTP ${response.statusCode}');
    } catch (e) {
      Logger.error('AWS Incident Service: Error sending heartbeat', e);
      rethrow;
    }
  }
}
