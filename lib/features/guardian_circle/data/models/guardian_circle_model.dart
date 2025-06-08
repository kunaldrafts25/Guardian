/*
 * Guardian - Women's Safety App
 * © 2025 All Rights Reserved - Kunal Singh
 * Contact: kunalsingh2514@gmail.com
 */

/// Status of a guardian circle member
enum GuardianMemberStatus {
  /// Member has been invited but hasn't accepted yet
  invited,
  
  /// Member has accepted the invitation and is active
  active,
  
  /// Member has been blocked
  blocked,
}

/// Role of a guardian circle member
enum GuardianMemberRole {
  /// Regular member who can respond to alerts
  member,
  
  /// Admin who can manage the circle
  admin,
}

/// A model representing a member of a guardian circle
class GuardianCircleMember {
  /// Unique identifier for the member
  final String id;
  
  /// User ID if the member is a registered user
  final String? userId;
  
  /// Name of the member
  final String name;
  
  /// Phone number of the member
  final String phoneNumber;
  
  /// Email address of the member
  final String? email;
  
  /// Relationship to the user
  final String? relationship;
  
  /// Status of the member
  final GuardianMemberStatus status;
  
  /// Role of the member
  final GuardianMemberRole role;
  
  /// When the member was added to the circle
  final DateTime addedAt;
  
  /// When the member last responded to an alert
  final DateTime? lastResponseTime;
  
  /// Profile picture URL
  final String? profilePictureUrl;

  GuardianCircleMember({
    required this.id,
    this.userId,
    required this.name,
    required this.phoneNumber,
    this.email,
    this.relationship,
    required this.status,
    required this.role,
    DateTime? addedAt,
    this.lastResponseTime,
    this.profilePictureUrl,
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
      'status': status.toString().split('.').last,
      'role': role.toString().split('.').last,
      'addedAt': addedAt.toIso8601String(),
      'lastResponseTime': lastResponseTime?.toIso8601String(),
      'profilePictureUrl': profilePictureUrl,
    };
  }

  /// Create from a map
  factory GuardianCircleMember.fromMap(Map<String, dynamic> map) {
    return GuardianCircleMember(
      id: map['id'] ?? '',
      userId: map['userId'],
      name: map['name'] ?? '',
      phoneNumber: map['phoneNumber'] ?? '',
      email: map['email'],
      relationship: map['relationship'],
      status: GuardianMemberStatus.values.firstWhere(
        (e) => e.toString().split('.').last == map['status'],
        orElse: () => GuardianMemberStatus.invited,
      ),
      role: GuardianMemberRole.values.firstWhere(
        (e) => e.toString().split('.').last == map['role'],
        orElse: () => GuardianMemberRole.member,
      ),
      addedAt: map['addedAt'] != null
          ? DateTime.parse(map['addedAt'])
          : DateTime.now(),
      lastResponseTime: map['lastResponseTime'] != null
          ? DateTime.parse(map['lastResponseTime'])
          : null,
      profilePictureUrl: map['profilePictureUrl'],
    );
  }

  /// Create a copy with updated values
  GuardianCircleMember copyWith({
    String? id,
    String? userId,
    String? name,
    String? phoneNumber,
    String? email,
    String? relationship,
    GuardianMemberStatus? status,
    GuardianMemberRole? role,
    DateTime? addedAt,
    DateTime? lastResponseTime,
    String? profilePictureUrl,
  }) {
    return GuardianCircleMember(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      email: email ?? this.email,
      relationship: relationship ?? this.relationship,
      status: status ?? this.status,
      role: role ?? this.role,
      addedAt: addedAt ?? this.addedAt,
      lastResponseTime: lastResponseTime ?? this.lastResponseTime,
      profilePictureUrl: profilePictureUrl ?? this.profilePictureUrl,
    );
  }
}

/// A model representing a guardian circle
class GuardianCircle {
  /// Unique identifier for the circle
  final String id;
  
  /// User ID of the circle owner
  final String ownerId;
  
  /// Name of the circle
  final String name;
  
  /// Description of the circle
  final String? description;
  
  /// Members of the circle
  final List<GuardianCircleMember> members;
  
  /// When the circle was created
  final DateTime createdAt;
  
  /// When the circle was last updated
  final DateTime updatedAt;
  
  /// Whether the circle is the default circle
  final bool isDefault;

  GuardianCircle({
    required this.id,
    required this.ownerId,
    required this.name,
    this.description,
    required this.members,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.isDefault = false,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  /// Convert to a map for storage
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'ownerId': ownerId,
      'name': name,
      'description': description,
      'members': members.map((m) => m.toMap()).toList(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'isDefault': isDefault,
    };
  }

  /// Create from a map
  factory GuardianCircle.fromMap(Map<String, dynamic> map) {
    return GuardianCircle(
      id: map['id'] ?? '',
      ownerId: map['ownerId'] ?? '',
      name: map['name'] ?? '',
      description: map['description'],
      members: (map['members'] as List?)
              ?.map((m) => GuardianCircleMember.fromMap(m))
              .toList() ??
          [],
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'])
          : DateTime.now(),
      updatedAt: map['updatedAt'] != null
          ? DateTime.parse(map['updatedAt'])
          : DateTime.now(),
      isDefault: map['isDefault'] ?? false,
    );
  }

  /// Create a copy with updated values
  GuardianCircle copyWith({
    String? id,
    String? ownerId,
    String? name,
    String? description,
    List<GuardianCircleMember>? members,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isDefault,
  }) {
    return GuardianCircle(
      id: id ?? this.id,
      ownerId: ownerId ?? this.ownerId,
      name: name ?? this.name,
      description: description ?? this.description,
      members: members ?? this.members,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isDefault: isDefault ?? this.isDefault,
    );
  }
}
