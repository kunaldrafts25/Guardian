/*
 * Guardian - Women's Safety App
 * © 2025 All Rights Reserved - Kunal Singh
 * Contact: kunalsingh2514@gmail.com
 */

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:guardian/core/models/emergency_contact.dart';
import 'package:guardian/core/models/emergency_alert.dart';
import 'package:guardian/core/utils/location_utils.dart';
import 'package:guardian/core/utils/logger.dart';

/// Repository for handling emergency-related functionality
class EmergencyRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Collection references
  final String _contactsCollection = 'emergency_contacts';
  final String _alertsCollection = 'emergency_alerts';

  /// Get emergency contacts for the current user
  Future<List<EmergencyContact>> getEmergencyContacts() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection(_contactsCollection)
          .get();

      return snapshot.docs
          .map((doc) => EmergencyContact.fromMap(doc.data(), doc.id))
          .toList();
    } catch (e) {
      Logger.error('Failed to get emergency contacts', e);
      return [];
    }
  }

  /// Add a new emergency contact
  Future<bool> addEmergencyContact(EmergencyContact contact) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      await _firestore
          .collection('users')
          .doc(userId)
          .collection(_contactsCollection)
          .add(contact.toMap());

      return true;
    } catch (e) {
      Logger.error('Failed to add emergency contact', e);
      return false;
    }
  }

  /// Update an existing emergency contact
  Future<bool> updateEmergencyContact(EmergencyContact contact) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      await _firestore
          .collection('users')
          .doc(userId)
          .collection(_contactsCollection)
          .doc(contact.id)
          .update(contact.toMap());

      return true;
    } catch (e) {
      Logger.error('Failed to update emergency contact', e);
      return false;
    }
  }

  /// Delete an emergency contact
  Future<bool> deleteEmergencyContact(String contactId) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      await _firestore
          .collection('users')
          .doc(userId)
          .collection(_contactsCollection)
          .doc(contactId)
          .delete();

      return true;
    } catch (e) {
      Logger.error('Failed to delete emergency contact', e);
      return false;
    }
  }

  /// Create an emergency alert
  Future<bool> createEmergencyAlert({
    required String alertType,
    String? message,
  }) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      // Get current location
      final position = await LocationUtils.getCurrentPosition();

      // Default location if position is null
      final Map<String, double> location = position != null
          ? {
              'latitude': position.latitude,
              'longitude': position.longitude,
            }
          : {
              'latitude': 0.0,
              'longitude': 0.0,
            };

      final alert = EmergencyAlert(
        userId: userId,
        alertType: alertType,
        message: message,
        timestamp: DateTime.now(),
        location: location,
        status: 'active',
      );

      await _firestore
          .collection(_alertsCollection)
          .add(alert.toMap());

      // TODO: Send notifications to emergency contacts

      return true;
    } catch (e) {
      Logger.error('Failed to create emergency alert', e);
      return false;
    }
  }

  /// Get emergency alerts for the current user
  Future<List<EmergencyAlert>> getEmergencyAlerts() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      final snapshot = await _firestore
          .collection(_alertsCollection)
          .where('userId', isEqualTo: userId)
          .orderBy('timestamp', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => EmergencyAlert.fromMap(doc.data(), doc.id))
          .toList();
    } catch (e) {
      Logger.error('Failed to get emergency alerts', e);
      return [];
    }
  }

  /// Cancel an emergency alert
  Future<bool> cancelEmergencyAlert(String alertId) async {
    try {
      await _firestore
          .collection(_alertsCollection)
          .doc(alertId)
          .update({'status': 'cancelled'});

      return true;
    } catch (e) {
      Logger.error('Failed to cancel emergency alert', e);
      return false;
    }
  }
}

