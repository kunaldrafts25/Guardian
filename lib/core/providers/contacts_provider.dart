import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:guardian/core/database/guardian_database.dart';
import 'package:guardian/core/models/user_model.dart';
import 'package:guardian/core/providers/auth_provider.dart';
import 'package:guardian/core/services/aws_auth_service.dart';
import 'package:guardian/core/services/safety_service_bridge.dart';
import 'package:guardian/core/utils/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class ContactsState {
  final List<EmergencyContact> contacts;
  final bool isLoading;
  final String? errorMessage;

  const ContactsState({
    this.contacts = const [],
    this.isLoading = false,
    this.errorMessage,
  });

  ContactsState copyWith({
    List<EmergencyContact>? contacts,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
  }) {
    return ContactsState(
      contacts: contacts ?? this.contacts,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }

  EmergencyContact? get primaryContact =>
      contacts.where((contact) => contact.isPrimary).firstOrNull;

  int get count => contacts.length;
  static const int maxContacts = 5;
  bool get canAddMore => contacts.length < maxContacts;
}

/// Drift is the sole runtime source of truth for emergency contacts.
/// SharedPreferences is read only once to migrate older installations.
class ContactsNotifier extends StateNotifier<ContactsState> {
  static const _legacyStorageKey = 'guardian_emergency_contacts';
  static const _migrationMarkerKey = 'guardian_contacts_drift_migrated_v1';

  final GuardianDatabase _database;
  final AwsAuthService _authService;
  final String _ownerUserId;
  final Uuid _uuid;
  StreamSubscription<List<LocalContact>>? _subscription;
  late final Future<void> ready;

  ContactsNotifier({
    required GuardianDatabase database,
    required String ownerUserId,
    AwsAuthService? authService,
    Uuid uuid = const Uuid(),
  })  : _database = database,
        _authService = authService ?? AwsAuthService.instance,
        _ownerUserId = ownerUserId,
        _uuid = uuid,
        super(const ContactsState(isLoading: true)) {
    ready = _initialize();
  }

  Future<void> _initialize() async {
    try {
      if (_ownerUserId.isEmpty) {
        state = const ContactsState(
          errorMessage: 'Sign in to access emergency contacts.',
        );
        return;
      }
      await _migrateLegacyContacts();
      final contacts = await _database.getAllContacts(_ownerUserId);
      await _publishNativeSnapshot(contacts);
      if (!mounted) return;
      state = ContactsState(contacts: contacts.map(_toModel).toList());
      _subscription = _database.watchContacts(_ownerUserId).listen(
        (rows) {
          if (mounted) {
            state = ContactsState(contacts: rows.map(_toModel).toList());
            unawaited(_publishNativeSnapshot(rows));
          }
        },
        onError: (Object error, StackTrace stackTrace) {
          Logger.error(
              'Failed to observe emergency contacts', error, stackTrace);
          if (mounted) {
            state = state.copyWith(
              isLoading: false,
              errorMessage: 'Emergency contacts could not be loaded.',
            );
          }
        },
      );
      unawaited(_bootstrapFromCloudIfEmpty());
    } catch (error, stackTrace) {
      Logger.error(
          'Failed to initialize emergency contacts', error, stackTrace);
      if (mounted) {
        state = const ContactsState(
          errorMessage: 'Emergency contacts could not be loaded.',
        );
      }
    }
  }

  Future<void> _migrateLegacyContacts() async {
    final preferences = await SharedPreferences.getInstance();
    if (preferences.getBool(_migrationMarkerKey) == true) return;

    final existing = await _database.getAllContacts(_ownerUserId);
    final encoded = preferences.getString(_legacyStorageKey);
    if (existing.isEmpty && encoded != null && encoded.isNotEmpty) {
      final decoded = jsonDecode(encoded);
      if (decoded is! List) {
        throw const FormatException('Legacy emergency contacts are not a list');
      }
      final contacts = decoded
          .whereType<Map>()
          .map((item) => EmergencyContact.fromJson(
                Map<String, dynamic>.from(item),
              ))
          .where((contact) =>
              contact.name.trim().isNotEmpty && contact.phone.trim().isNotEmpty)
          .take(ContactsState.maxContacts)
          .toList();

      await _database.transaction(() async {
        final primaryIndex = contacts.indexWhere((item) => item.isPrimary);
        for (var index = 0; index < contacts.length; index++) {
          final contact = contacts[index];
          await _database.upsertContactByKey(_toCompanion(
            contact.copyWith(
              id: contact.id.isEmpty ? _uuid.v4() : contact.id,
              isPrimary: primaryIndex < 0 ? index == 0 : index == primaryIndex,
            ),
          ));
        }
      });
    }

    await preferences.setBool(_migrationMarkerKey, true);
    await preferences.remove(_legacyStorageKey);
  }

