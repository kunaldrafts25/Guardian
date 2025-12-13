/*
 * Guardian - Women's Safety App
 * © 2025 All Rights Reserved - Kunal Singh
 * 
 * Mock Auth Service - Compatibility layer backed by Firebase Auth
 * This provides a simple interface for features that haven't migrated to Firebase yet
 */

import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:guardian/core/utils/logger.dart';

/// A user class that wraps Firebase User for compatibility
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

  /// Create MockUser from Firebase User
  factory MockUser.fromFirebaseUser(User user) {
    return MockUser(
      uid: user.uid,
      email: user.email ?? '',
      displayName: user.displayName,
      photoURL: user.photoURL,
      phoneNumber: user.phoneNumber,
      emailVerified: user.emailVerified,
    );
  }

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
}

/// Compatibility layer for MockAuthService backed by Firebase Auth
class MockAuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // Get current user as MockUser
  static MockUser? get currentUser {
    final firebaseUser = _auth.currentUser;
    if (firebaseUser == null) return null;
    return MockUser.fromFirebaseUser(firebaseUser);
  }

  // Get auth state changes as MockUser stream
  static Stream<MockUser?> get authStateChanges {
    return _auth.authStateChanges().map((user) {
      if (user == null) return null;
      return MockUser.fromFirebaseUser(user);
    });
  }

  // Initialize - no longer needed with Firebase but kept for compatibility
  static Future<void> initialize() async {
    Logger.info('MockAuthService initialized (Firebase-backed)');
  }

  // Sign out
  static Future<void> signOut() async {
    await _auth.signOut();
    Logger.info('User signed out');
  }
}
