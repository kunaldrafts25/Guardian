/*
 * Guardian - Women's Safety App
 * © 2025 All Rights Reserved - Kunal Singh
 * Contact: kunalsingh2514@gmail.com
 */

/// Category of a product
enum ProductCategory {
  /// Wearable safety devices
  wearable,
  
  /// Personal alarms
  alarm,
  
  /// Self-defense tools
  selfDefense,
  
  /// Safety subscriptions
  subscription,
  
  /// Safety courses
  course,
  
  /// Safety accessories
  accessory,
  
  /// Other products
  other,
}

/// A model representing a product review
class ProductReview {
  /// Unique identifier for the review
  final String id;
  
  /// User ID who submitted the review
  final String userId;
  
  /// User name who submitted the review
  final String userName;
  
  /// Rating (1-5)
  final double rating;
  
  /// Review text
  final String? comment;
  
  /// When the review was submitted
  final DateTime createdAt;
  
  /// Whether the review is verified
  final bool isVerified;
  
  /// User's profile image URL
  final String? userImageUrl;

  ProductReview({
    required this.id,
    required this.userId,
    required this.userName,
    required this.rating,
    this.comment,
    DateTime? createdAt,
    this.isVerified = false,
    this.userImageUrl,
  }) : createdAt = createdAt ?? DateTime.now();

  /// Convert to a map for storage
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'userName': userName,
      'rating': rating,
      'comment': comment,
      'createdAt': createdAt.toIso8601String(),
      'isVerified': isVerified,
      'userImageUrl': userImageUrl,
    };
  }

  /// Create from a map
  factory ProductReview.fromMap(Map<String, dynamic> map) {
    return ProductReview(
      id: map['id'] ?? '',
      userId: map['userId'] ?? '',
      userName: map['userName'] ?? '',
      rating: (map['rating'] ?? 0.0).toDouble(),
      comment: map['comment'],
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'])
          : DateTime.now(),
      isVerified: map['isVerified'] ?? false,
      userImageUrl: map['userImageUrl'],
    );
  }
}

/// A model representing a product in the store
class Product {
  /// Unique identifier for the product
  final String id;
  
  /// Name of the product
  final String name;
  
  /// Description of the product
  final String description;
  
  /// Price in USD
  final double price;
  
  /// Discount percentage (0-100)
  final double? discountPercentage;
  
  /// Product category
  final ProductCategory category;
  
  /// Product images URLs
  final List<String> imageUrls;
  
  /// Average rating (1-5)
  final double averageRating;
  
  /// Number of reviews
  final int reviewCount;
  
  /// Product reviews
  final List<ProductReview> reviews;
  
  /// Whether the product is in stock
  final bool inStock;
  
  /// Stock quantity
  final int? stockQuantity;
  
  /// Product features
  final List<String> features;
  
  /// Product specifications
  final Map<String, String> specifications;
  
  /// Whether the product is featured
  final bool isFeatured;
  
  /// Whether the product is new
  final bool isNew;
  
  /// Whether the product is a bestseller
  final bool isBestseller;
  
  /// When the product was created
  final DateTime createdAt;
  
  /// When the product was last updated
  final DateTime updatedAt;
  
  /// Shipping information
  final String? shippingInfo;
  
  /// Return policy
  final String? returnPolicy;
  
  /// Warranty information
  final String? warrantyInfo;

  Product({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    this.discountPercentage,
    required this.category,
    required this.imageUrls,
    this.averageRating = 0.0,
    this.reviewCount = 0,
    this.reviews = const [],
    this.inStock = true,
    this.stockQuantity,
    this.features = const [],
    this.specifications = const {},
    this.isFeatured = false,
    this.isNew = false,
    this.isBestseller = false,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.shippingInfo,
    this.returnPolicy,
    this.warrantyInfo,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  /// Convert to a map for storage
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'price': price,
      'discountPercentage': discountPercentage,
      'category': category.toString().split('.').last,
      'imageUrls': imageUrls,
      'averageRating': averageRating,
      'reviewCount': reviewCount,
      'reviews': reviews.map((r) => r.toMap()).toList(),
      'inStock': inStock,
      'stockQuantity': stockQuantity,
      'features': features,
      'specifications': specifications,
      'isFeatured': isFeatured,
      'isNew': isNew,
      'isBestseller': isBestseller,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'shippingInfo': shippingInfo,
      'returnPolicy': returnPolicy,
      'warrantyInfo': warrantyInfo,
    };
  }

  /// Create from a map
  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      price: (map['price'] ?? 0.0).toDouble(),
      discountPercentage: map['discountPercentage'] != null
          ? (map['discountPercentage'] as num).toDouble()
          : null,
      category: ProductCategory.values.firstWhere(
        (e) => e.toString().split('.').last == map['category'],
        orElse: () => ProductCategory.other,
      ),
      imageUrls: List<String>.from(map['imageUrls'] ?? []),
      averageRating: (map['averageRating'] ?? 0.0).toDouble(),
      reviewCount: map['reviewCount'] ?? 0,
      reviews: (map['reviews'] as List?)
              ?.map((r) => ProductReview.fromMap(r))
              .toList() ??
          [],
      inStock: map['inStock'] ?? true,
      stockQuantity: map['stockQuantity'],
      features: List<String>.from(map['features'] ?? []),
      specifications: Map<String, String>.from(map['specifications'] ?? {}),
      isFeatured: map['isFeatured'] ?? false,
      isNew: map['isNew'] ?? false,
      isBestseller: map['isBestseller'] ?? false,
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'])
          : DateTime.now(),
      updatedAt: map['updatedAt'] != null
          ? DateTime.parse(map['updatedAt'])
          : DateTime.now(),
      shippingInfo: map['shippingInfo'],
      returnPolicy: map['returnPolicy'],
      warrantyInfo: map['warrantyInfo'],
    );
  }

  /// Get the discounted price
  double get discountedPrice {
    if (discountPercentage == null || discountPercentage == 0) {
      return price;
    }
    
    return price - (price * discountPercentage! / 100);
  }

  /// Create a copy with updated values
  Product copyWith({
    String? id,
    String? name,
    String? description,
    double? price,
    double? discountPercentage,
    ProductCategory? category,
    List<String>? imageUrls,
    double? averageRating,
    int? reviewCount,
    List<ProductReview>? reviews,
    bool? inStock,
    int? stockQuantity,
    List<String>? features,
    Map<String, String>? specifications,
    bool? isFeatured,
    bool? isNew,
    bool? isBestseller,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? shippingInfo,
    String? returnPolicy,
    String? warrantyInfo,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      price: price ?? this.price,
      discountPercentage: discountPercentage ?? this.discountPercentage,
      category: category ?? this.category,
      imageUrls: imageUrls ?? this.imageUrls,
      averageRating: averageRating ?? this.averageRating,
      reviewCount: reviewCount ?? this.reviewCount,
      reviews: reviews ?? this.reviews,
      inStock: inStock ?? this.inStock,
      stockQuantity: stockQuantity ?? this.stockQuantity,
      features: features ?? this.features,
      specifications: specifications ?? this.specifications,
      isFeatured: isFeatured ?? this.isFeatured,
      isNew: isNew ?? this.isNew,
      isBestseller: isBestseller ?? this.isBestseller,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      shippingInfo: shippingInfo ?? this.shippingInfo,
      returnPolicy: returnPolicy ?? this.returnPolicy,
      warrantyInfo: warrantyInfo ?? this.warrantyInfo,
    );
  }
}
