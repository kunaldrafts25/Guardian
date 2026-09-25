import 'package:flutter_test/flutter_test.dart';
import 'package:guardian/core/errors/guardian_error_taxonomy.dart';
import 'package:guardian/core/models/user_model.dart';
import 'package:guardian/core/models/emergency_model.dart';
import 'package:guardian/core/models/sms_delivery_state.dart';
import 'package:guardian/core/providers/emergency_provider.dart';
import 'package:guardian/core/services/aws_auth_service.dart';
import 'package:guardian/core/services/backend_health_service.dart';
import 'package:guardian/core/services/responder_service.dart';
import 'package:guardian/core/services/sos_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('P2: Emergency Lifecycle State Semantics', () {
    test('EmergencyLifecycleStage enum defines distinct states', () {
      expect(
          EmergencyLifecycleStage.values,
          containsAll([
            EmergencyLifecycleStage.idle,
            EmergencyLifecycleStage.localEmergencyActive,
            EmergencyLifecycleStage.cloudQueued,
            EmergencyLifecycleStage.cloudDelivering,
            EmergencyLifecycleStage.cloudAcknowledged,
            EmergencyLifecycleStage.contactDeliveryPending,
            EmergencyLifecycleStage.responderSearching,
            EmergencyLifecycleStage.responderInvited,
            EmergencyLifecycleStage.responderAccepted,
            EmergencyLifecycleStage.responderEnRoute,
            EmergencyLifecycleStage.responderArrived,
            EmergencyLifecycleStage.resolved,
            EmergencyLifecycleStage.failedOrPartial,
          ]));
    });

    test('EmergencyState distinguishes local active from cloud delivery stages',
        () {
      const state1 = EmergencyState(
        state: SosState.active,
        lifecycleStage: EmergencyLifecycleStage.localEmergencyActive,
      );
      expect(
          state1.lifecycleStage, EmergencyLifecycleStage.localEmergencyActive);

      final state2 = state1.copyWith(
        lifecycleStage: EmergencyLifecycleStage.cloudQueued,
      );
      expect(state2.lifecycleStage, EmergencyLifecycleStage.cloudQueued);

      final state3 = state2.copyWith(
        lifecycleStage: EmergencyLifecycleStage.cloudAcknowledged,
      );
      expect(state3.lifecycleStage, EmergencyLifecycleStage.cloudAcknowledged);
      expect(state3.lifecycleStage != state1.lifecycleStage, isTrue);
    });
  });

  group('P2: Authentication Lifecycle & UI Consistency', () {
    test('AuthStatus lifecycle enums are complete', () {
      expect(
          AuthStatus.values,
          containsAll([
            AuthStatus.signedOut,
            AuthStatus.authenticating,
            AuthStatus.authenticated,
            AuthStatus.refreshing,
            AuthStatus.reauthenticationRequired,
          ]));
    });

    test('reauthenticationRequired does not falsely claim isSignedIn', () {
      final auth = AwsAuthService.instance;
      expect(auth.authStatus, isA<AuthStatus>());
      // If authStatus is not authenticated, isSignedIn must be false
      if (auth.authStatus != AuthStatus.authenticated) {
        expect(auth.isSignedIn, isFalse);
      }
    });
  });

  group('P2: SMS Model Truth-in-Advertising Cleanup', () {
    test(
        'ContactAlertStatus exposes device acceptance and backward-compatible aliases',
        () {
      const contact = EmergencyContact(
        id: 'c1',
        name: 'Jane Doe',
        phone: '+919876543210',
        relation: 'Sister',
      );

      final status = ContactAlertStatus(
        contact: contact,
        smsAcceptedByDevice: true,
        deliveryState: SmsDeliveryState.osAccepted,
        pushDispatched: false,
        dispatchedAt: DateTime.utc(2026, 9, 24, 12, 0, 0),
      );

      // New truthful getters
      expect(status.smsAcceptedByDevice, isTrue);
      expect(status.pushDispatched, isFalse);
      expect(status.dispatchedAt, DateTime.utc(2026, 9, 24, 12, 0, 0));

      // Deprecated aliases for backward compatibility
      expect(status.smsSent, isTrue);
      expect(status.pushSent, isFalse);
      expect(status.sentAt, DateTime.utc(2026, 9, 24, 12, 0, 0));
    });

    test('SosAlert contactsDispatchedCount computes correctly', () {
      const contact1 = EmergencyContact(
          id: 'c1', name: 'A', phone: '111', relation: 'Sister');
      const contact2 = EmergencyContact(
          id: 'c2', name: 'B', phone: '222', relation: 'Friend');

      final alert = SosAlert(
        id: 'alert_1',
        source: SosTriggerSource.button,
        status: SosAlertStatus.active,
        startedAt: DateTime.now(),
        contactStatuses: [
          const ContactAlertStatus(
            contact: contact1,
            smsAcceptedByDevice: true,
            deliveryState: SmsDeliveryState.osAccepted,
          ),
          const ContactAlertStatus(
            contact: contact2,
            smsAcceptedByDevice: false,
            deliveryState: SmsDeliveryState.notAttempted,
          ),
        ],
      );

      expect(alert.contactsDispatchedCount, 1);
      expect(alert.notifiedCount, 1);
    });

    test(
        'Emergency model provides dispatchedContacts and backward-compatible alias',
        () {
      final emergency = Emergency(
        id: 'em_1',
        userId: 'u_1',
        status: EmergencyStatus.active,
        startedAt: DateTime.now(),
        dispatchedContacts: ['+919876543210', '+919876543211'],
      );

      expect(emergency.dispatchedContacts, hasLength(2));
      expect(emergency.notifiedContacts, hasLength(2));
      expect(emergency.toJson()['dispatchedContacts'], hasLength(2));
    });
  });

  group('P2: Responder Location Freshness Metadata', () {
    test(
        'AuthorizedMissionLocation parses full metadata and determines freshness quality',
        () {
      final now = DateTime.now().toUtc();
      final freshResponse = {
        'latitude': 19.0760,
        'longitude': 72.8777,
        'accuracy': 5.0,
        'captured_at':
            now.subtract(const Duration(seconds: 10)).toIso8601String(),
        'received_at': now.toIso8601String(),
        'age_seconds': 10.0,
        'source': 'DEVICE_GPS',
        'freshness': 'FRESH',
        'grant_expires_at':
            now.add(const Duration(minutes: 15)).millisecondsSinceEpoch ~/ 1000,
      };

      final loc = AuthorizedMissionLocation.fromJson(freshResponse);
      expect(loc.latitude, 19.0760);
      expect(loc.longitude, 72.8777);
      expect(loc.accuracy, 5.0);
      expect(loc.source, 'DEVICE_GPS');
      expect(loc.ageSeconds, 10.0);
      expect(loc.freshness, 'FRESH');
      expect(loc.quality, LocationFreshnessQuality.fresh);
      expect(loc.isFresh, isTrue);
      expect(loc.isStale, isFalse);

      final staleResponse = {
        'latitude': 19.0760,
        'longitude': 72.8777,
        'accuracy': 15.0,
        'captured_at':
            now.subtract(const Duration(seconds: 180)).toIso8601String(),
        'received_at': now.toIso8601String(),
        'age_seconds': 180.0,
        'source': 'DEVICE_GPS',
        'freshness': 'STALE',
        'grant_expires_at':
            now.add(const Duration(minutes: 15)).millisecondsSinceEpoch ~/ 1000,
      };

      final staleLoc = AuthorizedMissionLocation.fromJson(staleResponse);
      expect(staleLoc.quality, LocationFreshnessQuality.stale);
      expect(staleLoc.isStale, isTrue);
      expect(staleLoc.isFresh, isFalse);
    });
  });

  group('P2: Error Taxonomy & Observability Telemetry', () {
    test('GuardianErrorCode covers all required safety failure categories', () {
      expect(
          GuardianErrorCode.values,
          containsAll([
            GuardianErrorCode.locationPermissionDenied,
            GuardianErrorCode.gpsDisabled,
            GuardianErrorCode.locationStale,
            GuardianErrorCode.smsPermissionDenied,
            GuardianErrorCode.smsSubmissionFailed,
            GuardianErrorCode.networkUnavailable,
            GuardianErrorCode.cloudQueued,
            GuardianErrorCode.authExpired,
            GuardianErrorCode.sessionRevoked,
            GuardianErrorCode.responderUnavailable,
            GuardianErrorCode.navigationProviderFailed,
          ]));
    });

    test('GuardianException holds error taxonomy and safe message', () {
      final exc = GuardianException(
        code: GuardianErrorCode.locationPermissionDenied,
        userMessage: 'Location access is disabled.',
        internalDetails:
            'android.permission.ACCESS_FINE_LOCATION denied by user',
        retryable: false,
      );

      expect(exc.code, GuardianErrorCode.locationPermissionDenied);
      expect(exc.userMessage, 'Location access is disabled.');
      expect(exc.retryable, isFalse);
      expect(exc.toString(), contains('LOCATION_PERMISSION_DENIED'));
    });

    test('GuardianSafeTelemetry sanitizes sensitive phone numbers', () {
      expect(
          GuardianSafeTelemetry.sanitizePhone('+919876543210'), '+91*****3210');
      expect(GuardianSafeTelemetry.sanitizePhone('123'), '****');
    });
  });

  group('P2: Backend Health Service', () {
    test('BackendHealthState tracks real health attributes', () {
      final state = BackendHealthState(
        status: HealthConnectivityStatus.connected,
        internetConnected: true,
        apiReachable: true,
        apiHealthStatus: 'healthy',
        authStatus: AuthStatus.authenticated,
        checks: {'database': 'connected', 'auth': 'cognito_configured'},
        timestamp: DateTime.now().toUtc(),
      );

      expect(state.isHealthy, isTrue);
      expect(state.internetConnected, isTrue);
      expect(state.apiReachable, isTrue);
      expect(state.checks['database'], 'connected');
    });
  });
}
