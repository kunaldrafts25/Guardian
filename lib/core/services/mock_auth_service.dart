/*
 * Guardian - Women's Safety App
 * © 2025 All Rights Reserved - Kunal Singh
 * Contact: kunalsingh2514@gmail.com
 */

import 'dart:async';
import 'package:guardian/core/services/mock_data_service.dart';
import 'package:guardian/core/utils/logger.dart';

/// A mock user class to replace Firebase User
class MockUser {
  final String uid;
  final String email;
  final String? displayName;
  final String? photoURL;
  final String? phoneNumber;
  final bool emailVerified;

  MockUser({
    required this.uid,
    required this.email,
    this.displayName,
    this.photoURL,
    this.phoneNumber,
    this.emailVerified = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'displayName': displayName,
      'photoURL': photoURL,
      'phoneNumber': phoneNumber,
      'emailVerified': emailVerified,
    };
  }

  factory MockUser.fromMap(Map<String, dynamic> map) {
    return MockUser(
      uid: map['uid'] ?? '',
      email: map['email'] ?? '',
      displayName: map['displayName'],
      photoURL: map['photoURL'],
      phoneNumber: map['phoneNumber'],
      emailVerified: map['emailVerified'] ?? false,
    );
  }
}

/// A service for handling authentication without Firebase
class MockAuthService {
  static final MockAuthService _instance = MockAuthService._internal();
  static MockUser? _currentUser;
  static final StreamController<MockUser?> _authStateController =
      StreamController<MockUser?>.broadcast();

  // Factory constructor
  factory MockAuthService() {
    return _instance;
  }

  // Internal constructor
  MockAuthService._internal();

  // Get current user
  static MockUser? get currentUser => _currentUser;

  // Get auth state changes stream
  static Stream<MockUser?> get authStateChanges => _authStateController.stream;

  // Initialize the service
  static Future<void> initialize() async {
    // Check if there's a saved user in SharedPreferences
    try {
      final users = await MockDataService.getUsers();
      final savedUserData =
          await MockDataService.getDocument('auth_state', 'current_user');

      if (savedUserData != null && savedUserData['uid'] != null) {
        final String uid = savedUserData['uid'];
        final userDoc = users.firstWhere(
          (user) => user['id'] == uid,
          orElse: () => {},
        );

        if (userDoc.isNotEmpty) {
          _currentUser = MockUser(
            uid: userDoc['id'],
            email: userDoc['email'] ?? '',
            displayName: userDoc['displayName'],
            photoURL: userDoc['photoURL'],
            phoneNumber: userDoc['phoneNumber'],
            emailVerified: userDoc['emailVerified'] ?? false,
          );

          // Update the auth state
          _authStateController.add(_currentUser);

          // Update the MockDataService current user
          MockDataService.setCurrentUser(userDoc, userDoc['id']);

          Logger.info('User restored from saved state: ${_currentUser?.email}');
        }
      }
    } catch (e) {
      Logger.error('Error initializing MockAuthService', e);
    }
  }

  // Sign up with email and password
  static Future<MockUser?> signUpWithEmailAndPassword({
    required String email,
    required String password,
    required String name,
    required String phoneNumber,
  }) async {
    try {
      Logger.info('Attempting to create user with email: $email');

      // Validate email and password
      if (email.isEmpty || !email.contains('@')) {
        throw Exception('Please enter a valid email address');
      }

      if (password.length < 6) {
        throw Exception('Password must be at least 6 characters long');
      }

      // Check if user already exists
      final users = await MockDataService.getUsers();
      final existingUser = users.firstWhere(
        (user) => user['email'] == email,
        orElse: () => {},
      );

      if (existingUser.isNotEmpty) {
        throw Exception(
            'The email address is already in use by another account');
      }

      // Create new user
      final String uid = DateTime.now().millisecondsSinceEpoch.toString();
      final Map<String, dynamic> userData = {
        'id': uid,
        'email': email,
        'displayName': name,
        'phoneNumber': phoneNumber,
        'emailVerified': false,
        'createdAt': DateTime.now().toIso8601String(),
        'lastLogin': DateTime.now().toIso8601String(),
      };

      // Add user to collection
      await MockDataService.addDocument('users', userData);

      // Create user object
      _currentUser = MockUser(
        uid: uid,
        email: email,
        displayName: name,
        phoneNumber: phoneNumber,
      );

      // Save current user state
      await MockDataService.addDocument('auth_state', {
        'id': 'current_user',
        'uid': uid,
      });

      // Update the auth state
      _authStateController.add(_currentUser);

      // Update the MockDataService current user
      MockDataService.setCurrentUser(userData, uid);

      Logger.info('User created successfully: $email');
      return _currentUser;
    } catch (e) {
      Logger.error('Error creating user', e);
      rethrow;
    }
  }

  // Sign in with email and password
  static Future<MockUser?> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      Logger.info('Attempting to sign in user with email: $email');

      // Get users
      final users = await MockDataService.getUsers();

      // Find user with matching email
      final userDoc = users.firstWhere(
        (user) => user['email'] == email,
        orElse: () => {},
      );

      if (userDoc.isEmpty) {
        throw Exception('No user found with this email');
      }

      // In a real app, we would check the password hash
      // For this mock, we'll just assume the password is correct

      // Create user object
      _currentUser = MockUser(
        uid: userDoc['id'],
        email: userDoc['email'] ?? '',
        displayName: userDoc['displayName'],
        photoURL: userDoc['photoURL'],
        phoneNumber: userDoc['phoneNumber'],
        emailVerified: userDoc['emailVerified'] ?? false,
      );

      // Update last login
      await MockDataService.updateDocument('users', userDoc['id'], {
        'lastLogin': DateTime.now().toIso8601String(),
      });

      // Save current user state
      await MockDataService.addDocument('auth_state', {
        'id': 'current_user',
        'uid': userDoc['id'],
      });

      // Update the auth state
      _authStateController.add(_currentUser);

      // Update the MockDataService current user
      MockDataService.setCurrentUser(userDoc, userDoc['id']);

      Logger.info('User signed in successfully: $email');
      return _currentUser;
    } catch (e) {
      Logger.error('Error signing in user', e);
      rethrow;
    }
  }

  // Sign out
  static Future<void> signOut() async {
    try {
      Logger.info('Signing out user: ${_currentUser?.email}');

      // Clear current user
      _currentUser = null;

      // Delete current user state
      await MockDataService.deleteDocument('auth_state', 'current_user');

      // Update the auth state
      _authStateController.add(null);

      // Clear the MockDataService current user
      MockDataService.clearCurrentUser();

      Logger.info('User signed out successfully');
    } catch (e) {
      Logger.error('Error signing out user', e);
      rethrow;
    }
  }

  // Direct login (for development/testing)
  static Future<MockUser?> directLogin() async {
    try {
      Logger.info('Performing direct login for development');

      // Create a test user if none exists
      final users = await MockDataService.getUsers();
      if (users.isEmpty) {
        await signUpWithEmailAndPassword(
          email: 'test@example.com',
          password: 'password123',
          name: 'Test User',
          phoneNumber: '1234567890',
        );
        return _currentUser;
      }

      // Use the first user in the collection
      return await signInWithEmailAndPassword(
        email: users.first['email'],
        password: 'password123', // Dummy password
      );
    } catch (e) {
      Logger.error('Error performing direct login', e);
      return null;
    }
  }
}
