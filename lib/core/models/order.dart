/*
 * Guardian - Women's Safety App
 * © 2025 All Rights Reserved - Kunal Singh
 * Contact: kunalsingh2514@gmail.com
 */

/// Model class for store orders
class Order {
  /// Unique identifier for the order
  final String id;
  
  /// User ID who placed the order
  final String userId;
  
  /// Items in the order
  final List<Map<String, dynamic>> items;
  
  /// Total price of the order
  final double total;
  
  /// Status of the order (pending, processing, shipped, delivered, cancelled)
  final String status;
  
  /// Payment method used
  final String paymentMethod;
  
  /// Shipping address
  final String shippingAddress;
  
  /// Timestamp when the order was created
  final DateTime createdAt;
  
  /// Timestamp when the order was updated
  final DateTime? updatedAt;
  
  /// Constructor
  Order({
    required this.id,
    required this.userId,
    required this.items,
    required this.total,
    required this.status,
    required this.paymentMethod,
    required this.shippingAddress,
    required this.createdAt,
    this.updatedAt,
  });
  
  /// Create an order from a map (e.g., from Firestore)
  factory Order.fromMap(Map<String, dynamic> map, String id) {
    return Order(
      id: id,
      userId: map['userId'] ?? '',
      items: List<Map<String, dynamic>>.from(map['items'] ?? []),
      total: (map['total'] ?? 0.0).toDouble(),
      status: map['status'] ?? 'pending',
      paymentMethod: map['paymentMethod'] ?? '',
      shippingAddress: map['shippingAddress'] ?? '',
      createdAt: (map['createdAt'] as dynamic)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as dynamic)?.toDate(),
    );
  }
  
  /// Convert order to a map (e.g., for Firestore)
  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'items': items,
      'total': total,
      'status': status,
      'paymentMethod': paymentMethod,
      'shippingAddress': shippingAddress,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }
  
  /// Create a copy of this order with some fields replaced
  Order copyWith({
    List<Map<String, dynamic>>? items,
    double? total,
    String? status,
    String? paymentMethod,
    String? shippingAddress,
    DateTime? updatedAt,
  }) {
    return Order(
      id: id,
      userId: userId,
      items: items ?? this.items,
      total: total ?? this.total,
      status: status ?? this.status,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      shippingAddress: shippingAddress ?? this.shippingAddress,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
