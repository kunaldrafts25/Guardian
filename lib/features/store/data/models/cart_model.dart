/*
 * Guardian - Women's Safety App
 * © 2025 All Rights Reserved - Kunal Singh
 * Contact: kunalsingh2514@gmail.com
 */

import 'package:guardian/features/store/data/models/product_model.dart';

/// Status of an order
enum OrderStatus {
  /// Order has been placed but not yet processed
  pending,
  
  /// Order has been processed and payment confirmed
  confirmed,
  
  /// Order has been shipped
  shipped,
  
  /// Order has been delivered
  delivered,
  
  /// Order has been cancelled
  cancelled,
  
  /// Order has been returned
  returned,
}

/// A model representing a cart item
class CartItem {
  /// Product ID
  final String productId;
  
  /// Product name
  final String productName;
  
  /// Product image URL
  final String productImageUrl;
  
  /// Product price
  final double price;
  
  /// Quantity of the product
  final int quantity;
  
  /// Product discount percentage
  final double? discountPercentage;

  CartItem({
    required this.productId,
    required this.productName,
    required this.productImageUrl,
    required this.price,
    required this.quantity,
    this.discountPercentage,
  });

  /// Convert to a map for storage
  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'productName': productName,
      'productImageUrl': productImageUrl,
      'price': price,
      'quantity': quantity,
      'discountPercentage': discountPercentage,
    };
  }

  /// Create from a map
  factory CartItem.fromMap(Map<String, dynamic> map) {
    return CartItem(
      productId: map['productId'] ?? '',
      productName: map['productName'] ?? '',
      productImageUrl: map['productImageUrl'] ?? '',
      price: (map['price'] ?? 0.0).toDouble(),
      quantity: map['quantity'] ?? 1,
      discountPercentage: map['discountPercentage'] != null
          ? (map['discountPercentage'] as num).toDouble()
          : null,
    );
  }

  /// Create from a product
  factory CartItem.fromProduct(Product product, {int quantity = 1}) {
    return CartItem(
      productId: product.id,
      productName: product.name,
      productImageUrl: product.imageUrls.isNotEmpty
          ? product.imageUrls.first
          : '',
      price: product.price,
      quantity: quantity,
      discountPercentage: product.discountPercentage,
    );
  }

  /// Get the total price for this item
  double get totalPrice {
    if (discountPercentage == null || discountPercentage == 0) {
      return price * quantity;
    }
    
    final discountedPrice = price - (price * discountPercentage! / 100);
    return discountedPrice * quantity;
  }

  /// Create a copy with updated values
  CartItem copyWith({
    String? productId,
    String? productName,
    String? productImageUrl,
    double? price,
    int? quantity,
    double? discountPercentage,
  }) {
    return CartItem(
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      productImageUrl: productImageUrl ?? this.productImageUrl,
      price: price ?? this.price,
      quantity: quantity ?? this.quantity,
      discountPercentage: discountPercentage ?? this.discountPercentage,
    );
  }
}

/// A model representing a shopping cart
class Cart {
  /// List of items in the cart
  final List<CartItem> items;
  
  /// When the cart was last updated
  final DateTime updatedAt;

  Cart({
    this.items = const [],
    DateTime? updatedAt,
  }) : updatedAt = updatedAt ?? DateTime.now();

