/*
 * Guardian - Women's Safety App
 * © 2025 All Rights Reserved - Kunal Singh
 * Contact: kunalsingh2514@gmail.com
 */

import 'package:guardian/core/services/mock_auth_service.dart';
import 'package:guardian/core/services/mock_data_service.dart';
import 'package:guardian/core/utils/logger.dart';

class AuthRepository {
  // Cache for user data
  static Map<String, dynamic>? _cachedUserData;
  static DateTime? _cacheTimestamp;
  static const Duration _cacheDuration = Duration(minutes: 5);

  // Get current user
  MockUser? get currentUser => MockAuthService.currentUser;

  // Get auth state changes
  Stream<MockUser?> get authStateChanges => MockAuthService.authStateChanges;

  // Sign up with email and password
  Future<MockUser?> signUpWithEmailAndPassword({
    required String email,
    required String password,
    required String name,
    required String phoneNumber,
  }) async {
    try {
      Logger.info('Attempting to create user with email: $email');

      // Validate email and password before attempting to create user
      if (email.isEmpty || !email.contains('@')) {
        throw Exception('Please enter a valid email address');
      }

      if (password.length < 6) {
        throw Exception('Password must be at least 6 characters long');
      }

      return await MockAuthService.signUpWithEmailAndPassword(
        email: email,
        password: password,
        name: name,
        phoneNumber: phoneNumber,
      );
    } catch (e) {
      Logger.error('Error creating user', e);
      rethrow;
    }
  }

  // Sign in with email and password
  Future<MockUser?> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      return await MockAuthService.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } catch (e) {
      _logAuthException(e as Exception);
      rethrow;
    }
  }

  // Direct login for development purposes
  Future<MockUser?> directLogin() async {
    try {
      Logger.warning('Using direct login for development');
      return await MockAuthService.directLogin();
    } catch (e) {
      Logger.error('Error during direct login', e);
      throw Exception('Failed to perform direct login: $e');
    }
  }

  // Sign out
  Future<void> signOut() async {
    await MockAuthService.signOut();

    // Clear cache when signing out
    clearUserDataCache();
  }

  // Reset password
  Future<void> resetPassword(String email) async {
    try {
      // In a mock implementation, we'll just log this
      Logger.info('Password reset requested for email: $email');
    } catch (e) {
      Logger.error('Error resetting password', e);
      rethrow;
    }
  }

  // Update user profile
  Future<void> updateUserProfile({
    String? name,
    String? phoneNumber,
    String? photoUrl,
  }) async {
    try {
      final MockUser? user = MockAuthService.currentUser;
      if (user == null) throw Exception('User not found');

      // Update Firestore data
      final Map<String, dynamic> userData = {};
      if (name != null) userData['displayName'] = name;
      if (phoneNumber != null) userData['phoneNumber'] = phoneNumber;
      if (photoUrl != null) userData['photoURL'] = photoUrl;

      if (userData.isNotEmpty) {
        await MockDataService.updateDocument('users', user.uid, userData);

        // Clear cache to ensure fresh data on next fetch
        clearUserDataCache();
      }
    } catch (e) {
      Logger.error('Error updating user profile', e);
      rethrow;
    }
  }

  // Add emergency contact
  Future<void> addEmergencyContact({
    required String name,
    required String phoneNumber,
    String? relationship,
  }) async {
    try {
      final MockUser? user = MockAuthService.currentUser;
      if (user == null) throw Exception('User not found');

      // Get current user data
      final userData = await getUserData(forceRefresh: true);
      if (userData == null) throw Exception('User data not found');

      // Get current emergency contacts or initialize empty list
      List<Map<String, dynamic>> contacts = [];
      if (userData.containsKey('emergencyContacts')) {
        contacts =
            List<Map<String, dynamic>>.from(userData['emergencyContacts']);
      }

      // Add new contact
      contacts.add({
        'name': name,
        'phone': phoneNumber,
        'relationship': relationship,
      });

      // Update user data
      await MockDataService.updateDocument('users', user.uid, {
        'emergencyContacts': contacts,
      });

      // Clear cache to ensure fresh data on next fetch
      clearUserDataCache();
    } catch (e) {
      throw Exception('Failed to add emergency contact: $e');
    }
  }

  // Remove emergency contact
  Future<void> removeEmergencyContact(String phoneNumber) async {
    try {
      final MockUser? user = MockAuthService.currentUser;
      if (user == null) throw Exception('User not found');

      // Get current user data
      final userData = await getUserData(forceRefresh: true);
      if (userData == null) throw Exception('User data not found');

      // Get current emergency contacts
      if (userData.containsKey('emergencyContacts')) {
        final contacts =
            List<Map<String, dynamic>>.from(userData['emergencyContacts']);
        final updatedContacts = contacts
            .where((contact) => contact['phone'] != phoneNumber)
            .toList();

        await MockDataService.updateDocument('users', user.uid, {
          'emergencyContacts': updatedContacts,
        });

        // Clear cache to ensure fresh data on next fetch
        clearUserDataCache();
      }
    } catch (e) {
      throw Exception('Failed to remove emergency contact: $e');
    }
  }

  // Get user data with caching
  Future<Map<String, dynamic>?> getUserData({bool forceRefresh = false}) async {
    try {
      final MockUser? user = MockAuthService.currentUser;
      if (user == null) return null;

      // Check if we have valid cached data
      if (!forceRefresh &&
          _cachedUserData != null &&
          _cacheTimestamp != null &&
          DateTime.now().difference(_cacheTimestamp!) < _cacheDuration) {
        return _cachedUserData;
      }

      // Fetch fresh data from mock data service
      final userData = await MockDataService.getDocument('users', user.uid);

      // Update cache
      if (userData != null) {
        _cachedUserData = userData;
        _cacheTimestamp = DateTime.now();
      }

      return userData;
    } catch (e) {
      throw Exception('Failed to get user data: $e');
    }
  }

  // Clear user data cache
  void clearUserDataCache() {
    _cachedUserData = null;
    _cacheTimestamp = null;
  }

  // Handle authentication exceptions (used internally)
  void _logAuthException(Exception e) {
    Logger.error('Authentication error', e);
  }
}
