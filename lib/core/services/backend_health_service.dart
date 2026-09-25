/*
 * Guardian 2.0 - Women's Safety App
 * Backend Health & Connectivity Service
 */

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:guardian/core/services/aws_auth_service.dart';
import 'package:guardian/core/utils/logger.dart';

enum HealthConnectivityStatus {
  connected,
  degraded,
  offline,
  authExpired,
  untested,
}

class BackendHealthState {
  final HealthConnectivityStatus status;
  final bool internetConnected;
  final bool apiReachable;
  final String apiHealthStatus;
  final AuthStatus authStatus;
  final Map<String, dynamic> checks;
  final DateTime timestamp;
  final String? lastError;

  const BackendHealthState({
    required this.status,
    required this.internetConnected,
    required this.apiReachable,
    required this.apiHealthStatus,
    required this.authStatus,
    this.checks = const {},
    required this.timestamp,
    this.lastError,
  });

  bool get isHealthy => status == HealthConnectivityStatus.connected;
}

class BackendHealthService {
  BackendHealthService._();
  static final BackendHealthService instance = BackendHealthService._();

  BackendHealthState? _lastState;
  DateTime? _lastCheckedAt;
  Future<BackendHealthState>? _inFlightCheck;
  static const Duration _cacheTtl = Duration(seconds: 60);

  BackendHealthState? get currentState => _lastState;

  Future<BackendHealthState> checkHealth({bool forceRefresh = false}) {
    final now = DateTime.now();
    if (!forceRefresh &&
        _lastState != null &&
        _lastCheckedAt != null &&
        now.difference(_lastCheckedAt!) < _cacheTtl) {
      return Future.value(_lastState!);
    }

    if (_inFlightCheck != null) {
      return _inFlightCheck!;
    }

    final future = _performHealthCheck();
    _inFlightCheck = future;
    return future.whenComplete(() {
      _inFlightCheck = null;
    });
  }

  Future<BackendHealthState> _performHealthCheck() async {
    final now = DateTime.now().toUtc();
    final authService = AwsAuthService.instance;
    final currentAuthStatus = authService.authStatus;

    bool internetConnected = false;
    bool apiReachable = false;
    String apiHealthStatus = 'unreachable';
    Map<String, dynamic> checks = {};
    String? errorDetail;

    // 1. Basic socket reachability check (DNS / Internet connectivity)
    try {
      if (!kIsWeb) {
        final result = await InternetAddress.lookup('dns.google')
            .timeout(const Duration(seconds: 3));
        internetConnected =
            result.isNotEmpty && result[0].rawAddress.isNotEmpty;
      } else {
        internetConnected = true;
      }
    } catch (_) {
      internetConnected = false;
    }

    // 2. Query Guardian backend /health endpoint
    final baseUrl = authService.baseUrl;
    try {
      final uri = Uri.parse('$baseUrl/health');
      final response = await http.get(uri).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        apiReachable = true;
        internetConnected =
            true; // Confirmed internet reachability via working API
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        apiHealthStatus = data['status']?.toString() ?? 'healthy';
        if (data['checks'] is Map<String, dynamic>) {
          checks = data['checks'] as Map<String, dynamic>;
        }
      } else {
        apiReachable = true;
        apiHealthStatus = 'degraded';
        errorDetail = 'HTTP ${response.statusCode} from /health';
      }
    } catch (e) {
      apiReachable = false;
      apiHealthStatus = 'unreachable';
      errorDetail = e.toString();
    }

    HealthConnectivityStatus overallStatus;
    if (!internetConnected && !apiReachable) {
      overallStatus = HealthConnectivityStatus.offline;
    } else if (currentAuthStatus == AuthStatus.reauthenticationRequired) {
      overallStatus = HealthConnectivityStatus.authExpired;
    } else if (apiHealthStatus == 'degraded' || !apiReachable) {
      overallStatus = HealthConnectivityStatus.degraded;
    } else {
      overallStatus = HealthConnectivityStatus.connected;
    }

    final newState = BackendHealthState(
      status: overallStatus,
      internetConnected: internetConnected,
      apiReachable: apiReachable,
      apiHealthStatus: apiHealthStatus,
      authStatus: currentAuthStatus,
      checks: checks,
      timestamp: now,
      lastError: errorDetail,
    );

    _lastState = newState;
    _lastCheckedAt = DateTime.now();
    Logger.info(
      'BackendHealth: status=${overallStatus.name} apiReachable=$apiReachable health=$apiHealthStatus',
    );
    return newState;
  }
}
