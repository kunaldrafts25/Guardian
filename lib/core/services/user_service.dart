/*
 * Guardian 2.0 - Women's Safety App
 * © 2025 All Rights Reserved - Kunal Singh
 * 
 * User Service - Firestore operations for user profiles
 */

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:guardian/core/models/user_model.dart';
import 'package:guardian/core/utils/logger.dart';

/// Service for managing user profiles in Firestore
class UserService {
  final FirebaseFirestore _firestore;
  
  UserService(this._firestore);
  
  /// Collection reference
  CollectionReference<Map<String, dynamic>> get _usersCollection => 
      _firestore.collection('users');
  
  /// Create user profile on first login
  Future<UserModel> createUserProfile(User firebaseUser) async {
    try {
      Logger.info('Creating user profile for ${firebaseUser.uid}');
      
      final now = DateTime.now();
      final userModel = UserModel(
        uid: firebaseUser.uid,
        phoneNumber: firebaseUser.phoneNumber ?? '',
        displayName: firebaseUser.displayName,
        photoUrl: firebaseUser.photoURL,
        createdAt: now,
        updatedAt: now,
      );
      
      await _usersCollection.doc(firebaseUser.uid).set(userModel.toJson());
      
      Logger.info('User profile created successfully');
      return userModel;
    } catch (e) {
      Logger.error('Error creating user profile', e);
      rethrow;
    }
  }
  
  /// Get user profile by UID
  Future<UserModel?> getUserProfile(String uid) async {
    try {
      final doc = await _usersCollection.doc(uid).get();
      
      if (!doc.exists) {
        Logger.warning('User profile not found for $uid');
        return null;
      }
      
      return UserModel.fromFirestore(doc);
    } catch (e) {
      Logger.error('Error getting user profile', e);
      rethrow;
    }
  }
  
  /// Stream user profile for real-time updates
  Stream<UserModel?> streamUserProfile(String uid) {
    return _usersCollection
        .doc(uid)
        .snapshots()
        .map((doc) => doc.exists ? UserModel.fromFirestore(doc) : null);
  }
  
  /// Update user profile fields
  Future<void> updateUserProfile(String uid, Map<String, dynamic> data) async {
    try {
      Logger.info('Updating user profile for $uid');
      
      data['updatedAt'] = Timestamp.now();
      
      await _usersCollection.doc(uid).update(data);
      
      Logger.info('User profile updated successfully');
    } catch (e) {
      Logger.error('Error updating user profile', e);
      rethrow;
    }
  }
  
  /// Update display name
  Future<void> updateDisplayName(String uid, String name) async {
    await updateUserProfile(uid, {'displayName': name});
  }
  
  /// Update photo URL
  Future<void> updatePhotoUrl(String uid, String url) async {
    await updateUserProfile(uid, {'photoUrl': url});
  }
  
  /// Update location mode
  Future<void> updateLocationMode(String uid, LocationMode mode) async {
    await updateUserProfile(uid, {'locationMode': mode.name});
  }
  
  /// Add emergency contact
  Future<void> addEmergencyContact(String uid, EmergencyContact contact) async {
    try {
      await _usersCollection.doc(uid).update({
        'emergencyContacts': FieldValue.arrayUnion([contact.toJson()]),
        'updatedAt': Timestamp.now(),
      });
      Logger.info('Emergency contact added');
    } catch (e) {
      Logger.error('Error adding emergency contact', e);
      rethrow;
    }
  }
  
  /// Remove emergency contact
  Future<void> removeEmergencyContact(String uid, String contactId) async {
    try {
      final profile = await getUserProfile(uid);
      if (profile == null) return;
      
      final updatedContacts = profile.emergencyContacts
          .where((c) => c.id != contactId)
          .map((c) => c.toJson())
          .toList();
      
      await updateUserProfile(uid, {'emergencyContacts': updatedContacts});
      Logger.info('Emergency contact removed');
    } catch (e) {
      Logger.error('Error removing emergency contact', e);
      rethrow;
    }
  }
  
  /// Add trust points
  Future<void> addTrustPoints(String uid, int points) async {
    try {
      final profile = await getUserProfile(uid);
      if (profile == null) return;
      
      final newScore = profile.trustScore + points;
      final newRank = UserModel.calculateRank(newScore);
      
      await updateUserProfile(uid, {
        'trustScore': newScore,
        'trustRank': newRank.name,
      });
      
      Logger.info('Added $points trust points. New score: $newScore');
    } catch (e) {
      Logger.error('Error adding trust points', e);
      rethrow;
    }
  }
  
  /// Increment helped count
  Future<void> incrementHelpedCount(String uid) async {
    await _usersCollection.doc(uid).update({
      'helpedCount': FieldValue.increment(1),
      'updatedAt': Timestamp.now(),
    });
  }
  
  /// Increment SOS used count
  Future<void> incrementSosCount(String uid) async {
    await _usersCollection.doc(uid).update({
      'sosUsedCount': FieldValue.increment(1),
      'updatedAt': Timestamp.now(),
    });
  }
  
  /// Delete user profile
  Future<void> deleteUserProfile(String uid) async {
    try {
      Logger.info('Deleting user profile for $uid');
      await _usersCollection.doc(uid).delete();
      Logger.info('User profile deleted');
    } catch (e) {
      Logger.error('Error deleting user profile', e);
      rethrow;
    }
  }
  
  /// Check if user profile exists
  Future<bool> userProfileExists(String uid) async {
    final doc = await _usersCollection.doc(uid).get();
    return doc.exists;
  }
}
