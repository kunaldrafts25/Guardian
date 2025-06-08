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
import 'package:guardian/core/utils/logger.dart';
import 'package:guardian/features/guardian_mode/data/models/guardian_contact_model.dart';
import 'package:guardian/features/guardian_mode/data/models/guardian_session_model.dart';

/// Repository for handling Guardian Mode functionality
class GuardianRepository {
  static const String _guardianContactsCollection = 'guardian_contacts';
  static const String _guardianSessionsCollection = 'guardian_sessions';
  static const MethodChannel _batteryChannel = MethodChannel('com.guardian/battery');
  
  /// Stream controller for active session updates
  final StreamController<GuardianSession?> _activeSessionController = 
      StreamController<GuardianSession?>.broadcast();
  
  /// Stream of active session updates
  Stream<GuardianSession?> get activeSessionStream => _activeSessionController.stream;
  
  /// Current active session
  GuardianSession? _activeSession;
  
  /// Timer for updating the session
  Timer? _sessionUpdateTimer;
  
  /// Stream subscription for location updates
  StreamSubscription<Position>? _locationSubscription;
  
  /// Get the current active session
  GuardianSession? get activeSession => _activeSession;
  
  /// Get all guardian contacts for the current user
  Future<List<GuardianContact>> getGuardianContacts() async {
    try {
      final user = MockAuthService.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }
      
      final userData = await MockDataService.getDocument('users', user.uid);
      if (userData == null) {
        return [];
      }
      
      if (!userData.containsKey('guardianContacts')) {
        return [];
      }
      
      final contactIds = List<String>.from(userData['guardianContacts']);
      final contacts = <GuardianContact>[];
      
      for (final contactId in contactIds) {
        final contactData = await MockDataService.getDocument(
          _guardianContactsCollection, 
          contactId
        );
        
        if (contactData != null) {
          contacts.add(GuardianContact.fromMap(contactData));
        }
      }
      
      return contacts;
    } catch (e) {
      Logger.error('Failed to get guardian contacts', e);
      return [];
    }
  }
  
  /// Add a new guardian contact
  Future<String?> addGuardianContact(GuardianContact contact) async {
    try {
      final user = MockAuthService.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }
      
      // Add contact to collection
      final contactId = await MockDataService.addDocument(
        _guardianContactsCollection,
        contact.toMap(),
      );
      
      if (contactId.isEmpty) {
        throw Exception('Failed to add contact');
      }
      
      // Update user's guardian contacts list
      final userData = await MockDataService.getDocument('users', user.uid);
      if (userData == null) {
        throw Exception('User data not found');
      }
      
      final List<String> contactIds = userData.containsKey('guardianContacts')
          ? List<String>.from(userData['guardianContacts'])
          : [];
      
      contactIds.add(contactId);
      
      await MockDataService.updateDocument(
        'users',
        user.uid,
        {'guardianContacts': contactIds},
      );
      
      return contactId;
    } catch (e) {
      Logger.error('Failed to add guardian contact', e);
      return null;
    }
  }
  
  /// Update a guardian contact
  Future<bool> updateGuardianContact(GuardianContact contact) async {
    try {
      return await MockDataService.updateDocument(
        _guardianContactsCollection,
        contact.id,
        contact.toMap(),
      );
    } catch (e) {
      Logger.error('Failed to update guardian contact', e);
      return false;
    }
  }
  
  /// Remove a guardian contact
  Future<bool> removeGuardianContact(String contactId) async {
    try {
      final user = MockAuthService.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }
      
      // Update user's guardian contacts list
      final userData = await MockDataService.getDocument('users', user.uid);
      if (userData == null) {
        throw Exception('User data not found');
      }
      
      if (!userData.containsKey('guardianContacts')) {
        return false;
      }
      
      final List<String> contactIds = List<String>.from(userData['guardianContacts']);
      contactIds.remove(contactId);
      
      await MockDataService.updateDocument(
        'users',
        user.uid,
        {'guardianContacts': contactIds},
      );
      
      return true;
    } catch (e) {
      Logger.error('Failed to remove guardian contact', e);
      return false;
    }
  }
  
  /// Start a new guardian session
  Future<GuardianSession?> startGuardianSession(List<String> guardianIds) async {
    try {
      // Check if there's already an active session
      if (_activeSession != null) {
        throw Exception('A guardian session is already active');
      }
      
      final user = MockAuthService.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }
      
      // Get current position
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      
      // Get battery level
      final batteryLevel = await _getBatteryLevel();
      
      // Create new session
      final session = GuardianSession.create(
        userId: user.uid,
        guardianIds: guardianIds,
        initialPosition: position,
        batteryLevel: batteryLevel,
      );
      
      // Save session to database
      final sessionId = await MockDataService.addDocument(
        _guardianSessionsCollection,
        session.toMap(),
      );
      
      if (sessionId.isEmpty) {
        throw Exception('Failed to create session');
      }
      
      // Start location updates
      _startLocationUpdates(sessionId);
      
      // Set active session
      _activeSession = session;
      _activeSessionController.add(_activeSession);
      
      return session;
    } catch (e) {
      Logger.error('Failed to start guardian session', e);
      return null;
    }
  }
  
  /// End the current guardian session
  Future<bool> endGuardianSession({
    GuardianSessionStatus status = GuardianSessionStatus.completed,
    String? notes,
  }) async {
    try {
      if (_activeSession == null) {
        return false;
      }
      
      // Stop location updates
      await _stopLocationUpdates();
      
      // Update session in database
      final updatedSession = _activeSession!.copyWith(
        status: status,
        endTime: DateTime.now(),
        notes: notes,
      );
      
      final success = await MockDataService.updateDocument(
        _guardianSessionsCollection,
        _activeSession!.id,
        updatedSession.toMap(),
      );
      
      // Clear active session
      _activeSession = null;
      _activeSessionController.add(null);
      
      return success;
    } catch (e) {
      Logger.error('Failed to end guardian session', e);
      return false;
    }
  }
  
  /// Get battery level
  Future<int> _getBatteryLevel() async {
    try {
      final int batteryLevel = await _batteryChannel.invokeMethod('getBatteryLevel');
      return batteryLevel;
    } on PlatformException {
      // Return a default value if the platform call fails
      return 100;
    }
  }
  
  /// Start location updates for the session
  void _startLocationUpdates(String sessionId) {
    // Cancel any existing subscription
    _locationSubscription?.cancel();
    
    // Start new subscription
    _locationSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, // Update every 10 meters
      ),
    ).listen((Position position) {
      _updateSessionLocation(sessionId, position);
    });
    
    // Start timer for periodic updates (battery, heart rate, etc.)
    _sessionUpdateTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => _updateSessionData(sessionId),
    );
  }
  
  /// Stop location updates
  Future<void> _stopLocationUpdates() async {
    await _locationSubscription?.cancel();
    _locationSubscription = null;
    
    _sessionUpdateTimer?.cancel();
    _sessionUpdateTimer = null;
  }
  
  /// Update session with new location
  Future<void> _updateSessionLocation(String sessionId, Position position) async {
    if (_activeSession == null) return;
    
    try {
      // Add location to history
      final locationData = {
        'latitude': position.latitude,
        'longitude': position.longitude,
        'timestamp': DateTime.now().toIso8601String(),
        'accuracy': position.accuracy,
        'speed': position.speed,
      };
      
      final updatedHistory = List<Map<String, dynamic>>.from(_activeSession!.locationHistory)
        ..add(locationData);
      
      // Detect movement pattern based on speed
      final MovementPattern pattern = _detectMovementPattern(position.speed);
      
      // Update session
      final updatedSession = _activeSession!.copyWith(
        lastLocation: {
          'latitude': position.latitude,
          'longitude': position.longitude,
        },
        locationHistory: updatedHistory,
        movementPattern: pattern,
      );
      
      // Update in database
      await MockDataService.updateDocument(
        _guardianSessionsCollection,
        sessionId,
        {
          'lastLocation': updatedSession.lastLocation,
          'locationHistory': updatedSession.locationHistory,
          'movementPattern': updatedSession.movementPattern.toString().split('.').last,
          'updatedAt': DateTime.now().toIso8601String(),
        },
      );
      
      // Update active session
      _activeSession = updatedSession;
      _activeSessionController.add(_activeSession);
    } catch (e) {
      Logger.error('Failed to update session location', e);
    }
  }
  
  /// Update session data (battery, heart rate, etc.)
  Future<void> _updateSessionData(String sessionId) async {
    if (_activeSession == null) return;
    
    try {
      // Get battery level
      final batteryLevel = await _getBatteryLevel();
      
      // Get heart rate (mock for now)
      final heartRate = _getMockHeartRate();
      
      // Update session
      final updatedSession = _activeSession!.copyWith(
        batteryLevel: batteryLevel,
        heartRate: heartRate,
      );
      
      // Update in database
      await MockDataService.updateDocument(
        _guardianSessionsCollection,
        sessionId,
        {
          'batteryLevel': updatedSession.batteryLevel,
          'heartRate': updatedSession.heartRate,
          'updatedAt': DateTime.now().toIso8601String(),
        },
      );
      
      // Update active session
      _activeSession = updatedSession;
      _activeSessionController.add(_activeSession);
    } catch (e) {
      Logger.error('Failed to update session data', e);
    }
  }
  
  /// Detect movement pattern based on speed
  MovementPattern _detectMovementPattern(double speedMps) {
    if (speedMps < 0.5) {
      return MovementPattern.stationary;
    } else if (speedMps < 2.0) {
      return MovementPattern.walking;
    } else if (speedMps < 6.0) {
      return MovementPattern.running;
    } else {
      return MovementPattern.inVehicle;
    }
  }
  
  /// Get mock heart rate (for demonstration)
  int _getMockHeartRate() {
    // In a real app, this would come from a wearable device
    // For now, return a random value between 60-100
    return 60 + (DateTime.now().millisecondsSinceEpoch % 40);
  }
  
  /// Dispose resources
  void dispose() {
    _stopLocationUpdates();
    _activeSessionController.close();
  }
}
