import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:guardian/core/database/guardian_database.dart';
import 'package:guardian/core/services/aws_auth_service.dart';
import 'package:guardian/core/services/aws_incident_service.dart';
import 'package:guardian/core/services/connectivity_orchestrator.dart';
import 'package:guardian/core/utils/logger.dart';

final offlineSyncProvider = Provider<OfflineSyncService>((ref) {
  final service = OfflineSyncService(
    db: ref.read(databaseProvider),
    connectivity: ref.read(connectivityProvider),
  );
  service.startWatching();
  ref.onDispose(service.dispose);
  return service;
});

/// Replays durable local writes against AWS after network recovery.
class OfflineSyncService {
  final GuardianDatabase _db;
  final ConnectivityOrchestrator _connectivity;
  StreamSubscription<ConnectivityLayer>? _connectivitySubscription;
  bool _isSyncing = false;

  OfflineSyncService({
    required GuardianDatabase db,
    required ConnectivityOrchestrator connectivity,
  })  : _db = db,
        _connectivity = connectivity;

  void startWatching() {
    _connectivitySubscription =
        _connectivity.connectivityStream.listen((layer) {
      if (layer.canReachCloud) unawaited(_syncAll());
    });
    if (_connectivity.currentLayer.canReachCloud) unawaited(_syncAll());
  }

  Future<void> syncNow() => _syncAll();

  Future<void> _syncAll() async {
    if (_isSyncing || !AwsAuthService.instance.isSignedIn) return;
    _isSyncing = true;
    try {
      await _syncOutbox();
      await _syncLegacyAlerts();
      await _syncContacts();
    } finally {
      _isSyncing = false;
    }
  }

  Future<void> _syncOutbox() async {
    final userId = AwsAuthService.instance.currentUserId;
    if (userId == null) return;

    final operations = await _db.getDueOutboxOperations();
    for (final operation in operations) {
      try {
        final payload = jsonDecode(operation.payloadJson);
        if (payload is! Map<String, dynamic>) {
          throw const FormatException('Outbox payload must be a JSON object');
        }
        switch (operation.operationType) {
          case 'createIncident':
            final localAlert = await _db.getAlert(operation.aggregateId);
            if (localAlert == null ||
                const {'resolved', 'cancelled', 'expired'}
                    .contains(localAlert.status)) {
              await _db.markOutboxSuperseded(
                operation.operationId,
                'Create skipped because the local incident is absent or terminal',
              );
              continue;
            }
            final locationValue = payload['location'];
            final motionValue = payload['motion_data'];
            final incident = await AwsIncidentService.instance.createIncident(
              eventId: operation.aggregateId,
              userId: userId,
              eventType: payload['event_type'] as String,
              location: locationValue is Map
                  ? Map<String, dynamic>.from(locationValue)
                  : null,
              motionData: motionValue is Map
                  ? Map<String, dynamic>.from(motionValue)
                  : const <String, dynamic>{'offline_sync': true},
            );
            final cloudIncidentId = incident['incident_id'] as String?;
            if (cloudIncidentId == null || cloudIncidentId.isEmpty) {
              throw const FormatException(
                  'Incident response has no incident_id');
            }
            await _db.recordCloudIncidentCreated(
              alertId: operation.aggregateId,
              cloudIncidentId: cloudIncidentId,
            );
            break;
          case 'updateIncidentStatus':
            final cloudIncidentId = payload['cloud_incident_id'] as String?;
            final targetState = payload['state'] as String?;
            if (cloudIncidentId == null || targetState == null) {
              throw const FormatException(
                'Status operation is missing cloud incident ID or state',
              );
            }
            await AwsIncidentService.instance.updateIncidentStatus(
              cloudIncidentId,
              targetState,
              actor: payload['actor'] as String? ?? 'user',
              note: 'Replayed durable local terminal transition',
            );
            break;
          default:
            throw UnsupportedError(
              'Unsupported outbox operation: ${operation.operationType}',
            );
        }
        await _db.markOutboxSucceeded(operation.operationId);
      } catch (error) {
        await _db.markOutboxRetry(
          operationId: operation.operationId,
          previousAttemptCount: operation.attemptCount,
          error: error.toString(),
        );
        Logger.warning(
          'Outbox ${operation.operationId} remains queued: $error',
        );
      }
    }
  }

  /// Migrates alerts created by database schema v1, before the durable outbox
  /// existed. New alerts are handled only by [_syncOutbox].
  Future<void> _syncLegacyAlerts() async {
    final userId = AwsAuthService.instance.currentUserId;
    if (userId == null) return;
    final alerts = await _db.getUnsyncedAlerts();
    for (final alert in alerts) {
      if (const {'resolved', 'cancelled', 'expired'}.contains(alert.status)) {
        await _db.markAlertSynced(alert.alertId);
        continue;
      }
      final operation =
          await _db.getOutboxOperation('${alert.alertId}:createIncident');
      if (operation != null) continue;
      try {
        final incident = await AwsIncidentService.instance.createIncident(
          eventId: alert.alertId,
          userId: userId,
          eventType: alert.source,
          location: alert.latitude != null && alert.longitude != null
              ? {
                  'latitude': alert.latitude,
                  'longitude': alert.longitude,
                  if (alert.accuracy != null) 'accuracy': alert.accuracy,
                }
              : null,
          motionData: {
            'offline_sync': true,
            'sms_sent': alert.smsSent,
            'sms_count': alert.smsCount,
          },
        );
        final cloudIncidentId = incident['incident_id'] as String?;
        if (cloudIncidentId == null || cloudIncidentId.isEmpty) {
          throw const FormatException('Incident response has no incident_id');
        }
        await _db.recordCloudIncidentCreated(
          alertId: alert.alertId,
          cloudIncidentId: cloudIncidentId,
        );
      } catch (error) {
        Logger.warning('Alert ${alert.alertId} remains queued: $error');
      }
    }
  }

  Future<void> _syncContacts() async {
    final ownerUserId = AwsAuthService.instance.currentUserId;
    if (ownerUserId == null) return;
    final pending = await _db.getPendingSyncContacts(ownerUserId);
    if (pending.isEmpty) return;

    // The API replaces the contact array, so send the complete local set.
    final contacts = await _db.getAllContacts(ownerUserId);
    final saved = await AwsAuthService.instance.saveEmergencyContacts(
      contacts
          .map((contact) => {
                'id': contact.contactKey ?? contact.id.toString(),
                'name': contact.name,
                'phone': contact.phone,
                'relation': contact.relationship,
                'is_primary': contact.isPrimary,
                if (contact.contactUid.isNotEmpty)
                  'contact_uid': contact.contactUid,
              })
          .toList(),
    );
    if (!saved) return;

    final syncedAt = DateTime.now();
    for (final contact in pending) {
      await _db.markContactSynced(contact.id, syncedAt);
    }
  }

  void dispose() {
    _connectivitySubscription?.cancel();
  }
}
