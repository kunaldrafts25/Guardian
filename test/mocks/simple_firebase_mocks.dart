/*
 * Guardian - Women's Safety App
 * © 2025 All Rights Reserved - Kunal Singh
 * Contact: kunalsingh2514@gmail.com
 */

import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';

/// A simplified mock of FirebaseAuth for testing
class MockFirebaseAuth {
  final StreamController<User?> _authStateController = StreamController<User?>.broadcast();
  MockUser? _currentUser;

  MockFirebaseAuth({MockUser? currentUser}) {
    _currentUser = currentUser;
    if (currentUser != null) {
      _authStateController.add(currentUser);
    }
  }

  /// Get the current user
  User? get currentUser => _currentUser;

  /// Get the auth state changes stream
  Stream<User?> authStateChanges() {
    return _authStateController.stream;
  }

  /// Get the user changes stream
  Stream<User?> userChanges() {
    return _authStateController.stream;
  }

  /// Sign in with email and password
  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    if (email == 'error@example.com') {
      throw FirebaseAuthException(
        code: 'user-not-found',
        message: 'No user found for that email.',
      );
    }

    if (password == 'wrongpassword') {
      throw FirebaseAuthException(
        code: 'wrong-password',
        message: 'Wrong password provided for that user.',
      );
    }

    _currentUser = MockUser(
      uid: 'user-${DateTime.now().millisecondsSinceEpoch}',
      email: email,
      displayName: 'Test User',
    );
    _authStateController.add(_currentUser);

    return MockUserCredential(user: _currentUser);
  }

  /// Create user with email and password
  Future<UserCredential> createUserWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    if (email == 'exists@example.com') {
      throw FirebaseAuthException(
        code: 'email-already-in-use',
        message: 'The email address is already in use by another account.',
      );
    }

    _currentUser = MockUser(
      uid: 'user-${DateTime.now().millisecondsSinceEpoch}',
      email: email,
      displayName: null,
    );
    _authStateController.add(_currentUser);

    return MockUserCredential(user: _currentUser);
  }

  /// Sign out
  Future<void> signOut() async {
    _currentUser = null;
    _authStateController.add(null);
    return;
  }

  /// Send password reset email
  Future<void> sendPasswordResetEmail({
    required String email,
    ActionCodeSettings? actionCodeSettings,
  }) async {
    if (email == 'error@example.com') {
      throw FirebaseAuthException(
        code: 'user-not-found',
        message: 'No user found for that email.',
      );
    }
    return;
  }

  /// Dispose resources
  void dispose() {
    _authStateController.close();
  }
}

/// A simplified mock of User for testing
class MockUser implements User {
  final String _uid;
  final String? _email;
  final String? _displayName;
  final bool _emailVerified;

  MockUser({
    String? uid,
    String? email,
    String? displayName,
    bool emailVerified = false,
  }) :
    _uid = uid ?? 'mock-uid',
    _email = email ?? 'mock@example.com',
    _displayName = displayName ?? 'Mock User',
    _emailVerified = emailVerified;

  @override
  String get uid => _uid;

  @override
  String? get displayName => _displayName;

  @override
  String? get email => _email;

  @override
  bool get emailVerified => _emailVerified;

  @override
  Future<void> updateDisplayName(String? displayName) async {
    throw UnimplementedError('updateDisplayName is not implemented in MockUser');
  }

  // Implement only the methods needed for testing
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// A simplified mock of UserCredential for testing
class MockUserCredential implements UserCredential {
  final User? _user;

  MockUserCredential({User? user}) : _user = user;

  @override
  User? get user => _user;

  // Implement only the methods needed for testing
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
