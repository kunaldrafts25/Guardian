/*
 * Guardian - Women's Safety App
 * © 2025 All Rights Reserved - Kunal Singh
 * Contact: kunalsingh2514@gmail.com
 */

import 'dart:async';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:guardian/core/services/mock_auth_service.dart';
import 'package:guardian/core/services/mock_data_service.dart';
import 'package:guardian/core/utils/location_utils.dart';
import 'package:guardian/core/utils/logger.dart';
import 'package:url_launcher/url_launcher.dart';

class EmergencyService {
  static bool _isTripleTapListening = false;
  static Timer? _panicTimer;

  // Start listening for triple tap on power button
  static Future<bool> startTripleTapDetection() async {
    if (_isTripleTapListening) return true;

    try {
      // Mock implementation - just return true
      _isTripleTapListening = true;
      return true;
    } on PlatformException catch (e) {
      Logger.error("Failed to start triple tap detection", e.message);
      return false;
    }
  }

  // Stop listening for triple tap
  static Future<bool> stopTripleTapDetection() async {
    if (!_isTripleTapListening) return true;

    try {
      // Mock implementation - just return true
      _isTripleTapListening = false;
      return true;
    } on PlatformException catch (e) {
      Logger.error("Failed to stop triple tap detection", e.message);
      return false;
    }
  }

  // Trigger emergency alert
  static Future<String?> triggerEmergencyAlert({
    bool sendSMS = true,
    bool recordAudio = false,
    bool recordVideo = false,
  }) async {
    try {
      // Get current user
      final user = MockAuthService.currentUser;
      if (user == null) return null;

      // Get current location
      final Position? position = await LocationUtils.getCurrentPosition();
      if (position == null) return null;

      // Create alert data
      final alertData = {
        'userId': user.uid,
        'type': 'sos',
        'status': 'active',
        'latitude': position.latitude,
        'longitude': position.longitude,
        'recordAudio': recordAudio,
        'recordVideo': recordVideo,
        'timestamp': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
      };

      // Save alert to mock database
      final alertId = await MockDataService.addDocument('alerts', alertData);

      // Get user's emergency contacts
      final userData = await MockDataService.getDocument('users', user.uid);

      if (userData != null && userData.containsKey('emergencyContacts')) {
        final emergencyContacts =
            List<Map<String, dynamic>>.from(userData['emergencyContacts']);

        // Send SMS to emergency contacts if enabled
        if (sendSMS) {
          for (var contact in emergencyContacts) {
            if (contact['phone'] != null) {
              _sendSMS(
                contact['phone'],
                "EMERGENCY: I need help! My current location is: https://maps.google.com/?q=${position.latitude},${position.longitude}",
              );
            }
          }
        }
      }

      // Return the alert ID
      return alertId;
    } catch (e) {
      Logger.error("Error triggering emergency alert", e);
      return null;
    }
  }

  // Cancel emergency alert
  static Future<bool> cancelEmergencyAlert(String alertId) async {
    try {
      // Update alert status
      final updateData = {
        'status': 'cancelled',
        'cancelledAt': DateTime.now().toIso8601String(),
      };

      return await MockDataService.updateDocument(
          'alerts', alertId, updateData);
    } catch (e) {
      Logger.error("Error cancelling emergency alert", e);
      return false;
    }
  }

  // Report incident
  static Future<bool> reportIncident({
    required String type,
    required Position position,
    required String description,
    bool isAnonymous = false,
  }) async {
    try {
      final user = MockAuthService.currentUser;

      // Create incident data
      final incidentData = {
        'userId': user?.uid ?? 'anonymous',
        'type': type,
        'latitude': position.latitude,
        'longitude': position.longitude,
        'description': description,
        'isAnonymous': isAnonymous,
        'timestamp': DateTime.now().toIso8601String(),
        'status': 'reported',
      };

      // Add incident to database
      final incidentId =
          await MockDataService.addDocument('incidents', incidentData);

      return incidentId.isNotEmpty;
    } catch (e) {
      Logger.error('Error reporting incident', e);
      return false;
    }
  }

  // Start panic timer
  static Future<String?> startPanicTimer(int durationInSeconds) async {
    // Create a pending alert
    final user = MockAuthService.currentUser;
    if (user == null) return null;

    final Position? position = await LocationUtils.getCurrentPosition();
    if (position == null) return null;

    final alertData = {
      'userId': user.uid,
      'type': 'panic',
      'status': 'pending',
      'latitude': position.latitude,
      'longitude': position.longitude,
      'panicTimer': true,
      'panicTimerDuration': durationInSeconds,
      'timestamp': DateTime.now().toIso8601String(),
      'updatedAt': DateTime.now().toIso8601String(),
    };

    final alertId = await MockDataService.addDocument('alerts', alertData);

    // Start timer
    _panicTimer = Timer(Duration(seconds: durationInSeconds), () async {
      // If timer completes, trigger the alert
      await MockDataService.updateDocument('alerts', alertId, {
        'status': 'active',
        'activatedAt': DateTime.now().toIso8601String(),
      });

      // Get updated location
      final Position? newPosition = await LocationUtils.getCurrentPosition();
      if (newPosition != null) {
        await MockDataService.updateDocument('alerts', alertId, {
          'latitude': newPosition.latitude,
          'longitude': newPosition.longitude,
          'updatedAt': DateTime.now().toIso8601String(),
        });
      }

      // Get user's emergency contacts and send SMS
      final userData = await MockDataService.getDocument('users', user.uid);

      if (userData != null && userData.containsKey('emergencyContacts')) {
        final emergencyContacts =
            List<Map<String, dynamic>>.from(userData['emergencyContacts']);

        for (var contact in emergencyContacts) {
          if (contact['phone'] != null) {
            _sendSMS(
              contact['phone'],
              "EMERGENCY: I didn't check in on time and may need help! My last known location is: https://maps.google.com/?q=${newPosition?.latitude ?? position.latitude},${newPosition?.longitude ?? position.longitude}",
            );
          }
        }
      }
    });

    return alertId;
  }

  // Cancel panic timer
  static Future<bool> cancelPanicTimer(String alertId) async {
    _panicTimer?.cancel();
    _panicTimer = null;

    try {
      await MockDataService.updateDocument('alerts', alertId, {
        'status': 'cancelled',
        'cancelledAt': DateTime.now().toIso8601String(),
      });
      return true;
    } catch (e) {
      Logger.error("Error cancelling panic timer", e);
      return false;
    }
  }

  // Send SMS helper method
  static Future<void> _sendSMS(String phoneNumber, String message) async {
    final Uri smsUri = Uri(
      scheme: 'sms',
      path: phoneNumber,
      queryParameters: {'body': message},
    );

    if (await canLaunchUrl(smsUri)) {
      await launchUrl(smsUri);
    }
  }
}