  /// Convert to a map for storage
  Map<String, dynamic> toMap() {
    return {
      'items': items.map((item) => item.toMap()).toList(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  /// Create from a map
  factory Cart.fromMap(Map<String, dynamic> map) {
    return Cart(
      items: (map['items'] as List?)
              ?.map((item) => CartItem.fromMap(item))
              .toList() ??
          [],
      updatedAt: map['updatedAt'] != null
          ? DateTime.parse(map['updatedAt'])
          : DateTime.now(),
    );
  }

  /// Get the total price of all items in the cart
  double get totalPrice {
    return items.fold(0, (sum, item) => sum + item.totalPrice);
  }

  /// Get the total number of items in the cart
  int get itemCount {
    return items.fold(0, (sum, item) => sum + item.quantity);
  }

  /// Create a copy with updated values
  Cart copyWith({
    List<CartItem>? items,
    DateTime? updatedAt,
  }) {
    return Cart(
      items: items ?? this.items,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// A model representing a shipping address
class ShippingAddress {
  /// Full name of the recipient
  final String fullName;
  
  /// Street address
  final String streetAddress;
  
  /// City
  final String city;
  
  /// State or province
  final String state;
  
  /// Postal code
  final String postalCode;
  
  /// Country
  final String country;
  
  /// Phone number
  final String phoneNumber;
  
  /// Whether this is the default address
  final bool isDefault;

  ShippingAddress({
    required this.fullName,
    required this.streetAddress,
    required this.city,
    required this.state,
    required this.postalCode,
    required this.country,
    required this.phoneNumber,
    this.isDefault = false,
  });

  /// Convert to a map for storage
  Map<String, dynamic> toMap() {
    return {
      'fullName': fullName,
      'streetAddress': streetAddress,
      'city': city,
      'state': state,
      'postalCode': postalCode,
      'country': country,
      'phoneNumber': phoneNumber,
      'isDefault': isDefault,
    };
  }

  /// Create from a map
  factory ShippingAddress.fromMap(Map<String, dynamic> map) {
    return ShippingAddress(
      fullName: map['fullName'] ?? '',
      streetAddress: map['streetAddress'] ?? '',
      city: map['city'] ?? '',
      state: map['state'] ?? '',
      postalCode: map['postalCode'] ?? '',
      country: map['country'] ?? '',
      phoneNumber: map['phoneNumber'] ?? '',
      isDefault: map['isDefault'] ?? false,
    );
  }

  /// Get the formatted address
  String get formattedAddress {
    return '$streetAddress, $city, $state $postalCode, $country';
  }

  /// Create a copy with updated values
  ShippingAddress copyWith({
    String? fullName,
    String? streetAddress,
    String? city,
    String? state,
    String? postalCode,
    String? country,
    String? phoneNumber,
    bool? isDefault,
  }) {
    return ShippingAddress(
      fullName: fullName ?? this.fullName,
      streetAddress: streetAddress ?? this.streetAddress,
      city: city ?? this.city,
      state: state ?? this.state,
      postalCode: postalCode ?? this.postalCode,
      country: country ?? this.country,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      isDefault: isDefault ?? this.isDefault,
    );
  }
}

/// A model representing an order
class Order {
  /// Unique identifier for the order
  final String id;
  
  /// User ID who placed the order
  final String userId;
  
  /// Items in the order
  final List<CartItem> items;
  
  /// Total price of the order
  final double totalPrice;
  
  /// Shipping address
  final ShippingAddress shippingAddress;
  
  /// Order status
  final OrderStatus status;
  
  /// When the order was placed
  final DateTime createdAt;
  
  /// When the order was last updated
  final DateTime updatedAt;
  
  /// Tracking number for shipping
  final String? trackingNumber;
  
  /// Shipping carrier
  final String? shippingCarrier;
  
  /// Estimated delivery date
  final DateTime? estimatedDeliveryDate;
  
  /// Payment method used
  final String paymentMethod;
  
  /// Transaction ID from payment processor
  final String? transactionId;

  Order({
    required this.id,
    required this.userId,
    required this.items,
    required this.totalPrice,
    required this.shippingAddress,
    required this.status,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.trackingNumber,
    this.shippingCarrier,
    this.estimatedDeliveryDate,
    required this.paymentMethod,
    this.transactionId,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  /// Convert to a map for storage
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'items': items.map((item) => item.toMap()).toList(),
      'totalPrice': totalPrice,
      'shippingAddress': shippingAddress.toMap(),
      'status': status.toString().split('.').last,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'trackingNumber': trackingNumber,
      'shippingCarrier': shippingCarrier,
      'estimatedDeliveryDate': estimatedDeliveryDate?.toIso8601String(),
      'paymentMethod': paymentMethod,
      'transactionId': transactionId,
    };
  }

  /// Create from a map
  factory Order.fromMap(Map<String, dynamic> map) {
    return Order(
      id: map['id'] ?? '',
      userId: map['userId'] ?? '',
      items: (map['items'] as List?)
              ?.map((item) => CartItem.fromMap(item))
              .toList() ??
          [],
      totalPrice: (map['totalPrice'] ?? 0.0).toDouble(),
      shippingAddress: ShippingAddress.fromMap(
          map['shippingAddress'] ?? {}),
      status: OrderStatus.values.firstWhere(
        (e) => e.toString().split('.').last == map['status'],
        orElse: () => OrderStatus.pending,
      ),
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'])
          : DateTime.now(),
      updatedAt: map['updatedAt'] != null
          ? DateTime.parse(map['updatedAt'])
          : DateTime.now(),
      trackingNumber: map['trackingNumber'],
      shippingCarrier: map['shippingCarrier'],
      estimatedDeliveryDate: map['estimatedDeliveryDate'] != null
          ? DateTime.parse(map['estimatedDeliveryDate'])
          : null,
      paymentMethod: map['paymentMethod'] ?? 'Credit Card',
      transactionId: map['transactionId'],
    );
  }

  /// Create a copy with updated values
  Order copyWith({
    String? id,
    String? userId,
    List<CartItem>? items,
    double? totalPrice,
    ShippingAddress? shippingAddress,
    OrderStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? trackingNumber,
    String? shippingCarrier,
    DateTime? estimatedDeliveryDate,
    String? paymentMethod,
    String? transactionId,
  }) {
    return Order(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      items: items ?? this.items,
      totalPrice: totalPrice ?? this.totalPrice,
      shippingAddress: shippingAddress ?? this.shippingAddress,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      trackingNumber: trackingNumber ?? this.trackingNumber,
      shippingCarrier: shippingCarrier ?? this.shippingCarrier,
      estimatedDeliveryDate: estimatedDeliveryDate ?? this.estimatedDeliveryDate,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      transactionId: transactionId ?? this.transactionId,
    );
  }
}
