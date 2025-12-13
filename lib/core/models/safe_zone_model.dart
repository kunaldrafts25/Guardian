/*
 * Guardian 2.0 - Women's Safety App
 * © 2025 All Rights Reserved - Kunal Singh
 * 
 * SafeZone Model - Represents a safe location
 */

import 'package:cloud_firestore/cloud_firestore.dart';

/// Safe zone type
enum SafeZoneType {
  home,
  work,
  school,
  gym,
  custom,
}

/// Safe zone model
class SafeZone {
  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final double radius; // in meters
  final SafeZoneType type;
  final bool isActive;
  final bool notifyOnExit;
  final bool autoGuardianMode; // Enable Guardian mode when leaving
  final DateTime createdAt;

  const SafeZone({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    this.radius = 200, // Default 200m radius
    this.type = SafeZoneType.custom,
    this.isActive = true,
    this.notifyOnExit = true,
    this.autoGuardianMode = false,
    required this.createdAt,
  });

  /// Create from Firestore document
  factory SafeZone.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return SafeZone.fromJson(data, doc.id);
  }

  /// Create from JSON
  factory SafeZone.fromJson(Map<String, dynamic> json, String id) {
    return SafeZone(
      id: id,
      name: json['name'] as String? ?? '',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0,
      radius: (json['radius'] as num?)?.toDouble() ?? 200,
      type: SafeZoneType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => SafeZoneType.custom,
      ),
      isActive: json['isActive'] as bool? ?? true,
      notifyOnExit: json['notifyOnExit'] as bool? ?? true,
      autoGuardianMode: json['autoGuardianMode'] as bool? ?? false,
      createdAt: (json['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  /// Convert to JSON for Firestore
  Map<String, dynamic> toJson() => {
    'name': name,
    'latitude': latitude,
    'longitude': longitude,
    'radius': radius,
    'type': type.name,
    'isActive': isActive,
    'notifyOnExit': notifyOnExit,
    'autoGuardianMode': autoGuardianMode,
    'createdAt': Timestamp.fromDate(createdAt),
  };

  /// Copy with modifications
  SafeZone copyWith({
    String? id,
    String? name,
    double? latitude,
    double? longitude,
    double? radius,
    SafeZoneType? type,
    bool? isActive,
    bool? notifyOnExit,
    bool? autoGuardianMode,
    DateTime? createdAt,
  }) {
    return SafeZone(
      id: id ?? this.id,
      name: name ?? this.name,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      radius: radius ?? this.radius,
      type: type ?? this.type,
      isActive: isActive ?? this.isActive,
      notifyOnExit: notifyOnExit ?? this.notifyOnExit,
      autoGuardianMode: autoGuardianMode ?? this.autoGuardianMode,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// Get icon for zone type
  String get iconName {
    switch (type) {
      case SafeZoneType.home:
        return 'home';
      case SafeZoneType.work:
        return 'work';
      case SafeZoneType.school:
        return 'school';
      case SafeZoneType.gym:
        return 'fitness_center';
      case SafeZoneType.custom:
        return 'place';
    }
  }

  /// Get display name for type
  String get typeDisplayName {
    switch (type) {
      case SafeZoneType.home:
        return 'Home';
      case SafeZoneType.work:
        return 'Work';
      case SafeZoneType.school:
        return 'School';
      case SafeZoneType.gym:
        return 'Gym';
      case SafeZoneType.custom:
        return 'Custom';
    }
  }
}
