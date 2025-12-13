/*
 * Guardian 2.0 - Women's Safety App
 * © 2025 All Rights Reserved - Kunal Singh
 * 
 * Authentication Service
 */

import 'package:firebase_auth/firebase_auth.dart';
import '../utils/logger.dart';

/// Service for handling Firebase Authentication
class AuthService {
  final FirebaseAuth _auth;
  
  AuthService(this._auth);
  
  /// Get current user
  User? get currentUser => _auth.currentUser;
  
  /// Auth state changes stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();
  
  /// Send OTP to phone number
  Future<void> sendOtp({
    required String phoneNumber,
    required void Function(String verificationId, int? resendToken) onCodeSent,
    required void Function(FirebaseAuthException exception) onVerificationFailed,
    required void Function(PhoneAuthCredential credential) onVerificationCompleted,
    required void Function(String verificationId) onAutoRetrievalTimeout,
    int? forceResendingToken,
  }) async {
    try {
      Logger.info('Sending OTP to $phoneNumber');
      
      await _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        timeout: const Duration(seconds: 60),
        forceResendingToken: forceResendingToken,
        verificationCompleted: onVerificationCompleted,
        verificationFailed: onVerificationFailed,
        codeSent: onCodeSent,
        codeAutoRetrievalTimeout: onAutoRetrievalTimeout,
      );
    } catch (e) {
      Logger.error('Error sending OTP', e);
      rethrow;
    }
  }
  
  /// Sign in with phone credential
  Future<UserCredential> signInWithCredential(PhoneAuthCredential credential) async {
    try {
      Logger.info('Signing in with phone credential');
      final userCredential = await _auth.signInWithCredential(credential);
      Logger.info('User signed in: ${userCredential.user?.uid}');
      return userCredential;
    } catch (e) {
      Logger.error('Error signing in with credential', e);
      rethrow;
    }
  }
  
  /// Update user display name
  Future<void> updateDisplayName(String name) async {
    try {
      await _auth.currentUser?.updateDisplayName(name);
      Logger.info('Display name updated to: $name');
    } catch (e) {
      Logger.error('Error updating display name', e);
      rethrow;
    }
  }
  
  /// Update user photo URL
  Future<void> updatePhotoUrl(String url) async {
    try {
      await _auth.currentUser?.updatePhotoURL(url);
      Logger.info('Photo URL updated');
    } catch (e) {
      Logger.error('Error updating photo URL', e);
      rethrow;
    }
  }
  
  /// Sign out
  Future<void> signOut() async {
    try {
      await _auth.signOut();
      Logger.info('User signed out');
    } catch (e) {
      Logger.error('Error signing out', e);
      rethrow;
    }
  }
  
  /// Delete user account
  Future<void> deleteAccount() async {
    try {
      await _auth.currentUser?.delete();
      Logger.info('User account deleted');
    } catch (e) {
      Logger.error('Error deleting account', e);
      rethrow;
    }
  }
}
