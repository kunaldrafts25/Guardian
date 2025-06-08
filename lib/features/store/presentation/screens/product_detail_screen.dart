/*
 * Guardian - Women's Safety App
 * © 2025 All Rights Reserved - Kunal Singh
 * Contact: kunalsingh2514@gmail.com
 */

import 'package:flutter/material.dart';
import 'package:guardian/core/constants/app_colors.dart';
import 'package:guardian/core/constants/app_strings.dart';
import 'package:guardian/core/widgets/custom_button.dart';
import 'package:guardian/features/store/data/product_model.dart';

class ProductDetailScreen extends StatefulWidget {
  final Product product;

  const ProductDetailScreen({
    super.key,
    required this.product,
  });

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  String _selectedColor = '';
  int _quantity = 1;

  @override
  void initState() {
    super.initState();
    if (widget.product.colors.isNotEmpty) {
      _selectedColor = widget.product.colors.first;
    }
  }

  void _incrementQuantity() {
    setState(() {
      _quantity++;
    });
  }

  void _decrementQuantity() {
    if (_quantity > 1) {
      setState(() {
        _quantity--;
      });
    }
  }

  void _addToCart() {
    // TODO: Implement add to cart functionality
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${widget.product.name} added to cart'),
        backgroundColor: AppColors.success,
      ),
    );
  }

  void _buyNow() {
    // TODO: Implement buy now functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Proceeding to checkout...'),
        backgroundColor: AppColors.primary,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Product Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.shopping_cart),
            onPressed: () {
              // TODO: Navigate to cart screen
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product image
            AspectRatio(
              aspectRatio: 1,
              child: Image.network(
                widget.product.imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: Colors.grey[200],
                    child: const Center(
                      child: Icon(
                        Icons.image_not_supported,
                        size: 50,
                        color: Colors.grey,
                      ),
                    ),
                  );
                },
              ),
            ),

            // Product details
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name and price
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          widget.product.name,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Text(
                        '₹${widget.product.price.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Rating
                  Row(
                    children: [
                      const Icon(
                        Icons.star,
                        color: Colors.amber,
                        size: 20,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        widget.product.rating.toString(),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '(${widget.product.reviewCount} reviews)',
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: widget.product.isAvailable
                              ? AppColors.success.withOpacity(0.1)
                              : AppColors.danger.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          widget.product.isAvailable ? 'In Stock' : 'Out of Stock',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: widget.product.isAvailable
                                ? AppColors.success
                                : AppColors.danger,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Description
                  const Text(
                    'Description',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.product.description,
                    style: const TextStyle(
                      fontSize: 16,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Colors
                  if (widget.product.colors.isNotEmpty) ...[
                    const Text(
                      'Colors',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: widget.product.colors.map((color) {
                        final isSelected = color == _selectedColor;
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedColor = color;
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppColors.primary.withOpacity(0.1)
                                  : Colors.transparent,
                              border: Border.all(
                                color: isSelected
                                    ? AppColors.primary
                                    : AppColors.divider,
                              ),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              color,
                              style: TextStyle(
                                color: isSelected
                                    ? AppColors.primary
                                    : AppColors.textPrimary,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Quantity
                  const Text(
                    'Quantity',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      IconButton(
                        onPressed: _decrementQuantity,
                        icon: const Icon(Icons.remove),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.grey[200],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _quantity.toString(),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: _incrementQuantity,
                        icon: const Icon(Icons.add),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.grey[200],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Action buttons
                  Row(
                    children: [
                      Expanded(
                        child: CustomButton(
                          text: AppStrings.addToCart,
                          onPressed: widget.product.isAvailable ? _addToCart : null,
                          type: ButtonType.outline,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: CustomButton(
                          text: AppStrings.buyNow,
                          onPressed: widget.product.isAvailable ? _buyNow : null,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
