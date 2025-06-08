/*
 * Guardian - Women's Safety App
 * © 2025 All Rights Reserved - Kunal Singh
 * Contact: kunalsingh2514@gmail.com
 */

import 'package:flutter/material.dart';
import 'package:guardian/core/constants/app_colors.dart';
import 'package:guardian/core/constants/app_typography.dart';
import 'package:guardian/core/di/service_locator.dart';
import 'package:guardian/core/utils/logger.dart';
import 'package:guardian/core/widgets/custom_app_bar.dart';
import 'package:guardian/core/widgets/custom_button.dart';
import 'package:guardian/core/widgets/loading_indicator.dart';
import 'package:guardian/features/store/data/mock_store_repository.dart';
import 'package:guardian/features/store/presentation/screens/checkout_screen.dart';
import 'package:guardian/features/store/presentation/widgets/cart_item_card.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final StoreRepository _repository = sl<StoreRepository>();

  List<Map<String, dynamic>> _cartItems = [];
  bool _isLoading = true;
  double _totalPrice = 0.0;

  @override
  void initState() {
    super.initState();
    _loadCartItems();
  }

  Future<void> _loadCartItems() async {
    try {
      setState(() {
        _isLoading = true;
      });

      final cartItems = await _repository.getCartItems();

      setState(() {
        _cartItems = cartItems;
        _calculateTotal();
        _isLoading = false;
      });
    } catch (e) {
      Logger.error('Failed to load cart items', e);

      setState(() {
        _isLoading = false;
      });
    }
  }

  void _calculateTotal() {
    double total = 0.0;

    for (final item in _cartItems) {
      final product = item['product'];
      final quantity = item['quantity'] as int;

      total += product.price * quantity;
    }

    setState(() {
      _totalPrice = total;
    });
  }

  Future<void> _removeItem(String productId, String? color) async {
    try {
      final success = await _repository.removeFromCart(productId, color);

      if (success) {
        await _loadCartItems();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Item removed from cart'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      } else {
        throw Exception('Failed to remove item from cart');
      }
    } catch (e) {
      Logger.error('Failed to remove item from cart', e);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to remove item: ${e.toString()}'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  Future<void> _navigateToCheckout() async {
    if (_cartItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Your cart is empty'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => CheckoutScreen(
          cartItems: _cartItems,
          totalPrice: _totalPrice,
        ),
      ),
    );

    if (result == true) {
      await _loadCartItems();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: 'Shopping Cart',
      ),
      body: _isLoading
          ? const Center(child: LoadingIndicator())
          : _buildContent(),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildContent() {
    if (_cartItems.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.shopping_cart_outlined,
              size: 64,
              color: AppColors.textSecondary,
            ),
            const SizedBox(height: 16),
            Text(
              'Your cart is empty',
              style: AppTypography.heading4.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add some safety products to your cart',
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
              child: const Text('Continue Shopping'),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _cartItems.length,
      itemBuilder: (context, index) {
        final item = _cartItems[index];
        final product = item['product'];
        final quantity = item['quantity'] as int;
        final color = item['color'] as String?;

        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: CartItemCard(
            product: product,
            quantity: quantity,
            color: color,
            onRemove: () => _removeItem(product.id, color),
          ),
        );
      },
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Total',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
                Text(
                  '₹${_totalPrice.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: CustomButton(
                text: 'Proceed to Checkout',
                onPressed: _cartItems.isEmpty ? null : _navigateToCheckout,
                isFullWidth: true,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
