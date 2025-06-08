/*
 * Guardian - Women's Safety App
 * © 2025 All Rights Reserved - Kunal Singh
 * Contact: kunalsingh2514@gmail.com
 */

import 'package:guardian/core/services/mock_auth_service.dart';
import 'package:guardian/core/services/mock_data_service.dart';
import 'package:guardian/core/utils/logger.dart';
import 'package:guardian/features/community/data/incident_model.dart';
import 'package:guardian/features/community/data/safety_tip_model.dart';
import 'package:guardian/features/community/data/event_model.dart';

class CommunityRepository {
  // Get incidents
  Future<List<Incident>> getIncidents() async {
    try {
      final incidents = await MockDataService.getIncidents();
      return incidents.map((incident) => Incident.fromMap(incident)).toList();
    } catch (e) {
      Logger.error('Error getting incidents', e);
      return mockIncidents; // Fallback to mock data
    }
  }

  // Get incidents near location
  Future<List<Incident>> getIncidentsNearLocation(
    double latitude,
    double longitude,
    double radiusInKm,
  ) async {
    try {
      final incidents = await MockDataService.getIncidents();

      // In a real implementation, we would filter by distance
      // For mock purposes, we'll just return all incidents
      return incidents.map((incident) => Incident.fromMap(incident)).toList();
    } catch (e) {
      Logger.error('Error getting incidents near location', e);
      return mockIncidents; // Fallback to mock data
    }
  }

  // Report incident
  Future<String?> reportIncident(Incident incident) async {
    try {
      final MockUser? user = MockAuthService.currentUser;

      final incidentData = {
        'userId': user?.uid ?? 'anonymous',
        'title': incident.title,
        'description': incident.description,
        'type': incident.type,
        'latitude': incident.location.latitude,
        'longitude': incident.location.longitude,
        'isAnonymous': incident.isAnonymous,
        'timestamp': DateTime.now().toIso8601String(),
        'status': 'reported',
        'verified': false,
        'likes': 0,
        'comments': [],
      };

      return await MockDataService.addDocument('incidents', incidentData);
    } catch (e) {
      Logger.error('Error reporting incident', e);
      return null;
    }
  }

  // Get incident by ID
  Future<Incident?> getIncidentById(String id) async {
    try {
      final incidentData = await MockDataService.getDocument('incidents', id);
      if (incidentData == null) return null;

      return Incident.fromMap(incidentData);
    } catch (e) {
      Logger.error('Error getting incident by ID', e);

      // Fallback to mock data
      try {
        return mockIncidents.firstWhere((incident) => incident.id == id);
      } catch (_) {
        return null;
      }
    }
  }

  // Like incident
  Future<bool> likeIncident(String incidentId) async {
    try {
      final MockUser? user = MockAuthService.currentUser;
      if (user == null) return false;

      // Get incident
      final incidentData =
          await MockDataService.getDocument('incidents', incidentId);
      if (incidentData == null) return false;

      // Get likes
      final int currentLikes = incidentData['likes'] ?? 0;

      // Check if user already liked this incident
      List<String> likedBy = [];
      if (incidentData.containsKey('likedBy')) {
        likedBy = List<String>.from(incidentData['likedBy']);
      }

      if (likedBy.contains(user.uid)) {
        // User already liked this incident, unlike it
        likedBy.remove(user.uid);

        return await MockDataService.updateDocument('incidents', incidentId, {
          'likes': currentLikes - 1,
          'likedBy': likedBy,
        });
      } else {
        // User hasn't liked this incident yet
        likedBy.add(user.uid);

        return await MockDataService.updateDocument('incidents', incidentId, {
          'likes': currentLikes + 1,
          'likedBy': likedBy,
        });
      }
    } catch (e) {
      Logger.error('Error liking incident', e);
      return false;
    }
  }

  // Add comment to incident
  Future<bool> addCommentToIncident(String incidentId, String comment) async {
    try {
      final MockUser? user = MockAuthService.currentUser;
      if (user == null) return false;

      // Get incident
      final incidentData =
          await MockDataService.getDocument('incidents', incidentId);
      if (incidentData == null) return false;

      // Get comments
      List<Map<String, dynamic>> comments = [];
      if (incidentData.containsKey('comments')) {
        comments = List<Map<String, dynamic>>.from(incidentData['comments']);
      }

      // Add new comment
      comments.add({
        'userId': user.uid,
        'userName': user.displayName ?? 'Anonymous',
        'text': comment,
        'timestamp': DateTime.now().toIso8601String(),
      });

      return await MockDataService.updateDocument('incidents', incidentId, {
        'comments': comments,
      });
    } catch (e) {
      Logger.error('Error adding comment to incident', e);
      return false;
    }
  }

