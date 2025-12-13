/*
 * Guardian - Women's Safety App
 * © 2025 All Rights Reserved - Kunal Singh
 * Contact: kunalsingh2514@gmail.com
 */

import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:guardian/core/utils/logger.dart';

class AuthRepository {
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final GoogleSignIn _googleSignIn;

  // Cache for user data
  static Map<String, dynamic>? _cachedUserData;
  static DateTime? _cacheTimestamp;
  static const Duration _cacheDuration = Duration(minutes: 5);

  AuthRepository({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    GoogleSignIn? googleSignIn,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance,
        _googleSignIn = googleSignIn ?? GoogleSignIn(scopes: ['email', 'profile']);

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Get auth state changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Sign up with email and password
  Future<User?> signUpWithEmailAndPassword({
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

      // Create user with Firebase Auth
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = userCredential.user;
      if (user != null) {
        // Update display name
        await user.updateDisplayName(name);

        // Create user document in Firestore
        await _firestore.collection('users').doc(user.uid).set({
          'email': email,
          'displayName': name,
          'phoneNumber': phoneNumber,
          'createdAt': FieldValue.serverTimestamp(),
          'lastLogin': FieldValue.serverTimestamp(),
        });

        Logger.info('User created successfully: ${user.uid}');
      }

      return user;
    } on FirebaseAuthException catch (e) {
      Logger.error('Firebase Auth Error', e);
      throw _handleFirebaseAuthError(e);
    } catch (e) {
      Logger.error('Error creating user', e);
      rethrow;
    }
  }

  // Sign in with email and password
  Future<User?> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      Logger.info('Attempting to sign in user with email: $email');

      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = userCredential.user;
      if (user != null) {
        // Update last login in Firestore (use set with merge to create if doesn't exist)
        await _firestore.collection('users').doc(user.uid).set({
          'email': user.email,
          'lastLogin': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      Logger.info('User signed in successfully: ${user?.uid}');
      return user;
    } on FirebaseAuthException catch (e) {
      Logger.error('Firebase Auth Error', e);
      throw _handleFirebaseAuthError(e);
    } catch (e) {
      Logger.error('Error signing in user', e);
      rethrow;
    }
  }

  // Sign in with Google
  Future<User?> signInWithGoogle() async {
    try {
      Logger.info('Attempting Google Sign-In');

      // Trigger the Google Sign-In flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        Logger.info('Google Sign-In cancelled by user');
        return null;
      }

      // Obtain the auth details from the request
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      // Create a new credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase with the Google credential
      final userCredential = await _auth.signInWithCredential(credential);
      final user = userCredential.user;

      if (user != null) {
        // Check if user document exists, if not create it
        final userDoc = await _firestore.collection('users').doc(user.uid).get();
        if (!userDoc.exists) {
          await _firestore.collection('users').doc(user.uid).set({
            'email': user.email,
            'displayName': user.displayName,
            'photoURL': user.photoURL,
            'authProvider': 'google',
            'createdAt': FieldValue.serverTimestamp(),
            'lastLogin': FieldValue.serverTimestamp(),
          });
          Logger.info('New Google user created: ${user.email}');
        } else {
          await _firestore.collection('users').doc(user.uid).update({
            'lastLogin': FieldValue.serverTimestamp(),
          });
          Logger.info('Existing Google user signed in: ${user.email}');
        }
      }

      return user;
    } on FirebaseAuthException catch (e) {
      Logger.error('Firebase Auth Error during Google Sign-In', e);
      throw _handleFirebaseAuthError(e);
    } catch (e) {
      Logger.error('Error during Google Sign-In', e);
      rethrow;
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      // Sign out from Google if signed in with Google
      if (await _googleSignIn.isSignedIn()) {
        await _googleSignIn.signOut();
      }
      
      await _auth.signOut();
      
      // Clear cache when signing out
      clearUserDataCache();
      
      Logger.info('User signed out successfully');
    } catch (e) {
      Logger.error('Error signing out', e);
      rethrow;
    }
  }

  // Reset password
  Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      Logger.info('Password reset email sent to: $email');
    } on FirebaseAuthException catch (e) {
      Logger.error('Firebase Auth Error', e);
      throw _handleFirebaseAuthError(e);
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
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not found');

      // Update Firebase Auth profile
      if (name != null) {
        await user.updateDisplayName(name);
      }
      if (photoUrl != null) {
        await user.updatePhotoURL(photoUrl);
      }

      // Update Firestore data
      final Map<String, dynamic> userData = {};
      if (name != null) userData['displayName'] = name;
      if (phoneNumber != null) userData['phoneNumber'] = phoneNumber;
      if (photoUrl != null) userData['photoURL'] = photoUrl;

      if (userData.isNotEmpty) {
        await _firestore.collection('users').doc(user.uid).update(userData);

        // Clear cache to ensure fresh data on next fetch
        clearUserDataCache();
      }

      Logger.info('User profile updated successfully');
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
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not found');

      await _firestore.collection('users').doc(user.uid).update({
        'emergencyContacts': FieldValue.arrayUnion([
          {
            'name': name,
            'phone': phoneNumber,
            'relationship': relationship,
          }
        ]),
      });

      // Clear cache to ensure fresh data on next fetch
      clearUserDataCache();
      Logger.info('Emergency contact added: $name');
    } catch (e) {
      throw Exception('Failed to add emergency contact: $e');
    }
  }

  // Remove emergency contact
  Future<void> removeEmergencyContact(String phoneNumber) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not found');

      // Get current user data
      final userData = await getUserData(forceRefresh: true);
      if (userData == null) throw Exception('User data not found');

      // Get current emergency contacts
      if (userData.containsKey('emergencyContacts')) {
        final contacts = List<Map<String, dynamic>>.from(userData['emergencyContacts']);
        final updatedContacts = contacts
            .where((contact) => contact['phone'] != phoneNumber)
            .toList();

        await _firestore.collection('users').doc(user.uid).update({
          'emergencyContacts': updatedContacts,
        });

        // Clear cache to ensure fresh data on next fetch
        clearUserDataCache();
        Logger.info('Emergency contact removed');
      }
    } catch (e) {
      throw Exception('Failed to remove emergency contact: $e');
    }
  }

  // Get user data with caching
  Future<Map<String, dynamic>?> getUserData({bool forceRefresh = false}) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return null;

      // Check if we have valid cached data
      if (!forceRefresh &&
          _cachedUserData != null &&
          _cacheTimestamp != null &&
          DateTime.now().difference(_cacheTimestamp!) < _cacheDuration) {
        return _cachedUserData;
      }

      // Fetch fresh data from Firestore
      final doc = await _firestore.collection('users').doc(user.uid).get();
      final userData = doc.data();

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

  // Handle Firebase Auth errors and convert to user-friendly messages
  Exception _handleFirebaseAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'weak-password':
        return Exception('The password is too weak');
      case 'email-already-in-use':
        return Exception('An account already exists with this email');
      case 'invalid-email':
        return Exception('The email address is invalid');
      case 'user-not-found':
        return Exception('No user found with this email');
      case 'wrong-password':
        return Exception('Incorrect password');
      case 'user-disabled':
        return Exception('This account has been disabled');
      case 'too-many-requests':
        return Exception('Too many attempts. Please try again later');
      case 'operation-not-allowed':
        return Exception('This sign-in method is not enabled');
      case 'invalid-credential':
        return Exception('Invalid email or password');
      default:
        return Exception(e.message ?? 'Authentication failed');
    }
  }
}
