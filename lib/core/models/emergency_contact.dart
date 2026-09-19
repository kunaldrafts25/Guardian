/*
 * Guardian - Women's Safety App
 * © 2025 All Rights Reserved - Kunal Singh
 * Contact: kunalsingh2514@gmail.com
 */

/// Model class for emergency contacts
class EmergencyContact {
  /// Unique identifier for the contact
  final String? id;

  /// Name of the emergency contact
  final String name;

  /// Phone number of the emergency contact
  final String phoneNumber;

  /// Email address of the emergency contact (optional)
  final String? email;

  /// Relationship to the user (e.g., family, friend, etc.)
  final String relationship;

  /// Whether this contact should be notified in case of emergency
  final bool notifyInEmergency;

  /// Whether this contact can track the user's location
  final bool canTrackLocation;

  /// Constructor
  EmergencyContact({
    this.id,
    required this.name,
    required this.phoneNumber,
    this.email,
    required this.relationship,
    this.notifyInEmergency = true,
    this.canTrackLocation = false,
  });

  /// Create a contact from a map (e.g., from Firestore)
  factory EmergencyContact.fromMap(Map<String, dynamic> map, [String? id]) {
    return EmergencyContact(
      id: id ?? map['id'],
      name: map['name'] ?? '',
      phoneNumber: map['phoneNumber'] ?? '',
      email: map['email'],
      relationship: map['relationship'] ?? '',
      notifyInEmergency: map['notifyInEmergency'] ?? true,
      canTrackLocation: map['canTrackLocation'] ?? false,
    );
  }

  /// Convert contact to a map (e.g., for Firestore)
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'phoneNumber': phoneNumber,
      'email': email,
      'relationship': relationship,
      'notifyInEmergency': notifyInEmergency,
      'canTrackLocation': canTrackLocation,
    };
  }

  /// Create a copy of this contact with some fields replaced
  EmergencyContact copyWith({
    String? name,
    String? phoneNumber,
    String? email,
    String? relationship,
    bool? notifyInEmergency,
    bool? canTrackLocation,
  }) {
    return EmergencyContact(
      id: id,
      name: name ?? this.name,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      email: email ?? this.email,
      relationship: relationship ?? this.relationship,
      notifyInEmergency: notifyInEmergency ?? this.notifyInEmergency,
      canTrackLocation: canTrackLocation ?? this.canTrackLocation,
    );
  }
}
