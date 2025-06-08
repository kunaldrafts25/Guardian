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
import 'package:guardian/features/ngo_integration/data/models/ngo_model.dart';
import 'package:guardian/features/ngo_integration/data/ngo_repository.dart';
import 'package:guardian/features/ngo_integration/presentation/screens/booking_confirmation_screen.dart';
import 'package:intl/intl.dart';

class BookServiceScreen extends StatefulWidget {
  final NGO ngo;
  final NGOService service;

  const BookServiceScreen({
    super.key,
    required this.ngo,
    required this.service,
  });

  @override
  State<BookServiceScreen> createState() => _BookServiceScreenState();
}

class _BookServiceScreenState extends State<BookServiceScreen> {
  final NGORepository _repository = sl<NGORepository>();
  final _formKey = GlobalKey<FormState>();
  final _notesController = TextEditingController();

  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _selectedTime = const TimeOfDay(hour: 10, minute: 0);
  bool _isLoading = false;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 90)),
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );

    if (picked != null && picked != _selectedTime) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  Future<void> _bookService() async {
    if (_formKey.currentState?.validate() != true) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Combine date and time
      final appointmentDate = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _selectedTime.hour,
        _selectedTime.minute,
      );

      // Book service
      final bookingId = await _repository.bookService(
        serviceId: widget.service.id,
        ngoId: widget.ngo.id,
        appointmentDate: appointmentDate,
        notes: _notesController.text.isNotEmpty ? _notesController.text : null,
      );

      if (bookingId == null) {
        throw Exception('Failed to book service');
      }

      if (mounted) {
        // Navigate to confirmation screen
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => BookingConfirmationScreen(
              ngo: widget.ngo,
              service: widget.service,
              appointmentDate: appointmentDate,
              bookingId: bookingId,
            ),
          ),
        );
      }
    } catch (e) {
      Logger.error('Failed to book service', e);

      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to book service: ${e.toString()}'),
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
        title: 'Book Service',
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Service Details
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
                        'Service Details',
                        style: AppTypography.heading4.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildInfoRow('Organization', widget.ngo.name),
                      const SizedBox(height: 8),
                      _buildInfoRow('Service', widget.service.name),
                      const SizedBox(height: 8),
                      _buildInfoRow(
                        'Cost',
                        widget.service.isFree
                            ? 'Free'
                            : '${widget.service.cost} ${widget.service.currency}',
                      ),
                      const SizedBox(height: 8),
                      _buildInfoRow(
                        'Availability',
                        widget.service.isAvailable24x7
                            ? 'Available 24/7'
                            : widget.service.availabilityHours ??
                                'Contact for hours',
                      ),
                      const SizedBox(height: 8),
                      _buildInfoRow(
                        'Mode',
                        _getServiceMode(),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Appointment Date & Time
              Text(
                'Select Appointment Date & Time',
                style: AppTypography.heading4.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => _selectDate(context),
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Date',
                          border: OutlineInputBorder(),
                          suffixIcon: Icon(Icons.calendar_today),
                        ),
                        child: Text(
                          DateFormat('MMM dd, yyyy').format(_selectedDate),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: InkWell(
                      onTap: () => _selectTime(context),
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Time',
                          border: OutlineInputBorder(),
                          suffixIcon: Icon(Icons.access_time),
                        ),
                        child: Text(
                          _selectedTime.format(context),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Notes
              Text(
                'Additional Notes (Optional)',
                style: AppTypography.heading4.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _notesController,
                decoration: const InputDecoration(
                  labelText: 'Notes',
                  hintText: 'Any specific requirements or questions...',
                  border: OutlineInputBorder(),
                ),
                maxLines: 4,
              ),
              const SizedBox(height: 24),

              // Terms & Conditions
              if (widget.service.requiresAppointment)
                Text(
                  'Note: This service requires an appointment. The organization will confirm your booking.',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textSecondary,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              const SizedBox(height: 24),

              // Book Button
              CustomButton(
                text: 'Book Service',
                onPressed: _bookService,
                isLoading: _isLoading,
                type: ButtonType.primary,
                isFullWidth: true,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: AppTypography.bodyMedium.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  String _getServiceMode() {
    if (widget.service.isOnline && widget.service.isInPerson) {
      return 'Online & In-Person';
    } else if (widget.service.isOnline) {
      return 'Online';
    } else if (widget.service.isInPerson) {
      return 'In-Person';
    } else {
      return 'Contact for details';
    }
  }
}
