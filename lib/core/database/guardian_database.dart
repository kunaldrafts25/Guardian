/*
 * Guardian — GuardianDatabase (Drift + SQLite)
 *
 * This is the OFFLINE-FIRST local database. All safety-critical data
 * lives here first and syncs to Firestore when connectivity is available.
 *
 * Tables:
 *   - local_contacts      — emergency contacts (most critical: must survive offline)
 *   - local_alerts        — SOS alerts queued for sync
 *   - local_safe_zones    — geofenced safe zones
 *   - local_check_ins     — scheduled check-ins
 *   - local_location_log  — last N GPS positions for dead reckoning + route learning
 *   - local_mesh_beacons  — received BLE mesh beacons (store-and-forward)
 *   - local_incidents     — community incidents pending sync
 */

import 'package:drift/drift.dart';
import 'connection/connection.dart' as impl;

part 'guardian_database.g.dart';

// ═══════════════════════════════════════════════════════
// TABLE DEFINITIONS
// ═══════════════════════════════════════════════════════

/// Emergency contacts — stored locally, encrypted at rest
class LocalContacts extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get contactUid => text()();           // Firebase UID of contact (if Guardian user)
  TextColumn get name => text()();
  TextColumn get phone => text()();
  TextColumn get relationship => text().withDefault(const Constant(''))();
  BoolColumn get isPrimary => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get syncedAt => dateTime().nullable()();
  BoolColumn get pendingSync => boolean().withDefault(const Constant(false))();
}

/// SOS alerts — created offline, synced when online
class LocalAlerts extends Table {
  TextColumn get alertId => text()();
  TextColumn get userId => text()();
  TextColumn get source => text()();               // 'button', 'shake', 'voice', etc.
  TextColumn get status => text()();               // 'active', 'resolved', 'cancelled'
  RealColumn get latitude => real().nullable()();
  RealColumn get longitude => real().nullable()();
  RealColumn get accuracy => real().nullable()();
  TextColumn get customMessage => text().nullable()();
  DateTimeColumn get startedAt => dateTime()();
  DateTimeColumn get resolvedAt => dateTime().nullable()();
  BoolColumn get smsSent => boolean().withDefault(const Constant(false))();
  IntColumn get smsCount => integer().withDefault(const Constant(0))();
  BoolColumn get syncedToCloud => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {alertId};
}

/// Safe zones — geofenced areas
class LocalSafeZones extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  RealColumn get latitude => real()();
  RealColumn get longitude => real()();
  RealColumn get radiusMeters => real().withDefault(const Constant(200.0))();
  TextColumn get type => text().withDefault(const Constant('safe'))(); // 'safe' | 'avoid'
  BoolColumn get alertOnExit => boolean().withDefault(const Constant(true))();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// Check-ins — scheduled safety check-ins with escalation
class LocalCheckIns extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text()();
  DateTimeColumn get scheduledAt => dateTime()();
  DateTimeColumn get confirmedAt => dateTime().nullable()();
  TextColumn get status => text().withDefault(const Constant('pending'))();
  IntColumn get escalationMinutes => integer().withDefault(const Constant(5))();
  BoolColumn get escalated => boolean().withDefault(const Constant(false))();
  TextColumn get location => text().nullable()();   // Description of where user is
}

/// Location log — rolling window of GPS positions for dead reckoning
class LocalLocationLog extends Table {
  IntColumn get id => integer().autoIncrement()();
  RealColumn get latitude => real()();
  RealColumn get longitude => real()();
  RealColumn get accuracy => real()();
  RealColumn get altitude => real().nullable()();
  RealColumn get speed => real().nullable()();
  RealColumn get heading => real().nullable()();
  TextColumn get provider => text()();             // 'gps' | 'network' | 'dead_reckoning'
  DateTimeColumn get timestamp => dateTime().withDefault(currentDateAndTime)();
}

/// BLE mesh beacons — store-and-forward for offline alert relay
class LocalMeshBeacons extends Table {
  TextColumn get beaconId => text()();             // hash(userHash + timestamp)
  TextColumn get userHash => text()();             // Pseudonymous identifier
  RealColumn get latitude => real().nullable()();
  RealColumn get longitude => real().nullable()();
  IntColumn get hopCount => integer().withDefault(const Constant(0))();
  IntColumn get maxHops => integer().withDefault(const Constant(5))();
  BoolColumn get forwarded => boolean().withDefault(const Constant(false))();
  BoolColumn get relayedToCloud => boolean().withDefault(const Constant(false))();
  DateTimeColumn get receivedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get expiresAt => dateTime()();    // Beacons expire after 24 hours

  @override
  Set<Column> get primaryKey => {beaconId};
}

/// Community incidents pending sync
class LocalIncidents extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get type => text()();
  TextColumn get description => text()();
  RealColumn get latitude => real()();
  RealColumn get longitude => real()();
  TextColumn get address => text().nullable()();
  BoolColumn get anonymous => boolean().withDefault(const Constant(true))();
  BoolColumn get syncedToCloud => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

// ═══════════════════════════════════════════════════════
// DATABASE
// ═══════════════════════════════════════════════════════

