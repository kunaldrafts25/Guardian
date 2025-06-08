/*
 * Guardian - Women's Safety App
 * © 2025 All Rights Reserved - Kunal Singh
 * Contact: kunalsingh2514@gmail.com
 */

import 'package:guardian/features/community/data/incident_model.dart';

class CommunityEvent {
  final String id;
  final String title;
  final String description;
  final String organizer;
  final DateTime startDate;
  final DateTime endDate;
  final Location location;
  final String address;
  final String category;
  final String? imageUrl;
  final int attendeeCount;
  final List<String> attendees;
  final DateTime createdAt;

  CommunityEvent({
    required this.id,
    required this.title,
    required this.description,
    required this.organizer,
    required this.startDate,
    required this.endDate,
    required this.location,
    required this.address,
    required this.category,
    this.imageUrl,
    this.attendeeCount = 0,
    this.attendees = const [],
    required this.createdAt,
  });

  factory CommunityEvent.fromMap(Map<String, dynamic> map) {
    return CommunityEvent(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      organizer: map['organizer'] ?? '',
      startDate: map['startDate'] != null
          ? DateTime.parse(map['startDate'])
          : DateTime.now(),
      endDate: map['endDate'] != null
          ? DateTime.parse(map['endDate'])
          : DateTime.now().add(const Duration(hours: 2)),
      location: Location(
        latitude: map['latitude']?.toDouble() ?? 0.0,
        longitude: map['longitude']?.toDouble() ?? 0.0,
      ),
      address: map['address'] ?? '',
      category: map['category'] ?? '',
      imageUrl: map['imageUrl'],
      attendeeCount: map['attendeeCount']?.toInt() ?? 0,
      attendees: List<String>.from(map['attendees'] ?? []),
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'organizer': organizer,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
      'latitude': location.latitude,
      'longitude': location.longitude,
      'address': address,
      'category': category,
      'imageUrl': imageUrl,
      'attendeeCount': attendeeCount,
      'attendees': attendees,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  CommunityEvent copyWith({
    String? id,
    String? title,
    String? description,
    String? organizer,
    DateTime? startDate,
    DateTime? endDate,
    Location? location,
    String? address,
    String? category,
    String? imageUrl,
    int? attendeeCount,
    List<String>? attendees,
    DateTime? createdAt,
  }) {
    return CommunityEvent(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      organizer: organizer ?? this.organizer,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      location: location ?? this.location,
      address: address ?? this.address,
      category: category ?? this.category,
      imageUrl: imageUrl ?? this.imageUrl,
      attendeeCount: attendeeCount ?? this.attendeeCount,
      attendees: attendees ?? this.attendees,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  bool get isUpcoming => startDate.isAfter(DateTime.now());
  bool get isPast => endDate.isBefore(DateTime.now());
  bool get isOngoing =>
      startDate.isBefore(DateTime.now()) && endDate.isAfter(DateTime.now());
}

// Mock events for fallback
final List<CommunityEvent> mockEvents = [
  CommunityEvent(
    id: '1',
    title: 'Self-Defense Workshop',
    description: 'Learn basic self-defense techniques from certified instructors. No prior experience required.',
    organizer: 'Community Safety Group',
    startDate: DateTime.now().add(const Duration(days: 7)),
    endDate: DateTime.now().add(const Duration(days: 7, hours: 3)),
    location: const Location(latitude: 19.0760, longitude: 72.8777), // Mumbai
    address: 'Community Center, 123 Main St, Mumbai',
    category: 'Workshop',
    imageUrl: 'https://via.placeholder.com/300',
    attendeeCount: 25,
    attendees: [],
    createdAt: DateTime.now().subtract(const Duration(days: 14)),
  ),
  CommunityEvent(
    id: '2',
    title: 'Women\'s Safety Awareness Walk',
    description: 'Join us for a community walk to raise awareness about women\'s safety issues in our neighborhood.',
    organizer: 'Women\'s Safety Coalition',
    startDate: DateTime.now().add(const Duration(days: 14)),
    endDate: DateTime.now().add(const Duration(days: 14, hours: 2)),
    location: const Location(latitude: 28.7041, longitude: 77.1025), // Delhi
    address: 'Central Park, Delhi',
    category: 'Community',
    imageUrl: 'https://via.placeholder.com/300',
    attendeeCount: 50,
    attendees: [],
    createdAt: DateTime.now().subtract(const Duration(days: 10)),
  ),
  CommunityEvent(
    id: '3',
    title: 'Safety Tech Showcase',
    description: 'Explore the latest safety technologies and gadgets designed for personal protection.',
    organizer: 'Tech for Safety',
    startDate: DateTime.now().add(const Duration(days: 21)),
    endDate: DateTime.now().add(const Duration(days: 21, hours: 5)),
    location: const Location(latitude: 12.9716, longitude: 77.5946), // Bangalore
    address: 'Tech Hub, 456 Innovation Ave, Bangalore',
    category: 'Exhibition',
    imageUrl: 'https://via.placeholder.com/300',
    attendeeCount: 75,
    attendees: [],
    createdAt: DateTime.now().subtract(const Duration(days: 7)),
  ),
];
