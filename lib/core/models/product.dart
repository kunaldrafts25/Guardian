/*
 * Guardian - Women's Safety App
 * © 2025 All Rights Reserved - Kunal Singh
 * Contact: kunalsingh2514@gmail.com
 */

/// Model class for store products
class Product {
  /// Unique identifier for the product
  final String id;
  
  /// Name of the product
  final String name;
  
  /// Description of the product
  final String description;
  
  /// Price of the product
  final double price;
  
  /// URL to the product image
  final String imageUrl;
  
  /// Category of the product
  final String category;
  
  /// Whether the product is in stock
  final bool inStock;
  
  /// Whether the product is active and can be purchased
  final bool isActive;
  
  /// Average rating of the product (0-5)
  final double rating;
  
  /// Number of reviews for the product
  final int reviewCount;
  
  /// Additional product details
  final Map<String, dynamic>? details;
  
  /// Constructor
  Product({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.imageUrl,
    required this.category,
    this.inStock = true,
    this.isActive = true,
    this.rating = 0.0,
    this.reviewCount = 0,
    this.details,
  });
  
  /// Create a product from a map (e.g., from Firestore)
  factory Product.fromMap(Map<String, dynamic> map, String id) {
    return Product(
      id: id,
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      price: (map['price'] ?? 0.0).toDouble(),
      imageUrl: map['imageUrl'] ?? '',
      category: map['category'] ?? '',
      inStock: map['inStock'] ?? true,
      isActive: map['isActive'] ?? true,
      rating: (map['rating'] ?? 0.0).toDouble(),
      reviewCount: map['reviewCount'] ?? 0,
      details: map['details'],
    );
  }
  
  /// Convert product to a map (e.g., for Firestore)
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'price': price,
      'imageUrl': imageUrl,
      'category': category,
      'inStock': inStock,
      'isActive': isActive,
      'rating': rating,
      'reviewCount': reviewCount,
      'details': details,
    };
  }
  
  /// Create a copy of this product with some fields replaced
  Product copyWith({
    String? name,
    String? description,
    double? price,
    String? imageUrl,
    String? category,
    bool? inStock,
    bool? isActive,
    double? rating,
    int? reviewCount,
    Map<String, dynamic>? details,
  }) {
    return Product(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
      price: price ?? this.price,
      imageUrl: imageUrl ?? this.imageUrl,
      category: category ?? this.category,
      inStock: inStock ?? this.inStock,
      isActive: isActive ?? this.isActive,
      rating: rating ?? this.rating,
      reviewCount: reviewCount ?? this.reviewCount,
      details: details ?? this.details,
    );
  }
}