  Future<void> _bootstrapFromCloudIfEmpty() async {
    try {
      if (await _database.hasContactRecords(_ownerUserId)) return;
      final profile = await _authService.getUserProfile();
      final rawContacts = profile?['emergency_contacts'];
      if (rawContacts is! List || rawContacts.isEmpty) return;

      final contacts = rawContacts
          .whereType<Map>()
          .map((item) => EmergencyContact.fromJson(
                Map<String, dynamic>.from(item),
              ))
          .where((contact) =>
              contact.name.trim().isNotEmpty && contact.phone.trim().isNotEmpty)
          .take(ContactsState.maxContacts)
          .toList();
      await _database.transaction(() async {
        if (await _database.hasContactRecords(_ownerUserId)) return;
        final primaryIndex = contacts.indexWhere((item) => item.isPrimary);
        for (var index = 0; index < contacts.length; index++) {
          final contact = contacts[index];
          await _database.upsertContactByKey(_toCompanion(
            contact.copyWith(
              id: contact.id.isEmpty ? _uuid.v4() : contact.id,
              isPrimary: primaryIndex < 0 ? index == 0 : index == primaryIndex,
            ),
            pendingSync: false,
          ));
        }
      });
    } catch (error, stackTrace) {
      Logger.warning('Cloud contact bootstrap deferred: $error');
      Logger.debug(stackTrace.toString());
    }
  }

  EmergencyContact _toModel(LocalContact row) => EmergencyContact(
        id: row.contactKey ?? row.id.toString(),
        name: row.name,
        phone: row.phone,
        relation: row.relationship,
        isPrimary: row.isPrimary,
      );

  Future<void> _reloadFromDatabase() async {
    final rows = await _database.getAllContacts(_ownerUserId);
    await _publishNativeSnapshot(rows);
    if (mounted) {
      state = ContactsState(contacts: rows.map(_toModel).toList());
    }
  }

  Future<void> _publishNativeSnapshot(List<LocalContact> rows) async {
    final latestUpdate = rows
        .map((row) => row.updatedAt.millisecondsSinceEpoch)
        .fold<int>(1, (latest, value) => value > latest ? value : latest);
    await SafetyServiceBridge.updateEmergencySnapshot(
      version: latestUpdate,
      userId: _ownerUserId,
      userName: _authService.currentUser?.displayName ??
          _authService.currentPhone ??
          'Guardian user',
      contacts: rows
          .map((row) => {'id': row.contactKey ?? '', 'phone': row.phone})
          .toList(),
    );
  }

  LocalContactsCompanion _toCompanion(
    EmergencyContact contact, {
    bool pendingSync = true,
  }) {
    return LocalContactsCompanion.insert(
      ownerUserId: _ownerUserId,
      contactKey: Value(contact.id),
      contactUid: '',
      name: contact.name.trim(),
      phone: _normalizePhone(contact.phone),
      relationship: Value(contact.relation.trim()),
      isPrimary: Value(contact.isPrimary),
      updatedAt: Value(DateTime.now()),
      pendingSync: Value(pendingSync),
    );
  }

  Future<void> addContact(EmergencyContact contact) async {
    await ready;
    _validateContact(contact);
    final key = contact.id.isEmpty ? _uuid.v4() : contact.id;
    final shouldBePrimary = state.contacts.isEmpty || contact.isPrimary;
    await _database.transaction(() async {
      if ((await _database.getAllContacts(_ownerUserId)).length >=
          ContactsState.maxContacts) {
        throw StateError(
          'No more than ${ContactsState.maxContacts} emergency contacts are allowed.',
        );
      }
      if (shouldBePrimary) await _clearPrimaryContacts();
      await _database.upsertContactByKey(_toCompanion(contact.copyWith(
        id: key,
        isPrimary: shouldBePrimary,
      )));
    });
    await _reloadFromDatabase();
    Logger.info('Emergency contact added: ${contact.name}');
  }

