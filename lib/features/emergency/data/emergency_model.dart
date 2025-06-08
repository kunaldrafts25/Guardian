/*
 * Guardian - Women's Safety App
 * © 2025 All Rights Reserved - Kunal Singh
 * Contact: kunalsingh2514@gmail.com
 */

class EmergencyAlert {
  final String id;
  final String userId;
  final String type;
  final String status;
  final double latitude;
  final double longitude;
  final String? message;
  final DateTime timestamp;
  final DateTime? updatedAt;
  final DateTime? cancelledAt;

  EmergencyAlert({
    required this.id,
    required this.userId,
    required this.type,
    required this.status,
    required this.latitude,
    required this.longitude,
    this.message,
    required this.timestamp,
    this.updatedAt,
    this.cancelledAt,
  });

  factory EmergencyAlert.fromMap(Map<String, dynamic> map) {
    return EmergencyAlert(
      id: map['id'] ?? '',
      userId: map['userId'] ?? '',
      type: map['type'] ?? '',
      status: map['status'] ?? '',
      latitude: map['latitude']?.toDouble() ?? 0.0,
      longitude: map['longitude']?.toDouble() ?? 0.0,
      message: map['message'],
      timestamp: map['timestamp'] != null
          ? DateTime.parse(map['timestamp'])
          : DateTime.now(),
      updatedAt: map['updatedAt'] != null
          ? DateTime.parse(map['updatedAt'])
          : null,
      cancelledAt: map['cancelledAt'] != null
          ? DateTime.parse(map['cancelledAt'])
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'type': type,
      'status': status,
      'latitude': latitude,
      'longitude': longitude,
      'message': message,
      'timestamp': timestamp.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'cancelledAt': cancelledAt?.toIso8601String(),
    };
  }

  EmergencyAlert copyWith({
    String? id,
    String? userId,
    String? type,
    String? status,
    double? latitude,
    double? longitude,
    String? message,
    DateTime? timestamp,
    DateTime? updatedAt,
    DateTime? cancelledAt,
  }) {
    return EmergencyAlert(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      type: type ?? this.type,
      status: status ?? this.status,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      message: message ?? this.message,
      timestamp: timestamp ?? this.timestamp,
      updatedAt: updatedAt ?? this.updatedAt,
      cancelledAt: cancelledAt ?? this.cancelledAt,
    );
  }

  bool get isActive => status == 'active';
  bool get isCancelled => status == 'cancelled';
  bool get isCompleted => status == 'completed';
}
