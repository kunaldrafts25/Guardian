/*
 * Guardian - Women's Safety App
 * © 2025 All Rights Reserved - Kunal Singh
 * Contact: kunalsingh2514@gmail.com
 */

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:guardian/core/utils/logger.dart';

/// A service for managing mock data that replaces Firebase functionality
class MockDataService {
  static final MockDataService _instance = MockDataService._internal();
  static SharedPreferences? _prefs;
  static bool _initialized = false;

  // Collection names
  static const String _usersCollection = 'users';
  static const String _alertsCollection = 'alerts';
  static const String _productsCollection = 'products';
  static const String _incidentsCollection = 'incidents';
  static const String _safetyTipsCollection = 'safetyTips';

  // Current user data
  static Map<String, dynamic>? _currentUser;
  static String? _currentUserId;

  // Factory constructor
  factory MockDataService() {
    return _instance;
  }

  // Internal constructor
  MockDataService._internal();

  // Initialize the service
  static Future<bool> initialize() async {
    if (_initialized) {
      Logger.info('MockDataService already initialized');
      return true;
    }

    try {
      _prefs = await SharedPreferences.getInstance();
      _initialized = true;

      // Initialize collections with default data if they don't exist
      await _initializeCollectionIfEmpty(_usersCollection, []);
      await _initializeCollectionIfEmpty(_alertsCollection, []);
      await _initializeCollectionIfEmpty(
          _productsCollection, _getDefaultProducts());
      await _initializeCollectionIfEmpty(_incidentsCollection, []);
      await _initializeCollectionIfEmpty(
          _safetyTipsCollection, _getDefaultSafetyTips());

      Logger.info('MockDataService initialized successfully');
      return true;
    } catch (e) {
      Logger.error('Error initializing MockDataService', e);
      return false;
    }
  }

  // Initialize a collection with default data if it doesn't exist
  static Future<void> _initializeCollectionIfEmpty(
      String collection, List<Map<String, dynamic>> defaultData) async {
    if (_prefs?.getString(collection) == null) {
      await _prefs?.setString(collection, jsonEncode(defaultData));
      Logger.info('Initialized $collection with default data');
    }
  }

  // Get current user
  static Map<String, dynamic>? get currentUser => _currentUser;

  // Get current user ID
  static String? get currentUserId => _currentUserId;

  // Set current user
  static void setCurrentUser(Map<String, dynamic> user, String userId) {
    _currentUser = user;
    _currentUserId = userId;
  }

  // Clear current user
  static void clearCurrentUser() {
    _currentUser = null;
    _currentUserId = null;
  }

  // Get all documents from a collection
  static Future<List<Map<String, dynamic>>> getCollection(
      String collection) async {
    try {
      final String? data = _prefs?.getString(collection);
      if (data == null) return [];

      return List<Map<String, dynamic>>.from(jsonDecode(data));
    } catch (e) {
      Logger.error('Error getting collection $collection', e);
      return [];
    }
  }

  // Get a document by ID
  static Future<Map<String, dynamic>?> getDocument(
      String collection, String id) async {
    try {
      final List<Map<String, dynamic>> documents =
          await getCollection(collection);
      return documents.firstWhere((doc) => doc['id'] == id, orElse: () => {});
    } catch (e) {
      Logger.error('Error getting document $id from $collection', e);
      return null;
    }
  }

  // Add a document to a collection
  static Future<String> addDocument(
      String collection, Map<String, dynamic> data) async {
    try {
      final List<Map<String, dynamic>> documents =
          await getCollection(collection);

      // Generate a unique ID
      final String id = DateTime.now().millisecondsSinceEpoch.toString();

      // Add ID to the document
      final Map<String, dynamic> newDoc = {
        'id': id,
        ...data,
        'createdAt': DateTime.now().toIso8601String(),
      };

      documents.add(newDoc);

      await _prefs?.setString(collection, jsonEncode(documents));

      return id;
    } catch (e) {
      Logger.error('Error adding document to $collection', e);
      return '';
    }
  }