@DriftDatabase(tables: [
  LocalContacts,
  LocalAlerts,
  LocalSafeZones,
  LocalCheckIns,
  LocalLocationLog,
  LocalMeshBeacons,
  LocalIncidents,
])
class GuardianDatabase extends _$GuardianDatabase {
  GuardianDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  // ─────────────────────────────────────────────────
  // Contacts
  // ─────────────────────────────────────────────────

  Future<List<LocalContact>> getAllContacts() =>
      select(localContacts).get();

  Stream<List<LocalContact>> watchContacts() =>
      select(localContacts).watch();

  Future<int> upsertContact(LocalContactsCompanion contact) =>
      into(localContacts).insertOnConflictUpdate(contact);

  Future<int> deleteContact(int id) =>
      (delete(localContacts)..where((t) => t.id.equals(id))).go();

  Future<List<LocalContact>> getPendingSyncContacts() =>
      (select(localContacts)..where((t) => t.pendingSync.equals(true))).get();

  // ─────────────────────────────────────────────────
  // Alerts
  // ─────────────────────────────────────────────────

  Future<void> upsertAlert(LocalAlertsCompanion alert) =>
      into(localAlerts).insertOnConflictUpdate(alert);

  Future<List<LocalAlert>> getUnsyncedAlerts() =>
      (select(localAlerts)..where((t) => t.syncedToCloud.equals(false))).get();

  Future<void> markAlertSynced(String alertId) =>
      (update(localAlerts)..where((t) => t.alertId.equals(alertId)))
          .write(const LocalAlertsCompanion(syncedToCloud: Value(true)));

  // ─────────────────────────────────────────────────
  // Location log — keep only last 500 positions
  // ─────────────────────────────────────────────────

  Future<void> logLocation(LocalLocationLogCompanion entry) async {
    await into(localLocationLog).insert(entry);
    // Prune old entries
    final count = await (selectOnly(localLocationLog)
          ..addColumns([localLocationLog.id.count()]))
        .getSingle();
    final total = count.read(localLocationLog.id.count()) ?? 0;
    if (total > 500) {
      final oldest = await (select(localLocationLog)
            ..orderBy([(t) => OrderingTerm.asc(t.timestamp)])
            ..limit(total - 500))
          .get();
      for (final row in oldest) {
        await (delete(localLocationLog)..where((t) => t.id.equals(row.id))).go();
      }
    }
  }

  Future<LocalLocationLogData?> getLastLocation() =>
      (select(localLocationLog)
            ..orderBy([(t) => OrderingTerm.desc(t.timestamp)])
            ..limit(1))
          .getSingleOrNull();

  Future<List<LocalLocationLogData>> getRecentLocations(int count) =>
      (select(localLocationLog)
            ..orderBy([(t) => OrderingTerm.desc(t.timestamp)])
            ..limit(count))
          .get();

  // ─────────────────────────────────────────────────
  // Safe Zones
  // ─────────────────────────────────────────────────

  Future<List<LocalSafeZone>> getActiveSafeZones() =>
      (select(localSafeZones)..where((t) => t.isActive.equals(true))).get();

  Stream<List<LocalSafeZone>> watchSafeZones() =>
      (select(localSafeZones)..where((t) => t.isActive.equals(true))).watch();

  // ─────────────────────────────────────────────────
  // Check-ins
  // ─────────────────────────────────────────────────

  Future<List<LocalCheckIn>> getPendingCheckIns() =>
      (select(localCheckIns)
            ..where((t) => t.status.equals('pending'))
            ..orderBy([(t) => OrderingTerm.asc(t.scheduledAt)]))
          .get();

  Stream<List<LocalCheckIn>> watchCheckIns() =>
      select(localCheckIns).watch();

  Future<int> upsertCheckIn(LocalCheckInsCompanion entry) =>
      into(localCheckIns).insert(entry, mode: InsertMode.insertOrReplace);

  // ─────────────────────────────────────────────────
  // BLE Mesh beacons
  // ─────────────────────────────────────────────────

  Future<bool> hasBeacon(String beaconId) async {
    final row = await (select(localMeshBeacons)
          ..where((t) => t.beaconId.equals(beaconId)))
        .getSingleOrNull();
    return row != null;
  }

  Future<void> storeBeacon(LocalMeshBeaconsCompanion beacon) =>
      into(localMeshBeacons).insertOnConflictUpdate(beacon);

  Future<List<LocalMeshBeacon>> getUnforwardedBeacons() =>
      (select(localMeshBeacons)
            ..where((t) =>
                t.forwarded.equals(false) &
                t.hopCount.isSmallerThan(const Variable(5))))
          .get();

  /// Delete expired beacons (> 24 hours old)
  Future<void> pruneExpiredBeacons() =>
      (delete(localMeshBeacons)
            ..where((t) => t.expiresAt.isSmallerThan(Variable(DateTime.now()))))
          .go();
}

// ═══════════════════════════════════════════════════════
// DATABASE CONNECTION
// ═══════════════════════════════════════════════════════

LazyDatabase _openConnection() {
  return impl.openConnection();
}
