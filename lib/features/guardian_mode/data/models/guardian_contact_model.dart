/*
 * Guardian - Women's Safety App
 * © 2025 All Rights Reserved - Kunal Singh
 * Contact: kunalsingh2514@gmail.com
 */

/// A model representing a trusted contact who can monitor guardian sessions
class GuardianContact {
  /// Unique identifier for the contact
  final String id;
  
  /// User ID if the contact is also a user of the app
  final String? userId;
  
  /// Name of the contact
  final String name;
  
  /// Phone number of the contact
  final String phoneNumber;
  
  /// Email address of the contact
  final String? email;
  
  /// Relationship to the user (e.g., family, friend, etc.)
  final String? relationship;
  
  /// Whether this contact is a primary emergency contact
  final bool isPrimaryContact;
  
  /// Whether this contact has access to live tracking
  final bool canAccessLiveTracking;
  
  /// Whether this contact should be notified in emergencies
  final bool notifyInEmergency;
  
  /// Profile picture URL
  final String? profilePictureUrl;
  
  /// When this contact was added
  final DateTime addedAt;

  GuardianContact({
    required this.id,
    this.userId,
    required this.name,
    required this.phoneNumber,
    this.email,
    this.relationship,
    this.isPrimaryContact = false,
    this.canAccessLiveTracking = true,
    this.notifyInEmergency = true,
    this.profilePictureUrl,
    DateTime? addedAt,
  }) : addedAt = addedAt ?? DateTime.now();

  /// Convert to a map for storage
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'name': name,
      'phoneNumber': phoneNumber,
      'email': email,
      'relationship': relationship,
      'isPrimaryContact': isPrimaryContact,
      'canAccessLiveTracking': canAccessLiveTracking,
      'notifyInEmergency': notifyInEmergency,
      'profilePictureUrl': profilePictureUrl,
      'addedAt': addedAt.toIso8601String(),
    };
  }

  /// Create from a map
  factory GuardianContact.fromMap(Map<String, dynamic> map) {
    return GuardianContact(
      id: map['id'] ?? '',
      userId: map['userId'],
      name: map['name'] ?? '',
      phoneNumber: map['phoneNumber'] ?? '',
      email: map['email'],
      relationship: map['relationship'],
      isPrimaryContact: map['isPrimaryContact'] ?? false,
      canAccessLiveTracking: map['canAccessLiveTracking'] ?? true,
      notifyInEmergency: map['notifyInEmergency'] ?? true,
      profilePictureUrl: map['profilePictureUrl'],
      addedAt: map['addedAt'] != null
          ? DateTime.parse(map['addedAt'])
          : DateTime.now(),
    );
  }

  /// Create a copy with updated values
  GuardianContact copyWith({
    String? id,
    String? userId,
    String? name,
    String? phoneNumber,
    String? email,
    String? relationship,
    bool? isPrimaryContact,
    bool? canAccessLiveTracking,
    bool? notifyInEmergency,
    String? profilePictureUrl,
    DateTime? addedAt,
  }) {
    return GuardianContact(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      email: email ?? this.email,
      relationship: relationship ?? this.relationship,
      isPrimaryContact: isPrimaryContact ?? this.isPrimaryContact,
      canAccessLiveTracking: canAccessLiveTracking ?? this.canAccessLiveTracking,
      notifyInEmergency: notifyInEmergency ?? this.notifyInEmergency,
      profilePictureUrl: profilePictureUrl ?? this.profilePictureUrl,
      addedAt: addedAt ?? this.addedAt,
    );
  }
}