  // Update a document in a collection
  static Future<bool> updateDocument(
      String collection, String id, Map<String, dynamic> data) async {
    try {
      final List<Map<String, dynamic>> documents =
          await getCollection(collection);

      final int index = documents.indexWhere((doc) => doc['id'] == id);
      if (index == -1) return false;

      documents[index] = {
        ...documents[index],
        ...data,
        'updatedAt': DateTime.now().toIso8601String(),
      };

      await _prefs?.setString(collection, jsonEncode(documents));

      return true;
    } catch (e) {
      Logger.error('Error updating document $id in $collection', e);
      return false;
    }
  }

  // Delete a document from a collection
  static Future<bool> deleteDocument(String collection, String id) async {
    try {
      final List<Map<String, dynamic>> documents =
          await getCollection(collection);

      final int index = documents.indexWhere((doc) => doc['id'] == id);
      if (index == -1) return false;

      documents.removeAt(index);

      await _prefs?.setString(collection, jsonEncode(documents));

      return true;
    } catch (e) {
      Logger.error('Error deleting document $id from $collection', e);
      return false;
    }
  }

  // Get users collection
  static Future<List<Map<String, dynamic>>> getUsers() async {
    return await getCollection(_usersCollection);
  }

  // Get alerts collection
  static Future<List<Map<String, dynamic>>> getAlerts() async {
    return await getCollection(_alertsCollection);
  }

  // Get products collection
  static Future<List<Map<String, dynamic>>> getProducts() async {
    return await getCollection(_productsCollection);
  }

  // Get incidents collection
  static Future<List<Map<String, dynamic>>> getIncidents() async {
    return await getCollection(_incidentsCollection);
  }

  // Get safety tips collection
  static Future<List<Map<String, dynamic>>> getSafetyTips() async {
    return await getCollection(_safetyTipsCollection);
  }

  // Default products data
  static List<Map<String, dynamic>> _getDefaultProducts() {
    return [
      {
        'id': '1',
        'name': 'Guardian Bracelet',
        'description':
            'Stylish bracelet with emergency trigger button and Bluetooth connectivity. Water-resistant and long battery life.',
        'price': 1999.0,
        'imageUrl': 'https://via.placeholder.com/300',
        'colors': ['Black', 'Silver', 'Rose Gold'],
        'category': 'Bracelet',
        'isAvailable': true,
        'rating': 4.5,
        'reviewCount': 128,
      },
      {
        'id': '2',
        'name': 'Safety Ring',
        'description':
            'Discreet ring with panic button. Connects to your phone via Bluetooth. Available in multiple sizes.',
        'price': 2499.0,
        'imageUrl': 'https://via.placeholder.com/300',
        'colors': ['Silver', 'Gold', 'Black'],
        'category': 'Ring',
        'isAvailable': true,
        'rating': 4.2,
        'reviewCount': 85,
      },
      {
        'id': '3',
        'name': 'Guardian Pendant',
        'description':
            'Elegant pendant necklace with hidden SOS button. Perfect for formal occasions.',
        'price': 1799.0,
        'imageUrl': 'https://via.placeholder.com/300',
        'colors': ['Silver', 'Gold'],
        'category': 'Necklace',
        'isAvailable': true,
        'rating': 4.0,
        'reviewCount': 62,
      },
    ];
  }

  // Default safety tips data
  static List<Map<String, dynamic>> _getDefaultSafetyTips() {
    return [
      {
        'id': '1',
        'title': 'Stay Aware of Your Surroundings',
        'content':
            'Always be aware of your surroundings. Avoid using your phone while walking alone, especially at night.',
        'category': 'General',
        'imageUrl': 'https://via.placeholder.com/300',
      },
      {
        'id': '2',
        'title': 'Share Your Location',
        'content':
            'Let someone know where you are going and when you expect to arrive, especially when meeting someone new.',
        'category': 'Travel',
        'imageUrl': 'https://via.placeholder.com/300',
      },
      {
        'id': '3',
        'title': 'Trust Your Instincts',
        'content':
            'If something doesn\'t feel right, trust your instincts and remove yourself from the situation.',
        'category': 'General',
        'imageUrl': 'https://via.placeholder.com/300',
      },
    ];
  }
}
