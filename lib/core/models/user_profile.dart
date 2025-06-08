/*
 * Guardian - Women's Safety App
 * © 2025 All Rights Reserved - Kunal Singh
 * Contact: kunalsingh2514@gmail.com
 */

/// Model class for user profile
class UserProfile {
  /// Unique identifier for the user
  final String id;
  
  /// User's display name
  final String displayName;
  
  /// User's email address
  final String email;
  
  /// URL to the user's profile picture
  final String? photoUrl;
  
  /// User's phone number
  final String? phoneNumber;
  
  /// User's address
  final String? address;
  
  /// Emergency information (e.g., medical conditions, allergies)
  final Map<String, dynamic>? emergencyInfo;
  
  /// User settings
  final Map<String, dynamic>? settings;
  
  /// Constructor
  UserProfile({
    required this.id,
    required this.displayName,
    required this.email,
    this.photoUrl,
    this.phoneNumber,
    this.address,
    this.emergencyInfo,
    this.settings,
  });
  
  /// Create a profile from a map (e.g., from Firestore)
  factory UserProfile.fromMap(Map<String, dynamic> map, String id) {
    return UserProfile(
      id: id,
      displayName: map['displayName'] ?? '',
      email: map['email'] ?? '',
      photoUrl: map['photoUrl'],
      phoneNumber: map['phoneNumber'],
      address: map['address'],
      emergencyInfo: map['emergencyInfo'],
      settings: map['settings'],
    );
  }
  
  /// Convert profile to a map (e.g., for Firestore)
  Map<String, dynamic> toMap() {
    return {
      'displayName': displayName,
      'email': email,
      'photoUrl': photoUrl,
      'phoneNumber': phoneNumber,
      'address': address,
      'emergencyInfo': emergencyInfo,
      'settings': settings,
    };
  }
  
  /// Create a copy of this profile with some fields replaced
  UserProfile copyWith({
    String? displayName,
    String? email,
    String? photoUrl,
    String? phoneNumber,
    String? address,
    Map<String, dynamic>? emergencyInfo,
    Map<String, dynamic>? settings,
  }) {
    return UserProfile(
      id: id,
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
      photoUrl: photoUrl ?? this.photoUrl,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      address: address ?? this.address,
      emergencyInfo: emergencyInfo ?? this.emergencyInfo,
      settings: settings ?? this.settings,
    );
  }
}
