/*
 * Guardian - Women's Safety App
 * © 2025 All Rights Reserved - Kunal Singh
 * Contact: kunalsingh2514@gmail.com
 */

class Product {
  final String id;
  final String name;
  final String description;
  final double price;
  final String imageUrl;
  final List<String> colors;
  final String category;
  final bool isAvailable;
  final double rating;
  final int reviewCount;

  Product({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.imageUrl,
    required this.colors,
    required this.category,
    required this.isAvailable,
    required this.rating,
    required this.reviewCount,
  });

  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      price: (map['price'] ?? 0.0).toDouble(),
      imageUrl: map['imageUrl'] ?? '',
      colors: List<String>.from(map['colors'] ?? []),
      category: map['category'] ?? '',
      isAvailable: map['isAvailable'] ?? true,
      rating: (map['rating'] ?? 0.0).toDouble(),
      reviewCount: map['reviewCount'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'price': price,
      'imageUrl': imageUrl,
      'colors': colors,
      'category': category,
      'isAvailable': isAvailable,
      'rating': rating,
      'reviewCount': reviewCount,
    };
  }
}

// Mock products data
List<Product> mockProducts = [
  Product(
    id: '1',
    name: 'Guardian Bracelet',
    description: 'Stylish bracelet with emergency trigger button and Bluetooth connectivity. Water-resistant and long battery life.',
    price: 1999.0,
    imageUrl: 'https://via.placeholder.com/300',
    colors: ['Black', 'Silver', 'Rose Gold'],
    category: 'Bracelet',
    isAvailable: true,
    rating: 4.5,
    reviewCount: 128,
  ),
  Product(
    id: '2',
    name: 'Safety Ring',
    description: 'Discreet ring with panic button. Connects to your phone via Bluetooth. Available in multiple sizes.',
    price: 2499.0,
    imageUrl: 'https://via.placeholder.com/300',
    colors: ['Silver', 'Gold', 'Black'],
    category: 'Ring',
    isAvailable: true,
    rating: 4.2,
    reviewCount: 85,
  ),
  Product(
    id: '3',
    name: 'Guardian Pendant',
    description: 'Elegant pendant necklace with hidden emergency button. Perfect for formal occasions.',
    price: 1799.0,
    imageUrl: 'https://via.placeholder.com/300',
    colors: ['Silver', 'Gold'],
    category: 'Pendant',
    isAvailable: true,
    rating: 4.0,
    reviewCount: 64,
  ),
  Product(
    id: '4',
    name: 'Safety Watch',
    description: 'Smartwatch with emergency features, heart rate monitoring, and GPS tracking.',
    price: 3999.0,
    imageUrl: 'https://via.placeholder.com/300',
    colors: ['Black', 'White', 'Blue'],
    category: 'Watch',
    isAvailable: true,
    rating: 4.7,
    reviewCount: 203,
  ),
  Product(
    id: '5',
    name: 'Keychain Alarm',
    description: 'Loud alarm keychain with LED light. No Bluetooth required.',
    price: 599.0,
    imageUrl: 'https://via.placeholder.com/300',
    colors: ['Red', 'Black', 'Pink'],
    category: 'Keychain',
    isAvailable: true,
    rating: 3.8,
    reviewCount: 42,
  ),
  Product(
    id: '6',
    name: 'Safety Belt Clip',
    description: 'Clip-on device for your belt or bag with emergency button and GPS tracking.',
    price: 1499.0,
    imageUrl: 'https://via.placeholder.com/300',
    colors: ['Black', 'White'],
    category: 'Clip',
    isAvailable: false,
    rating: 4.1,
    reviewCount: 37,
  ),
];
