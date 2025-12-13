/*
 * Guardian - Women's Safety App
 * © 2025 All Rights Reserved - Kunal Singh
 * 
 * Mock Data Service - Compatibility layer backed by Cloud Firestore
 * This provides a simple interface for features that haven't migrated to Firebase yet
 */

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:guardian/core/utils/logger.dart';

/// Compatibility layer for MockDataService backed by Cloud Firestore
class MockDataService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static bool _initialized = false;

  // Current user data (cached)
  static Map<String, dynamic>? _currentUser;
  static String? _currentUserId;

  // Getters for current user
  static Map<String, dynamic>? get currentUser => _currentUser;
  static String? get currentUserId => _currentUserId;

  // Initialize the service
  static Future<bool> initialize() async {
    if (_initialized) {
      Logger.info('MockDataService already initialized');
      return true;
    }

    try {
      // Listen to auth state changes to update current user
      _auth.authStateChanges().listen((user) {
        if (user != null) {
          _currentUserId = user.uid;
          _loadCurrentUser(user.uid);
        } else {
          _currentUser = null;
          _currentUserId = null;
        }
      });

      _initialized = true;
      Logger.info('MockDataService initialized (Firestore-backed)');
      return true;
    } catch (e) {
      Logger.error('Error initializing MockDataService', e);
      return false;
    }
  }

  // Load current user data from Firestore
  static Future<void> _loadCurrentUser(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      _currentUser = doc.data();
    } catch (e) {
      Logger.error('Error loading current user', e);
    }
  }

  // Set current user (for compatibility)
  static void setCurrentUser(Map<String, dynamic> user, String userId) {
    _currentUser = user;
    _currentUserId = userId;
  }

  // Clear current user
  static void clearCurrentUser() {
    _currentUser = null;
    _currentUserId = null;
  }

  // Get all documents from a collection
  static Future<List<Map<String, dynamic>>> getCollection(String collection) async {
    try {
      final snapshot = await _firestore.collection(collection).get();
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      Logger.error('Error getting collection $collection', e);
      return [];
    }
  }

  // Get a document by ID
  static Future<Map<String, dynamic>?> getDocument(String collection, String id) async {
    try {
      final doc = await _firestore.collection(collection).doc(id).get();
      if (!doc.exists) return null;
      final data = doc.data();
      if (data != null) {
        data['id'] = doc.id;
      }
      return data;
    } catch (e) {
      Logger.error('Error getting document $id from $collection', e);
      return null;
    }
  }

  // Add a document to a collection
  static Future<String> addDocument(String collection, Map<String, dynamic> data) async {
    try {
      // If document has an ID, use it; otherwise let Firestore generate one
      final String? existingId = data['id']?.toString();
      
      if (existingId != null) {
        await _firestore.collection(collection).doc(existingId).set({
          ...data,
          'createdAt': FieldValue.serverTimestamp(),
        });
        return existingId;
      } else {
        final docRef = await _firestore.collection(collection).add({
          ...data,
          'createdAt': FieldValue.serverTimestamp(),
        });
        return docRef.id;
      }
    } catch (e) {
      Logger.error('Error adding document to $collection', e);
      return '';
    }
  }

  // Update a document in a collection
  static Future<bool> updateDocument(String collection, String id, Map<String, dynamic> data) async {
    try {
      await _firestore.collection(collection).doc(id).update({
        ...data,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      Logger.error('Error updating document $id in $collection', e);
      return false;
    }
  }

  // Delete a document from a collection
  static Future<bool> deleteDocument(String collection, String id) async {
    try {
      await _firestore.collection(collection).doc(id).delete();
      return true;
    } catch (e) {
      Logger.error('Error deleting document $id from $collection', e);
      return false;
    }
  }

  // Convenience methods for specific collections
  static Future<List<Map<String, dynamic>>> getUsers() async => getCollection('users');
  static Future<List<Map<String, dynamic>>> getAlerts() async => getCollection('alerts');
  static Future<List<Map<String, dynamic>>> getProducts() async => getCollection('products');
  static Future<List<Map<String, dynamic>>> getIncidents() async => getCollection('incidents');
  static Future<List<Map<String, dynamic>>> getSafetyTips() async => getCollection('safetyTips');
}
