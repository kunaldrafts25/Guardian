/*
 * Guardian - Women's Safety App
 * © 2025 All Rights Reserved - Kunal Singh
 * Contact: kunalsingh2514@gmail.com
 */

import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:guardian/core/services/auth_service.dart';
import 'package:guardian/core/services/firestore_service.dart';
import 'package:guardian/core/utils/logger.dart';
import 'package:guardian/core/utils/location_utils.dart';
import 'package:guardian/features/guardian_circle/data/models/guardian_circle_model.dart';
import 'package:guardian/features/guardian_circle/data/models/emergency_response_model.dart';

/// Repository for handling Guardian Circle functionality
class GuardianCircleRepository {
  static const String _circlesCollection = 'guardian_circles';
  static const String _alertsCollection = 'emergency_alerts';
  static const String _responsesCollection = 'emergency_responses';

  /// Stream controller for emergency alerts
  final StreamController<EmergencyAlert> _alertsController =
      StreamController<EmergencyAlert>.broadcast();

  /// Stream of emergency alerts
  Stream<EmergencyAlert> get alertsStream => _alertsController.stream;

  /// Get all guardian circles for the current user
  Future<List<GuardianCircle>> getGuardianCircles() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      final circles = await FirestoreService.getCollection(_circlesCollection);

