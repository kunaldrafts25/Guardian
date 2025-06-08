/*
 * Guardian - Women's Safety App
 * © 2025 All Rights Reserved - Kunal Singh
 * Contact: kunalsingh2514@gmail.com
 */

import 'package:guardian/core/services/mock_auth_service.dart';
import 'package:guardian/core/services/mock_data_service.dart';
import 'package:guardian/core/services/firebase_init_service.dart';

/// A mock service for interacting with Firebase services
class FirebaseService {
  // Singleton instance
  static final FirebaseService _instance = FirebaseService._internal();

  // Factory constructor
  factory FirebaseService() {
    return _instance;
  }

  // Internal constructor
  FirebaseService._internal();

  // Initialize Firebase
  static Future<void> initialize() async {
    // Call the FirebaseInitService to initialize mock services
    await FirebaseInitService.initializeFirebase();
  }

  // Auth methods
  static MockUser? get currentUser => MockAuthService.currentUser;

  // Get FCM token (static method)
  static Future<String?> getFCMToken() async {
    return 'mock-fcm-token-${DateTime.now().millisecondsSinceEpoch}';
  }

  // Get FCM token (instance method)
  Future<String?> getFCMTokenInstance() async {
    return 'mock-fcm-token-${DateTime.now().millisecondsSinceEpoch}';
  }

  // Save user data (static method)
  static Future<void> saveUserData(
      dynamic user, Map<String, dynamic> userData) async {
    await MockDataService.updateDocument('users', user.uid, userData);
  }

  // Get user data (static method)
  static Future<Map<String, dynamic>?> getUserData(String userId) async {
    return await MockDataService.getDocument('users', userId);
  }

  // Create a new emergency alert (static method)
  static Future<String> createEmergencyAlert(
      Map<String, dynamic> alertData) async {
    return await MockDataService.addDocument('alerts', alertData);
  }

  // Update an emergency alert (static method)
  static Future<bool> updateEmergencyAlert(
      String alertId, Map<String, dynamic> alertData) async {
    return await MockDataService.updateDocument('alerts', alertId, alertData);
  }

  // Get nearby users (static method)
  static Future<List<Map<String, dynamic>>> getNearbyUsers(
      double latitude, double longitude, double radiusInKm) async {
    // This is a simplified approach. In a real app, we would filter by distance
    // For mock purposes, we'll fetch all users
    return await MockDataService.getCollection('users');
  }

  // Report an incident (static method)
  static Future<String> reportIncident(
      Map<String, dynamic> incidentData) async {
    return await MockDataService.addDocument('incidents', incidentData);
  }

  // Get safety tips (static method)
  static Future<List<Map<String, dynamic>>> getSafetyTips() async {
    return await MockDataService.getSafetyTips();
  }

  // Get products from store (static method)
  static Future<List<Map<String, dynamic>>> getProducts() async {
    return await MockDataService.getProducts();
  }
}
