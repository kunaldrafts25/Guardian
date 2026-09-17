/*
 * Guardian 2.0 - Women's Safety App
 * © 2025 All Rights Reserved - Kunal Singh
 * 
 * Authentication Provider
 */

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/auth_service.dart';

/// Firebase Auth instance provider
final firebaseAuthProvider = Provider<FirebaseAuth>((ref) {
  return FirebaseAuth.instance;
});

/// Auth service provider
final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(ref.watch(firebaseAuthProvider));
});

/// Current auth state stream
final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(firebaseAuthProvider).authStateChanges();
});

/// Current user provider
final currentUserProvider = Provider<User?>((ref) {
  return ref.watch(authStateProvider).valueOrNull;
});

/// Phone verification state
enum PhoneVerificationState {
  idle,
  codeSent,
  verifying,
  verified,
  error,
}

/// Phone verification notifier
final phoneVerificationProvider = StateNotifierProvider<PhoneVerificationNotifier, PhoneVerificationState>((ref) {
  return PhoneVerificationNotifier(ref.watch(authServiceProvider));
});

class PhoneVerificationNotifier extends StateNotifier<PhoneVerificationState> {
  final AuthService _authService;
  String? _verificationId;
  // ignore: unused_field
  int? _resendToken;
  String? _errorMessage;
  
  PhoneVerificationNotifier(this._authService) : super(PhoneVerificationState.idle);
  
  String? get errorMessage => _errorMessage;
  String? get verificationId => _verificationId;
  
  /// Send OTP to phone number
  Future<void> sendOtp(String phoneNumber) async {
    state = PhoneVerificationState.verifying;
    _errorMessage = null;
    
    try {
      await _authService.sendOtp(
        phoneNumber: phoneNumber,
        onCodeSent: (verificationId, resendToken) {
          _verificationId = verificationId;
          _resendToken = resendToken;
          state = PhoneVerificationState.codeSent;
        },
        onVerificationFailed: (exception) {
          _errorMessage = exception.message ?? 'Verification failed';
          state = PhoneVerificationState.error;
        },
        onVerificationCompleted: (credential) async {
          // Auto-verification on Android
          await _authService.signInWithCredential(credential);
          state = PhoneVerificationState.verified;
        },
        onAutoRetrievalTimeout: (verificationId) {
          _verificationId = verificationId;
        },
      );
    } catch (e) {
      _errorMessage = e.toString();
      state = PhoneVerificationState.error;
    }
  }
  
  /// Verify OTP
  Future<bool> verifyOtp(String otp) async {
    if (_verificationId == null) {
      _errorMessage = 'Verification ID not found. Please request OTP again.';
      state = PhoneVerificationState.error;
      return false;
    }
    
    state = PhoneVerificationState.verifying;
    
    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: otp,
      );
      
      await _authService.signInWithCredential(credential);
      state = PhoneVerificationState.verified;
      return true;
    } catch (e) {
      _errorMessage = 'Invalid OTP. Please try again.';
      state = PhoneVerificationState.error;
      return false;
    }
  }
  
  /// Resend OTP
  Future<void> resendOtp(String phoneNumber) async {
    await sendOtp(phoneNumber);
  }
  
  /// Reset state
  void reset() {
    state = PhoneVerificationState.idle;
    _verificationId = null;
    _resendToken = null;
    _errorMessage = null;
  }
}

/// Sign out provider
final signOutProvider = Provider<Future<void> Function()>((ref) {
  return () async {
    await ref.read(authServiceProvider).signOut();
  };
});
