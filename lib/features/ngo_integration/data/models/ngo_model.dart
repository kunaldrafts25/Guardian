/*
 * Guardian - Women's Safety App
 * © 2025 All Rights Reserved - Kunal Singh
 * Contact: kunalsingh2514@gmail.com
 */

/// Type of NGO
enum NGOType {
  /// Women's safety organization
  womenSafety,
  
  /// Crisis support organization
  crisisSupport,
  
  /// Legal aid organization
  legalAid,
  
  /// Mental health support organization
  mentalHealth,
  
  /// Community safety organization
  communitySafety,
  
  /// Other type of organization
  other,
}

/// A model representing an NGO service
class NGOService {
  /// Unique identifier for the service
  final String id;
  
  /// Name of the service
  final String name;
  
  /// Description of the service
  final String description;
  
  /// Type of service
  final String type;
  
  /// Whether the service is free
  final bool isFree;
  
  /// Cost of the service (if not free)
  final double? cost;
  
  /// Currency of the cost
  final String? currency;
  
  /// Whether the service is available 24/7
  final bool isAvailable24x7;
  
  /// Service availability hours (if not 24/7)
  final String? availabilityHours;
  
  /// Whether the service requires appointment
  final bool requiresAppointment;
  
  /// Whether the service is available online
  final bool isOnline;
  
  /// Whether the service is available in person
  final bool isInPerson;
  
  /// Contact information for the service
  final Map<String, String>? contactInfo;

  NGOService({
    required this.id,
    required this.name,
    required this.description,
    required this.type,
    required this.isFree,
    this.cost,
    this.currency,
    required this.isAvailable24x7,
    this.availabilityHours,
    required this.requiresAppointment,
    required this.isOnline,
    required this.isInPerson,
    this.contactInfo,
  });

  /// Convert to a map for storage
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'type': type,
      'isFree': isFree,
      'cost': cost,
      'currency': currency,
      'isAvailable24x7': isAvailable24x7,
      'availabilityHours': availabilityHours,
      'requiresAppointment': requiresAppointment,
      'isOnline': isOnline,
      'isInPerson': isInPerson,
      'contactInfo': contactInfo,
    };
  }

  /// Create from a map
  factory NGOService.fromMap(Map<String, dynamic> map) {
    return NGOService(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      type: map['type'] ?? '',
      isFree: map['isFree'] ?? false,
      cost: map['cost'],
      currency: map['currency'],
      isAvailable24x7: map['isAvailable24x7'] ?? false,
      availabilityHours: map['availabilityHours'],
      requiresAppointment: map['requiresAppointment'] ?? false,
      isOnline: map['isOnline'] ?? false,
      isInPerson: map['isInPerson'] ?? false,
      contactInfo: map['contactInfo'] != null
          ? Map<String, String>.from(map['contactInfo'])
          : null,
    );
  }
}

/// A model representing an NGO
class NGO {
  /// Unique identifier for the NGO
  final String id;
  
  /// Name of the NGO
  final String name;
  
  /// Description of the NGO
  final String description;
  
  /// Type of NGO
  final NGOType type;
  
  /// Logo URL
  final String logoUrl;
  
  /// Website URL
  final String? websiteUrl;
  
  /// Phone number
  final String? phoneNumber;
  
  /// Email address
  final String? email;
  
  /// Physical address
  final String? address;
  
  /// City
  final String? city;
  
  /// State or province
  final String? state;
  
  /// Country
  final String? country;
  
  /// Postal code
  final String? postalCode;
  
  /// Social media links
  final Map<String, String>? socialMedia;
  
  /// Services offered by the NGO
  final List<NGOService> services;
  
  /// Operating hours
  final String? operatingHours;
  
  /// Whether the NGO is verified
  final bool isVerified;
  
  /// Average rating (1-5)
  final double averageRating;
  
  /// Number of ratings
  final int ratingCount;
  
  /// Whether the NGO accepts donations
  final bool acceptsDonations;
  
  /// Donation methods
  final List<String>? donationMethods;
  
  /// Whether the NGO accepts volunteers
  final bool acceptsVolunteers;
  
  /// Volunteer opportunities
  final List<String>? volunteerOpportunities;

  NGO({
    required this.id,
    required this.name,
    required this.description,
    required this.type,
    required this.logoUrl,
    this.websiteUrl,
    this.phoneNumber,
    this.email,
    this.address,
    this.city,
    this.state,
    this.country,
    this.postalCode,
    this.socialMedia,
    required this.services,
    this.operatingHours,
    this.isVerified = false,
    this.averageRating = 0.0,
    this.ratingCount = 0,
    this.acceptsDonations = false,
    this.donationMethods,
    this.acceptsVolunteers = false,
    this.volunteerOpportunities,
  });

  /// Convert to a map for storage
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'type': type.toString().split('.').last,
      'logoUrl': logoUrl,
      'websiteUrl': websiteUrl,
      'phoneNumber': phoneNumber,
      'email': email,
      'address': address,
      'city': city,
      'state': state,
      'country': country,
      'postalCode': postalCode,
      'socialMedia': socialMedia,
      'services': services.map((service) => service.toMap()).toList(),
      'operatingHours': operatingHours,
      'isVerified': isVerified,
      'averageRating': averageRating,
      'ratingCount': ratingCount,
      'acceptsDonations': acceptsDonations,
      'donationMethods': donationMethods,
      'acceptsVolunteers': acceptsVolunteers,
      'volunteerOpportunities': volunteerOpportunities,
    };
  }

  /// Create from a map
  factory NGO.fromMap(Map<String, dynamic> map) {
    return NGO(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      type: NGOType.values.firstWhere(
        (e) => e.toString().split('.').last == map['type'],
        orElse: () => NGOType.other,
      ),
      logoUrl: map['logoUrl'] ?? '',
      websiteUrl: map['websiteUrl'],
      phoneNumber: map['phoneNumber'],
      email: map['email'],
      address: map['address'],
      city: map['city'],
      state: map['state'],
      country: map['country'],
      postalCode: map['postalCode'],
      socialMedia: map['socialMedia'] != null
          ? Map<String, String>.from(map['socialMedia'])
          : null,
      services: (map['services'] as List?)
              ?.map((service) => NGOService.fromMap(service))
              .toList() ??
          [],
      operatingHours: map['operatingHours'],
      isVerified: map['isVerified'] ?? false,
      averageRating: (map['averageRating'] ?? 0.0).toDouble(),
      ratingCount: map['ratingCount'] ?? 0,
      acceptsDonations: map['acceptsDonations'] ?? false,
      donationMethods: (map['donationMethods'] as List?)
          ?.map((method) => method.toString())
          .toList(),
      acceptsVolunteers: map['acceptsVolunteers'] ?? false,
      volunteerOpportunities: (map['volunteerOpportunities'] as List?)
          ?.map((opportunity) => opportunity.toString())
          .toList(),
    );
  }
}
