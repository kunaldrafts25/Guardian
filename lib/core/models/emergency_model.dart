/*
 * Guardian 2.0 - Women's Safety App
 * © 2025 All Rights Reserved - Kunal Singh
 * 
 * Emergency Model
 */

import 'package:cloud_firestore/cloud_firestore.dart';

/// Emergency status enum
enum EmergencyStatus {
  active,      // Emergency is active, help needed
  responding,  // Guardians are responding
  resolved,    // Emergency resolved safely
  cancelled,   // User cancelled the emergency
}

/// Emergency record model
class Emergency {
  final String id;
  final String userId;
  final EmergencyStatus status;
  final double? latitude;
  final double? longitude;
  final String? address;
  final DateTime startedAt;
  final DateTime? endedAt;
  final List<String> notifiedContacts;
  final List<String> responders;
  final String? audioRecordingUrl;
  final String? notes;

  const Emergency({
    required this.id,
    required this.userId,
    required this.status,
    this.latitude,
    this.longitude,
    this.address,
    required this.startedAt,
    this.endedAt,
    this.notifiedContacts = const [],
    this.responders = const [],
    this.audioRecordingUrl,
    this.notes,
  });

  /// Create from Firestore document
  factory Emergency.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return Emergency.fromJson(data, doc.id);
  }

  /// Create from JSON
  factory Emergency.fromJson(Map<String, dynamic> json, String id) {
    return Emergency(
      id: id,
      userId: json['userId'] as String? ?? '',
      status: EmergencyStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => EmergencyStatus.active,
      ),
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      address: json['address'] as String?,
      startedAt: (json['startedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      endedAt: (json['endedAt'] as Timestamp?)?.toDate(),
      notifiedContacts: List<String>.from(json['notifiedContacts'] ?? []),
      responders: List<String>.from(json['responders'] ?? []),
      audioRecordingUrl: json['audioRecordingUrl'] as String?,
      notes: json['notes'] as String?,
    );
  }

  /// Convert to JSON for Firestore
  Map<String, dynamic> toJson() => {
    'userId': userId,
    'status': status.name,
    'latitude': latitude,
    'longitude': longitude,
    'address': address,
    'startedAt': Timestamp.fromDate(startedAt),
    'endedAt': endedAt != null ? Timestamp.fromDate(endedAt!) : null,
    'notifiedContacts': notifiedContacts,
    'responders': responders,
    'audioRecordingUrl': audioRecordingUrl,
    'notes': notes,
  };

  /// Copy with modifications
  Emergency copyWith({
    String? id,
    String? userId,
    EmergencyStatus? status,
    double? latitude,
    double? longitude,
    String? address,
    DateTime? startedAt,
    DateTime? endedAt,
    List<String>? notifiedContacts,
    List<String>? responders,
    String? audioRecordingUrl,
    String? notes,
  }) {
    return Emergency(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      status: status ?? this.status,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      address: address ?? this.address,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      notifiedContacts: notifiedContacts ?? this.notifiedContacts,
      responders: responders ?? this.responders,
      audioRecordingUrl: audioRecordingUrl ?? this.audioRecordingUrl,
      notes: notes ?? this.notes,
    );
  }

  /// Check if emergency is active
  bool get isActive => status == EmergencyStatus.active || status == EmergencyStatus.responding;

  /// Duration of emergency
  Duration get duration {
    final end = endedAt ?? DateTime.now();
    return end.difference(startedAt);
  }

  /// Display status name
  String get statusDisplayName {
    switch (status) {
      case EmergencyStatus.active:
        return 'Active - Help Needed';
      case EmergencyStatus.responding:
        return 'Guardians Responding';
      case EmergencyStatus.resolved:
        return 'Resolved';
      case EmergencyStatus.cancelled:
        return 'Cancelled';
    }
  }
}
