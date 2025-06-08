/*
 * Guardian - Women's Safety App
 * © 2025 All Rights Reserved - Kunal Singh
 * Contact: kunalsingh2514@gmail.com
 */

/// Model class for community posts
class CommunityPost {
  /// Unique identifier for the post
  final String id;
  
  /// User ID who created the post
  final String userId;
  
  /// Title of the post
  final String title;
  
  /// Content of the post
  final String content;
  
  /// URLs to images in the post
  final List<String> imageUrls;
  
  /// Category of the post (e.g., 'safety_tip', 'question', 'story')
  final String? category;
  
  /// Number of likes on the post
  final int likes;
  
  /// Comments on the post
  final List<Map<String, dynamic>> comments;
  
  /// Timestamp when the post was created
  final DateTime createdAt;
  
  /// Constructor
  CommunityPost({
    required this.id,
    required this.userId,
    required this.title,
    required this.content,
    this.imageUrls = const [],
    this.category,
    this.likes = 0,
    this.comments = const [],
    required this.createdAt,
  });
  
  /// Create a post from a map (e.g., from Firestore)
  factory CommunityPost.fromMap(Map<String, dynamic> map, String id) {
    return CommunityPost(
      id: id,
      userId: map['userId'] ?? '',
      title: map['title'] ?? '',
      content: map['content'] ?? '',
      imageUrls: List<String>.from(map['imageUrls'] ?? []),
      category: map['category'],
      likes: map['likes'] ?? 0,
      comments: List<Map<String, dynamic>>.from(map['comments'] ?? []),
      createdAt: (map['createdAt'] as dynamic)?.toDate() ?? DateTime.now(),
    );
  }
  
  /// Convert post to a map (e.g., for Firestore)
  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'title': title,
      'content': content,
      'imageUrls': imageUrls,
      'category': category,
      'likes': likes,
      'comments': comments,
      'createdAt': createdAt,
    };
  }
  
  /// Create a copy of this post with some fields replaced
  CommunityPost copyWith({
    String? title,
    String? content,
    List<String>? imageUrls,
    String? category,
    int? likes,
    List<Map<String, dynamic>>? comments,
  }) {
    return CommunityPost(
      id: id,
      userId: userId,
      title: title ?? this.title,
      content: content ?? this.content,
      imageUrls: imageUrls ?? this.imageUrls,
      category: category ?? this.category,
      likes: likes ?? this.likes,
      comments: comments ?? this.comments,
      createdAt: createdAt,
    );
  }
}
