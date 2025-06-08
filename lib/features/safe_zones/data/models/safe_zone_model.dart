/*
 * Guardian - Women's Safety App
 * © 2025 All Rights Reserved - Kunal Singh
 * Contact: kunalsingh2514@gmail.com
 */

/// Safety rating of a zone
enum SafetyRatingLevel {
  /// Very safe zone
  verySafe,

  /// Safe zone
  safe,

  /// Moderate safety
  moderate,

  /// Unsafe zone
  unsafe,

  /// Very unsafe zone
  veryUnsafe,
}

/// Time context for safety ratings
enum TimeContext {
  /// Safe during all times
  allTimes,

  /// Safe during daytime only
  daytimeOnly,

  /// Safe during nighttime only
  nighttimeOnly,

  /// Unsafe at all times
  neverSafe,
}

/// A model representing a safety rating for a location
class SafetyRating {
  /// Unique identifier for the rating
  final String id;

  /// User ID who submitted the rating
  final String userId;

  /// Safety rating value
  final SafetyRatingLevel rating;

  /// Time context for the rating
  final TimeContext timeContext;

  /// Comment or description
  final String? comment;

  /// When the rating was submitted
  final DateTime createdAt;

  /// Incident type (if applicable)
  final String? incidentType;

  /// Whether the rating is anonymous
  final bool isAnonymous;

  SafetyRating({
    required this.id,
    required this.userId,
    required this.rating,
    required this.timeContext,
    this.comment,
    DateTime? createdAt,
    this.incidentType,
    this.isAnonymous = false,
  }) : createdAt = createdAt ?? DateTime.now();

  /// Convert to a map for storage
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'rating': rating.toString().split('.').last,
      'timeContext': timeContext.toString().split('.').last,
      'comment': comment,
      'createdAt': createdAt.toIso8601String(),
      'incidentType': incidentType,
      'isAnonymous': isAnonymous,
    };
  }

  /// Create from a map
  factory SafetyRating.fromMap(Map<String, dynamic> map) {
    return SafetyRating(
      id: map['id'] ?? '',
      userId: map['userId'] ?? '',
      rating: SafetyRatingLevel.values.firstWhere(
        (e) => e.toString().split('.').last == map['rating'],
        orElse: () => SafetyRatingLevel.moderate,
      ),
      timeContext: TimeContext.values.firstWhere(
        (e) => e.toString().split('.').last == map['timeContext'],
        orElse: () => TimeContext.allTimes,
      ),
      comment: map['comment'],
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'])
          : DateTime.now(),
      incidentType: map['incidentType'],
      isAnonymous: map['isAnonymous'] ?? false,
    );
  }
}

/// A model representing a safe zone
class SafeZone {
  /// Unique identifier for the zone
  final String id;

  /// Name of the zone
  final String name;

  /// Description of the zone
  final String? description;

  /// Location of the zone
  final Map<String, double> location;

  /// Radius of the zone in meters
  final double radius;

  /// Address of the zone (if available)
  final String? address;

  /// Safety ratings for this zone
  final List<SafetyRating> ratings;

  /// Average safety rating
  final double averageRating;

  /// Predominant time context
  final TimeContext predominantTimeContext;

  /// When the zone was created
  final DateTime createdAt;

  /// When the zone was last updated
  final DateTime updatedAt;

  /// User ID who created the zone
  final String createdBy;

  /// Tags or categories for the zone
  final List<String> tags;

  /// Whether the zone is verified by authorities
  final bool isVerified;

  SafeZone({
    required this.id,
    required this.name,
    this.description,
    required this.location,
    required this.radius,
    this.address,
    required this.ratings,
    required this.averageRating,
    required this.predominantTimeContext,
    DateTime? createdAt,
    DateTime? updatedAt,
    required this.createdBy,
    required this.tags,
    this.isVerified = false,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  /// Convert to a map for storage
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'location': location,
      'radius': radius,
      'address': address,
      'ratings': ratings.map((r) => r.toMap()).toList(),
      'averageRating': averageRating,
      'predominantTimeContext':
          predominantTimeContext.toString().split('.').last,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'createdBy': createdBy,
      'tags': tags,
      'isVerified': isVerified,
    };
  }

  /// Create from a map
  factory SafeZone.fromMap(Map<String, dynamic> map) {
    return SafeZone(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      description: map['description'],
      location: Map<String, double>.from(map['location'] ?? {}),
      radius: map['radius'] ?? 100.0,
      address: map['address'],
      ratings: (map['ratings'] as List?)
              ?.map((r) => SafetyRating.fromMap(r))
              .toList() ??
          [],
      averageRating: map['averageRating'] ?? 3.0,
      predominantTimeContext: TimeContext.values.firstWhere(
        (e) => e.toString().split('.').last == map['predominantTimeContext'],
        orElse: () => TimeContext.allTimes,
      ),
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'])
          : DateTime.now(),
      updatedAt: map['updatedAt'] != null
          ? DateTime.parse(map['updatedAt'])
          : DateTime.now(),
      createdBy: map['createdBy'] ?? '',
      tags: List<String>.from(map['tags'] ?? []),
      isVerified: map['isVerified'] ?? false,
    );
  }

  /// Create a copy with updated values
  SafeZone copyWith({
    String? id,
    String? name,
    String? description,
    Map<String, double>? location,
    double? radius,
    String? address,
    List<SafetyRating>? ratings,
    double? averageRating,
    TimeContext? predominantTimeContext,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
    List<String>? tags,
    bool? isVerified,
  }) {
    return SafeZone(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      location: location ?? this.location,
      radius: radius ?? this.radius,
      address: address ?? this.address,
      ratings: ratings ?? this.ratings,
      averageRating: averageRating ?? this.averageRating,
      predominantTimeContext:
          predominantTimeContext ?? this.predominantTimeContext,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
      tags: tags ?? this.tags,
      isVerified: isVerified ?? this.isVerified,
    );
  }
}
