import 'dart:convert';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guardian/core/database/guardian_database.dart';
import 'package:guardian/core/models/emergency_domain.dart';

void main() {
  late GuardianDatabase database;

  setUp(() {
    database = GuardianDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() => database.close());

  test('queues alert, first event, and cloud operation atomically', () async {
    final startedAt = DateTime.utc(2026, 9, 19, 10);
    final alert = LocalAlertsCompanion.insert(
      alertId: 'alert-1',
      userId: 'user-1',
      source: 'hardware_power_panic',
      status: 'active',
      startedAt: startedAt,
    );
    final payload = <String, dynamic>{
      'event_type': 'hardware_power_panic',
      'motion_data': {'tap_count': 3},
    };

    await database.queueAlertForCloud(
      alert: alert,
      alertId: 'alert-1',
      eventType: 'hardware_power_panic',
      occurredAt: startedAt,
      cloudPayload: payload,
      deliveryAttempts: [
        LocalDeliveryAttemptsCompanion.insert(
          attemptId: 'alert-1:sms:contact-1',
          incidentId: 'alert-1',
          channel: 'sms',
          recipientRef: 'contact-1',
          status: 'accepted',
          queuedAt: startedAt,
          updatedAt: startedAt,
        ),
      ],
    );

    expect(await database.getUnsyncedAlerts(), hasLength(1));
    final events = await database.getIncidentEvents('alert-1');
    expect(events, hasLength(1));
    expect(events.single.incidentState, 'triggered');
    expect(events.single.actorType, 'device');

    final operation =
        await database.getOutboxOperation('alert-1:createIncident');
    expect(operation, isNotNull);
    expect(operation!.status, 'pending');
    expect(jsonDecode(operation.payloadJson), payload);
    final attempts = await database.getDeliveryAttempts('alert-1');
    expect(attempts, hasLength(1));
    expect(attempts.single.status, 'accepted');
    expect(attempts.single.recipientRef, 'contact-1');
  });

  test('replaying the same queue command does not duplicate work', () async {
    final startedAt = DateTime.utc(2026, 9, 19, 10);
    final alert = LocalAlertsCompanion.insert(
      alertId: 'alert-2',
      userId: 'user-1',
      source: 'sos_button',
      status: 'active',
      startedAt: startedAt,
    );

    for (var attempt = 0; attempt < 2; attempt++) {
      await database.queueAlertForCloud(
        alert: alert,
        alertId: 'alert-2',
        eventType: 'sos_button',
        occurredAt: startedAt,
        cloudPayload: const {'event_type': 'sos_button'},
      );
    }

    expect(await database.getUnsyncedAlerts(), hasLength(1));
    expect(await database.getIncidentEvents('alert-2'), hasLength(1));
    expect(await database.select(database.localOutboxOperations).get(),
        hasLength(1));
  });

  test('failed operation is delayed and preserves failure evidence', () async {
    final now = DateTime.utc(2026, 9, 19, 10);
    await database.into(database.localOutboxOperations).insert(
          LocalOutboxOperationsCompanion.insert(
            operationId: 'operation-1',
            aggregateType: 'incident',
            aggregateId: 'alert-1',
            operationType: 'createIncident',
            payloadJson: '{}',
            nextAttemptAt: Value(now),
          ),
        );

    await database.markOutboxRetry(
      operationId: 'operation-1',
      previousAttemptCount: 0,
      error: 'network unavailable',
      now: now,
    );

    final operation = await database.getOutboxOperation('operation-1');
    expect(operation!.attemptCount, 1);
    expect(operation.lastError, 'network unavailable');
    expect(
      operation.nextAttemptAt.toUtc(),
      now.add(const Duration(seconds: 5)),
    );
    expect(
      await database.getDueOutboxOperations(
        now: now.add(const Duration(seconds: 4)),
      ),
      isEmpty,
    );
    expect(
      await database.getDueOutboxOperations(
        now: now.add(const Duration(seconds: 5)),
      ),
      hasLength(1),
    );
  });

  test('v3 contact migration preserves rows and assigns stable keys', () async {
    await database.customStatement('DROP TABLE local_contacts');
    await database.customStatement('''
      CREATE TABLE local_contacts (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        contact_uid TEXT NOT NULL,
        name TEXT NOT NULL,
        phone TEXT NOT NULL,
        relationship TEXT NOT NULL DEFAULT '',
        is_primary INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now')),
        synced_at INTEGER NULL,
        pending_sync INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await database.customStatement('''
      INSERT INTO local_contacts
        (contact_uid, name, phone, relationship, is_primary, created_at)
      VALUES ('', 'Existing contact', '+919000000000', 'Friend', 1, 1000)
    ''');

    await database.migration.onUpgrade(Migrator(database), 3, 4);

    final contacts = await database.getAllContacts('');
    expect(contacts, hasLength(1));
    expect(contacts.single.contactKey, contacts.single.id.toString());
    expect(contacts.single.updatedAt, contacts.single.createdAt);
    expect(contacts.single.deletedAt, isNull);
  });

  test('terminal transition supersedes create and replay cannot reopen alert',
      () async {
    final startedAt = DateTime.utc(2026, 9, 19, 10);
    final companion = LocalAlertsCompanion.insert(
      alertId: 'terminal-alert',
      userId: 'user-1',
      source: 'sos_button',
      status: 'active',
      startedAt: startedAt,
    );
    expect(
      await database.queueAlertForCloud(
        alert: companion,
        alertId: 'terminal-alert',
        eventType: 'sos_button',
        occurredAt: startedAt,
        cloudPayload: const {'event_type': 'sos_button'},
      ),
      isTrue,
    );

    await database.transitionAlertToTerminal(
      alertId: 'terminal-alert',
      terminalState: EmergencyIncidentState.resolved,
      occurredAt: startedAt.add(const Duration(minutes: 1)),
    );
    final replayed = await database.queueAlertForCloud(
      alert: companion,
      alertId: 'terminal-alert',
      eventType: 'sos_button',
      occurredAt: startedAt,
      cloudPayload: const {'event_type': 'sos_button'},
    );

    expect(replayed, isFalse);
    expect((await database.getAlert('terminal-alert'))!.status, 'resolved');
    expect(
      (await database.getOutboxOperation('terminal-alert:createIncident'))!
          .status,
      'superseded',
    );
    expect(await database.getIncidentEvents('terminal-alert'), hasLength(2));
  });

  test('late cloud creation queues terminal state instead of reopening',
      () async {
    final startedAt = DateTime.utc(2026, 9, 19, 10);
    await database.queueAlertForCloud(
      alert: LocalAlertsCompanion.insert(
        alertId: 'late-create',
        userId: 'user-1',
        source: 'hardware_power_panic',
        status: 'active',
        startedAt: startedAt,
      ),
      alertId: 'late-create',
      eventType: 'hardware_power_panic',
      occurredAt: startedAt,
      cloudPayload: const {'event_type': 'hardware_power_panic'},
    );
    await database.transitionAlertToTerminal(
      alertId: 'late-create',
      terminalState: EmergencyIncidentState.resolved,
      occurredAt: startedAt.add(const Duration(seconds: 10)),
    );

    await database.recordCloudIncidentCreated(
      alertId: 'late-create',
      cloudIncidentId: 'inc-cloud-1',
    );

    final alert = await database.getAlert('late-create');
    expect(alert!.status, 'resolved');
    expect(alert.cloudIncidentId, 'inc-cloud-1');
    final operation =
        await database.getOutboxOperation('late-create:update:resolved');
    expect(operation, isNotNull);
    expect(operation!.status, 'pending');
    expect(
      (jsonDecode(operation.payloadJson) as Map<String, dynamic>)['state'],
      'RESOLVED',
    );
  });

  test('active alert restoration is scoped to its authenticated user',
      () async {
    final now = DateTime.utc(2026, 9, 19, 10);
    await database.into(database.localAlerts).insert(
          LocalAlertsCompanion.insert(
            alertId: 'user-a-alert',
            userId: 'user-a',
            source: 'sos_button',
            status: 'cloudAccepted',
            startedAt: now,
          ),
        );
    await database.into(database.localAlerts).insert(
          LocalAlertsCompanion.insert(
            alertId: 'resolved-user-b-alert',
            userId: 'user-b',
            source: 'sos_button',
            status: 'resolved',
            startedAt: now,
          ),
        );

    expect((await database.getActiveAlert('user-a'))?.alertId, 'user-a-alert');
    expect(await database.getActiveAlert('user-b'), isNull);
  });

  test('check-in is durable, account scoped, and replaces an active timer',
      () async {
    final now = DateTime.utc(2026, 9, 19, 10);
    final firstId = await database.createCheckIn(
      LocalCheckInsCompanion.insert(
        ownerUserId: const Value('user-a'),
        operationId: const Value('check-in-1'),
        title: 'Trip home',
        scheduledAt: now.add(const Duration(minutes: 30)),
        graceDeadlineAt: Value(now.add(const Duration(minutes: 35))),
        status: const Value('active'),
      ),
    );
    final secondId = await database.createCheckIn(
      LocalCheckInsCompanion.insert(
        ownerUserId: const Value('user-a'),
        operationId: const Value('check-in-2'),
        title: 'Replacement trip',
        scheduledAt: now.add(const Duration(minutes: 45)),
        graceDeadlineAt: Value(now.add(const Duration(minutes: 50))),
        status: const Value('active'),
      ),
    );

    expect((await database.getActiveCheckIn('user-a'))?.id, secondId);
    expect(await database.getActiveCheckIn('user-b'), isNull);
    final first = await (database.select(database.localCheckIns)
          ..where((row) => row.id.equals(firstId)))
        .getSingle();
    expect(first.status, 'cancelled');
  });

  test('check-in transitions are compare-and-set and cannot be reopened',
      () async {
    final now = DateTime.utc(2026, 9, 19, 10);
    final id = await database.createCheckIn(LocalCheckInsCompanion.insert(
      ownerUserId: const Value('user-a'),
      operationId: const Value('check-in-cas'),
      title: 'Walk',
      scheduledAt: now,
      graceDeadlineAt: Value(now.add(const Duration(minutes: 5))),
      status: const Value('active'),
    ));

    expect(
      await database.transitionCheckIn(
        id: id,
        fromStatuses: const ['active'],
        status: 'awaiting_confirmation',
      ),
      isTrue,
    );
    expect(
      await database.transitionCheckIn(
        id: id,
        fromStatuses: const ['active'],
        status: 'cancelled',
      ),
      isFalse,
    );
    expect(
      await database.transitionCheckIn(
        id: id,
        fromStatuses: const ['awaiting_confirmation'],
        status: 'escalated',
        escalationAlertId: 'alert-from-check-in',
      ),
      isTrue,
    );
    expect(
      await database.extendCheckIn(
        id: id,
        scheduledAt: now.add(const Duration(hours: 1)),
        graceDeadlineAt: now.add(const Duration(hours: 1, minutes: 5)),
      ),
      isFalse,
    );
    final row = await (database.select(database.localCheckIns)
          ..where((entry) => entry.id.equals(id)))
        .getSingle();
    expect(row.status, 'escalated');
    expect(row.escalationAlertId, 'alert-from-check-in');
  });
}
