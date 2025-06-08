/*
 * Guardian - Women's Safety App
 * © 2025 All Rights Reserved - Kunal Singh
 * Contact: kunalsingh2514@gmail.com
 */

import 'package:geolocator/geolocator.dart';

/// Status of a guardian session
enum GuardianSessionStatus {
  /// Session is active and being monitored
  active,

  /// Session has ended normally
  completed,

  /// Session was ended due to an emergency
  emergency,

  /// Session was cancelled
  cancelled,
}

/// Movement pattern detected by the system
enum MovementPattern {
  /// User is stationary
  stationary,

  /// User is walking at normal pace
  walking,

  /// User is running or moving quickly
  running,

  /// User is in a vehicle
  inVehicle,

  /// Movement pattern is unknown or cannot be determined
  unknown,
}

/// A model representing a live guardian session
class GuardianSession {
  /// Unique identifier for the session
  final String id;

  /// ID of the user who started the session
  final String userId;

  /// List of guardian contact IDs who are monitoring this session
  final List<String> guardianIds;

  /// Current status of the session
  final GuardianSessionStatus status;

  /// When the session was started
  final DateTime startTime;

  /// When the session ended (null if still active)
  final DateTime? endTime;

  /// Last known location
  final Map<String, double>? lastLocation;

  /// Last known heart rate (if available from wearable)
  final int? heartRate;

  /// Current battery level of the device
  final int batteryLevel;

  /// Current movement pattern
  final MovementPattern movementPattern;

  /// Location history for this session
  final List<Map<String, dynamic>> locationHistory;

  /// Notes or messages associated with this session
  final String? notes;

  GuardianSession({
    required this.id,
    required this.userId,
    required this.guardianIds,
    required this.status,
    required this.startTime,
    this.endTime,
    this.lastLocation,
    this.heartRate,
    required this.batteryLevel,
    required this.movementPattern,
    required this.locationHistory,
    this.notes,
  });

  /// Create a new guardian session
  factory GuardianSession.create({
    required String userId,
    required List<String> guardianIds,
    required Position initialPosition,
    required int batteryLevel,
  }) {
    return GuardianSession(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      userId: userId,
      guardianIds: guardianIds,
      status: GuardianSessionStatus.active,
      startTime: DateTime.now(),
      lastLocation: {
        'latitude': initialPosition.latitude,
        'longitude': initialPosition.longitude,
      },
      batteryLevel: batteryLevel,
      movementPattern: MovementPattern.stationary,
      locationHistory: [
        {
          'latitude': initialPosition.latitude,
          'longitude': initialPosition.longitude,
          'timestamp': DateTime.now().toIso8601String(),
          'accuracy': initialPosition.accuracy,
          'speed': initialPosition.speed,
        }
      ],
    );
  }

  /// Convert to a map for storage
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'guardianIds': guardianIds,
      'status': status.toString().split('.').last,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime?.toIso8601String(),
      'lastLocation': lastLocation,
      'heartRate': heartRate,
      'batteryLevel': batteryLevel,
      'movementPattern': movementPattern.toString().split('.').last,
      'locationHistory': locationHistory,
      'notes': notes,
    };
  }

  /// Create from a map
  factory GuardianSession.fromMap(Map<String, dynamic> map) {
    return GuardianSession(
      id: map['id'] ?? '',
      userId: map['userId'] ?? '',
      guardianIds: List<String>.from(map['guardianIds'] ?? []),
      status: GuardianSessionStatus.values.firstWhere(
        (e) => e.toString().split('.').last == map['status'],
        orElse: () => GuardianSessionStatus.active,
      ),
      startTime:
          DateTime.parse(map['startTime'] ?? DateTime.now().toIso8601String()),
      endTime: map['endTime'] != null ? DateTime.parse(map['endTime']) : null,
      lastLocation: map['lastLocation'] != null
          ? Map<String, double>.from(map['lastLocation'])
          : null,
      heartRate: map['heartRate'],
      batteryLevel: map['batteryLevel'] ?? 100,
      movementPattern: MovementPattern.values.firstWhere(
        (e) => e.toString().split('.').last == map['movementPattern'],
        orElse: () => MovementPattern.unknown,
      ),
      locationHistory:
          List<Map<String, dynamic>>.from(map['locationHistory'] ?? []),
      notes: map['notes'],
    );
  }

  /// Create a copy with updated values
  GuardianSession copyWith({
    String? id,
    String? userId,
    List<String>? guardianIds,
    GuardianSessionStatus? status,
    DateTime? startTime,
    DateTime? endTime,
    Map<String, double>? lastLocation,
    int? heartRate,
    int? batteryLevel,
    MovementPattern? movementPattern,
    List<Map<String, dynamic>>? locationHistory,
    String? notes,
  }) {
    return GuardianSession(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      guardianIds: guardianIds ?? this.guardianIds,
      status: status ?? this.status,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      lastLocation: lastLocation ?? this.lastLocation,
      heartRate: heartRate ?? this.heartRate,
      batteryLevel: batteryLevel ?? this.batteryLevel,
      movementPattern: movementPattern ?? this.movementPattern,
      locationHistory: locationHistory ?? this.locationHistory,
      notes: notes ?? this.notes,
    );
  }
}
