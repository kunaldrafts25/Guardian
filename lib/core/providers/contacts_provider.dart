/*
 * Guardian 2.0 - Women's Safety App
 * © 2025 All Rights Reserved - Kunal Singh
 * 
 * Contacts Provider - Emergency contacts management
 */

import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:guardian/core/models/user_model.dart';
import 'package:guardian/core/utils/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Contact state with list management
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
  }) {
    return ContactsState(
      contacts: contacts ?? this.contacts,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }

  /// Get primary contact
  EmergencyContact? get primaryContact => 
      contacts.where((c) => c.isPrimary).firstOrNull;
  
  /// Number of contacts
  int get count => contacts.length;
  
  /// Max contacts allowed
  static const int maxContacts = 5;
  
  /// Can add more contacts
  bool get canAddMore => contacts.length < maxContacts;
}

/// Contacts state notifier with persistent storage
class ContactsNotifier extends StateNotifier<ContactsState> {
  static const String _storageKey = 'guardian_emergency_contacts';

  static const List<EmergencyContact> defaultContacts = [
    EmergencyContact(
      id: '1',
      name: 'Mom',
      phone: '+91 98765 43210',
      relation: 'Parent',
      isPrimary: true,
    ),
    EmergencyContact(
      id: '2',
      name: 'Dad',
      phone: '+91 98765 43211',
      relation: 'Parent',
      isPrimary: false,
    ),
  ];

  ContactsNotifier() : super(const ContactsState(contacts: defaultContacts)) {
    _loadContacts();
  }

  Future<void> _loadContacts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final storedJson = prefs.getString(_storageKey);
      if (storedJson != null && storedJson.isNotEmpty) {
        final List<dynamic> list = jsonDecode(storedJson) as List<dynamic>;
        final contacts = list
            .map((item) => EmergencyContact.fromJson(item as Map<String, dynamic>))
            .toList();
        state = state.copyWith(contacts: contacts);
        return;
      }
    } catch (e) {
      Logger.error('Failed to load contacts from storage, using defaults', e);
    }
    _loadSampleContacts();
  }

  Future<void> _persistContacts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = state.contacts.map((c) => c.toJson()).toList();
      await prefs.setString(_storageKey, jsonEncode(list));
    } catch (e) {
      Logger.error('Failed to persist contacts to storage', e);
    }
  }

  /// Load sample contacts for initial setup
  void _loadSampleContacts() {
    state = state.copyWith(
      contacts: const [
        EmergencyContact(
          id: '1',
          name: 'Mom',
          phone: '+91 98765 43210',
          relation: 'Parent',
          isPrimary: true,
        ),
        EmergencyContact(
          id: '2',
          name: 'Dad',
          phone: '+91 98765 43211',
          relation: 'Parent',
          isPrimary: false,
        ),
      ],
    );
    _persistContacts();
  }

  /// Add a new contact
  void addContact(EmergencyContact contact) {
    if (!state.canAddMore) {
      Logger.warning('Cannot add more than ${ContactsState.maxContacts} contacts');
      return;
    }
    
    final isPrimary = state.contacts.isEmpty || contact.isPrimary;
    
    List<EmergencyContact> updatedContacts = state.contacts;
    if (isPrimary) {
      updatedContacts = state.contacts.map((c) => 
        EmergencyContact(
          id: c.id,
          name: c.name,
          phone: c.phone,
          relation: c.relation,
          isPrimary: false,
        )
      ).toList();
    }
    
    final newContact = EmergencyContact(
      id: contact.id.isEmpty ? DateTime.now().millisecondsSinceEpoch.toString() : contact.id,
      name: contact.name,
      phone: contact.phone,
      relation: contact.relation,
      isPrimary: isPrimary,
    );
    
    state = state.copyWith(contacts: [...updatedContacts, newContact]);
    _persistContacts();
    Logger.info('📱 Contact added: ${contact.name}');
  }

  /// Update a contact
  void updateContact(int index, EmergencyContact contact) {
    if (index < 0 || index >= state.contacts.length) return;
    
    final updatedContacts = [...state.contacts];
    
    if (contact.isPrimary) {
      for (int i = 0; i < updatedContacts.length; i++) {
        if (i != index) {
          updatedContacts[i] = EmergencyContact(
            id: updatedContacts[i].id,
            name: updatedContacts[i].name,
            phone: updatedContacts[i].phone,
            relation: updatedContacts[i].relation,
            isPrimary: false,
          );
        }
      }
    }
    
    updatedContacts[index] = contact;
    state = state.copyWith(contacts: updatedContacts);
    _persistContacts();
    Logger.info('📱 Contact updated: ${contact.name}');
  }

  /// Remove a contact
  void removeContact(int index) {
    if (index < 0 || index >= state.contacts.length) return;
    
    final removedName = state.contacts[index].name;
    final updatedContacts = [...state.contacts]..removeAt(index);
    
    if (state.contacts[index].isPrimary && updatedContacts.isNotEmpty) {
      updatedContacts[0] = EmergencyContact(
        id: updatedContacts[0].id,
        name: updatedContacts[0].name,
        phone: updatedContacts[0].phone,
        relation: updatedContacts[0].relation,
        isPrimary: true,
      );
    }
    
    state = state.copyWith(contacts: updatedContacts);
    _persistContacts();
    Logger.info('📱 Contact removed: $removedName');
  }

  /// Set primary contact
  void setPrimaryContact(int index) {
    if (index < 0 || index >= state.contacts.length) return;
    
    final updatedContacts = state.contacts.asMap().entries.map((entry) {
      return EmergencyContact(
        id: entry.value.id,
        name: entry.value.name,
        phone: entry.value.phone,
        relation: entry.value.relation,
        isPrimary: entry.key == index,
      );
    }).toList();
    
    state = state.copyWith(contacts: updatedContacts);
    _persistContacts();
    Logger.info('📱 Primary contact set: ${state.contacts[index].name}');
  }

  /// Clear all contacts
  void clearContacts() {
    state = state.copyWith(contacts: []);
    _persistContacts();
    Logger.info('📱 All contacts cleared');
  }
}

/// Contacts provider
final contactsProvider = StateNotifierProvider<ContactsNotifier, ContactsState>((ref) {
  return ContactsNotifier();
});

/// Primary contact provider
final primaryContactProvider = Provider<EmergencyContact?>((ref) {
  return ref.watch(contactsProvider).primaryContact;
});

/// Contacts count provider
final contactsCountProvider = Provider<int>((ref) {
  return ref.watch(contactsProvider).count;
});
