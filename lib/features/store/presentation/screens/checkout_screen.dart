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
import 'package:guardian/features/store/presentation/screens/order_confirmation_screen.dart';
import 'package:guardian/features/store/presentation/widgets/address_form.dart';
import 'package:guardian/features/store/presentation/widgets/payment_method_selector.dart';

class CheckoutScreen extends StatefulWidget {
  final List<Map<String, dynamic>> cartItems;
  final double totalPrice;

  const CheckoutScreen({
    super.key,
    required this.cartItems,
    required this.totalPrice,
  });

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final StoreRepository _repository = sl<StoreRepository>();
  final _addressFormKey = GlobalKey<FormState>();

  bool _isLoading = false;
  String _selectedPaymentMethod = 'Credit Card';

  // Address fields
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _zipController = TextEditingController();
  final _phoneController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _zipController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _placeOrder() async {
    if (_addressFormKey.currentState?.validate() != true) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Format address
      final shippingAddress =
          '${_nameController.text}, ${_addressController.text}, '
          '${_cityController.text}, ${_stateController.text} ${_zipController.text}, '
          'Phone: ${_phoneController.text}';

      // Create order items
      final orderItems = widget.cartItems.map((item) {
        final product = item['product'];
        final quantity = item['quantity'] as int;
        final color = item['color'] as String?;

        return {
          'productId': product.id,
          'name': product.name,
          'price': product.price,
          'quantity': quantity,
          'color': color,
          'imageUrl': product.imageUrl,
        };
      }).toList();

      // Place order
      final orderId = await _repository.createOrder(
        items: orderItems,
        total: widget.totalPrice,
        paymentMethod: _selectedPaymentMethod,
        shippingAddress: shippingAddress,
      );

      if (orderId == null) {
        throw Exception('Failed to create order');
      }

      if (mounted) {
        // Navigate to confirmation screen
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => OrderConfirmationScreen(
              orderId: orderId,
            ),
          ),
        );
      }
    } catch (e) {
      Logger.error('Failed to place order', e);

      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to place order: ${e.toString()}'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: 'Checkout',
      ),
      body: _isLoading
          ? const Center(child: LoadingIndicator())
          : _buildContent(),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Order summary
          _buildOrderSummary(),
          const SizedBox(height: 24),

          // Shipping address
          Text(
            'Shipping Address',
            style: AppTypography.heading4.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          AddressForm(
            formKey: _addressFormKey,
            nameController: _nameController,
            addressController: _addressController,
            cityController: _cityController,
            stateController: _stateController,
            zipController: _zipController,
            phoneController: _phoneController,
          ),
          const SizedBox(height: 24),

          // Payment method
          Text(
            'Payment Method',
            style: AppTypography.heading4.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          PaymentMethodSelector(
            selectedMethod: _selectedPaymentMethod,
            onMethodSelected: (method) {
              setState(() {
                _selectedPaymentMethod = method;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildOrderSummary() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Order Summary',
              style: AppTypography.heading4.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),

            // Items
            ...widget.cartItems.map((item) {
              final product = item['product'];
              final quantity = item['quantity'] as int;
              final color = item['color'] as String?;

              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Text(
                      '$quantity x',
                      style: AppTypography.bodyMedium.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        product.name,
                        style: AppTypography.bodyMedium,
                      ),
                    ),
                    if (color != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        color,
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                    const SizedBox(width: 8),
                    Text(
                      '₹${(product.price * quantity).toStringAsFixed(2)}',
                      style: AppTypography.bodyMedium.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              );
            }),

            const Divider(height: 24),

            // Subtotal
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Subtotal'),
                Text(
                  '₹${widget.totalPrice.toStringAsFixed(2)}',
                  style: AppTypography.bodyMedium.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Shipping
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Shipping'),
                Text(
                  'Free',
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.success,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Tax
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Tax'),
                Text(
                  '₹${(widget.totalPrice * 0.18).toStringAsFixed(2)}',
                  style: AppTypography.bodyMedium.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),

            const Divider(height: 24),

            // Total
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total',
                  style: AppTypography.heading4.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '₹${(widget.totalPrice + widget.totalPrice * 0.18).toStringAsFixed(2)}',
                  style: AppTypography.heading4.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
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
        child: CustomButton(
          text: 'Place Order',
          onPressed: _placeOrder,
          isLoading: _isLoading,
          isFullWidth: true,
        ),
      ),
    );
  }
}
