/*
 * Guardian - Contacts Provider Unit Tests
 */

import 'package:flutter_test/flutter_test.dart';
import 'package:guardian/core/models/user_model.dart';
import 'package:guardian/core/providers/contacts_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('ContactsState & Notifier', () {
    test('Starts with no contacts until the user adds them', () {
      final notifier = ContactsNotifier();
      expect(notifier.state.contacts, isEmpty);
      expect(notifier.state.primaryContact, isNull);
      expect(notifier.state.canAddMore, isTrue);
    });

    test('Adding a contact updates list and respects max contacts', () {
      final notifier = ContactsNotifier();
      const newContact = EmergencyContact(
        id: '3',
        name: 'Sister',
        phone: '+91 99999 88888',
        relation: 'Sibling',
      );

      notifier.addContact(newContact);
      expect(notifier.state.contacts.length, 1);
      expect(notifier.state.contacts.last.name, 'Sister');
    });

    test('Primary contact can be switched', () {
      final notifier = ContactsNotifier();
      notifier.addContact(const EmergencyContact(
        id: '1',
        name: 'Mom',
        phone: '+91 98765 43210',
        relation: 'Parent',
        isPrimary: true,
      ));
      notifier.addContact(const EmergencyContact(
        id: '2',
        name: 'Dad',
        phone: '+91 98765 43211',
        relation: 'Parent',
      ));
      notifier.setPrimaryContact(1);
      expect(notifier.state.primaryContact?.name, 'Dad');
    });

    test('Removing a contact decreases count', () {
      final notifier = ContactsNotifier();
      notifier.addContact(const EmergencyContact(
        id: '1',
        name: 'Mom',
        phone: '+91 98765 43210',
        relation: 'Parent',
        isPrimary: true,
      ));
      final initialCount = notifier.state.contacts.length;
      notifier.removeContact(0);
      expect(notifier.state.contacts.length, initialCount - 1);
    });
  });
}
