/*
 * Guardian 2.0 - Women's Safety App
 * © 2025 All Rights Reserved - Kunal Singh
 * 
 * User Model
 */

import 'package:cloud_firestore/cloud_firestore.dart';

/// Location mode enum for privacy settings
enum LocationMode {
  ghost,    // Location only during SOS
  smart,    // Auto-activate at night/risky moments
  guardian, // Always on
}

/// Trust rank based on points
enum TrustRank {
  watcher,        // 0-49 points
  walker,         // 50-199 points  
  responder,      // 200-499 points
  sentinel,       // 500-999 points
  guardianAngel,  // 1000+ points
}

/// Emergency contact model
class EmergencyContact {
  final String id;
  final String name;
  final String phone;
  final String relation;
  final bool isPrimary;

  const EmergencyContact({
    required this.id,
    required this.name,
    required this.phone,
    required this.relation,
    this.isPrimary = false,
  });

  factory EmergencyContact.fromJson(Map<String, dynamic> json) {
    return EmergencyContact(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      relation: json['relation'] as String? ?? '',
      isPrimary: json['isPrimary'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'phone': phone,
    'relation': relation,
    'isPrimary': isPrimary,
  };

  EmergencyContact copyWith({
    String? id,
    String? name,
    String? phone,
    String? relation,
    bool? isPrimary,
  }) {
    return EmergencyContact(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      relation: relation ?? this.relation,
      isPrimary: isPrimary ?? this.isPrimary,
    );
  }
}

/// User profile model
class UserModel {
  final String uid;
  final String phoneNumber;
  final String? displayName;
  final String? photoUrl;
  final int trustScore;
  final TrustRank trustRank;
  final LocationMode locationMode;
  final List<EmergencyContact> emergencyContacts;
  final int helpedCount;
  final int sosUsedCount;
  final int walkSessionsCount;
  final bool isPhoneVerified;
  final bool isIdVerified;
  final DateTime createdAt;
  final DateTime updatedAt;

  const UserModel({
    required this.uid,
    required this.phoneNumber,
    this.displayName,
    this.photoUrl,
    this.trustScore = 0,
    this.trustRank = TrustRank.watcher,
    this.locationMode = LocationMode.smart,
    this.emergencyContacts = const [],
    this.helpedCount = 0,
    this.sosUsedCount = 0,
    this.walkSessionsCount = 0,
    this.isPhoneVerified = true,
    this.isIdVerified = false,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Create from Firestore document
  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return UserModel.fromJson(data, doc.id);
  }

  /// Create from JSON
  factory UserModel.fromJson(Map<String, dynamic> json, String uid) {
    final contacts = (json['emergencyContacts'] as List<dynamic>?)
        ?.map((e) => EmergencyContact.fromJson(e as Map<String, dynamic>))
        .toList() ?? [];
    
    return UserModel(
      uid: uid,
      phoneNumber: json['phoneNumber'] as String? ?? '',
      displayName: json['displayName'] as String?,
      photoUrl: json['photoUrl'] as String?,
      trustScore: json['trustScore'] as int? ?? 0,
      trustRank: TrustRank.values.firstWhere(
        (e) => e.name == json['trustRank'],
        orElse: () => TrustRank.watcher,
      ),
      locationMode: LocationMode.values.firstWhere(
        (e) => e.name == json['locationMode'],
        orElse: () => LocationMode.smart,
      ),
      emergencyContacts: contacts,
      helpedCount: json['helpedCount'] as int? ?? 0,
      sosUsedCount: json['sosUsedCount'] as int? ?? 0,
      walkSessionsCount: json['walkSessionsCount'] as int? ?? 0,
      isPhoneVerified: json['isPhoneVerified'] as bool? ?? true,
      isIdVerified: json['isIdVerified'] as bool? ?? false,
      createdAt: (json['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (json['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  /// Convert to JSON for Firestore
  Map<String, dynamic> toJson() => {
    'phoneNumber': phoneNumber,
    'displayName': displayName,
    'photoUrl': photoUrl,
    'trustScore': trustScore,
    'trustRank': trustRank.name,
    'locationMode': locationMode.name,
    'emergencyContacts': emergencyContacts.map((e) => e.toJson()).toList(),
    'helpedCount': helpedCount,
    'sosUsedCount': sosUsedCount,
    'walkSessionsCount': walkSessionsCount,
    'isPhoneVerified': isPhoneVerified,
    'isIdVerified': isIdVerified,
    'createdAt': Timestamp.fromDate(createdAt),
    'updatedAt': Timestamp.fromDate(updatedAt),
  };

  /// Copy with modifications
  UserModel copyWith({
    String? uid,
    String? phoneNumber,
    String? displayName,
    String? photoUrl,
    int? trustScore,
    TrustRank? trustRank,
    LocationMode? locationMode,
    List<EmergencyContact>? emergencyContacts,
    int? helpedCount,
    int? sosUsedCount,
    int? walkSessionsCount,
    bool? isPhoneVerified,
    bool? isIdVerified,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      displayName: displayName ?? this.displayName,
      photoUrl: photoUrl ?? this.photoUrl,
      trustScore: trustScore ?? this.trustScore,
      trustRank: trustRank ?? this.trustRank,
      locationMode: locationMode ?? this.locationMode,
      emergencyContacts: emergencyContacts ?? this.emergencyContacts,
      helpedCount: helpedCount ?? this.helpedCount,
      sosUsedCount: sosUsedCount ?? this.sosUsedCount,
      walkSessionsCount: walkSessionsCount ?? this.walkSessionsCount,
      isPhoneVerified: isPhoneVerified ?? this.isPhoneVerified,
      isIdVerified: isIdVerified ?? this.isIdVerified,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Calculate trust rank from score
  static TrustRank calculateRank(int score) {
    if (score >= 1000) return TrustRank.guardianAngel;
    if (score >= 500) return TrustRank.sentinel;
    if (score >= 200) return TrustRank.responder;
    if (score >= 50) return TrustRank.walker;
    return TrustRank.watcher;
  }

  /// Points needed for next rank
  int get pointsToNextRank {
    switch (trustRank) {
      case TrustRank.watcher:
        return 50 - trustScore;
      case TrustRank.walker:
        return 200 - trustScore;
      case TrustRank.responder:
        return 500 - trustScore;
      case TrustRank.sentinel:
        return 1000 - trustScore;
      case TrustRank.guardianAngel:
        return 0; // Max rank
    }
  }

  /// Display name for trust rank
  String get trustRankDisplayName {
    switch (trustRank) {
      case TrustRank.watcher:
        return 'Watcher';
      case TrustRank.walker:
        return 'Walker';
      case TrustRank.responder:
        return 'Responder';
      case TrustRank.sentinel:
        return 'Sentinel';
      case TrustRank.guardianAngel:
        return 'Guardian Angel';
    }
  }
}
