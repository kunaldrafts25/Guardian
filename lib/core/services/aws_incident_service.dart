/*
 * Guardian - Women's Safety App
 * AWS Serverless & Agentic Response Client
 */

import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:guardian/core/utils/logger.dart';

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
      return _configuredEndpoint.endsWith('/')
          ? _configuredEndpoint.substring(0, _configuredEndpoint.length - 1)
          : _configuredEndpoint;
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
      };

  /// Ingest a potential incident
  Future<Map<String, dynamic>> createIncident({
    required String eventId,
    required String userId,
    required String eventType,
    Map<String, dynamic>? location,
    Map<String, dynamic>? motionData,
  }) async {
    final url = Uri.parse('$baseUrl/incidents');
    final body = jsonEncode({
      'event_id': eventId,
      'user_id': userId,
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
      throw Exception('Failed to create incident: HTTP ${response.statusCode} - ${response.body}');
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
    String actor = 'USER',
    String note = '',
  }) async {
    final url = Uri.parse('$baseUrl/incidents/$incidentId/status');
    final body = jsonEncode({
      'state': newState,
      'actor': actor,
      'note': note,
    });

    try {
      final response = await http
          .put(url, headers: _headers, body: body)
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      throw Exception('Failed to update incident status: HTTP ${response.statusCode} - ${response.body}');
    } catch (e) {
      Logger.error('AWS Incident Service: Error updating status', e);
      rethrow;
    }
  }

  /// Fetch immutable incident timeline audit trail
  Future<List<Map<String, dynamic>>> getIncidentTimeline(String incidentId) async {
    final url = Uri.parse('$baseUrl/incidents/$incidentId/timeline');
    try {
      final response = await http
          .get(url, headers: _headers)
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final list = data['timeline'] as List<dynamic>? ?? [];
        return list.map((item) => Map<String, dynamic>.from(item as Map)).toList();
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

  /// Trigger emergency demo scenario ('fall', 'sos', 'inactivity', 'hardware_panic')
  Future<Map<String, dynamic>> simulateScenario(String scenario) async {
    final url = Uri.parse('$baseUrl/simulate/$scenario');
    try {
      final response = await http
          .post(url, headers: _headers)
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      throw Exception('Simulation failed: HTTP ${response.statusCode} - ${response.body}');
    } catch (e) {
      Logger.error('AWS Incident Service: Error simulating scenario', e);
      rethrow;
    }
  }

  /// Query verified nearby responders within radius
  Future<List<Map<String, dynamic>>> getNearbyResponders(
    String incidentId, {
    double radiusMeters = 1200.0,
  }) async {
    final url = Uri.parse('$baseUrl/incidents/$incidentId/nearby?radius_meters=$radiusMeters');
    try {
      final response = await http
          .get(url, headers: _headers)
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final list = data['nearby_responders'] as List<dynamic>? ?? [];
        return list.map((item) => Map<String, dynamic>.from(item as Map)).toList();
      }
      return [];
    } catch (e) {
      Logger.error('AWS Incident Service: Error getting nearby responders', e);
      return [];
    }
  }

  /// Accept rescue mission (Good Samaritan helper)
  Future<Map<String, dynamic>> acceptMission(
    String incidentId, {
    String responderId = 'resp_01',
  }) async {
    final url = Uri.parse('$baseUrl/incidents/$incidentId/accept');
    final body = jsonEncode({'responder_id': responderId});

    try {
      final response = await http
          .post(url, headers: _headers, body: body)
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      throw Exception('Failed to accept mission: HTTP ${response.statusCode} - ${response.body}');
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
      throw Exception('Failed to dispatch community: HTTP ${response.statusCode}');
    } catch (e) {
      Logger.error('AWS Incident Service: Error dispatching community', e);
      rethrow;
    }
  }

  /// Register active responder location heartbeat
  Future<Map<String, dynamic>> sendResponderHeartbeat({
    required String responderId,
    String name = 'Good Samaritan',
    double latitude = 19.0760,
    double longitude = 72.8777,
    int trustScore = 85,
  }) async {
    final url = Uri.parse('$baseUrl/responders/heartbeat');
    final body = jsonEncode({
      'responder_id': responderId,
      'name': name,
      'latitude': latitude,
      'longitude': longitude,
      'trust_score': trustScore,
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

