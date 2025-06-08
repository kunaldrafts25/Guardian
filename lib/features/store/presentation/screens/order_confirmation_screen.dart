/*
 * Guardian - Women's Safety App
 * © 2025 All Rights Reserved - Kunal Singh
 * Contact: kunalsingh2514@gmail.com
 */

import 'package:flutter/material.dart';
import 'package:guardian/core/constants/app_colors.dart';
import 'package:guardian/core/constants/app_typography.dart';
import 'package:guardian/core/di/service_locator.dart';
import 'package:guardian/core/models/order.dart';
import 'package:guardian/core/utils/logger.dart';
import 'package:guardian/core/widgets/custom_app_bar.dart';
import 'package:guardian/core/widgets/custom_button.dart';
import 'package:guardian/core/widgets/loading_indicator.dart';
import 'package:guardian/features/store/data/mock_store_repository.dart';
import 'package:guardian/features/store/presentation/screens/order_details_screen.dart';
import 'package:guardian/features/store/presentation/screens/store_screen.dart';

class OrderConfirmationScreen extends StatefulWidget {
  final String orderId;

  const OrderConfirmationScreen({
    super.key,
    required this.orderId,
  });

  @override
  State<OrderConfirmationScreen> createState() =>
      _OrderConfirmationScreenState();
}

class _OrderConfirmationScreenState extends State<OrderConfirmationScreen> {
  final StoreRepository _repository = sl<StoreRepository>();

  bool _isLoading = true;
  Order? _order;

  @override
  void initState() {
    super.initState();
    _loadOrder();
  }

  Future<void> _loadOrder() async {
    try {
      setState(() {
        _isLoading = true;
      });

      final order = await _repository.getOrderById(widget.orderId);

      setState(() {
        _order = order;
        _isLoading = false;
      });
    } catch (e) {
      Logger.error('Failed to load order', e);

      setState(() {
        _isLoading = false;
      });
    }
  }

  void _navigateToOrderDetails() {
    if (_order == null) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => OrderDetailsScreen(order: _order!),
      ),
    );
  }

  void _continueShopping() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (context) => const StoreScreen(),
      ),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: 'Order Confirmation',
      ),
      body: _isLoading
          ? const Center(child: LoadingIndicator())
          : _buildContent(),
    );
  }

  Widget _buildContent() {
    if (_order == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 64,
              color: AppColors.danger,
            ),
            const SizedBox(height: 16),
            Text(
              'Order not found',
              style: AppTypography.heading4.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'We couldn\'t find your order. Please try again.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            CustomButton(
              text: 'Continue Shopping',
              onPressed: _continueShopping,
              type: ButtonType.primary,
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // Success icon
          const Icon(
            Icons.check_circle,
            size: 80,
            color: AppColors.success,
          ),
          const SizedBox(height: 24),

          // Thank you message
          Text(
            'Thank You!',
            style: AppTypography.heading2.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Your order has been placed successfully.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),

          // Order details
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                _buildInfoRow('Order ID', widget.orderId),
                const SizedBox(height: 8),
                _buildInfoRow(
                  'Date',
                  _formatDate(_order!.createdAt),
                ),
                const SizedBox(height: 8),
                _buildInfoRow(
                  'Total Amount',
                  '₹${_order!.total.toStringAsFixed(2)}',
                ),
                const SizedBox(height: 8),
                _buildInfoRow(
                  'Payment Method',
                  _order!.paymentMethod,
                ),
                const SizedBox(height: 8),
                _buildInfoRow(
                  'Status',
                  _getStatusText(_order!.status),
                  _getStatusColor(_order!.status),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Shipping info
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Shipping Address',
                  style: AppTypography.bodyLarge.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(_order!.shippingAddress),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Order summary
          Text(
            'Order Summary',
            style: AppTypography.heading4.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _order!.items.length,
            itemBuilder: (context, index) {
              final item = _order!.items[index];

              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: item['imageUrl'] != null
                      ? Image.network(
                          item['imageUrl'],
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return const Icon(
                              Icons.image_not_supported,
                              color: Colors.grey,
                            );
                          },
                        )
                      : const Icon(
                          Icons.image_not_supported,
                          color: Colors.grey,
                        ),
                ),
                title: Text(
                  item['name'],
                  style: AppTypography.bodyMedium.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: Text(
                  'Qty: ${item['quantity']}${item['color'] != null ? ' • ${item['color']}' : ''}',
                  style: AppTypography.caption,
                ),
                trailing: Text(
                  '₹${(item['price'] * item['quantity']).toStringAsFixed(2)}',
                  style: AppTypography.bodyMedium.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 32),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: CustomButton(
                  text: 'View Order Details',
                  onPressed: _navigateToOrderDetails,
                  type: ButtonType.outline,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: CustomButton(
                  text: 'Continue Shopping',
                  onPressed: _continueShopping,
                  type: ButtonType.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, [Color? valueColor]) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: AppTypography.bodyMedium.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        Text(
          value,
          style: AppTypography.bodyMedium.copyWith(
            fontWeight: FontWeight.bold,
            color: valueColor,
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'pending':
        return 'Pending';
      case 'confirmed':
        return 'Confirmed';
      case 'shipped':
        return 'Shipped';
      case 'delivered':
        return 'Delivered';
      case 'cancelled':
        return 'Cancelled';
      default:
        return status;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return AppColors.warning;
      case 'confirmed':
        return AppColors.info;
      case 'shipped':
        return AppColors.info;
      case 'delivered':
        return AppColors.success;
      case 'cancelled':
        return AppColors.danger;
      default:
        return AppColors.textPrimary;
    }
  }
}
