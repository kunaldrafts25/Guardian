/*
 * Guardian - Women's Safety App
 * © 2025 All Rights Reserved - Kunal Singh
 * Contact: kunalsingh2514@gmail.com
 */

/// Type of AI safety advice
enum AdviceType {
  /// General safety advice
  general,
  
  /// Location-specific advice
  location,
  
  /// Situation-specific advice
  situation,
  
  /// Travel advice
  travel,
  
  /// Emergency response advice
  emergency,
}

/// Risk level for safety alerts
enum RiskLevel {
  /// Low risk level
  low,
  
  /// Medium risk level
  medium,
  
  /// High risk level
  high,
}

/// A model representing an AI safety advice
class SafetyAdvice {
  /// Unique identifier for the advice
  final String id;
  
  /// Title of the advice
  final String title;
  
  /// Content of the advice
  final String content;
  
  /// Type of advice
  final AdviceType type;
  
  /// Risk level associated with the advice
  final RiskLevel riskLevel;
  
  /// When the advice was generated
  final DateTime createdAt;
  
  /// Whether the advice has been read
  final bool isRead;
  
  /// Whether the advice is personalized
  final bool isPersonalized;
  
  /// Tags or categories for the advice
  final List<String> tags;
  
  /// Location context (if applicable)
  final Map<String, dynamic>? locationContext;

  SafetyAdvice({
    required this.id,
    required this.title,
    required this.content,
    required this.type,
    required this.riskLevel,
    DateTime? createdAt,
    this.isRead = false,
    this.isPersonalized = false,
    this.tags = const [],
    this.locationContext,
  }) : createdAt = createdAt ?? DateTime.now();

  /// Convert to a map for storage
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'type': type.toString().split('.').last,
      'riskLevel': riskLevel.toString().split('.').last,
      'createdAt': createdAt.toIso8601String(),
      'isRead': isRead,
      'isPersonalized': isPersonalized,
      'tags': tags,
      'locationContext': locationContext,
    };
  }

  /// Create from a map
  factory SafetyAdvice.fromMap(Map<String, dynamic> map) {
    return SafetyAdvice(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      content: map['content'] ?? '',
      type: AdviceType.values.firstWhere(
        (e) => e.toString().split('.').last == map['type'],
        orElse: () => AdviceType.general,
      ),
      riskLevel: RiskLevel.values.firstWhere(
        (e) => e.toString().split('.').last == map['riskLevel'],
        orElse: () => RiskLevel.low,
      ),
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'])
          : DateTime.now(),
      isRead: map['isRead'] ?? false,
      isPersonalized: map['isPersonalized'] ?? false,
      tags: List<String>.from(map['tags'] ?? []),
      locationContext: map['locationContext'],
    );
  }

  /// Create a copy with updated values
  SafetyAdvice copyWith({
    String? id,
    String? title,
    String? content,
    AdviceType? type,
    RiskLevel? riskLevel,
    DateTime? createdAt,
    bool? isRead,
    bool? isPersonalized,
    List<String>? tags,
    Map<String, dynamic>? locationContext,
  }) {
    return SafetyAdvice(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      type: type ?? this.type,
      riskLevel: riskLevel ?? this.riskLevel,
      createdAt: createdAt ?? this.createdAt,
      isRead: isRead ?? this.isRead,
      isPersonalized: isPersonalized ?? this.isPersonalized,
      tags: tags ?? this.tags,
      locationContext: locationContext ?? this.locationContext,
    );
  }
}

/// A model representing a chat message with the AI assistant
class ChatMessage {
  /// Unique identifier for the message
  final String id;
  
  /// Content of the message
  final String content;
  
  /// Whether the message is from the user (true) or AI (false)
  final bool isUserMessage;
  
  /// When the message was sent
  final DateTime timestamp;
  
  /// Whether the message contains a safety advice
  final bool containsAdvice;
  
  /// Safety advice ID (if applicable)
  final String? adviceId;

  ChatMessage({
    required this.id,
    required this.content,
    required this.isUserMessage,
    DateTime? timestamp,
    this.containsAdvice = false,
    this.adviceId,
  }) : timestamp = timestamp ?? DateTime.now();

  /// Convert to a map for storage
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'content': content,
      'isUserMessage': isUserMessage,
      'timestamp': timestamp.toIso8601String(),
      'containsAdvice': containsAdvice,
      'adviceId': adviceId,
    };
  }

  /// Create from a map
  factory ChatMessage.fromMap(Map<String, dynamic> map) {
    return ChatMessage(
      id: map['id'] ?? '',
      content: map['content'] ?? '',
      isUserMessage: map['isUserMessage'] ?? false,
      timestamp: map['timestamp'] != null
          ? DateTime.parse(map['timestamp'])
          : DateTime.now(),
      containsAdvice: map['containsAdvice'] ?? false,
      adviceId: map['adviceId'],
    );
  }
}

/// A model representing a safety alert generated by AI
class SafetyAlert {
  /// Unique identifier for the alert
  final String id;
  
  /// Title of the alert
  final String title;
  
  /// Content of the alert
  final String content;
  
  /// Risk level of the alert
  final RiskLevel riskLevel;
  
  /// When the alert was generated
  final DateTime createdAt;
  
  /// Whether the alert has been read
  final bool isRead;
  
  /// Whether the alert has been dismissed
  final bool isDismissed;
  
  /// Location context (if applicable)
  final Map<String, dynamic>? locationContext;
  
  /// Action to take (if applicable)
  final String? actionText;
  
  /// Action data (if applicable)
  final Map<String, dynamic>? actionData;

  SafetyAlert({
    required this.id,
    required this.title,
    required this.content,
    required this.riskLevel,
    DateTime? createdAt,
    this.isRead = false,
    this.isDismissed = false,
    this.locationContext,
    this.actionText,
    this.actionData,
  }) : createdAt = createdAt ?? DateTime.now();

  /// Convert to a map for storage
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'riskLevel': riskLevel.toString().split('.').last,
      'createdAt': createdAt.toIso8601String(),
      'isRead': isRead,
      'isDismissed': isDismissed,
      'locationContext': locationContext,
      'actionText': actionText,
      'actionData': actionData,
    };
  }

  /// Create from a map
  factory SafetyAlert.fromMap(Map<String, dynamic> map) {
    return SafetyAlert(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      content: map['content'] ?? '',
      riskLevel: RiskLevel.values.firstWhere(
        (e) => e.toString().split('.').last == map['riskLevel'],
        orElse: () => RiskLevel.low,
      ),
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'])
          : DateTime.now(),
      isRead: map['isRead'] ?? false,
      isDismissed: map['isDismissed'] ?? false,
      locationContext: map['locationContext'],
      actionText: map['actionText'],
      actionData: map['actionData'],
    );
  }

  /// Create a copy with updated values
  SafetyAlert copyWith({
    String? id,
    String? title,
    String? content,
    RiskLevel? riskLevel,
    DateTime? createdAt,
    bool? isRead,
    bool? isDismissed,
    Map<String, dynamic>? locationContext,
    String? actionText,
    Map<String, dynamic>? actionData,
  }) {
    return SafetyAlert(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      riskLevel: riskLevel ?? this.riskLevel,
      createdAt: createdAt ?? this.createdAt,
      isRead: isRead ?? this.isRead,
      isDismissed: isDismissed ?? this.isDismissed,
      locationContext: locationContext ?? this.locationContext,
      actionText: actionText ?? this.actionText,
      actionData: actionData ?? this.actionData,
    );
  }
}
