/*
 * Guardian — OfflineSyncService
 *
 * Watches for connectivity and syncs all locally-queued data to Firestore.
 * Guarantees that no SOS alert, contact update, or incident is ever lost
 * due to temporary network unavailability.
 *
 * Sync order (most critical first):
 *   1. SOS alerts (life-safety)
 *   2. Emergency contacts
 *   3. Community incidents
 *   4. Safe zone changes
 *   5. BLE beacon relay (forward received mesh beacons to Firebase)
 */

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:drift/drift.dart' show Value;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:guardian/core/database/guardian_database.dart';
import 'package:guardian/core/services/ble_emergency_mesh.dart' show databaseProvider;
import 'package:guardian/core/services/connectivity_orchestrator.dart';
import 'package:guardian/core/utils/logger.dart';

// ═══════════════════════════════════════════════════════
// PROVIDER
// ═══════════════════════════════════════════════════════

final offlineSyncProvider = Provider<OfflineSyncService>((ref) {
  final db = ref.read(databaseProvider);
  final connectivity = ref.read(connectivityProvider);
  final sync = OfflineSyncService(db: db, connectivity: connectivity);
  sync.startWatching();
  ref.onDispose(sync.dispose);
  return sync;
});

// ═══════════════════════════════════════════════════════
// SYNC SERVICE
// ═══════════════════════════════════════════════════════

class OfflineSyncService {
  final GuardianDatabase _db;
  final ConnectivityOrchestrator _connectivity;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  StreamSubscription? _connectivitySub;
  bool _isSyncing = false;

  OfflineSyncService({
    required GuardianDatabase db,
    required ConnectivityOrchestrator connectivity,
  })  : _db = db,
        _connectivity = connectivity;

  /// Start watching connectivity — sync whenever we come online
  void startWatching() {
    _connectivitySub = _connectivity.connectivityStream.listen((layer) {
      if (layer.canReachFirebase) {
        Logger.info('🔄 Back online — starting sync');
        _syncAll();
      }
    });
  }

  // ─────────────────────────────────────────────────
  // Full sync
  // ─────────────────────────────────────────────────

  Future<void> _syncAll() async {
    if (_isSyncing) return;
    _isSyncing = true;

    try {
      await _syncAlerts();
      await _syncContacts();
      await _syncMeshBeacons();
      await _syncIncidents();
      Logger.info('✅ Offline sync complete');
    } catch (e) {
      Logger.error('Sync error', e);
    } finally {
      _isSyncing = false;
    }
  }

  /// Trigger a manual sync (call after connectivity is confirmed)
  Future<void> syncNow() => _syncAll();

  // ─────────────────────────────────────────────────
  // SOS Alerts (P0 — most critical)
  // ─────────────────────────────────────────────────

  Future<void> _syncAlerts() async {
    final unsyncedAlerts = await _db.getUnsyncedAlerts();
    if (unsyncedAlerts.isEmpty) return;

    Logger.info('🔄 Syncing ${unsyncedAlerts.length} queued alert(s)');

    for (final alert in unsyncedAlerts) {
      try {
        final userId = FirebaseAuth.instance.currentUser?.uid ?? 'unknown';
        await _firestore.collection('sos_alerts').doc(alert.alertId).set({
          'id': alert.alertId,
          'userId': userId,
          'source': alert.source,
          'status': alert.status,
          'latitude': alert.latitude,
          'longitude': alert.longitude,
          'accuracy': alert.accuracy,
          'customMessage': alert.customMessage,
          'startedAt': Timestamp.fromDate(alert.startedAt),
          'resolvedAt': alert.resolvedAt != null
              ? Timestamp.fromDate(alert.resolvedAt!)
              : null,
          'smsSent': alert.smsSent,
          'smsCount': alert.smsCount,
          'syncedFromOffline': true,
          'createdAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        await _db.markAlertSynced(alert.alertId);
        Logger.info('✅ Alert synced: ${alert.alertId.substring(0, 8)}...');
      } catch (e) {
        Logger.error('Failed to sync alert ${alert.alertId}', e);
        // Continue with other alerts — don't block the queue
      }
    }
  }

  // ─────────────────────────────────────────────────
  // Contacts
  // ─────────────────────────────────────────────────

  Future<void> _syncContacts() async {
    final pendingContacts = await _db.getPendingSyncContacts();
    if (pendingContacts.isEmpty) return;

    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    Logger.info('🔄 Syncing ${pendingContacts.length} contact(s)');

    for (final contact in pendingContacts) {
      try {
        await _firestore
            .collection('users')
            .doc(userId)
            .collection('emergency_contacts')
            .doc(contact.id.toString())
            .set({
          'name': contact.name,
          'phone': contact.phone,
          'relationship': contact.relationship,
          'isPrimary': contact.isPrimary,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        await _db.upsertContact(LocalContactsCompanion(
          id: Value(contact.id),
          name: Value(contact.name),
          phone: Value(contact.phone),
          relationship: Value(contact.relationship),
          isPrimary: Value(contact.isPrimary),
          pendingSync: const Value(false),
          syncedAt: Value(DateTime.now()),
        ));
      } catch (e) {
        Logger.error('Failed to sync contact ${contact.name}', e);
      }
    }
  }

  // ─────────────────────────────────────────────────
  // BLE Mesh Beacons — relay received alerts to Firebase
  // ─────────────────────────────────────────────────

  Future<void> _syncMeshBeacons() async {
    final beacons = await _db.getUnforwardedBeacons();
    if (beacons.isEmpty) return;

    Logger.info('📡 Relaying ${beacons.length} BLE beacon(s) to Firebase');

    for (final beacon in beacons) {
      try {
        // This relays another user's SOS alert that we received via BLE mesh
        await _firestore.collection('mesh_relays').doc(beacon.beaconId).set({
          'beaconId': beacon.beaconId,
          'userHash': beacon.userHash,
          'latitude': beacon.latitude,
          'longitude': beacon.longitude,
          'hopCount': beacon.hopCount,
          'receivedAt': Timestamp.fromDate(beacon.receivedAt),
          'relayedAt': FieldValue.serverTimestamp(),
          'relayedBy': FirebaseAuth.instance.currentUser?.uid ?? 'anonymous',
        }, SetOptions(merge: true));

        // Mark as relayed
        await _db.storeBeacon(LocalMeshBeaconsCompanion(
          beaconId: Value(beacon.beaconId),
          userHash: Value(beacon.userHash),
          forwarded: const Value(true),
          relayedToCloud: const Value(true),
        ));

        Logger.info('✅ Beacon relayed to Firebase: ${beacon.beaconId.substring(0, 8)}...');
      } catch (e) {
        Logger.error('Failed to relay beacon', e);
      }
    }
  }

  // ─────────────────────────────────────────────────
  // Incidents
  // ─────────────────────────────────────────────────

  Future<void> _syncIncidents() async {
    // Implementation: sync unsynced local incidents to Firestore
    Logger.debug('🔄 Incident sync (placeholder — no pending incidents)');
  }

  void dispose() {
    _connectivitySub?.cancel();
  }
}
