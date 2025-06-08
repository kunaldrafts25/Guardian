/*
 * Guardian - Women's Safety App
 * © 2025 All Rights Reserved - Kunal Singh
 * Contact: kunalsingh2514@gmail.com
 */

class UserProfile {
  final String id;
  final String email;
  final String? displayName;
  final String? phoneNumber;
  final String? photoURL;
  final bool emailVerified;
  final List<EmergencyContact> emergencyContacts;
  final Map<String, dynamic> settings;
  final DateTime? createdAt;
  final DateTime? lastLogin;

  UserProfile({
    required this.id,
    required this.email,
    this.displayName,
    this.phoneNumber,
    this.photoURL,
    this.emailVerified = false,
    this.emergencyContacts = const [],
    this.settings = const {},
    this.createdAt,
    this.lastLogin,
  });

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    List<EmergencyContact> contacts = [];
    if (map['emergencyContacts'] != null) {
      contacts = List<Map<String, dynamic>>.from(map['emergencyContacts'])
          .map((contact) => EmergencyContact.fromMap(contact))
          .toList();
    }

    return UserProfile(
      id: map['id'] ?? '',
      email: map['email'] ?? '',
      displayName: map['displayName'],
      phoneNumber: map['phoneNumber'],
      photoURL: map['photoURL'],
      emailVerified: map['emailVerified'] ?? false,
      emergencyContacts: contacts,
      settings: Map<String, dynamic>.from(map['settings'] ?? {}),
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'])
          : null,
      lastLogin: map['lastLogin'] != null
          ? DateTime.parse(map['lastLogin'])
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'email': email,
      'displayName': displayName,
      'phoneNumber': phoneNumber,
      'photoURL': photoURL,
      'emailVerified': emailVerified,
      'emergencyContacts': emergencyContacts.map((contact) => contact.toMap()).toList(),
      'settings': settings,
      'createdAt': createdAt?.toIso8601String(),
      'lastLogin': lastLogin?.toIso8601String(),
    };
  }

  UserProfile copyWith({
    String? id,
    String? email,
    String? displayName,
    String? phoneNumber,
    String? photoURL,
    bool? emailVerified,
    List<EmergencyContact>? emergencyContacts,
    Map<String, dynamic>? settings,
    DateTime? createdAt,
    DateTime? lastLogin,
  }) {
    return UserProfile(
      id: id ?? this.id,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      photoURL: photoURL ?? this.photoURL,
      emailVerified: emailVerified ?? this.emailVerified,
      emergencyContacts: emergencyContacts ?? this.emergencyContacts,
      settings: settings ?? this.settings,
      createdAt: createdAt ?? this.createdAt,
      lastLogin: lastLogin ?? this.lastLogin,
    );
  }
}

class EmergencyContact {
  final String name;
  final String phone;
  final String? relationship;

  EmergencyContact({
    required this.name,
    required this.phone,
    this.relationship,
  });

  factory EmergencyContact.fromMap(Map<String, dynamic> map) {
    return EmergencyContact(
      name: map['name'] ?? '',
      phone: map['phone'] ?? '',
      relationship: map['relationship'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'phone': phone,
      'relationship': relationship,
    };
  }

  EmergencyContact copyWith({
    String? name,
    String? phone,
    String? relationship,
  }) {
    return EmergencyContact(
      name: name ?? this.name,
      phone: phone ?? this.phone,
      relationship: relationship ?? this.relationship,
    );
  }
}
