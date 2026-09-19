import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guardian/core/database/guardian_database.dart';
import 'package:guardian/core/models/user_model.dart';
import 'package:guardian/core/providers/contacts_provider.dart';
import 'package:guardian/core/services/aws_auth_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockAwsAuthService extends Mock implements AwsAuthService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late GuardianDatabase database;
  late ContactsNotifier notifier;

  Future<ContactsNotifier> createNotifier() async {
    final value = ContactsNotifier(
      database: database,
      ownerUserId: 'test-user',
    );
    await value.ready;
    return value;
  }

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    database = GuardianDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    notifier.dispose();
    await database.close();
  });

  group('ContactsNotifier', () {
    test('starts empty and persists a new primary contact', () async {
      notifier = await createNotifier();

      await notifier.addContact(const EmergencyContact(
        id: 'contact-1',
        name: 'Sister',
        phone: '+919999988888',
        relation: 'Sibling',
      ));

      expect(notifier.state.contacts, hasLength(1));
      expect(notifier.state.primaryContact?.name, 'Sister');
      final stored = await database.getAllContacts('test-user');
      expect(stored.single.contactKey, 'contact-1');
      expect(stored.single.pendingSync, isTrue);
    });

    test('switches the primary contact atomically', () async {
      notifier = await createNotifier();
      await notifier.addContact(const EmergencyContact(
        id: 'contact-1',
        name: 'Mom',
        phone: '+919876543210',
        relation: 'Parent',
      ));
      await notifier.addContact(const EmergencyContact(
        id: 'contact-2',
        name: 'Dad',
        phone: '+919876543211',
        relation: 'Parent',
      ));

      await notifier.setPrimaryContact(1);

      expect(notifier.state.primaryContact?.id, 'contact-2');
      expect(notifier.state.contacts.where((item) => item.isPrimary),
          hasLength(1));
    });

    test('soft deletion keeps a pending tombstone and promotes a primary',
        () async {
      notifier = await createNotifier();
      await notifier.addContact(const EmergencyContact(
        id: 'contact-1',
        name: 'Mom',
        phone: '+919876543210',
        relation: 'Parent',
      ));
      await notifier.addContact(const EmergencyContact(
        id: 'contact-2',
        name: 'Dad',
        phone: '+919876543211',
        relation: 'Parent',
      ));

      await notifier.removeContact(0);

      expect(notifier.state.contacts, hasLength(1));
      expect(notifier.state.primaryContact?.id, 'contact-2');
      final pending = await database.getPendingSyncContacts('test-user');
      final tombstone = pending.singleWhere(
        (row) => row.contactKey == 'contact-1',
      );
      expect(tombstone.deletedAt, isNotNull);
    });

    test('migrates legacy SharedPreferences contacts exactly once', () async {
      SharedPreferences.setMockInitialValues({
        'guardian_emergency_contacts': jsonEncode([
          {
            'id': 'legacy-1',
            'name': 'Legacy Contact',
            'phone': '+919000000000',
            'relation': 'Friend',
            'is_primary': true,
          }
        ]),
      });

      notifier = await createNotifier();

      expect(notifier.state.contacts.single.id, 'legacy-1');
      final preferences = await SharedPreferences.getInstance();
      expect(
        preferences.getBool('guardian_contacts_drift_migrated_v1'),
        isTrue,
      );
      expect(preferences.containsKey('guardian_emergency_contacts'), isFalse);
    });

    test('restores offline contacts after the provider restarts', () async {
      notifier = await createNotifier();
      await notifier.addContact(const EmergencyContact(
        id: 'persistent-contact',
        name: 'Persistent Contact',
        phone: '+919000000000',
        relation: 'Friend',
      ));
      notifier.dispose();

      notifier = await createNotifier();

      expect(notifier.state.contacts.single.id, 'persistent-contact');
    });

    test('does not expose contacts belonging to another signed-in account',
        () async {
      notifier = await createNotifier();
      await notifier.addContact(const EmergencyContact(
        id: 'private-contact',
        name: 'Private Contact',
        phone: '+919000000000',
        relation: 'Friend',
      ));
      final otherAccount = ContactsNotifier(
        database: database,
        ownerUserId: 'other-user',
      );
      await otherAccount.ready;

      expect(otherAccount.state.contacts, isEmpty);
      expect(await database.getAllContacts('other-user'), isEmpty);
      otherAccount.dispose();
    });

    test('a deletion tombstone blocks stale cloud bootstrap', () async {
      notifier = await createNotifier();
      await notifier.addContact(const EmergencyContact(
        id: 'deleted-contact',
        name: 'Deleted Contact',
        phone: '+919000000000',
        relation: 'Friend',
      ));
      await notifier.removeContact(0);
      notifier.dispose();
      final authService = MockAwsAuthService();
      when(() => authService.getUserProfile()).thenAnswer((_) async => {
            'emergency_contacts': [
              {
                'id': 'deleted-contact',
                'name': 'Deleted Contact',
                'phone': '+919000000000',
                'relation': 'Friend',
              }
            ],
          });

      notifier = ContactsNotifier(
        database: database,
        ownerUserId: 'test-user',
        authService: authService,
      );
      await notifier.ready;
      await Future<void>.delayed(Duration.zero);

      expect(notifier.state.contacts, isEmpty);
      verifyNever(() => authService.getUserProfile());
    });

    test('enforces the five-contact limit without writing a sixth row',
        () async {
      notifier = await createNotifier();
      for (var index = 0; index < ContactsState.maxContacts; index++) {
        await notifier.addContact(EmergencyContact(
          id: 'contact-$index',
          name: 'Contact $index',
          phone: '+91900000000$index',
          relation: 'Friend',
        ));
      }

      expect(
        () => notifier.addContact(const EmergencyContact(
          id: 'contact-6',
          name: 'Sixth',
          phone: '+919000000006',
          relation: 'Friend',
        )),
        throwsA(isA<StateError>()),
      );
      expect(await database.getAllContacts('test-user'), hasLength(5));
    });
  });
}