  // Get safety tips
  Future<List<SafetyTip>> getSafetyTips() async {
    try {
      final tips = await MockDataService.getSafetyTips();
      return tips.map((tip) => SafetyTip.fromMap(tip)).toList();
    } catch (e) {
      Logger.error('Error getting safety tips', e);
      return mockSafetyTips; // Fallback to mock data
    }
  }

  // Get safety tip by ID
  Future<SafetyTip?> getSafetyTipById(String id) async {
    try {
      final tipData = await MockDataService.getDocument('safetyTips', id);
      if (tipData == null) return null;

      return SafetyTip.fromMap(tipData);
    } catch (e) {
      Logger.error('Error getting safety tip by ID', e);

      // Fallback to mock data
      try {
        return mockSafetyTips.firstWhere((tip) => tip.id == id);
      } catch (_) {
        return null;
      }
    }
  }

  // Get safety tips by category
  Future<List<SafetyTip>> getSafetyTipsByCategory(String category) async {
    try {
      final tips = await MockDataService.getSafetyTips();
      final filteredTips =
          tips.where((tip) => tip['category'] == category).toList();

      return filteredTips.map((tip) => SafetyTip.fromMap(tip)).toList();
    } catch (e) {
      Logger.error('Error getting safety tips by category', e);

      // Fallback to mock data
      return mockSafetyTips.where((tip) => tip.category == category).toList();
    }
  }

  // Get community events
  Future<List<CommunityEvent>> getCommunityEvents() async {
    try {
      final events = await MockDataService.getCollection('events');
      return events.map((event) => CommunityEvent.fromMap(event)).toList();
    } catch (e) {
      Logger.error('Error getting community events', e);
      return mockEvents; // Fallback to mock data
    }
  }

  // Get community event by ID
  Future<CommunityEvent?> getCommunityEventById(String id) async {
    try {
      final eventData = await MockDataService.getDocument('events', id);
      if (eventData == null) return null;

      return CommunityEvent.fromMap(eventData);
    } catch (e) {
      Logger.error('Error getting community event by ID', e);

      // Fallback to mock data
      try {
        return mockEvents.firstWhere((event) => event.id == id);
      } catch (_) {
        return null;
      }
    }
  }

  // RSVP to event
  Future<bool> rsvpToEvent(String eventId) async {
    try {
      final MockUser? user = MockAuthService.currentUser;
      if (user == null) return false;

      // Get event
      final eventData = await MockDataService.getDocument('events', eventId);
      if (eventData == null) return false;

      // Get attendees
      List<String> attendees = [];
      if (eventData.containsKey('attendees')) {
        attendees = List<String>.from(eventData['attendees']);
      }

      // Check if user already RSVP'd
      if (attendees.contains(user.uid)) {
        return true; // Already RSVP'd
      }

      // Add user to attendees
      attendees.add(user.uid);

      // Update attendee count
      final int currentCount = eventData['attendeeCount'] ?? 0;

      return await MockDataService.updateDocument('events', eventId, {
        'attendees': attendees,
        'attendeeCount': currentCount + 1,
      });
    } catch (e) {
      Logger.error('Error RSVP to event', e);
      return false;
    }
  }

  // Cancel RSVP to event
  Future<bool> cancelRsvpToEvent(String eventId) async {
    try {
      final MockUser? user = MockAuthService.currentUser;
      if (user == null) return false;

      // Get event
      final eventData = await MockDataService.getDocument('events', eventId);
      if (eventData == null) return false;

      // Get attendees
      List<String> attendees = [];
      if (eventData.containsKey('attendees')) {
        attendees = List<String>.from(eventData['attendees']);
      }

      // Check if user RSVP'd
      if (!attendees.contains(user.uid)) {
        return true; // Not RSVP'd
      }

      // Remove user from attendees
      attendees.remove(user.uid);

      // Update attendee count
      final int currentCount = eventData['attendeeCount'] ?? 0;

      return await MockDataService.updateDocument('events', eventId, {
        'attendees': attendees,
        'attendeeCount': currentCount > 0 ? currentCount - 1 : 0,
      });
    } catch (e) {
      Logger.error('Error cancelling RSVP to event', e);
      return false;
    }
  }
}
