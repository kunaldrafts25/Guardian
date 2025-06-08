/*
 * Guardian - Women's Safety App
 * © 2025 All Rights Reserved - Kunal Singh
 * Contact: kunalsingh2514@gmail.com
 */

import 'package:guardian/core/services/mock_auth_service.dart';
import 'package:guardian/core/services/mock_data_service.dart';
import 'package:guardian/core/utils/logger.dart';
import 'package:guardian/features/store/data/product_model.dart';
import 'package:guardian/core/models/order.dart';

class StoreRepository {
  // Get all products
  Future<List<Product>> getProducts() async {
    try {
      final products = await MockDataService.getProducts();
      return products.map((product) => Product.fromMap(product)).toList();
    } catch (e) {
      Logger.error('Error getting products', e);
      return mockProducts; // Fallback to mock data
    }
  }

  // Get product by ID
  Future<Product?> getProductById(String id) async {
    try {
      final productData = await MockDataService.getDocument('products', id);
      if (productData == null) return null;

      return Product.fromMap(productData);
    } catch (e) {
      Logger.error('Error getting product by ID', e);
      
      // Fallback to mock data
      try {
        return mockProducts.firstWhere((product) => product.id == id);
      } catch (_) {
        return null;
      }
    }
  }

  // Get products by category
  Future<List<Product>> getProductsByCategory(String category) async {
    try {
      final products = await MockDataService.getProducts();
      final filteredProducts = products.where((product) => 
        product['category'] == category
      ).toList();
      
      return filteredProducts.map((product) => Product.fromMap(product)).toList();
    } catch (e) {
      Logger.error('Error getting products by category', e);
      
      // Fallback to mock data
      return mockProducts.where((product) => product.category == category).toList();
    }
  }

  // Search products
  Future<List<Product>> searchProducts(String query) async {
    try {
      final products = await MockDataService.getProducts();
      final searchQuery = query.toLowerCase();
      
      final filteredProducts = products.where((product) => 
        product['name'].toString().toLowerCase().contains(searchQuery) ||
        product['description'].toString().toLowerCase().contains(searchQuery) ||
        product['category'].toString().toLowerCase().contains(searchQuery)
      ).toList();
      
      return filteredProducts.map((product) => Product.fromMap(product)).toList();
    } catch (e) {
      Logger.error('Error searching products', e);
      
      // Fallback to mock data
      return mockProducts.where((product) => 
        product.name.toLowerCase().contains(query.toLowerCase()) ||
        product.description.toLowerCase().contains(query.toLowerCase()) ||
        product.category.toLowerCase().contains(query.toLowerCase())
      ).toList();
    }
  }

  // Add product to cart
  Future<bool> addToCart(String productId, int quantity, String? color) async {
    try {
      final MockUser? user = MockAuthService.currentUser;
      if (user == null) return false;

      // Get current user data
      final userData = await MockDataService.getDocument('users', user.uid);
      if (userData == null) return false;

      // Get current cart or initialize empty list
      List<Map<String, dynamic>> cart = [];
      if (userData.containsKey('cart')) {
        cart = List<Map<String, dynamic>>.from(userData['cart']);
      }

      // Check if product already in cart
      final existingItem = cart.firstWhere(
        (item) => item['productId'] == productId && item['color'] == color,
        orElse: () => {},
      );

      if (existingItem.isNotEmpty) {
        // Update quantity
        final index = cart.indexOf(existingItem);
        cart[index]['quantity'] = (existingItem['quantity'] as int) + quantity;
      } else {
        // Add new item
        cart.add({
          'productId': productId,
          'quantity': quantity,
          'color': color,
          'addedAt': DateTime.now().toIso8601String(),
        });
      }

      // Update user data
      return await MockDataService.updateDocument('users', user.uid, {
        'cart': cart,
      });
    } catch (e) {
      Logger.error('Error adding product to cart', e);
      return false;
    }
  }

  // Get cart items
  Future<List<Map<String, dynamic>>> getCartItems() async {
    try {
      final MockUser? user = MockAuthService.currentUser;
      if (user == null) return [];

      // Get current user data
      final userData = await MockDataService.getDocument('users', user.uid);
      if (userData == null) return [];

      // Get cart items
      if (!userData.containsKey('cart')) return [];
      
      final cartItems = List<Map<String, dynamic>>.from(userData['cart']);
      
      // Fetch product details for each cart item
      final result = <Map<String, dynamic>>[];
      
      for (final item in cartItems) {
        final productId = item['productId'];
        final product = await getProductById(productId);
        
        if (product != null) {
          result.add({
            'product': product,
            'quantity': item['quantity'],
            'color': item['color'],
          });
        }
      }
      
      return result;
    } catch (e) {
      Logger.error('Error getting cart items', e);
      return [];
    }
  }

  // Remove item from cart
  Future<bool> removeFromCart(String productId, String? color) async {
    try {
      final MockUser? user = MockAuthService.currentUser;
      if (user == null) return false;

      // Get current user data
      final userData = await MockDataService.getDocument('users', user.uid);
      if (userData == null) return false;

      // Get cart items
      if (!userData.containsKey('cart')) return false;
      
      final cart = List<Map<String, dynamic>>.from(userData['cart']);
      
      // Remove item
      final updatedCart = cart.where((item) => 
        !(item['productId'] == productId && item['color'] == color)
      ).toList();
      
      // Update user data
      return await MockDataService.updateDocument('users', user.uid, {
        'cart': updatedCart,
      });
    } catch (e) {
      Logger.error('Error removing item from cart', e);
      return false;
    }
  }

  // Create order
  Future<String?> createOrder({
    required List<Map<String, dynamic>> items,
    required double total,
    required String paymentMethod,
    required String shippingAddress,
  }) async {
    try {
      final MockUser? user = MockAuthService.currentUser;
      if (user == null) return null;

      final orderData = {
        'userId': user.uid,
        'items': items,
        'total': total,
        'status': 'pending',
        'paymentMethod': paymentMethod,
        'shippingAddress': shippingAddress,
        'createdAt': DateTime.now().toIso8601String(),
      };

      // Create order
      final orderId = await MockDataService.addDocument('orders', orderData);
      
      // Clear cart
      await MockDataService.updateDocument('users', user.uid, {
        'cart': [],
      });
      
      return orderId;
    } catch (e) {
      Logger.error('Error creating order', e);
      return null;
    }
  }

  // Get user orders
  Future<List<Order>> getUserOrders() async {
    try {
      final MockUser? user = MockAuthService.currentUser;
      if (user == null) return [];

      // Get all orders
      final orders = await MockDataService.getCollection('orders');
      
      // Filter orders for current user
      final userOrders = orders.where((order) => order['userId'] == user.uid).toList();
      
      return userOrders.map((order) => Order.fromMap(order, order['id'])).toList();
    } catch (e) {
      Logger.error('Error getting user orders', e);
      return [];
    }
  }

  // Get order by ID
  Future<Order?> getOrderById(String orderId) async {
    try {
      final orderData = await MockDataService.getDocument('orders', orderId);
      if (orderData == null) return null;

      return Order.fromMap(orderData, orderId);
    } catch (e) {
      Logger.error('Error getting order by ID', e);
      return null;
    }
  }
}
