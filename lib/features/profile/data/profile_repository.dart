/*
 * Guardian - Women's Safety App
 * © 2025 All Rights Reserved - Kunal Singh
 * Contact: kunalsingh2514@gmail.com
 */

import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:guardian/core/models/user_profile.dart';
import 'package:guardian/core/utils/logger.dart';

/// Repository for handling user profile data
class ProfileRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  
  /// Collection reference
  final String _collection = 'users';
  
  /// Get the current user's profile
  Future<UserProfile?> getUserProfile() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        throw Exception('User not authenticated');
      }
      
      final doc = await _firestore.collection(_collection).doc(userId).get();
      
      if (!doc.exists) {
        return null;
      }
      
      return UserProfile.fromMap(doc.data()!, userId);
    } catch (e) {
      Logger.error('Failed to get user profile: $e');
      return null;
    }
  }
  
  /// Create or update the user's profile
  Future<bool> updateUserProfile(UserProfile profile) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        throw Exception('User not authenticated');
      }
      
      await _firestore
          .collection(_collection)
          .doc(userId)
          .set(profile.toMap(), SetOptions(merge: true));
      
      return true;
    } catch (e) {
      Logger.error('Failed to update user profile: $e');
      return false;
    }
  }
  
  /// Upload a profile picture and update the user's profile
  Future<bool> uploadProfilePicture(File imageFile) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        throw Exception('User not authenticated');
      }
      
      // Upload image to Firebase Storage
      final storageRef = _storage.ref().child('profile_pictures/$userId.jpg');
      await storageRef.putFile(imageFile);
      
      // Get download URL
      final downloadUrl = await storageRef.getDownloadURL();
      
      // Update user profile with new image URL
      await _firestore
          .collection(_collection)
          .doc(userId)
          .update({'photoUrl': downloadUrl});
      
      return true;
    } catch (e) {
      Logger.error('Failed to upload profile picture: $e');
      return false;
    }
  }
  
  /// Update user settings
  Future<bool> updateUserSettings(Map<String, dynamic> settings) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        throw Exception('User not authenticated');
      }
      
      await _firestore
          .collection(_collection)
          .doc(userId)
          .update({'settings': settings});
      
      return true;
    } catch (e) {
      Logger.error('Failed to update user settings: $e');
      return false;
    }
  }
  
  /// Delete the user's account
  Future<bool> deleteUserAccount() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        throw Exception('User not authenticated');
      }
      
      // Delete user data from Firestore
      await _firestore.collection(_collection).doc(userId).delete();
      
      // Delete profile picture if exists
      try {
        await _storage.ref().child('profile_pictures/$userId.jpg').delete();
      } catch (e) {
        // Ignore if file doesn't exist
      }
      
      // Delete Firebase Auth user
      await _auth.currentUser!.delete();
      
      return true;
    } catch (e) {
      Logger.error('Failed to delete user account: $e');
      return false;
    }
  }
}
