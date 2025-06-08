/*
 * Guardian - Women's Safety App
 * © 2025 All Rights Reserved - Kunal Singh
 * Contact: kunalsingh2514@gmail.com
 */

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:guardian/core/constants/app_colors.dart';
import 'package:guardian/core/constants/app_typography.dart';
import 'package:guardian/core/di/service_locator.dart';
import 'package:guardian/core/utils/logger.dart';
import 'package:guardian/core/widgets/custom_app_bar.dart';
import 'package:guardian/core/widgets/custom_button.dart';
import 'package:guardian/features/ngo_integration/data/models/ngo_model.dart';
import 'package:guardian/features/ngo_integration/data/ngo_repository.dart';
import 'package:guardian/features/ngo_integration/presentation/screens/donation_confirmation_screen.dart';

class DonateScreen extends StatefulWidget {
  final NGO ngo;

  const DonateScreen({
    super.key,
    required this.ngo,
  });

  @override
  State<DonateScreen> createState() => _DonateScreenState();
}

class _DonateScreenState extends State<DonateScreen> {
  final NGORepository _repository = sl<NGORepository>();
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _messageController = TextEditingController();

  String _selectedCurrency = 'INR';
  String _selectedPaymentMethod = 'Credit Card';
  bool _isLoading = false;

  final List<String> _currencies = ['INR', 'USD', 'EUR', 'GBP'];
  final List<String> _paymentMethods = [
    'Credit Card',
    'Debit Card',
    'UPI',
    'Net Banking',
    'PayPal',
  ];

  final List<double> _suggestedAmounts = [100, 500, 1000, 5000];

  @override
  void dispose() {
    _amountController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  void _selectAmount(double amount) {
    setState(() {
      _amountController.text = amount.toString();
    });
  }

  Future<void> _makeDonation() async {
    if (_formKey.currentState?.validate() != true) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final amount = double.parse(_amountController.text);

      // Make donation
      final donationId = await _repository.makeDonation(
        ngoId: widget.ngo.id,
        amount: amount,
        currency: _selectedCurrency,
        paymentMethod: _selectedPaymentMethod,
        message:
            _messageController.text.isNotEmpty ? _messageController.text : null,
      );

      if (donationId == null) {
        throw Exception('Failed to make donation');
      }

      if (mounted) {
        // Navigate to confirmation screen
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => DonationConfirmationScreen(
              ngo: widget.ngo,
              amount: amount,
              currency: _selectedCurrency,
              donationId: donationId,
            ),
          ),
        );
      }
    } catch (e) {
      Logger.error('Failed to make donation', e);

      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to make donation: ${e.toString()}'),
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
        title: 'Make a Donation',
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // NGO Info
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 5,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.all(8),
                        child: Image.network(
                          widget.ngo.logoUrl,
                          errorBuilder: (context, error, stackTrace) {
                            return const Icon(
                              Icons.business,
                              size: 32,
                              color: AppColors.primary,
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.ngo.name,
                              style: AppTypography.heading4.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Your donation will support their mission',
                              style: AppTypography.caption.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Donation Amount
              Text(
                'Donation Amount',
                style: AppTypography.heading4.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  // Currency Dropdown
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedCurrency,
                        items: _currencies.map((currency) {
                          return DropdownMenuItem<String>(
                            value: currency,
                            child: Text(currency),
                          );
                        }).toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              _selectedCurrency = value;
                            });
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Amount Input
                  Expanded(
                    child: TextFormField(
                      controller: _amountController,
                      decoration: const InputDecoration(
                        labelText: 'Amount',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                            RegExp(r'^\d+\.?\d{0,2}')),
                      ],
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter an amount';
                        }

                        final amount = double.tryParse(value);
                        if (amount == null || amount <= 0) {
                          return 'Please enter a valid amount';
                        }

                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Suggested Amounts
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _suggestedAmounts.map((amount) {
                  return ElevatedButton(
                    onPressed: () => _selectAmount(amount),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary.withOpacity(0.1),
                      foregroundColor: AppColors.primary,
                      elevation: 0,
                    ),
                    child: Text('$_selectedCurrency $amount'),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),

              // Payment Method
              Text(
                'Payment Method',
                style: AppTypography.heading4.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedPaymentMethod,
                decoration: const InputDecoration(
                  labelText: 'Select Payment Method',
                  border: OutlineInputBorder(),
                ),
                items: _paymentMethods.map((method) {
                  return DropdownMenuItem<String>(
                    value: method,
                    child: Text(method),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _selectedPaymentMethod = value;
                    });
                  }
                },
              ),
              const SizedBox(height: 24),

              // Message
              Text(
                'Message (Optional)',
                style: AppTypography.heading4.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _messageController,
                decoration: const InputDecoration(
                  labelText: 'Message',
                  hintText: 'Add a message to the organization...',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 24),

              // Donate Button
              CustomButton(
                text: 'Make Donation',
                onPressed: _makeDonation,
                isLoading: _isLoading,
                type: ButtonType.primary,
                isFullWidth: true,
              ),
              const SizedBox(height: 16),

              // Disclaimer
              Text(
                'Your donation will directly support the organization\'s mission. All donations are processed securely.',
                style: AppTypography.caption.copyWith(
                  color: AppColors.textSecondary,
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