      return circles
          .where((circle) => circle['ownerId'] == user.uid)
          .map((circle) => GuardianCircle.fromMap(circle))
          .toList();
    } catch (e) {
      Logger.error('Failed to get guardian circles', e);
      return [];
    }
  }

  /// Get a specific guardian circle by ID
  Future<GuardianCircle?> getGuardianCircle(String id) async {
    try {
      final circleData =
          await FirestoreService.getDocument(_circlesCollection, id);

      if (circleData == null) {
        return null;
      }

      return GuardianCircle.fromMap(circleData);
    } catch (e) {
      Logger.error('Failed to get guardian circle', e);
      return null;
    }
  }

  /// Create a new guardian circle
  Future<String?> createGuardianCircle({
    required String name,
    String? description,
    List<GuardianCircleMember>? members,
    bool isDefault = false,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Create owner as admin member
      final ownerMember = GuardianCircleMember(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        userId: user.uid,
        name: user.displayName ?? 'Me',
        phoneNumber: user.phoneNumber ?? '',
        email: user.email,
        status: GuardianMemberStatus.active,
        role: GuardianMemberRole.admin,
      );

      final allMembers = [ownerMember];
      if (members != null) {
        allMembers.addAll(members);
      }

      final circle = GuardianCircle(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        ownerId: user.uid,
        name: name,
        description: description,
        members: allMembers,
        isDefault: isDefault,
      );

      final circleId = await FirestoreService.addDocument(
        _circlesCollection,
        circle.toMap(),
      );

      return circleId;
    } catch (e) {
      Logger.error('Failed to create guardian circle', e);
      return null;
    }
  }

  /// Update an existing guardian circle
  Future<bool> updateGuardianCircle(GuardianCircle circle) async {
    try {
      return await FirestoreService.updateDocument(
        _circlesCollection,
        circle.id,
        circle.toMap(),
      );
    } catch (e) {
      Logger.error('Failed to update guardian circle', e);
      return false;
    }
  }

  /// Delete a guardian circle
  Future<bool> deleteGuardianCircle(String id) async {
    try {
      return await FirestoreService.deleteDocument(_circlesCollection, id);
    } catch (e) {
      Logger.error('Failed to delete guardian circle', e);
      return false;
    }
  }

  /// Add a member to a guardian circle
  Future<bool> addMemberToCircle({
    required String circleId,
    required String name,
    required String phoneNumber,
    String? email,
    String? relationship,
    GuardianMemberRole role = GuardianMemberRole.member,
  }) async {
    try {
      final circle = await getGuardianCircle(circleId);
      if (circle == null) {
        throw Exception('Circle not found');
      }

      // Check if member already exists
      final existingMember = circle.members.firstWhere(
        (m) => m.phoneNumber == phoneNumber,
        orElse: () => GuardianCircleMember(
          id: '',
          name: '',
          phoneNumber: '',
          status: GuardianMemberStatus.invited,
          role: GuardianMemberRole.member,
        ),
      );

      if (existingMember.id.isNotEmpty) {
        throw Exception('Member already exists in this circle');
      }

      // Create new member
      final newMember = GuardianCircleMember(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: name,
        phoneNumber: phoneNumber,
        email: email,
        relationship: relationship,
        status: GuardianMemberStatus.invited,
        role: role,
      );

      // Add to circle
      final updatedMembers = List<GuardianCircleMember>.from(circle.members)
        ..add(newMember);

      final updatedCircle = circle.copyWith(
        members: updatedMembers,
        updatedAt: DateTime.now(),
      );

      return await updateGuardianCircle(updatedCircle);
    } catch (e) {
      Logger.error('Failed to add member to circle', e);
      return false;
    }
  }

  /// Remove a member from a guardian circle
  Future<bool> removeMemberFromCircle({
    required String circleId,
    required String memberId,
  }) async {
    try {
      final circle = await getGuardianCircle(circleId);
      if (circle == null) {
        throw Exception('Circle not found');
      }

      // Remove member
      final updatedMembers =
          circle.members.where((m) => m.id != memberId).toList();

      final updatedCircle = circle.copyWith(
        members: updatedMembers,
        updatedAt: DateTime.now(),
      );

      return await updateGuardianCircle(updatedCircle);
    } catch (e) {
      Logger.error('Failed to remove member from circle', e);
      return false;
    }
  }

  /// Update a member's status in a guardian circle
  Future<bool> updateMemberStatus({
    required String circleId,
    required String memberId,
    required GuardianMemberStatus status,
  }) async {
    try {
      final circle = await getGuardianCircle(circleId);
      if (circle == null) {
        throw Exception('Circle not found');
      }

      // Find and update member
      final updatedMembers = List<GuardianCircleMember>.from(circle.members);
      final memberIndex = updatedMembers.indexWhere((m) => m.id == memberId);

      if (memberIndex == -1) {
        throw Exception('Member not found');
      }

      updatedMembers[memberIndex] = updatedMembers[memberIndex].copyWith(
        status: status,
      );

      final updatedCircle = circle.copyWith(
        members: updatedMembers,
        updatedAt: DateTime.now(),
      );

      return await updateGuardianCircle(updatedCircle);
    } catch (e) {
      Logger.error('Failed to update member status', e);
      return false;
    }
  }

  /// Get all emergency alerts for the current user
  Future<List<EmergencyAlert>> getEmergencyAlerts() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      final alerts = await FirestoreService.getCollection(_alertsCollection);

      return alerts
          .where((alert) => alert['userId'] == user.uid)
          .map((alert) => EmergencyAlert.fromMap(alert))
          .toList();
    } catch (e) {
      Logger.error('Failed to get emergency alerts', e);
      return [];
    }
  }

  /// Get a specific emergency alert by ID
  Future<EmergencyAlert?> getEmergencyAlert(String id) async {
    try {
      final alertData =
          await FirestoreService.getDocument(_alertsCollection, id);

      if (alertData == null) {
        return null;
      }

      return EmergencyAlert.fromMap(alertData);
    } catch (e) {
      Logger.error('Failed to get emergency alert', e);
      return null;
    }
  }

  /// Send an emergency alert to guardian circles
  Future<String?> sendEmergencyAlert({
    required String emergencyType,
    String? message,
    required List<String> circleIds,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Get current position
      final position = await LocationUtils.getCurrentPosition();
      if (position == null) {
        throw Exception('Failed to get current location');
      }

      // Get address
      final address = await LocationUtils.getAddressFromPosition(position);

      // Create alert
      final alert = EmergencyAlert(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        userId: user.uid,
        userName: user.displayName ?? 'User',
        emergencyType: emergencyType,
        message: message,
        location: {
          'latitude': position.latitude,
          'longitude': position.longitude,
        },
        address: address,
        status: 'active',
        circleIds: circleIds,
        responses: [],
      );

      final alertId = await FirestoreService.addDocument(
        _alertsCollection,
        alert.toMap(),
      );

      if (alertId.isNotEmpty) {
        // Notify listeners
        _alertsController.add(alert);
      }

      return alertId;
    } catch (e) {
      Logger.error('Failed to send emergency alert', e);
      return null;
    }
  }

  /// Respond to an emergency alert
  Future<String?> respondToAlert({
    required String alertId,
    required String responderId,
    required String responderName,
    required EmergencyResponseStatus status,
    int? etaMinutes,
    String? message,
  }) async {
    try {
      // Get current position
      final position = await LocationUtils.getCurrentPosition();

      // Create response
      final response = EmergencyResponse(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        alertId: alertId,
        responderId: responderId,
        responderName: responderName,
        status: status,
        etaMinutes: etaMinutes,
        responderLocation: position != null
            ? {
                'latitude': position.latitude,
                'longitude': position.longitude,
              }
            : null,
        message: message,
      );

      // Add response to database
      final responseId = await FirestoreService.addDocument(
        _responsesCollection,
        response.toMap(),
      );

      if (responseId.isNotEmpty) {
        // Update alert with response
        final alert = await getEmergencyAlert(alertId);
        if (alert != null) {
          final updatedResponses = List<EmergencyResponse>.from(alert.responses)
            ..add(response);

          final updatedAlert = alert.copyWith(
            responses: updatedResponses,
            updatedAt: DateTime.now(),
          );

          await FirestoreService.updateDocument(
            _alertsCollection,
            alertId,
            updatedAlert.toMap(),
          );

          // Notify listeners
          _alertsController.add(updatedAlert);
        }
      }

      return responseId;
    } catch (e) {
      Logger.error('Failed to respond to alert', e);
      return null;
    }
  }

  /// Update an emergency response
  Future<bool> updateResponse({
    required String alertId,
    required String responseId,
    required EmergencyResponseStatus status,
    int? etaMinutes,
    String? message,
  }) async {
    try {
      // Get current position
      final position = await LocationUtils.getCurrentPosition();

      // Get alert
      final alert = await getEmergencyAlert(alertId);
      if (alert == null) {
        throw Exception('Alert not found');
      }

      // Find response
      final responseIndex =
          alert.responses.indexWhere((r) => r.id == responseId);
      if (responseIndex == -1) {
        throw Exception('Response not found');
      }

      // Update response
      final updatedResponse = alert.responses[responseIndex].copyWith(
        status: status,
        etaMinutes: etaMinutes,
        message: message,
        responderLocation: position != null
            ? {
                'latitude': position.latitude,
                'longitude': position.longitude,
              }
            : alert.responses[responseIndex].responderLocation,
        updatedAt: DateTime.now(),
      );

      // Update response in database
      await FirestoreService.updateDocument(
        _responsesCollection,
        responseId,
        updatedResponse.toMap(),
      );

      // Update alert with updated response
      final updatedResponses = List<EmergencyResponse>.from(alert.responses);
      updatedResponses[responseIndex] = updatedResponse;

      final updatedAlert = alert.copyWith(
        responses: updatedResponses,
        updatedAt: DateTime.now(),
      );

      final success = await FirestoreService.updateDocument(
        _alertsCollection,
        alertId,
        updatedAlert.toMap(),
      );

      if (success) {
        // Notify listeners
        _alertsController.add(updatedAlert);
      }

      return success;
    } catch (e) {
      Logger.error('Failed to update response', e);
      return false;
    }
  }

  /// Resolve an emergency alert
  Future<bool> resolveAlert(String alertId) async {
    try {
      final alert = await getEmergencyAlert(alertId);
      if (alert == null) {
        throw Exception('Alert not found');
      }

      final updatedAlert = alert.copyWith(
        isResolved: true,
        status: 'resolved',
        updatedAt: DateTime.now(),
      );

      final success = await FirestoreService.updateDocument(
        _alertsCollection,
        alertId,
        updatedAlert.toMap(),
      );

      if (success) {
        // Notify listeners
        _alertsController.add(updatedAlert);
      }

      return success;
    } catch (e) {
      Logger.error('Failed to resolve alert', e);
      return false;
    }
  }

  /// Dispose resources
  void dispose() {
    _alertsController.close();
  }
}



