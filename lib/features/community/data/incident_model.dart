/*
 * Guardian - Women's Safety App
 * © 2025 All Rights Reserved - Kunal Singh
 * Contact: kunalsingh2514@gmail.com
 */

class Location {
  final double latitude;
  final double longitude;

  const Location({
    required this.latitude,
    required this.longitude,
  });

  factory Location.fromMap(Map<String, dynamic> map) {
    return Location(
      latitude: map['latitude']?.toDouble() ?? 0.0,
      longitude: map['longitude']?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'latitude': latitude,
      'longitude': longitude,
    };
  }
}

class Incident {
  final String id;
  final String userId;
  final String title;
  final String description;
  final Location location;
  final String category;
  final DateTime timestamp;
  final bool isAnonymous;
  final int reportCount;

  String get type => category;

  Incident({
    required this.id,
    required this.userId,
    required this.title,
    required this.description,
    required this.location,
    required this.category,
    required this.timestamp,
    required this.isAnonymous,
    required this.reportCount,
  });

  factory Incident.fromMap(Map<String, dynamic> map) {
    return Incident(
      id: map['id'] ?? '',
      userId: map['userId'] ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      location: Location(
        latitude: map['latitude']?.toDouble() ?? 0.0,
        longitude: map['longitude']?.toDouble() ?? 0.0,
      ),
      category: map['category'] ?? '',
      timestamp: map['timestamp'] != null
          ? (map['timestamp'] is DateTime
              ? map['timestamp']
              : DateTime.parse(map['timestamp']))
          : DateTime.now(),
      isAnonymous: map['isAnonymous'] ?? true,
      reportCount: map['reportCount'] ?? 1,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'title': title,
      'description': description,
      'latitude': location.latitude,
      'longitude': location.longitude,
      'category': category,
      'timestamp': timestamp,
      'isAnonymous': isAnonymous,
      'reportCount': reportCount,
    };
  }
}

// Mock incidents data
List<Incident> mockIncidents = [
  Incident(
    id: '1',
    userId: 'user123',
    title: 'Suspicious Activity',
    description:
        'Noticed a group of people following women near the park entrance. Be cautious when walking alone in this area.',
    location: const Location(latitude: 19.0760, longitude: 72.8777), // Mumbai
    category: 'Suspicious Activity',
    timestamp: DateTime.now().subtract(const Duration(hours: 5)),
    isAnonymous: true,
    reportCount: 3,
  ),
  Incident(
    id: '2',
    userId: 'user456',
    title: 'Poor Street Lighting',
    description:
        'The street lights on Main Road between 5th and 7th Avenue are not working. Very dark at night and feels unsafe.',
    location: const Location(latitude: 28.7041, longitude: 77.1025), // Delhi
    category: 'Infrastructure',
    timestamp: DateTime.now().subtract(const Duration(days: 1)),
    isAnonymous: false,
    reportCount: 5,
  ),
  Incident(
    id: '3',
    userId: 'user789',
    title: 'Harassment at Bus Stop',
    description:
        'Experienced verbal harassment at the Central Bus Stop around 8 PM. Multiple people have reported similar incidents.',
    location:
        const Location(latitude: 12.9716, longitude: 77.5946), // Bangalore
    category: 'Harassment',
    timestamp: DateTime.now().subtract(const Duration(days: 2)),
    isAnonymous: true,
    reportCount: 7,
  ),
  Incident(
    id: '4',
    userId: 'user101',
    title: 'Attempted Theft',
    description:
        'Someone tried to snatch my bag near the market area. Please be careful with your belongings in this area.',
    location: const Location(latitude: 22.5726, longitude: 88.3639), // Kolkata
    category: 'Theft',
    timestamp: DateTime.now().subtract(const Duration(days: 3)),
    isAnonymous: false,
    reportCount: 2,
  ),
];
