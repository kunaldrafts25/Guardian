/*
 * Guardian — GuardianDatabase (Drift + SQLite)
 *
 * This is the OFFLINE-FIRST local database. All safety-critical data
 * lives here first and syncs to AWS when connectivity is available.
 *
 * Tables:
 *   - local_contacts      — emergency contacts (most critical: must survive offline)
 *   - local_alerts        — SOS alerts queued for sync
 *   - local_safe_zones    — geofenced safe zones
 *   - local_check_ins     — scheduled check-ins
 *   - local_location_log  — last N GPS positions for dead reckoning + route learning
 *   - local_incidents     — community incidents pending sync
 */

import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:guardian/core/models/emergency_domain.dart';
import 'connection/connection.dart' as impl;

part 'guardian_database.g.dart';

// ═══════════════════════════════════════════════════════
// TABLE DEFINITIONS
// ═══════════════════════════════════════════════════════

/// Emergency contacts — stored in OS-protected app storage. The Drift file is
/// not SQLCipher-encrypted; see the storage/privacy ADR before changing this.
class LocalContacts extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get ownerUserId => text()();
  TextColumn get contactKey => text().nullable()();
  TextColumn get contactUid => text()(); // Guardian user ID, when registered
  TextColumn get name => text()();
  TextColumn get phone => text()();
  TextColumn get relationship => text().withDefault(const Constant(''))();
  BoolColumn get isPrimary => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  DateTimeColumn get syncedAt => dateTime().nullable()();
  BoolColumn get pendingSync => boolean().withDefault(const Constant(false))();
}

/// SOS alerts — created offline, synced when online
class LocalAlerts extends Table {
  TextColumn get alertId => text()();
  TextColumn get cloudIncidentId => text().nullable()();
  TextColumn get userId => text()();
  TextColumn get source => text()(); // 'button', 'shake', 'voice', etc.
  TextColumn get status => text()(); // 'active', 'resolved', 'cancelled'
  RealColumn get latitude => real().nullable()();
  RealColumn get longitude => real().nullable()();
  RealColumn get accuracy => real().nullable()();
  TextColumn get customMessage => text().nullable()();
  DateTimeColumn get startedAt => dateTime()();
  DateTimeColumn get resolvedAt => dateTime().nullable()();
  BoolColumn get smsSent => boolean().withDefault(const Constant(false))();
  IntColumn get smsCount => integer().withDefault(const Constant(0))();
  BoolColumn get syncedToCloud =>
      boolean().withDefault(const Constant(false))();
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
  TextColumn get type =>
      text().withDefault(const Constant('safe'))(); // 'safe' | 'avoid'
  BoolColumn get alertOnExit => boolean().withDefault(const Constant(true))();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// Check-ins — scheduled safety check-ins with escalation
class LocalCheckIns extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get ownerUserId => text().withDefault(const Constant(''))();
  TextColumn get operationId => text().withDefault(const Constant(''))();
  TextColumn get title => text()();
  DateTimeColumn get scheduledAt => dateTime()();
  DateTimeColumn get graceDeadlineAt => dateTime().nullable()();
  DateTimeColumn get confirmedAt => dateTime().nullable()();
  TextColumn get status => text().withDefault(const Constant('pending'))();
  IntColumn get escalationMinutes => integer().withDefault(const Constant(5))();
  BoolColumn get escalated => boolean().withDefault(const Constant(false))();
  TextColumn get location =>
      text().nullable()(); // Description of where user is
  TextColumn get escalationAlertId => text().nullable()();
  DateTimeColumn get updatedAt => dateTime().nullable()();
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
  TextColumn get provider => text()(); // 'gps' | 'network' | 'dead_reckoning'
  DateTimeColumn get timestamp => dateTime().withDefault(currentDateAndTime)();
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
  BoolColumn get syncedToCloud =>
      boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// Append-only audit journal for local emergency lifecycle events.
class LocalIncidentEvents extends Table {
  TextColumn get eventId => text()();
  TextColumn get incidentId => text()();
  TextColumn get eventType => text()();
  TextColumn get incidentState => text()();
  TextColumn get actorType => text()();
  TextColumn get actorId => text().nullable()();
  TextColumn get payloadJson => text().withDefault(const Constant('{}'))();
  DateTimeColumn get occurredAt => dateTime()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {eventId};
}

/// Durable operations awaiting an authenticated cloud write.
class LocalOutboxOperations extends Table {
  TextColumn get operationId => text()();
  TextColumn get ownerUserId => text().withDefault(const Constant(''))();
  TextColumn get aggregateType => text()();
  TextColumn get aggregateId => text()();
  TextColumn get operationType => text()();
  TextColumn get payloadJson => text()();
  TextColumn get dependencyId => text().nullable()();
  TextColumn get status => text().withDefault(const Constant('pending'))();
  IntColumn get attemptCount => integer().withDefault(const Constant(0))();
  DateTimeColumn get nextAttemptAt =>
      dateTime().withDefault(currentDateAndTime)();
  TextColumn get lastError => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {operationId};
}

/// Evidence for each recipient/channel delivery. Provider acceptance is not
/// represented as delivery or acknowledgement unless a later receipt proves it.
class LocalDeliveryAttempts extends Table {
  TextColumn get attemptId => text()();
  TextColumn get incidentId => text()();
  TextColumn get channel => text()();
  TextColumn get recipientRef => text()();
  TextColumn get status => text()();
  TextColumn get providerMessageId => text().nullable()();
  TextColumn get failureCode => text().nullable()();
  DateTimeColumn get queuedAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get acknowledgedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {attemptId};
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
  LocalIncidents,
  LocalIncidentEvents,
  LocalOutboxOperations,
  LocalDeliveryAttempts,
])
class GuardianDatabase extends _$GuardianDatabase {
  GuardianDatabase() : super(_openConnection());

  GuardianDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 8;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (migrator) => migrator.createAll(),
        onUpgrade: (migrator, from, to) async {
          if (from < 2 && to >= 2) {
            await migrator.createTable(localIncidentEvents);
            await migrator.createTable(localOutboxOperations);
          }
          if (from < 3 && to >= 3) {
            await migrator.createTable(localDeliveryAttempts);
          }
          if (from < 4 && to >= 4) {
            await migrator.alterTable(
              TableMigration(
                localContacts,
                newColumns: [
                  localContacts.ownerUserId,
                  localContacts.contactKey,
                  localContacts.updatedAt,
                  localContacts.deletedAt,
                ],
                columnTransformer: {
                  localContacts.ownerUserId:
                      const CustomExpression<String>("''"),
                  localContacts.contactKey:
                      const CustomExpression<String>('CAST(id AS TEXT)'),
                  localContacts.updatedAt: localContacts.createdAt,
                },
              ),
            );
          }
          if (from < 5 && to >= 5) {
            await migrator.addColumn(
              localAlerts,
              localAlerts.cloudIncidentId,
            );
          }
          if (from < 6 && to >= 6) {
            await migrator.addColumn(localCheckIns, localCheckIns.ownerUserId);
            await migrator.addColumn(localCheckIns, localCheckIns.operationId);
            await migrator.addColumn(
                localCheckIns, localCheckIns.graceDeadlineAt);
            await migrator.addColumn(
                localCheckIns, localCheckIns.escalationAlertId);
            await migrator.addColumn(localCheckIns, localCheckIns.updatedAt);
          }
          if (from < 7 && to >= 7) {
            await migrator.deleteTable('local_mesh_beacons');
          }
          if (from < 8 && to >= 8) {
            await migrator.addColumn(
              localOutboxOperations,
              localOutboxOperations.ownerUserId,
            );
            // Existing pending incident operations predate owner scoping.
            // Bind only rows that can be proven from their matching local alert;
            // unknown rows remain unowned and therefore cannot replay.
            await customStatement(
              'UPDATE local_outbox_operations '
              'SET owner_user_id = COALESCE(('
              'SELECT user_id FROM local_alerts '
              'WHERE local_alerts.alert_id = local_outbox_operations.aggregate_id'
              '), \'\') '
              'WHERE owner_user_id = \'\'',
            );
          }
        },
      );

  // ─────────────────────────────────────────────────
  // Contacts
  // ─────────────────────────────────────────────────

  Future<List<LocalContact>> getAllContacts(String ownerUserId) =>
      (select(localContacts)
            ..where((contact) =>
                contact.ownerUserId.equals(ownerUserId) &
                contact.deletedAt.isNull())
            ..orderBy([(contact) => OrderingTerm.asc(contact.createdAt)]))
          .get();

  Stream<List<LocalContact>> watchContacts(String ownerUserId) =>
      (select(localContacts)
            ..where((contact) =>
                contact.ownerUserId.equals(ownerUserId) &
                contact.deletedAt.isNull())
            ..orderBy([(contact) => OrderingTerm.asc(contact.createdAt)]))
          .watch();

  Future<bool> hasContactRecords(String ownerUserId) async =>
      await (selectOnly(localContacts)
            ..addColumns([localContacts.id])
            ..where(localContacts.ownerUserId.equals(ownerUserId))
            ..limit(1))
          .getSingleOrNull() !=
      null;

  Future<List<LocalContact>> getPendingSyncContacts(String ownerUserId) =>
      (select(localContacts)
            ..where((contact) =>
                contact.ownerUserId.equals(ownerUserId) &
                contact.pendingSync.equals(true)))
          .get();

  Future<void> markContactSynced(int id, DateTime syncedAt) =>
      (update(localContacts)..where((contact) => contact.id.equals(id))).write(
        LocalContactsCompanion(
          syncedAt: Value(syncedAt),
          pendingSync: const Value(false),
        ),
      );

  Future<void> upsertContactByKey(LocalContactsCompanion contact) async {
    final key = contact.contactKey.value;
    if (key == null || key.isEmpty) {
      throw ArgumentError.value(key, 'contactKey', 'A stable key is required');
    }
    final ownerUserId = contact.ownerUserId.value;
    final existing = await (select(localContacts)
          ..where((row) =>
              row.ownerUserId.equals(ownerUserId) & row.contactKey.equals(key)))
        .getSingleOrNull();
    if (existing == null) {
      await into(localContacts).insert(contact);
    } else {
      await (update(localContacts)..where((row) => row.id.equals(existing.id)))
          .write(contact);
    }
  }

  Future<void> softDeleteContact(
          String ownerUserId, String contactKey, DateTime deletedAt) =>
      (update(localContacts)
            ..where((contact) =>
                contact.ownerUserId.equals(ownerUserId) &
                contact.contactKey.equals(contactKey)))
          .write(LocalContactsCompanion(
        deletedAt: Value(deletedAt),
        updatedAt: Value(deletedAt),
        pendingSync: const Value(true),
      ));

  // ─────────────────────────────────────────────────
  // Alerts
  // ─────────────────────────────────────────────────

  Future<void> upsertAlert(LocalAlertsCompanion alert) =>
      into(localAlerts).insertOnConflictUpdate(alert);

  Future<List<LocalAlert>> getUnsyncedAlerts(String ownerUserId) =>
      (select(localAlerts)
            ..where((t) =>
                t.userId.equals(ownerUserId) &
                t.syncedToCloud.equals(false)))
          .get();

  Future<LocalAlert?> getActiveAlert(String userId) => (select(localAlerts)
        ..where((alert) =>
            alert.userId.equals(userId) &
            alert.status.isNotIn(const ['resolved', 'cancelled', 'expired']))
        ..orderBy([(alert) => OrderingTerm.desc(alert.startedAt)])
        ..limit(1))
      .getSingleOrNull();

  Future<LocalAlert?> getAlert(String alertId) =>
      (select(localAlerts)..where((alert) => alert.alertId.equals(alertId)))
          .getSingleOrNull();

  Future<void> markAlertSynced(String alertId) =>
      (update(localAlerts)..where((t) => t.alertId.equals(alertId)))
          .write(const LocalAlertsCompanion(syncedToCloud: Value(true)));

  Future<void> recordCloudIncidentCreated({
    required String alertId,
    required String cloudIncidentId,
    DateTime? occurredAt,
  }) async {
    final now = occurredAt ?? DateTime.now();
    await transaction(() async {
      final alert = await getAlert(alertId);
      if (alert == null) return;
      final currentState = _incidentStateFromStoredStatus(alert.status);
      await (update(localAlerts)..where((row) => row.alertId.equals(alertId)))
          .write(LocalAlertsCompanion(
        cloudIncidentId: Value(cloudIncidentId),
        status: currentState.isTerminal
            ? const Value.absent()
            : Value(EmergencyIncidentState.cloudAccepted.name),
        syncedToCloud: const Value(true),
      ));
      if (!currentState.isTerminal) {
        await into(localIncidentEvents).insert(
          LocalIncidentEventsCompanion.insert(
            eventId: '$alertId:${EmergencyIncidentState.cloudAccepted.name}',
            incidentId: alertId,
            eventType: EmergencyIncidentState.cloudAccepted.name,
            incidentState: EmergencyIncidentState.cloudAccepted.name,
            actorType: EmergencyActorType.service.name,
            occurredAt: now,
          ),
          mode: InsertMode.insertOrIgnore,
        );
      } else {
        await _queueTerminalCloudUpdate(
          alertId: alertId,
          ownerUserId: alert.userId,
          cloudIncidentId: cloudIncidentId,
          terminalState: currentState,
          occurredAt: alert.resolvedAt ?? now,
        );
      }
    });
  }

  Future<void> transitionAlertToTerminal({
    required String alertId,
    required EmergencyIncidentState terminalState,
    required DateTime occurredAt,
    EmergencyActorType actorType = EmergencyActorType.user,
  }) async {
    if (!terminalState.isTerminal) {
      throw ArgumentError.value(
        terminalState,
        'terminalState',
        'Only a terminal incident state is accepted',
      );
    }
    await transaction(() async {
      final alert = await getAlert(alertId);
      if (alert == null) return;
      final currentState = _incidentStateFromStoredStatus(alert.status);
      if (currentState.isTerminal) return;
      EmergencyStateMachine.validateTransition(currentState, terminalState);
      await (update(localAlerts)..where((row) => row.alertId.equals(alertId)))
          .write(LocalAlertsCompanion(
        status: Value(terminalState.name),
        resolvedAt: Value(occurredAt),
      ));
      await into(localIncidentEvents).insert(
        LocalIncidentEventsCompanion.insert(
          eventId: '$alertId:${terminalState.name}',
          incidentId: alertId,
          eventType: terminalState.name,
          incidentState: terminalState.name,
          actorType: actorType.name,
          occurredAt: occurredAt,
        ),
        mode: InsertMode.insertOrIgnore,
      );
      await (update(localOutboxOperations)
            ..where((operation) =>
                operation.aggregateId.equals(alertId) &
                operation.operationType.equals('createIncident') &
                operation.status.equals(OutboxOperationState.pending.name)))
          .write(LocalOutboxOperationsCompanion(
        status: Value(OutboxOperationState.superseded.name),
        lastError: Value('Incident became ${terminalState.name} before upload'),
        updatedAt: Value(occurredAt),
      ));
      if (alert.cloudIncidentId != null) {
        await _queueTerminalCloudUpdate(
          alertId: alertId,
          ownerUserId: alert.userId,
          cloudIncidentId: alert.cloudIncidentId!,
          terminalState: terminalState,
          occurredAt: occurredAt,
        );
      }
    });
  }

  Future<void> _queueTerminalCloudUpdate({
    required String alertId,
    required String ownerUserId,
    required String cloudIncidentId,
    required EmergencyIncidentState terminalState,
    required DateTime occurredAt,
  }) =>
      into(localOutboxOperations).insert(
        LocalOutboxOperationsCompanion.insert(
          operationId: '$alertId:update:${terminalState.name}',
          ownerUserId: ownerUserId,
          aggregateType: 'incident',
          aggregateId: alertId,
          operationType: 'updateIncidentStatus',
          payloadJson: jsonEncode({
            'cloud_incident_id': cloudIncidentId,
            'state': terminalState.name.toUpperCase(),
            'actor': EmergencyActorType.user.name.toUpperCase(),
            'occurred_at': occurredAt.toUtc().toIso8601String(),
          }),
        ),
        mode: InsertMode.insertOrIgnore,
      );

  /// Atomically records an alert, its first immutable lifecycle event, and the
  /// cloud operation. Replaying the same identifiers is safe.
  Future<bool> queueAlertForCloud({
    required LocalAlertsCompanion alert,
    required String ownerUserId,
    required String alertId,
    required String eventType,
    required DateTime occurredAt,
    required Map<String, dynamic> cloudPayload,
    List<LocalDeliveryAttemptsCompanion> deliveryAttempts = const [],
  }) =>
      transaction(() async {
        final existing = await getAlert(alertId);
        if (existing != null &&
            _incidentStateFromStoredStatus(existing.status).isTerminal) {
          return false;
        }
        if (existing == null) {
          await into(localAlerts).insert(alert);
        }
        await into(localIncidentEvents).insert(
          LocalIncidentEventsCompanion.insert(
            eventId: '$alertId:triggered',
            incidentId: alertId,
            eventType: eventType,
            incidentState: EmergencyIncidentState.triggered.name,
            actorType: EmergencyActorType.device.name,
            occurredAt: occurredAt,
            payloadJson: Value(jsonEncode({
              'source': eventType,
              'schema_version': 1,
            })),
          ),
          mode: InsertMode.insertOrIgnore,
        );
        await into(localOutboxOperations).insert(
          LocalOutboxOperationsCompanion.insert(
            operationId: '$alertId:createIncident',
            ownerUserId: ownerUserId,
            aggregateType: 'incident',
            aggregateId: alertId,
            operationType: 'createIncident',
            payloadJson: jsonEncode(cloudPayload),
          ),
          mode: InsertMode.insertOrIgnore,
        );
        for (final attempt in deliveryAttempts) {
          await into(localDeliveryAttempts).insert(
            attempt,
            mode: InsertMode.insertOrIgnore,
          );
        }
        return true;
      });

  EmergencyIncidentState _incidentStateFromStoredStatus(String status) {
    if (status == 'active') return EmergencyIncidentState.cloudPending;
    return EmergencyIncidentState.values.firstWhere(
      (state) => state.name == status,
      orElse: () => EmergencyIncidentState.triggered,
    );
  }

  Future<List<LocalIncidentEvent>> getIncidentEvents(String incidentId) =>
      (select(localIncidentEvents)
            ..where((event) => event.incidentId.equals(incidentId))
            ..orderBy([(event) => OrderingTerm.asc(event.occurredAt)]))
          .get();

  Future<List<LocalDeliveryAttempt>> getDeliveryAttempts(String incidentId) =>
      (select(localDeliveryAttempts)
            ..where((attempt) => attempt.incidentId.equals(incidentId))
            ..orderBy([(attempt) => OrderingTerm.asc(attempt.queuedAt)]))
          .get();

  Future<List<LocalOutboxOperation>> getDueOutboxOperations({
    required String ownerUserId,
    DateTime? now,
    int limit = 25,
  }) =>
      (select(localOutboxOperations)
            ..where((operation) =>
                operation.ownerUserId.equals(ownerUserId) &
                operation.status.equals(OutboxOperationState.pending.name) &
                operation.nextAttemptAt
                    .isSmallerOrEqualValue(now ?? DateTime.now()))
            ..orderBy([(operation) => OrderingTerm.asc(operation.createdAt)])
            ..limit(limit))
          .get();

  Future<LocalOutboxOperation?> getOutboxOperation(String operationId) =>
      (select(localOutboxOperations)
            ..where((operation) => operation.operationId.equals(operationId)))
          .getSingleOrNull();

  Future<void> markOutboxSucceeded(String operationId) =>
      (update(localOutboxOperations)
            ..where((operation) => operation.operationId.equals(operationId)))
          .write(LocalOutboxOperationsCompanion(
        status: Value(OutboxOperationState.succeeded.name),
        lastError: const Value(null),
        updatedAt: Value(DateTime.now()),
      ));

  Future<void> markOutboxSuperseded(String operationId, String reason) =>
      (update(localOutboxOperations)
            ..where((operation) => operation.operationId.equals(operationId)))
          .write(LocalOutboxOperationsCompanion(
        status: Value(OutboxOperationState.superseded.name),
        lastError:
            Value(reason.length > 500 ? reason.substring(0, 500) : reason),
        updatedAt: Value(DateTime.now()),
      ));

  Future<void> markOutboxRetry({
    required String operationId,
    required int previousAttemptCount,
    required String error,
    DateTime? now,
  }) {
    final attemptCount = previousAttemptCount + 1;
    final base = now ?? DateTime.now();
    final delaySeconds = switch (attemptCount) {
      <= 1 => 5,
      2 => 15,
      3 => 60,
      4 => 300,
      _ => 900,
    };
    return (update(localOutboxOperations)
          ..where((operation) => operation.operationId.equals(operationId)))
        .write(LocalOutboxOperationsCompanion(
      status: Value(OutboxOperationState.pending.name),
      attemptCount: Value(attemptCount),
      nextAttemptAt: Value(base.add(Duration(seconds: delaySeconds))),
      lastError: Value(error.length > 500 ? error.substring(0, 500) : error),
      updatedAt: Value(base),
    ));
  }

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
        await (delete(localLocationLog)..where((t) => t.id.equals(row.id)))
            .go();
      }
    }
  }

  Future<LocalLocationLogData?> getLastLocation() => (select(localLocationLog)
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

  Future<List<LocalSafeZone>> getAllSafeZones() => (select(localSafeZones)
        ..orderBy([(zone) => OrderingTerm.asc(zone.createdAt)]))
      .get();

  Future<int> insertSafeZone(LocalSafeZonesCompanion zone) =>
      into(localSafeZones).insert(zone);

  Future<void> updateSafeZone(int id, LocalSafeZonesCompanion zone) =>
      (update(localSafeZones)..where((table) => table.id.equals(id)))
          .write(zone);

  Future<void> deleteSafeZone(int id) =>
      (delete(localSafeZones)..where((table) => table.id.equals(id))).go();

  // ─────────────────────────────────────────────────
  // Check-ins
  // ─────────────────────────────────────────────────

  Future<List<LocalCheckIn>> getPendingCheckIns([String? ownerUserId]) =>
      (select(localCheckIns)
            ..where((t) =>
                t.status.isIn(const ['active', 'awaiting_confirmation']) &
                (ownerUserId == null
                    ? const Constant(true)
                    : t.ownerUserId.equals(ownerUserId)))
            ..orderBy([(t) => OrderingTerm.asc(t.scheduledAt)]))
          .get();

  Future<LocalCheckIn?> getActiveCheckIn(String ownerUserId) =>
      (select(localCheckIns)
            ..where((t) =>
                t.ownerUserId.equals(ownerUserId) &
                t.status.isIn(const ['active', 'awaiting_confirmation']))
            ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)])
            ..limit(1))
          .getSingleOrNull();

  Stream<List<LocalCheckIn>> watchCheckIns([String? ownerUserId]) =>
      (select(localCheckIns)
            ..where((t) => ownerUserId == null
                ? const Constant(true)
                : t.ownerUserId.equals(ownerUserId)))
          .watch();

  Future<int> upsertCheckIn(LocalCheckInsCompanion entry) =>
      into(localCheckIns).insert(entry, mode: InsertMode.insertOrReplace);

  Future<int> createCheckIn(LocalCheckInsCompanion entry) =>
      transaction(() async {
        final owner = entry.ownerUserId.value;
        await (update(localCheckIns)
              ..where((row) =>
                  row.ownerUserId.equals(owner) &
                  row.status.isIn(const ['active', 'awaiting_confirmation'])))
            .write(LocalCheckInsCompanion(
          status: const Value('cancelled'),
          updatedAt: Value(DateTime.now()),
        ));
        return into(localCheckIns).insert(entry);
      });

  Future<bool> transitionCheckIn({
    required int id,
    required List<String> fromStatuses,
    required String status,
    DateTime? confirmedAt,
    String? escalationAlertId,
  }) async {
    final affected = await (update(localCheckIns)
          ..where((row) => row.id.equals(id) & row.status.isIn(fromStatuses)))
        .write(LocalCheckInsCompanion(
      status: Value(status),
      confirmedAt: Value(confirmedAt),
      escalated: Value(status == 'escalated'),
      escalationAlertId: Value(escalationAlertId),
      updatedAt: Value(DateTime.now()),
    ));
    return affected == 1;
  }

  Future<bool> extendCheckIn({
    required int id,
    required DateTime scheduledAt,
    required DateTime graceDeadlineAt,
  }) async {
    final affected = await (update(localCheckIns)
          ..where((row) =>
              row.id.equals(id) &
              row.status.isIn(const ['active', 'awaiting_confirmation'])))
        .write(LocalCheckInsCompanion(
      scheduledAt: Value(scheduledAt),
      graceDeadlineAt: Value(graceDeadlineAt),
      status: const Value('active'),
      updatedAt: Value(DateTime.now()),
    ));
    return affected == 1;
  }
}

