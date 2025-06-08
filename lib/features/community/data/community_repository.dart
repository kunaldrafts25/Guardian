/*
 * Guardian - Women's Safety App
 * © 2025 All Rights Reserved - Kunal Singh
 * Contact: kunalsingh2514@gmail.com
 */

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:guardian/core/models/community_post.dart';
import 'package:guardian/core/models/community_event.dart';
import 'package:guardian/core/utils/logger.dart';

/// Repository for handling community-related functionality
class CommunityRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  /// Collection references
  final String _postsCollection = 'community_posts';
  final String _eventsCollection = 'community_events';
  
  /// Get community posts
  Future<List<CommunityPost>> getPosts({int limit = 20}) async {
    try {
      final snapshot = await _firestore
          .collection(_postsCollection)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();
      
      return snapshot.docs
          .map((doc) => CommunityPost.fromMap(doc.data(), doc.id))
          .toList();
    } catch (e) {
      Logger.error('Failed to get community posts: $e');
      return [];
    }
  }
  
  /// Get post by ID
  Future<CommunityPost?> getPostById(String postId) async {
    try {
      final doc = await _firestore
          .collection(_postsCollection)
          .doc(postId)
          .get();
      
      if (!doc.exists) {
        return null;
      }
      
      return CommunityPost.fromMap(doc.data()!, doc.id);
    } catch (e) {
      Logger.error('Failed to get post: $e');
      return null;
    }
  }
  
  /// Create a new post
  Future<String?> createPost({
    required String title,
    required String content,
    List<String>? imageUrls,
    String? category,
  }) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        throw Exception('User not authenticated');
      }
      
      final post = CommunityPost(
        id: '',
        userId: userId,
        title: title,
        content: content,
        imageUrls: imageUrls ?? [],
        category: category,
        likes: 0,
        comments: [],
        createdAt: DateTime.now(),
      );
      
      final docRef = await _firestore
          .collection(_postsCollection)
          .add(post.toMap());
      
      return docRef.id;
    } catch (e) {
      Logger.error('Failed to create post: $e');
      return null;
    }
  }
  
  /// Update an existing post
  Future<bool> updatePost(CommunityPost post) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        throw Exception('User not authenticated');
      }
      
      // Verify user is the author
      if (post.userId != userId) {
        throw Exception('Not authorized to update this post');
      }
      
      await _firestore
          .collection(_postsCollection)
          .doc(post.id)
          .update(post.toMap());
      
      return true;
    } catch (e) {
      Logger.error('Failed to update post: $e');
      return false;
    }
  }
  
  /// Delete a post
  Future<bool> deletePost(String postId) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        throw Exception('User not authenticated');
      }
      
      // Verify user is the author
      final post = await getPostById(postId);
      if (post == null || post.userId != userId) {
        throw Exception('Not authorized to delete this post');
      }
      
      await _firestore
          .collection(_postsCollection)
          .doc(postId)
          .delete();
      
      return true;
    } catch (e) {
      Logger.error('Failed to delete post: $e');
      return false;
    }
  }
  
  /// Like a post
  Future<bool> likePost(String postId) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        throw Exception('User not authenticated');
      }
      
      // Add user to likes collection
      await _firestore
          .collection(_postsCollection)
          .doc(postId)
          .collection('likes')
          .doc(userId)
          .set({'timestamp': FieldValue.serverTimestamp()});
      
      // Increment likes count
      await _firestore
          .collection(_postsCollection)
          .doc(postId)
          .update({'likes': FieldValue.increment(1)});
      
      return true;
    } catch (e) {
      Logger.error('Failed to like post: $e');
      return false;
    }
  }
  
  /// Unlike a post
  Future<bool> unlikePost(String postId) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        throw Exception('User not authenticated');
      }
      
      // Remove user from likes collection
      await _firestore
          .collection(_postsCollection)
          .doc(postId)
          .collection('likes')
          .doc(userId)
          .delete();
      
      // Decrement likes count
      await _firestore
          .collection(_postsCollection)
          .doc(postId)
          .update({'likes': FieldValue.increment(-1)});
      
      return true;
    } catch (e) {
      Logger.error('Failed to unlike post: $e');
      return false;
    }
  }
  
  /// Add a comment to a post
  Future<bool> addComment(String postId, String comment) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        throw Exception('User not authenticated');
      }
      
      await _firestore
          .collection(_postsCollection)
          .doc(postId)
          .collection('comments')
          .add({
            'userId': userId,
            'comment': comment,
            'createdAt': FieldValue.serverTimestamp(),
          });
      
      return true;
    } catch (e) {
      Logger.error('Failed to add comment: $e');
      return false;
    }
  }
  
  /// Get community events
  Future<List<CommunityEvent>> getEvents() async {
    try {
      final snapshot = await _firestore
          .collection(_eventsCollection)
          .orderBy('startDate')
          .where('startDate', isGreaterThanOrEqualTo: DateTime.now())
          .get();
      
      return snapshot.docs
          .map((doc) => CommunityEvent.fromMap(doc.data(), doc.id))
          .toList();
    } catch (e) {
      Logger.error('Failed to get community events: $e');
      return [];
    }
  }
  
  /// Get event by ID
  Future<CommunityEvent?> getEventById(String eventId) async {
    try {
      final doc = await _firestore
          .collection(_eventsCollection)
          .doc(eventId)
          .get();
      
      if (!doc.exists) {
        return null;
      }
      
      return CommunityEvent.fromMap(doc.data()!, doc.id);
    } catch (e) {
      Logger.error('Failed to get event: $e');
      return null;
    }
  }
  
  /// Create a new event
  Future<String?> createEvent(CommunityEvent event) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        throw Exception('User not authenticated');
      }
      
      final eventWithOrganizer = event.copyWith(organizerId: userId);
      
      final docRef = await _firestore
          .collection(_eventsCollection)
          .add(eventWithOrganizer.toMap());
      
      return docRef.id;
    } catch (e) {
      Logger.error('Failed to create event: $e');
      return null;
    }
  }
  
  /// RSVP to an event
  Future<bool> rsvpToEvent(String eventId) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        throw Exception('User not authenticated');
      }
      
      await _firestore
          .collection(_eventsCollection)
          .doc(eventId)
          .collection('attendees')
          .doc(userId)
          .set({'status': 'attending', 'timestamp': FieldValue.serverTimestamp()});
      
      // Increment attendee count
      await _firestore
          .collection(_eventsCollection)
          .doc(eventId)
          .update({'attendeeCount': FieldValue.increment(1)});
      
      return true;
    } catch (e) {
      Logger.error('Failed to RSVP to event: $e');
      return false;
    }
  }
}
