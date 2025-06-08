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
import 'package:guardian/core/widgets/loading_indicator.dart';
import 'package:guardian/features/ngo_integration/data/ngo_repository.dart';
import 'package:guardian/features/ngo_integration/presentation/widgets/booking_card.dart';

class MyBookingsScreen extends StatefulWidget {
  const MyBookingsScreen({super.key});

  @override
  State<MyBookingsScreen> createState() => _MyBookingsScreenState();
}

class _MyBookingsScreenState extends State<MyBookingsScreen> {
  final NGORepository _repository = sl<NGORepository>();

  List<Map<String, dynamic>> _bookings = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBookings();
  }

  Future<void> _loadBookings() async {
    try {
      setState(() {
        _isLoading = true;
      });

      final bookings = await _repository.getUserBookings();

      setState(() {
        _bookings = bookings;
        _isLoading = false;
      });
    } catch (e) {
      Logger.error('Failed to load bookings', e);

      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _cancelBooking(String bookingId) async {
    try {
      // Show confirmation dialog
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Cancel Booking'),
          content: const Text(
            'Are you sure you want to cancel this booking?',
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

      if (confirm != true) {
        return;
      }

      final success = await _repository.cancelBooking(bookingId);

      if (success) {
        await _loadBookings();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Booking cancelled successfully'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      } else {
        throw Exception('Failed to cancel booking');
      }
    } catch (e) {
      Logger.error('Failed to cancel booking', e);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to cancel booking: ${e.toString()}'),
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
        title: 'My Bookings',
      ),
      body: _isLoading
          ? const Center(child: LoadingIndicator())
          : _buildBookingsList(),
    );
  }

  Widget _buildBookingsList() {
    if (_bookings.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.calendar_today,
              size: 64,
              color: AppColors.textSecondary,
            ),
            const SizedBox(height: 16),
            Text(
              'No bookings found',
              style: AppTypography.heading4.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'You haven\'t booked any services yet',
              style: TextStyle(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadBookings,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _bookings.length,
        itemBuilder: (context, index) {
          final booking = _bookings[index];

          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: BookingCard(
              booking: booking,
              onCancel: () => _cancelBooking(booking['id']),
            ),
          );
        },
      ),
    );
  }
}
