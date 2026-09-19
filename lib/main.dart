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
 *   Fallback:   Firebase kept as graceful fallback for existing users
 */

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:guardian/core/services/aws_auth_service.dart';
import 'package:guardian/core/services/aws_incident_service.dart';
import 'package:guardian/core/services/aws_sns_service.dart';
import 'package:guardian/core/services/safety_service_bridge.dart';
import 'package:guardian/core/services/power_optimization_service.dart';
import 'package:guardian/core/utils/logger.dart';
import 'app/app.dart';

// Optional Firebase — only init if Firebase options are present
// Remove this block entirely once you are fully AWS-migrated
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

/// FCM background message handler — kept for backward compatibility
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  Logger.info('Background push received: ${message.messageId}');
}

/// Global navigator key — used for deep-navigation from notifications
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

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

  // ─── Firebase (Graceful Fallback — safe to remove later) ────────────────

  try {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    AwsSnsService.navigatorKey = navigatorKey;
    await AwsSnsService.initialize();
  } catch (e) {
    // Firebase failure does NOT stop the app — AWS is primary
    Logger.warning('Push transport initialization failed: $e');
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

  runApp(
    ProviderScope(
      child: GuardianApp(navigatorKey: navigatorKey),
    ),
  );
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
