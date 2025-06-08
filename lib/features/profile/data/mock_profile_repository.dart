/*
 * Guardian - Women's Safety App
 * © 2025 All Rights Reserved - Kunal Singh
 * Contact: kunalsingh2514@gmail.com
 */

import 'package:guardian/core/services/mock_auth_service.dart';
import 'package:guardian/core/services/mock_data_service.dart';
import 'package:guardian/core/utils/logger.dart';
import 'package:guardian/features/profile/data/profile_model.dart';

class ProfileRepository {
  // Get user profile
  Future<UserProfile?> getUserProfile() async {
    try {
      final MockUser? user = MockAuthService.currentUser;
      if (user == null) return null;

      final userData = await MockDataService.getDocument('users', user.uid);
      if (userData == null) return null;

      return UserProfile.fromMap(userData);
    } catch (e) {
      Logger.error('Error getting user profile', e);
      return null;
    }
  }

  // Update user profile
  Future<bool> updateUserProfile(UserProfile profile) async {
    try {
      final MockUser? user = MockAuthService.currentUser;
      if (user == null) return false;

      return await MockDataService.updateDocument('users', user.uid, profile.toMap());
    } catch (e) {
      Logger.error('Error updating user profile', e);
      return false;
    }
  }

  // Upload profile picture
  Future<String?> uploadProfilePicture(String localPath) async {
    try {
      // In a mock implementation, we'll just return a placeholder URL
      Logger.info('Mock uploading profile picture from: $localPath');
      return 'https://via.placeholder.com/150';
    } catch (e) {
      Logger.error('Error uploading profile picture', e);
      return null;
    }
  }

  // Get emergency contacts
  Future<List<EmergencyContact>> getEmergencyContacts() async {
    try {
      final MockUser? user = MockAuthService.currentUser;
      if (user == null) return [];

      final userData = await MockDataService.getDocument('users', user.uid);
      if (userData == null) return [];

      if (!userData.containsKey('emergencyContacts')) return [];

      final contacts = List<Map<String, dynamic>>.from(userData['emergencyContacts']);
      return contacts.map((contact) => EmergencyContact.fromMap(contact)).toList();
    } catch (e) {
      Logger.error('Error getting emergency contacts', e);
      return [];
    }
  }

  // Add emergency contact
  Future<bool> addEmergencyContact(EmergencyContact contact) async {
    try {
      final MockUser? user = MockAuthService.currentUser;
      if (user == null) return false;

      // Get current user data
      final userData = await MockDataService.getDocument('users', user.uid);
      if (userData == null) return false;

      // Get current emergency contacts or initialize empty list
      List<Map<String, dynamic>> contacts = [];
      if (userData.containsKey('emergencyContacts')) {
        contacts = List<Map<String, dynamic>>.from(userData['emergencyContacts']);
      }

      // Check if contact already exists
      final existingContact = contacts.firstWhere(
        (c) => c['phone'] == contact.phone,
        orElse: () => {},
      );

      if (existingContact.isNotEmpty) {
        // Update existing contact
        final index = contacts.indexOf(existingContact);
        contacts[index] = contact.toMap();
      } else {
        // Add new contact
        contacts.add(contact.toMap());
      }

      // Update user data
      return await MockDataService.updateDocument('users', user.uid, {
        'emergencyContacts': contacts,
      });
    } catch (e) {
      Logger.error('Error adding emergency contact', e);
      return false;
    }
  }

  // Remove emergency contact
  Future<bool> removeEmergencyContact(String phone) async {
    try {
      final MockUser? user = MockAuthService.currentUser;
      if (user == null) return false;

      // Get current user data
      final userData = await MockDataService.getDocument('users', user.uid);
      if (userData == null) return false;

      // Get current emergency contacts
      if (!userData.containsKey('emergencyContacts')) return false;

      final contacts = List<Map<String, dynamic>>.from(userData['emergencyContacts']);
      final updatedContacts = contacts.where((c) => c['phone'] != phone).toList();

      // Update user data
      return await MockDataService.updateDocument('users', user.uid, {
        'emergencyContacts': updatedContacts,
      });
    } catch (e) {
      Logger.error('Error removing emergency contact', e);
      return false;
    }
  }

  // Get user settings
  Future<Map<String, dynamic>> getUserSettings() async {
    try {
      final MockUser? user = MockAuthService.currentUser;
      if (user == null) return {};

      final userData = await MockDataService.getDocument('users', user.uid);
      if (userData == null) return {};

      // Extract settings or return default settings
      if (userData.containsKey('settings')) {
        return Map<String, dynamic>.from(userData['settings']);
      }

      // Default settings
      return {
        'notifications': true,
        'locationSharing': true,
        'darkMode': false,
        'language': 'en',
      };
    } catch (e) {
      Logger.error('Error getting user settings', e);
      return {};
    }
  }

  // Update user settings
  Future<bool> updateUserSettings(Map<String, dynamic> settings) async {
    try {
      final MockUser? user = MockAuthService.currentUser;
      if (user == null) return false;

      return await MockDataService.updateDocument('users', user.uid, {
        'settings': settings,
      });
    } catch (e) {
      Logger.error('Error updating user settings', e);
      return false;
    }
  }
}
