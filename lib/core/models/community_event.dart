/*
 * Guardian - Women's Safety App
 * © 2025 All Rights Reserved - Kunal Singh
 * Contact: kunalsingh2514@gmail.com
 */

/// Model class for community events
class CommunityEvent {
  /// Unique identifier for the event
  final String id;
  
  /// Title of the event
  final String title;
  
  /// Description of the event
  final String description;
  
  /// Location of the event
  final String location;
  
  /// Start date and time of the event
  final DateTime startDate;
  
  /// End date and time of the event
  final DateTime endDate;
  
  /// URL to the event image
  final String? imageUrl;
  
  /// User ID of the event organizer
  final String organizerId;
  
  /// Number of attendees
  final int attendeeCount;
  
  /// Whether the event is virtual
  final bool isVirtual;
  
  /// Link for virtual events
  final String? virtualLink;
  
  /// Constructor
  CommunityEvent({
    required this.id,
    required this.title,
    required this.description,
    required this.location,
    required this.startDate,
    required this.endDate,
    this.imageUrl,
    required this.organizerId,
    this.attendeeCount = 0,
    this.isVirtual = false,
    this.virtualLink,
  });
  
  /// Create an event from a map (e.g., from Firestore)
  factory CommunityEvent.fromMap(Map<String, dynamic> map, String id) {
    return CommunityEvent(
      id: id,
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      location: map['location'] ?? '',
      startDate: (map['startDate'] as dynamic)?.toDate() ?? DateTime.now(),
      endDate: (map['endDate'] as dynamic)?.toDate() ?? DateTime.now(),
      imageUrl: map['imageUrl'],
      organizerId: map['organizerId'] ?? '',
      attendeeCount: map['attendeeCount'] ?? 0,
      isVirtual: map['isVirtual'] ?? false,
      virtualLink: map['virtualLink'],
    );
  }
  
  /// Convert event to a map (e.g., for Firestore)
  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'location': location,
      'startDate': startDate,
      'endDate': endDate,
      'imageUrl': imageUrl,
      'organizerId': organizerId,
      'attendeeCount': attendeeCount,
      'isVirtual': isVirtual,
      'virtualLink': virtualLink,
    };
  }
  
  /// Create a copy of this event with some fields replaced
  CommunityEvent copyWith({
    String? title,
    String? description,
    String? location,
    DateTime? startDate,
    DateTime? endDate,
    String? imageUrl,
    String? organizerId,
    int? attendeeCount,
    bool? isVirtual,
    String? virtualLink,
  }) {
    return CommunityEvent(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      location: location ?? this.location,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      imageUrl: imageUrl ?? this.imageUrl,
      organizerId: organizerId ?? this.organizerId,
      attendeeCount: attendeeCount ?? this.attendeeCount,
      isVirtual: isVirtual ?? this.isVirtual,
      virtualLink: virtualLink ?? this.virtualLink,
    );
  }
}
