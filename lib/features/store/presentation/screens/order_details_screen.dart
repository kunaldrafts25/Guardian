/*
 * Guardian - Women's Safety App
 * © 2025 All Rights Reserved - Kunal Singh
 * Contact: kunalsingh2514@gmail.com
 */

import 'package:flutter/material.dart';
import 'package:guardian/core/constants/app_colors.dart';
import 'package:guardian/core/constants/app_typography.dart';
import 'package:guardian/core/models/order.dart';
import 'package:guardian/core/utils/logger.dart';
import 'package:guardian/core/widgets/custom_app_bar.dart';
import 'package:guardian/core/widgets/custom_button.dart';

class OrderDetailsScreen extends StatefulWidget {
  final Order order;

  const OrderDetailsScreen({
    super.key,
    required this.order,
  });

  @override
  State<OrderDetailsScreen> createState() => _OrderDetailsScreenState();
}

class _OrderDetailsScreenState extends State<OrderDetailsScreen> {
  bool _isCancelling = false;

  Future<void> _cancelOrder() async {
    // Show confirmation dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Order'),
        content: const Text(
          'Are you sure you want to cancel this order? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Yes'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() {
      _isCancelling = true;
    });

    try {
      // TODO: Implement cancel order functionality
      await Future.delayed(
          const Duration(seconds: 1)); // Simulate network delay

      setState(() {
        _isCancelling = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Order cancelled successfully'),
            backgroundColor: AppColors.success,
          ),
        );

        Navigator.pop(context, true);
      }
    } catch (e) {
      Logger.error('Failed to cancel order', e);

      setState(() {
        _isCancelling = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to cancel order: ${e.toString()}'),
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
        title: 'Order Details',
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Order ID and date
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _buildInfoRow('Order ID', widget.order.id),
                    const SizedBox(height: 8),
                    _buildInfoRow(
                      'Date',
                      _formatDate(widget.order.createdAt),
                    ),
                    const SizedBox(height: 8),
                    _buildInfoRow(
                      'Status',
                      _getStatusText(widget.order.status),
                      _getStatusColor(widget.order.status),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Shipping address
            Card(
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
                      'Shipping Address',
                      style: AppTypography.bodyLarge.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(widget.order.shippingAddress),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Payment information
            Card(
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
                      'Payment Information',
                      style: AppTypography.bodyLarge.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildInfoRow(
                      'Payment Method',
                      widget.order.paymentMethod,
                    ),
                    const SizedBox(height: 8),
                    _buildInfoRow(
                      'Total Amount',
                      '₹${widget.order.total.toStringAsFixed(2)}',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Order items
            Card(
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
                      'Order Items',
                      style: AppTypography.bodyLarge.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: widget.order.items.length,
                      itemBuilder: (context, index) {
                        final item = widget.order.items[index];

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Product image
                              Container(
                                width: 60,
                                height: 60,
                                decoration: BoxDecoration(
                                  color: Colors.grey[200],
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: item['imageUrl'] != null
                                    ? Image.network(
                                        item['imageUrl'],
                                        fit: BoxFit.cover,
                                        errorBuilder:
                                            (context, error, stackTrace) {
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
                              const SizedBox(width: 12),

                              // Product details
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item['name'],
                                      style: AppTypography.bodyMedium.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    if (item['color'] != null) ...[
                                      Text(
                                        'Color: ${item['color']}',
                                        style: AppTypography.caption.copyWith(
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                    ],
                                    Text(
                                      'Quantity: ${item['quantity']}',
                                      style: AppTypography.caption.copyWith(
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // Price
                              Text(
                                '₹${(item['price'] * item['quantity']).toStringAsFixed(2)}',
                                style: AppTypography.bodyMedium.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),

                    const Divider(),

                    // Order summary
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Subtotal'),
                        Text(
                          '₹${widget.order.total.toStringAsFixed(2)}',
                          style: AppTypography.bodyMedium,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Shipping'),
                        Text(
                          'Free',
                          style: AppTypography.bodyMedium.copyWith(
                            color: AppColors.success,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Tax'),
                        Text(
                          '₹${(widget.order.total * 0.18).toStringAsFixed(2)}',
                          style: AppTypography.bodyMedium,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Total',
                          style: AppTypography.bodyLarge.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '₹${(widget.order.total + widget.order.total * 0.18).toStringAsFixed(2)}',
                          style: AppTypography.bodyLarge.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Cancel button (only for pending or confirmed orders)
            if (widget.order.status == 'pending' ||
                widget.order.status == 'confirmed')
              SizedBox(
                width: double.infinity,
                child: CustomButton(
                  text: 'Cancel Order',
                  onPressed: _cancelOrder,
                  isLoading: _isCancelling,
                  type: ButtonType.secondary,
                ),
              ),
          ],
        ),
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
