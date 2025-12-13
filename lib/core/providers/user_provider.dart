/*
 * Guardian 2.0 - Women's Safety App
 * © 2025 All Rights Reserved - Kunal Singh
 * 
 * User Provider - Riverpod providers for user profile management
 */

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:guardian/core/models/user_model.dart';
import 'package:guardian/core/providers/auth_provider.dart';
import 'package:guardian/core/services/user_service.dart';

/// Firestore instance provider
final firestoreProvider = Provider<FirebaseFirestore>((ref) {
  return FirebaseFirestore.instance;
});

/// User service provider
final userServiceProvider = Provider<UserService>((ref) {
  return UserService(ref.watch(firestoreProvider));
});

/// Stream of current user's profile from Firestore
final userProfileStreamProvider = StreamProvider<UserModel?>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) {
    return Stream.value(null);
  }
  return ref.watch(userServiceProvider).streamUserProfile(user.uid);
});

/// Current user profile (async)
final userProfileProvider = FutureProvider<UserModel?>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return null;
  return ref.watch(userServiceProvider).getUserProfile(user.uid);
});

/// Create or get user profile on first login
final ensureUserProfileProvider = FutureProvider.family<UserModel, void>((ref, _) async {
  final firebaseUser = ref.watch(currentUserProvider);
  if (firebaseUser == null) {
    throw Exception('No authenticated user');
  }
  
  final userService = ref.watch(userServiceProvider);
  
  // Check if profile exists
  final existing = await userService.getUserProfile(firebaseUser.uid);
  if (existing != null) {
    return existing;
  }
  
  // Create new profile
  return userService.createUserProfile(firebaseUser);
});

/// Update profile mutation provider
class ProfileUpdateNotifier extends StateNotifier<AsyncValue<void>> {
  final UserService _userService;
  final String _uid;
  
  ProfileUpdateNotifier(this._userService, this._uid) : super(const AsyncValue.data(null));
  
  Future<void> updateDisplayName(String name) async {
    state = const AsyncValue.loading();
    try {
      await _userService.updateDisplayName(_uid, name);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
  
  Future<void> updatePhotoUrl(String url) async {
    state = const AsyncValue.loading();
    try {
      await _userService.updatePhotoUrl(_uid, url);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
  
  Future<void> updateLocationMode(LocationMode mode) async {
    state = const AsyncValue.loading();
    try {
      await _userService.updateLocationMode(_uid, mode);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
  
  Future<void> addEmergencyContact(EmergencyContact contact) async {
    state = const AsyncValue.loading();
    try {
      await _userService.addEmergencyContact(_uid, contact);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
  
  Future<void> removeEmergencyContact(String contactId) async {
    state = const AsyncValue.loading();
    try {
      await _userService.removeEmergencyContact(_uid, contactId);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

/// Profile update notifier provider
final profileUpdateProvider = StateNotifierProvider<ProfileUpdateNotifier, AsyncValue<void>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) {
    throw Exception('No authenticated user');
  }
  return ProfileUpdateNotifier(ref.watch(userServiceProvider), user.uid);
});

/// Trust score from user profile
final trustScoreProvider = Provider<int>((ref) {
  final profile = ref.watch(userProfileStreamProvider).valueOrNull;
  return profile?.trustScore ?? 0;
});

/// Trust rank from user profile
final trustRankProvider = Provider<TrustRank>((ref) {
  final profile = ref.watch(userProfileStreamProvider).valueOrNull;
  return profile?.trustRank ?? TrustRank.watcher;
});

/// Emergency contacts from user profile
final emergencyContactsProvider = Provider<List<EmergencyContact>>((ref) {
  final profile = ref.watch(userProfileStreamProvider).valueOrNull;
  return profile?.emergencyContacts ?? [];
});
