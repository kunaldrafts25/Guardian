/*
 * Guardian - Women's Safety App
 * © 2025 All Rights Reserved - Kunal Singh
 * Contact: kunalsingh2514@gmail.com
 */

import 'package:flutter/material.dart';
import 'package:guardian/core/constants/app_colors.dart';
import 'package:guardian/core/constants/app_strings.dart';
import 'package:guardian/features/store/data/product_model.dart';
import 'package:guardian/features/store/presentation/screens/product_detail_screen.dart';
import 'package:guardian/features/store/presentation/widgets/product_card.dart';

class StoreScreen extends StatefulWidget {
  const StoreScreen({super.key});

  @override
  State<StoreScreen> createState() => _StoreScreenState();
}

class _StoreScreenState extends State<StoreScreen> {
  List<Product> _products = [];
  List<Product> _filteredProducts = [];
  String _selectedCategory = 'All';
  String _searchQuery = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    // In a real app, this would fetch from Firestore
    // For now, we'll use mock data
    await Future.delayed(const Duration(seconds: 1)); // Simulate network delay
    setState(() {
      _products = mockProducts;
      _filteredProducts = mockProducts;
      _isLoading = false;
    });
  }

  void _filterProducts() {
    setState(() {
      if (_selectedCategory == 'All') {
        _filteredProducts = _products.where((product) {
          return product.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              product.description.toLowerCase().contains(_searchQuery.toLowerCase());
        }).toList();
      } else {
        _filteredProducts = _products.where((product) {
          return product.category == _selectedCategory &&
              (product.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                  product.description.toLowerCase().contains(_searchQuery.toLowerCase()));
        }).toList();
      }
    });
  }

  List<String> _getCategories() {
    final categories = _products.map((product) => product.category).toSet().toList();
    categories.sort();
    return ['All', ...categories];
  }

  void _navigateToProductDetail(Product product) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProductDetailScreen(product: product),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.store),
        actions: [
          IconButton(
            icon: const Icon(Icons.shopping_cart),
            onPressed: () {
              // TODO: Navigate to cart screen
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Search bar
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Search safety devices...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    ),
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value;
                      });
                      _filterProducts();
                    },
                  ),
                ),

                // Category filter
                SizedBox(
                  height: 50,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _getCategories().length,
                    itemBuilder: (context, index) {
                      final category = _getCategories()[index];
                      final isSelected = category == _selectedCategory;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(category),
                          selected: isSelected,
                          selectedColor: AppColors.primary.withOpacity(0.2),
                          onSelected: (selected) {
                            if (selected) {
                              setState(() {
                                _selectedCategory = category;
                              });
                              _filterProducts();
                            }
                          },
                        ),
                      );
                    },
                  ),
                ),

                // Product grid
                Expanded(
                  child: _filteredProducts.isEmpty
                      ? const Center(
                          child: Text(
                            'No products found',
                            style: TextStyle(
                              fontSize: 16,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        )
                      : GridView.builder(
                          padding: const EdgeInsets.all(16),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            childAspectRatio: 0.7,
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                          ),
                          itemCount: _filteredProducts.length,
                          itemBuilder: (context, index) {
                            final product = _filteredProducts[index];
                            return ProductCard(
                              product: product,
                              onTap: () => _navigateToProductDetail(product),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}
