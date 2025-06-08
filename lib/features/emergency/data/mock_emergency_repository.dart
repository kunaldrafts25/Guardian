/*
 * Guardian - Women's Safety App
 * © 2025 All Rights Reserved - Kunal Singh
 * Contact: kunalsingh2514@gmail.com
 */

import 'package:guardian/core/services/mock_auth_service.dart';
import 'package:guardian/core/services/mock_data_service.dart';
import 'package:guardian/core/utils/logger.dart';
import 'package:guardian/features/emergency/data/emergency_model.dart';

class EmergencyRepository {
  // Get active emergency alert for current user
  Future<EmergencyAlert?> getActiveEmergencyAlert() async {
    try {
      final MockUser? user = MockAuthService.currentUser;
      if (user == null) return null;

      // Get all alerts
      final alerts = await MockDataService.getAlerts();
      
      // Find active alert for current user
      final activeAlert = alerts.firstWhere(
        (alert) => 
          alert['userId'] == user.uid && 
          alert['status'] == 'active',
        orElse: () => {},
      );

      if (activeAlert.isEmpty) return null;

      return EmergencyAlert.fromMap(activeAlert);
    } catch (e) {
      Logger.error('Error getting active emergency alert', e);
      return null;
    }
  }

  // Create emergency alert
  Future<EmergencyAlert?> createEmergencyAlert({
    required String type,
    required double latitude,
    required double longitude,
    String? message,
  }) async {
    try {
      final MockUser? user = MockAuthService.currentUser;
      if (user == null) throw Exception('User not logged in');

      // Check if user already has an active alert
      final existingAlert = await getActiveEmergencyAlert();
      if (existingAlert != null) {
        return existingAlert;
      }

      // Create new alert
      final alertData = {
        'userId': user.uid,
        'type': type,
        'status': 'active',
        'latitude': latitude,
        'longitude': longitude,
        'message': message,
        'timestamp': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
      };

      final alertId = await MockDataService.addDocument('alerts', alertData);
      
      // Get the created alert
      final createdAlert = await MockDataService.getDocument('alerts', alertId);
      if (createdAlert == null) throw Exception('Failed to create emergency alert');

      return EmergencyAlert.fromMap(createdAlert);
    } catch (e) {
      Logger.error('Error creating emergency alert', e);
      rethrow;
    }
  }

  // Update emergency alert location
  Future<bool> updateEmergencyAlertLocation({
    required String alertId,
    required double latitude,
    required double longitude,
  }) async {
    try {
      final updateData = {
        'latitude': latitude,
        'longitude': longitude,
        'updatedAt': DateTime.now().toIso8601String(),
      };

      return await MockDataService.updateDocument('alerts', alertId, updateData);
    } catch (e) {
      Logger.error('Error updating emergency alert location', e);
      return false;
    }
  }

  // Cancel emergency alert
  Future<bool> cancelEmergencyAlert(String alertId) async {
    try {
      final updateData = {
        'status': 'cancelled',
        'cancelledAt': DateTime.now().toIso8601String(),
      };

      return await MockDataService.updateDocument('alerts', alertId, updateData);
    } catch (e) {
      Logger.error('Error cancelling emergency alert', e);
      return false;
    }
  }

  // Get emergency alert by ID
  Future<EmergencyAlert?> getEmergencyAlertById(String alertId) async {
    try {
      final alertData = await MockDataService.getDocument('alerts', alertId);
      if (alertData == null) return null;

      return EmergencyAlert.fromMap(alertData);
    } catch (e) {
      Logger.error('Error getting emergency alert by ID', e);
      return null;
    }
  }

  // Get emergency alerts for user
  Future<List<EmergencyAlert>> getEmergencyAlertsForUser() async {
    try {
      final MockUser? user = MockAuthService.currentUser;
      if (user == null) return [];

      // Get all alerts
      final alerts = await MockDataService.getAlerts();
      
      // Filter alerts for current user
      final userAlerts = alerts.where((alert) => alert['userId'] == user.uid).toList();
      
      return userAlerts.map((alert) => EmergencyAlert.fromMap(alert)).toList();
    } catch (e) {
      Logger.error('Error getting emergency alerts for user', e);
      return [];
    }
  }

  // Report incident
  Future<bool> reportIncident({
    required String type,
    required double latitude,
    required double longitude,
    required String description,
    bool isAnonymous = false,
  }) async {
    try {
      final MockUser? user = MockAuthService.currentUser;
      
      final incidentData = {
        'userId': user?.uid ?? 'anonymous',
        'type': type,
        'latitude': latitude,
        'longitude': longitude,
        'description': description,
        'isAnonymous': isAnonymous,
        'status': 'reported',
        'timestamp': DateTime.now().toIso8601String(),
      };

      final incidentId = await MockDataService.addDocument('incidents', incidentData);
      
      return incidentId.isNotEmpty;
    } catch (e) {
      Logger.error('Error reporting incident', e);
      return false;
    }
  }
}
