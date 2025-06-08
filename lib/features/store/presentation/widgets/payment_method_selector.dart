/*
 * Guardian - Women's Safety App
 * © 2025 All Rights Reserved - Kunal Singh
 * Contact: kunalsingh2514@gmail.com
 */

import 'package:flutter/material.dart';
import 'package:guardian/core/constants/app_colors.dart';
import 'package:guardian/core/constants/app_typography.dart';

/// A widget for selecting a payment method
class PaymentMethodSelector extends StatelessWidget {
  /// The currently selected payment method
  final String selectedMethod;

  /// Callback when a payment method is selected
  final Function(String) onMethodSelected;

  const PaymentMethodSelector({
    super.key,
    required this.selectedMethod,
    required this.onMethodSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildPaymentMethodTile(
          'Credit Card',
          Icons.credit_card,
          selectedMethod == 'Credit Card',
          onTap: () => onMethodSelected('Credit Card'),
        ),
        const SizedBox(height: 8),
        _buildPaymentMethodTile(
          'Debit Card',
          Icons.credit_card,
          selectedMethod == 'Debit Card',
          onTap: () => onMethodSelected('Debit Card'),
        ),
        const SizedBox(height: 8),
        _buildPaymentMethodTile(
          'UPI',
          Icons.account_balance,
          selectedMethod == 'UPI',
          onTap: () => onMethodSelected('UPI'),
        ),
        const SizedBox(height: 8),
        _buildPaymentMethodTile(
          'Cash on Delivery',
          Icons.money,
          selectedMethod == 'Cash on Delivery',
          onTap: () => onMethodSelected('Cash on Delivery'),
        ),
      ],
    );
  }

  Widget _buildPaymentMethodTile(
    String title,
    IconData icon,
    bool isSelected, {
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
          color: isSelected ? AppColors.primary.withOpacity(0.05) : null,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? AppColors.primary : Colors.grey[600],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: AppTypography.bodyLarge.copyWith(
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? AppColors.primary : AppColors.textPrimary,
                ),
              ),
            ),
            if (isSelected)
              const Icon(
                Icons.check_circle,
                color: AppColors.primary,
              ),
          ],
        ),
      ),
    );
  }
}
