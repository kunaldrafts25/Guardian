import 'dart:async';

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
      await _syncAlerts();
      await _syncContacts();
    } finally {
      _isSyncing = false;
    }
  }

  Future<void> _syncAlerts() async {
    final userId = AwsAuthService.instance.currentUserId;
    if (userId == null) return;
    final alerts = await _db.getUnsyncedAlerts();
    for (final alert in alerts) {
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
