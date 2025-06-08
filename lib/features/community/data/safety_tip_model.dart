/*
 * Guardian - Women's Safety App
 * © 2025 All Rights Reserved - Kunal Singh
 * Contact: kunalsingh2514@gmail.com
 */

class SafetyTip {
  final String id;
  final String title;
  final String content;
  final String category;
  final String? imageUrl;
  final List<String> tags;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  SafetyTip({
    required this.id,
    required this.title,
    required this.content,
    required this.category,
    this.imageUrl,
    this.tags = const [],
    this.createdAt,
    this.updatedAt,
  });

  factory SafetyTip.fromMap(Map<String, dynamic> map) {
    return SafetyTip(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      content: map['content'] ?? '',
      category: map['category'] ?? '',
      imageUrl: map['imageUrl'],
      tags: List<String>.from(map['tags'] ?? []),
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'])
          : null,
      updatedAt: map['updatedAt'] != null
          ? DateTime.parse(map['updatedAt'])
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'category': category,
      'imageUrl': imageUrl,
      'tags': tags,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  SafetyTip copyWith({
    String? id,
    String? title,
    String? content,
    String? category,
    String? imageUrl,
    List<String>? tags,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return SafetyTip(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      category: category ?? this.category,
      imageUrl: imageUrl ?? this.imageUrl,
      tags: tags ?? this.tags,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

// Mock safety tips for fallback
final List<SafetyTip> mockSafetyTips = [
  SafetyTip(
    id: '1',
    title: 'Stay Aware of Your Surroundings',
    content: 'Always be aware of your surroundings. Avoid using your phone while walking alone, especially at night. Keep your head up and stay alert to potential dangers.',
    category: 'General',
    imageUrl: 'https://via.placeholder.com/300',
    tags: ['awareness', 'safety', 'walking'],
    createdAt: DateTime.now().subtract(const Duration(days: 30)),
  ),
  SafetyTip(
    id: '2',
    title: 'Share Your Location',
    content: 'Let someone know where you are going and when you expect to arrive, especially when meeting someone new or traveling alone. Use location sharing apps with trusted contacts.',
    category: 'Travel',
    imageUrl: 'https://via.placeholder.com/300',
    tags: ['location', 'travel', 'sharing'],
    createdAt: DateTime.now().subtract(const Duration(days: 25)),
  ),
  SafetyTip(
    id: '3',
    title: 'Trust Your Instincts',
    content: 'If something doesn\'t feel right, trust your instincts and remove yourself from the situation. Your intuition is a powerful tool for personal safety.',
    category: 'General',
    imageUrl: 'https://via.placeholder.com/300',
    tags: ['instincts', 'intuition', 'safety'],
    createdAt: DateTime.now().subtract(const Duration(days: 20)),
  ),
  SafetyTip(
    id: '4',
    title: 'Public Transportation Safety',
    content: 'When using public transportation, sit near the driver or in a populated area. Avoid empty train cars or buses. Stay awake and alert during your journey.',
    category: 'Travel',
    imageUrl: 'https://via.placeholder.com/300',
    tags: ['transportation', 'travel', 'public'],
    createdAt: DateTime.now().subtract(const Duration(days: 15)),
  ),
  SafetyTip(
    id: '5',
    title: 'Emergency Contacts',
    content: 'Keep a list of emergency contacts easily accessible on your phone. Consider setting up emergency contacts that can be accessed even when your phone is locked.',
    category: 'Preparation',
    imageUrl: 'https://via.placeholder.com/300',
    tags: ['contacts', 'emergency', 'preparation'],
    createdAt: DateTime.now().subtract(const Duration(days: 10)),
  ),
];
