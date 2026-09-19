import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:guardian/core/database/guardian_database.dart';
import 'package:guardian/core/services/aws_auth_service.dart';
import 'package:guardian/core/services/aws_incident_service.dart';
import 'package:guardian/core/services/ble_emergency_mesh.dart'
    show databaseProvider;
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
      if (operation.operationType != 'createIncident') {
        await _db.markOutboxRetry(
          operationId: operation.operationId,
          previousAttemptCount: operation.attemptCount,
          error: 'Unsupported outbox operation: ${operation.operationType}',
        );
        continue;
      }

      try {
        final payload = jsonDecode(operation.payloadJson);
        if (payload is! Map<String, dynamic>) {
          throw const FormatException('Outbox payload must be a JSON object');
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
        if (incident['incident_id'] == null) {
          throw const FormatException('Incident response has no incident_id');
        }
        await _db.markAlertSynced(operation.aggregateId);
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
      final operation =
          await _db.getOutboxOperation('${alert.alertId}:createIncident');
      if (operation != null) continue;
      try {
        await AwsIncidentService.instance.createIncident(
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
        await _db.markAlertSynced(alert.alertId);
      } catch (error) {
        Logger.warning('Alert ${alert.alertId} remains queued: $error');
      }
    }
  }

  Future<void> _syncContacts() async {
    final pending = await _db.getPendingSyncContacts();
    if (pending.isEmpty) return;

    // The API replaces the contact array, so send the complete local set.
    final contacts = await _db.getAllContacts();
    final saved = await AwsAuthService.instance.saveEmergencyContacts(
      contacts
          .map((contact) => {
                'id': contact.id.toString(),
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
      await _db.upsertContact(LocalContactsCompanion(
        id: Value(contact.id),
        contactUid: Value(contact.contactUid),
        name: Value(contact.name),
        phone: Value(contact.phone),
        relationship: Value(contact.relationship),
        isPrimary: Value(contact.isPrimary),
        createdAt: Value(contact.createdAt),
        syncedAt: Value(syncedAt),
        pendingSync: const Value(false),
      ));
    }
  }

  void dispose() {
    _connectivitySubscription?.cancel();
  }
}
