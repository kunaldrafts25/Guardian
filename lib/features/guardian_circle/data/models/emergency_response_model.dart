/*
 * Guardian - Women's Safety App
 * © 2025 All Rights Reserved - Kunal Singh
 * Contact: kunalsingh2514@gmail.com
 */

/// Status of an emergency response
enum EmergencyResponseStatus {
  /// Response has been sent but not yet seen
  sent,
  
  /// Response has been seen by the user
  seen,
  
  /// Responder is on the way
  onTheWay,
  
  /// Responder has arrived
  arrived,
  
  /// Response has been completed
  completed,
  
  /// Response has been cancelled
  cancelled,
}

/// A model representing a response to an emergency alert
class EmergencyResponse {
  /// Unique identifier for the response
  final String id;
  
  /// ID of the emergency alert
  final String alertId;
  
  /// ID of the responder
  final String responderId;
  
  /// Name of the responder
  final String responderName;
  
  /// Status of the response
  final EmergencyResponseStatus status;
  
  /// When the response was created
  final DateTime createdAt;
  
  /// When the response was last updated
  final DateTime updatedAt;
  
  /// Estimated time of arrival (in minutes)
  final int? etaMinutes;
  
  /// Current location of the responder
  final Map<String, double>? responderLocation;
  
  /// Message from the responder
  final String? message;

  EmergencyResponse({
    required this.id,
    required this.alertId,
    required this.responderId,
    required this.responderName,
    required this.status,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.etaMinutes,
    this.responderLocation,
    this.message,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  /// Convert to a map for storage
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'alertId': alertId,
      'responderId': responderId,
      'responderName': responderName,
      'status': status.toString().split('.').last,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'etaMinutes': etaMinutes,
      'responderLocation': responderLocation,
      'message': message,
    };
  }

  /// Create from a map
  factory EmergencyResponse.fromMap(Map<String, dynamic> map) {
    return EmergencyResponse(
      id: map['id'] ?? '',
      alertId: map['alertId'] ?? '',
      responderId: map['responderId'] ?? '',
      responderName: map['responderName'] ?? '',
      status: EmergencyResponseStatus.values.firstWhere(
        (e) => e.toString().split('.').last == map['status'],
        orElse: () => EmergencyResponseStatus.sent,
      ),
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'])
          : DateTime.now(),
      updatedAt: map['updatedAt'] != null
          ? DateTime.parse(map['updatedAt'])
          : DateTime.now(),
      etaMinutes: map['etaMinutes'],
      responderLocation: map['responderLocation'] != null
          ? Map<String, double>.from(map['responderLocation'])
          : null,
      message: map['message'],
    );
  }

  /// Create a copy with updated values
  EmergencyResponse copyWith({
    String? id,
    String? alertId,
    String? responderId,
    String? responderName,
    EmergencyResponseStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? etaMinutes,
    Map<String, double>? responderLocation,
    String? message,
  }) {
    return EmergencyResponse(
      id: id ?? this.id,
      alertId: alertId ?? this.alertId,
      responderId: responderId ?? this.responderId,
      responderName: responderName ?? this.responderName,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      etaMinutes: etaMinutes ?? this.etaMinutes,
      responderLocation: responderLocation ?? this.responderLocation,
      message: message ?? this.message,
    );
  }
}

/// A model representing an emergency alert sent to guardian circle members
class EmergencyAlert {
  /// Unique identifier for the alert
  final String id;
  
  /// ID of the user who sent the alert
  final String userId;
  
  /// Name of the user who sent the alert
  final String userName;
  
  /// Type of emergency
  final String emergencyType;
  
  /// Message included with the alert
  final String? message;
  
  /// Location of the emergency
  final Map<String, double> location;
  
  /// Address of the emergency (if available)
  final String? address;
  
  /// When the alert was created
  final DateTime createdAt;
  
  /// When the alert was last updated
  final DateTime updatedAt;
  
  /// Status of the alert
  final String status;
  
  /// IDs of the guardian circles that received the alert
  final List<String> circleIds;
  
  /// Responses to the alert
  final List<EmergencyResponse> responses;
  
  /// Whether the alert has been resolved
  final bool isResolved;

  EmergencyAlert({
    required this.id,
    required this.userId,
    required this.userName,
    required this.emergencyType,
    this.message,
    required this.location,
    this.address,
    DateTime? createdAt,
    DateTime? updatedAt,
    required this.status,
    required this.circleIds,
    required this.responses,
    this.isResolved = false,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  /// Convert to a map for storage
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'userName': userName,
      'emergencyType': emergencyType,
      'message': message,
      'location': location,
      'address': address,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'status': status,
      'circleIds': circleIds,
      'responses': responses.map((r) => r.toMap()).toList(),
      'isResolved': isResolved,
    };
  }

  /// Create from a map
  factory EmergencyAlert.fromMap(Map<String, dynamic> map) {
    return EmergencyAlert(
      id: map['id'] ?? '',
      userId: map['userId'] ?? '',
      userName: map['userName'] ?? '',
      emergencyType: map['emergencyType'] ?? '',
      message: map['message'],
      location: Map<String, double>.from(map['location'] ?? {}),
      address: map['address'],
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'])
          : DateTime.now(),
      updatedAt: map['updatedAt'] != null
          ? DateTime.parse(map['updatedAt'])
          : DateTime.now(),
      status: map['status'] ?? 'active',
      circleIds: List<String>.from(map['circleIds'] ?? []),
      responses: (map['responses'] as List?)
              ?.map((r) => EmergencyResponse.fromMap(r))
              .toList() ??
          [],
      isResolved: map['isResolved'] ?? false,
    );
  }

  /// Create a copy with updated values
  EmergencyAlert copyWith({
    String? id,
    String? userId,
    String? userName,
    String? emergencyType,
    String? message,
    Map<String, double>? location,
    String? address,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? status,
    List<String>? circleIds,
    List<EmergencyResponse>? responses,
    bool? isResolved,
  }) {
    return EmergencyAlert(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      emergencyType: emergencyType ?? this.emergencyType,
      message: message ?? this.message,
      location: location ?? this.location,
      address: address ?? this.address,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      status: status ?? this.status,
      circleIds: circleIds ?? this.circleIds,
      responses: responses ?? this.responses,
      isResolved: isResolved ?? this.isResolved,
    );
  }
}