  Future<void> updateContact(int index, EmergencyContact contact) async {
    await ready;
    if (index < 0 || index >= state.contacts.length) return;
    _validateContact(contact);
    final existing = state.contacts[index];
    await _database.transaction(() async {
      if (contact.isPrimary) await _clearPrimaryContacts();
      await _database.upsertContactByKey(_toCompanion(contact.copyWith(
        id: existing.id,
      )));
    });
    await _reloadFromDatabase();
    Logger.info('Emergency contact updated: ${contact.name}');
  }

  Future<void> removeContact(int index) async {
    await ready;
    if (index < 0 || index >= state.contacts.length) return;
    final contact = state.contacts[index];
    await _database.transaction(() async {
      await _database.softDeleteContact(
        _ownerUserId,
        contact.id,
        DateTime.now(),
      );
      if (contact.isPrimary) {
        final remaining = await _database.getAllContacts(_ownerUserId);
        if (remaining.isNotEmpty) {
          await (_database.update(_database.localContacts)
                ..where((row) => row.id.equals(remaining.first.id)))
              .write(LocalContactsCompanion(
            isPrimary: const Value(true),
            updatedAt: Value(DateTime.now()),
            pendingSync: const Value(true),
          ));
        }
      }
    });
    await _reloadFromDatabase();
    Logger.info('Emergency contact removed: ${contact.name}');
  }

  Future<void> setPrimaryContact(int index) async {
    await ready;
    if (index < 0 || index >= state.contacts.length) return;
    final contact = state.contacts[index];
    await _database.transaction(() async {
      await _clearPrimaryContacts();
      final row = await (_database.select(_database.localContacts)
            ..where((candidate) =>
                candidate.ownerUserId.equals(_ownerUserId) &
                candidate.contactKey.equals(contact.id)))
          .getSingle();
      await (_database.update(_database.localContacts)
            ..where((candidate) => candidate.id.equals(row.id)))
          .write(LocalContactsCompanion(
        isPrimary: const Value(true),
        updatedAt: Value(DateTime.now()),
        pendingSync: const Value(true),
      ));
    });
    await _reloadFromDatabase();
    Logger.info('Primary emergency contact set: ${contact.name}');
  }

  Future<void> clearContacts() async {
    await ready;
    final contacts = List<EmergencyContact>.of(state.contacts);
    await _database.transaction(() async {
      final now = DateTime.now();
      for (final contact in contacts) {
        await _database.softDeleteContact(_ownerUserId, contact.id, now);
      }
    });
    await _reloadFromDatabase();
    Logger.info('All emergency contacts removed');
  }

  Future<void> _clearPrimaryContacts() async {
    await (_database.update(_database.localContacts)
          ..where((contact) =>
              contact.ownerUserId.equals(_ownerUserId) &
              contact.isPrimary.equals(true) &
              contact.deletedAt.isNull()))
        .write(LocalContactsCompanion(
      isPrimary: const Value(false),
      updatedAt: Value(DateTime.now()),
      pendingSync: const Value(true),
    ));
  }

  void _validateContact(EmergencyContact contact) {
    if (contact.name.trim().isEmpty) {
      throw const FormatException('Contact name is required.');
    }
    _normalizePhone(contact.phone);
  }

  String _normalizePhone(String value) {
    final normalized = value.trim().replaceAll(RegExp(r'[\s().-]'), '');
    if (!RegExp(r'^\+[1-9][0-9]{7,14}$').hasMatch(normalized)) {
      throw const FormatException(
        'Use international format with country code, for example +919876543210.',
      );
    }
    return normalized;
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

final contactsProvider =
    StateNotifierProvider<ContactsNotifier, ContactsState>((ref) {
  final userId = ref.watch(currentUserProvider)?.uid ?? '';
  return ContactsNotifier(
    database: ref.watch(databaseProvider),
    ownerUserId: userId,
  );
});

final primaryContactProvider = Provider<EmergencyContact?>((ref) {
  return ref.watch(contactsProvider).primaryContact;
});

final contactsCountProvider = Provider<int>((ref) {
  return ref.watch(contactsProvider).count;
});
