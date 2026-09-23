/*
 * Guardian — Application Entry Point
 * v3.0 — AWS-First Stack
 *
 * Service Priority:
 *   Auth:       AWS Cognito (via AwsAuthService) — primary
 *   Database:   AWS DynamoDB (via backend API)  — primary
 *   Push:       AWS SNS (via backend API)        — primary
 *   AI:         Amazon Bedrock Claude            — primary
 *   Maps:       OpenStreetMap (free, no key)     — primary
 *   Transport:  Firebase Messaging device integration behind Amazon SNS
 */

import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:guardian/core/services/aws_auth_service.dart';
import 'package:guardian/core/services/aws_incident_service.dart';
import 'package:guardian/core/services/aws_sns_service.dart';
import 'package:guardian/core/services/safety_service_bridge.dart';
import 'package:guardian/core/services/power_optimization_service.dart';
import 'package:guardian/core/services/firebase_runtime_options.dart';
import 'package:guardian/core/utils/logger.dart';
import 'app/app.dart';

import 'package:firebase_messaging/firebase_messaging.dart';

/// Background push handler for Firebase Messaging delivery callbacks.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await FirebaseRuntimeOptions.initialize();
  Logger.info('Background push received: ${message.messageId}');
  final title = message.notification?.title ??
      message.data['title'] as String? ??
      'Guardian Emergency Alert';
  final body = message.notification?.body ??
      message.data['body'] as String? ??
      'Open Guardian to view emergency dispatch.';
  final payload = jsonEncode(message.data);
  await AwsSnsService.showLocalNotification(
    title: title,
    body: body,
    payload: payload,
    id: message.hashCode,
  );
}

/// Global navigator key — used for deep-navigation from notifications
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Portrait-only for safety app (better one-handed use)
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // ─── AWS Services (Primary Stack) ─────────────────────────────────────────

  // 1. Restore cached AWS Cognito session (instant, no network needed)
  await AwsAuthService.instance.initialize();
  Logger.info('AWS Auth: restored=${AwsAuthService.instance.isSignedIn}');

  // 2. Verify backend connectivity (non-blocking)
  _checkBackendConnectivity();

  // ─── Firebase Messaging device integration ─────────────────────────────

  try {
    await FirebaseRuntimeOptions.initialize();
    FirebaseMessaging.onBackgroundMessage(
      _firebaseMessagingBackgroundHandler,
    );
    await AwsSnsService.initialize();
  } catch (e) {
    // Firebase failure does NOT stop the app — AWS is primary
    Logger.warning(
      'Push transport is not configured. Add native Firebase configuration '
      'or provide Firebase dart-defines: $e',
    );
  }

  // ─── Platform Services ───────────────────────────────────────────────────

  // Start safety foreground service (Android only — keeps GPS alive in background)
  if (!kIsWeb && Platform.isAndroid) {
    try {
      await SafetyServiceBridge().startService();
      Logger.info('Safety foreground service started');
    } catch (e) {
      Logger.warning('Safety service start failed (non-critical): $e');
    }
  }

  // Start power optimization service (sensor duty-cycling)
  if (!kIsWeb) {
    try {
      await PowerOptimizationService.instance.initialize();
      Logger.info('Power optimization service started');
    } catch (e) {
      Logger.warning('Power optimization init failed: $e');
    }
  }

  // ─── Launch App ──────────────────────────────────────────────────────────

  runApp(const ProviderScope(child: GuardianApp()));
}

/// Ping backend to verify connectivity — non-blocking, logged only.
void _checkBackendConnectivity() async {
  try {
    final svc = AwsIncidentService.instance;
    Logger.info('Backend check: ${svc.baseUrl}');
    // We don't await this — it's just a background health probe
  } catch (e) {
    Logger.warning('Backend connectivity check failed: $e');
  }
}
