/*
 * Guardian - Women's Safety App
 * © 2025 All Rights Reserved - Kunal Singh
 * Contact: kunalsingh2514@gmail.com
 */

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:guardian/core/models/product.dart';
import 'package:guardian/core/models/order.dart' as app_models;
import 'package:guardian/core/utils/logger.dart';

/// Repository for handling store-related functionality
class StoreRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Collection references
  final String _productsCollection = 'products';
  final String _ordersCollection = 'orders';
  final String _cartCollection = 'cart';

  /// Get all products
  Future<List<Product>> getProducts() async {
    try {
      final snapshot = await _firestore
          .collection(_productsCollection)
          .where('isActive', isEqualTo: true)
          .get();

      return snapshot.docs
          .map((doc) => Product.fromMap(doc.data(), doc.id))
          .toList();
    } catch (e) {
      Logger.error('Failed to get products: $e');
      return [];
    }
  }

  /// Get product by ID
  Future<Product?> getProductById(String productId) async {
    try {
      final doc = await _firestore
          .collection(_productsCollection)
          .doc(productId)
          .get();

      if (!doc.exists) {
        return null;
      }

      return Product.fromMap(doc.data()!, doc.id);
    } catch (e) {
      Logger.error('Failed to get product: $e');
      return null;
    }
  }

  /// Get products by category
  Future<List<Product>> getProductsByCategory(String category) async {
    try {
      final snapshot = await _firestore
          .collection(_productsCollection)
          .where('category', isEqualTo: category)
          .where('isActive', isEqualTo: true)
          .get();

      return snapshot.docs
          .map((doc) => Product.fromMap(doc.data(), doc.id))
          .toList();
    } catch (e) {
      Logger.error('Failed to get products by category: $e');
      return [];
    }
  }

  /// Add product to cart
  Future<bool> addToCart(String productId, int quantity) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      // Check if product already in cart
      final cartRef = _firestore
          .collection('users')
          .doc(userId)
          .collection(_cartCollection);

      final existingItem = await cartRef
          .where('productId', isEqualTo: productId)
          .get();

      if (existingItem.docs.isNotEmpty) {
        // Update quantity
        final currentQuantity = existingItem.docs.first.data()['quantity'] as int;
        await cartRef
            .doc(existingItem.docs.first.id)
            .update({'quantity': currentQuantity + quantity});
      } else {
        // Add new item
        await cartRef.add({
          'productId': productId,
          'quantity': quantity,
          'addedAt': FieldValue.serverTimestamp(),
        });
      }

      return true;
    } catch (e) {
      Logger.error('Failed to add product to cart: $e');
      return false;
    }
  }

  /// Get cart items
  Future<List<Map<String, dynamic>>> getCartItems() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection(_cartCollection)
          .get();

      List<Map<String, dynamic>> cartItems = [];

      for (var doc in snapshot.docs) {
        final cartItem = doc.data();
        final productId = cartItem['productId'] as String;

        // Get product details
        final product = await getProductById(productId);
        if (product != null) {
          cartItems.add({
            'id': doc.id,
            'product': product,
            'quantity': cartItem['quantity'] as int,
          });
        }
      }

      return cartItems;
    } catch (e) {
      Logger.error('Failed to get cart items: $e');
      return [];
    }
  }

  /// Remove item from cart
  Future<bool> removeFromCart(String cartItemId) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      await _firestore
          .collection('users')
          .doc(userId)
          .collection(_cartCollection)
          .doc(cartItemId)
          .delete();

      return true;
    } catch (e) {
      Logger.error('Failed to remove item from cart: $e');
      return false;
    }
  }

  /// Create an order
  Future<String?> createOrder({
    required List<Map<String, dynamic>> items,
    required String paymentMethod,
    required String shippingAddress,
  }) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      // Calculate total
      double total = 0;
      List<Map<String, dynamic>> orderItems = [];

      for (var item in items) {
        final product = item['product'] as Product;
        final quantity = item['quantity'] as int;
        final itemTotal = product.price * quantity;

        total += itemTotal;

        orderItems.add({
          'productId': product.id,
          'productName': product.name,
          'price': product.price,
          'quantity': quantity,
          'total': itemTotal,
        });
      }

      // Create order
      final orderRef = await _firestore.collection(_ordersCollection).add({
        'userId': userId,
        'items': orderItems,
        'total': total,
        'status': 'pending',
        'paymentMethod': paymentMethod,
        'shippingAddress': shippingAddress,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Clear cart
      final cartRef = _firestore
          .collection('users')
          .doc(userId)
          .collection(_cartCollection);

      final cartItems = await cartRef.get();
      for (var doc in cartItems.docs) {
        await doc.reference.delete();
      }

      return orderRef.id;
    } catch (e) {
      Logger.error('Failed to create order: $e');
      return null;
    }
  }

  /// Get user orders
  Future<List<app_models.Order>> getUserOrders() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      final snapshot = await _firestore
          .collection(_ordersCollection)
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => app_models.Order.fromMap(doc.data(), doc.id))
          .toList();
    } catch (e) {
      Logger.error('Failed to get user orders: $e');
      return [];
    }
  }

  /// Get order by ID
  Future<app_models.Order?> getOrderById(String orderId) async {
    try {
      final doc = await _firestore
          .collection(_ordersCollection)
          .doc(orderId)
          .get();

      if (!doc.exists) {
        return null;
      }

      return app_models.Order.fromMap(doc.data()!, doc.id);
    } catch (e) {
      Logger.error('Failed to get order: $e');
      return null;
    }
  }
}