// ═══════════════════════════════════════════════════════
// DATABASE CONNECTION
// ═══════════════════════════════════════════════════════

LazyDatabase _openConnection() {
  return impl.openConnection();
}

final databaseProvider = Provider<GuardianDatabase>((ref) {
  final database = GuardianDatabase();
  ref.onDispose(database.close);
  return database;

  /// Remove old local safety history without touching active/pending evidence.
  ///
  /// The database itself relies on OS application sandbox/device encryption,
  /// so minimizing retained sensitive history is part of the privacy boundary.
  Future<void> pruneLocalSafetyData({
    Duration incidentRetention = const Duration(days: 90),
    Duration locationRetention = const Duration(days: 7),
  }) async {
    final now = DateTime.now();
    final incidentCutoff = now.subtract(incidentRetention);
    final locationCutoff = now.subtract(locationRetention);

    await transaction(() async {
      await (delete(localLocationLog)
            ..where((row) => row.timestamp.isSmallerThanValue(locationCutoff)))
          .go();

      await (delete(localDeliveryAttempts)
            ..where((row) => row.updatedAt.isSmallerThanValue(incidentCutoff)))
          .go();

      await (delete(localIncidentEvents)
            ..where((row) => row.createdAt.isSmallerThanValue(incidentCutoff)))
          .go();

      await (delete(localIncidents)
            ..where((row) =>
                row.syncedToCloud.equals(true) &
                row.createdAt.isSmallerThanValue(incidentCutoff)))
          .go();

      final oldTerminalAlerts = await (select(localAlerts)
            ..where((row) =>
                row.syncedToCloud.equals(true) &
                row.createdAt.isSmallerThanValue(incidentCutoff) &
                row.status.isIn(const ['resolved', 'cancelled', 'expired'])))
          .get();
      for (final alert in oldTerminalAlerts) {
        await (delete(localIncidentEvents)
              ..where((row) => row.incidentId.equals(alert.alertId)))
            .go();
        await (delete(localDeliveryAttempts)
              ..where((row) => row.incidentId.equals(alert.alertId)))
            .go();
        await (delete(localAlerts)
              ..where((row) => row.alertId.equals(alert.alertId)))
            .go();
      }

      await (delete(localCheckIns)
            ..where((row) =>
                row.status.isIn(
                  const ['confirmed', 'cancelled', 'escalated'],
                ) &
                row.scheduledAt.isSmallerThanValue(incidentCutoff)))
          .go();
    });
  }

});
