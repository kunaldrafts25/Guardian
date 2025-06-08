/*
 * Guardian - Women's Safety App
 * © 2025 All Rights Reserved - Kunal Singh
 * Contact: kunalsingh2514@gmail.com
 */

/// Model class for emergency alerts
class EmergencyAlert {
  /// Unique identifier for the alert
  final String? id;
  
  /// User ID who created the alert
  final String userId;
  
  /// Type of alert (e.g., 'sos', 'panic', 'medical')
  final String alertType;
  
  /// Optional message with the alert
  final String? message;
  
  /// Timestamp when the alert was created
  final DateTime timestamp;
  
  /// Location where the alert was triggered
  final Map<String, double> location;
  
  /// Status of the alert (active, resolved, cancelled)
  final String status;
  
  /// Constructor
  EmergencyAlert({
    this.id,
    required this.userId,
    required this.alertType,
    this.message,
    required this.timestamp,
    required this.location,
    required this.status,
  });
  
  /// Create an alert from a map (e.g., from Firestore)
  factory EmergencyAlert.fromMap(Map<String, dynamic> map, [String? id]) {
    return EmergencyAlert(
      id: id ?? map['id'],
      userId: map['userId'] ?? '',
      alertType: map['alertType'] ?? '',
      message: map['message'],
      timestamp: (map['timestamp'] as dynamic)?.toDate() ?? DateTime.now(),
      location: Map<String, double>.from(map['location'] ?? {}),
      status: map['status'] ?? 'active',
    );
  }
  
  /// Convert alert to a map (e.g., for Firestore)
  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'alertType': alertType,
      'message': message,
      'timestamp': timestamp,
      'location': location,
      'status': status,
    };
  }
  
  /// Create a copy of this alert with some fields replaced
  EmergencyAlert copyWith({
    String? alertType,
    String? message,
    DateTime? timestamp,
    Map<String, double>? location,
    String? status,
  }) {
    return EmergencyAlert(
      id: id,
      userId: userId,
      alertType: alertType ?? this.alertType,
      message: message ?? this.message,
      timestamp: timestamp ?? this.timestamp,
      location: location ?? this.location,
      status: status ?? this.status,
    );
  }
}
