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
import 'package:guardian/features/guardian_circle/data/guardian_circle_repository.dart';
import 'package:guardian/features/guardian_circle/data/models/guardian_circle_model.dart';

/// A button widget for sending emergency alerts to guardian circles
class EmergencyAlertButton extends StatefulWidget {
  /// The available guardian circles
  final List<GuardianCircle> circles;

  /// Callback when an alert is sent
  final VoidCallback? onAlertSent;

  const EmergencyAlertButton({
    super.key,
    required this.circles,
    this.onAlertSent,
  });

  @override
  State<EmergencyAlertButton> createState() => _EmergencyAlertButtonState();
}

class _EmergencyAlertButtonState extends State<EmergencyAlertButton> {
  final GuardianCircleRepository _repository = sl<GuardianCircleRepository>();

  bool _isLoading = false;

  Future<void> _showAlertDialog() async {
    if (!mounted) return;

    if (widget.circles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You need to create a guardian circle first'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    if (!mounted) return;

    final selectedCircles = await showDialog<List<GuardianCircle>>(
      context: context,
      builder: (dialogContext) => AlertSelectionDialog(
        circles: widget.circles,
      ),
    );

    if (!mounted || selectedCircles == null || selectedCircles.isEmpty) {
      return;
    }

    final alertDetails = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => const AlertDetailsDialog(),
    );

    if (alertDetails == null) {
      return;
    }

    final emergencyType = alertDetails['type'] as String;
    final message = alertDetails['message'] as String?;

    await _sendAlert(
      selectedCircles,
      emergencyType,
      message,
    );
  }

  Future<void> _sendAlert(
    List<GuardianCircle> circles,
    String emergencyType,
    String? message,
  ) async {
    if (circles.isEmpty) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final circleIds = circles.map((c) => c.id).toList();

      final alertId = await _repository.sendEmergencyAlert(
        emergencyType: emergencyType,
        message: message,
        circleIds: circleIds,
      );

      if (alertId == null) {
        throw Exception('Failed to send alert');
      }

      if (widget.onAlertSent != null) {
        widget.onAlertSent!();
      }
    } catch (e) {
      Logger.error('Failed to send alert', e);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send alert: ${e.toString()}'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: _isLoading ? null : _showAlertDialog,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.danger,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(
          vertical: 16,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      child: _isLoading
          ? const SizedBox(
              height: 24,
              width: 24,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2,
              ),
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.warning_amber_rounded, size: 24),
                const SizedBox(width: 8),
                Text(
                  'Send Emergency Alert',
                  style: AppTypography.buttonMedium.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
    );
  }
}

/// A dialog for selecting guardian circles to alert
class AlertSelectionDialog extends StatefulWidget {
  /// The available guardian circles
  final List<GuardianCircle> circles;

  const AlertSelectionDialog({
    super.key,
    required this.circles,
  });

  @override
  State<AlertSelectionDialog> createState() => _AlertSelectionDialogState();
}

class _AlertSelectionDialogState extends State<AlertSelectionDialog> {
  final List<GuardianCircle> _selectedCircles = [];

  @override
  void initState() {
    super.initState();

    // Select default circle by default
    if (widget.circles.isNotEmpty) {
      final defaultCircle = widget.circles.firstWhere(
        (c) => c.isDefault,
        orElse: () => widget.circles.first,
      );

      _selectedCircles.add(defaultCircle);
    }
  }

  void _toggleCircleSelection(GuardianCircle circle) {
    setState(() {
      if (_selectedCircles.contains(circle)) {
        _selectedCircles.remove(circle);
      } else {
        _selectedCircles.add(circle);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Select Guardian Circles'),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: widget.circles.length,
          itemBuilder: (context, index) {
            final circle = widget.circles[index];
            final isSelected = _selectedCircles.contains(circle);

            return CheckboxListTile(
              title: Text(circle.name),
              subtitle: Text('${circle.members.length} members'),
              value: isSelected,
              onChanged: (_) => _toggleCircleSelection(circle),
              activeColor: AppColors.primary,
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _selectedCircles.isEmpty
              ? null
              : () => Navigator.pop(context, _selectedCircles),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
          ),
          child: const Text('Next'),
        ),
      ],
    );
  }
}

/// A dialog for entering emergency alert details
class AlertDetailsDialog extends StatefulWidget {
  const AlertDetailsDialog({super.key});

  @override
  State<AlertDetailsDialog> createState() => _AlertDetailsDialogState();
}

class _AlertDetailsDialogState extends State<AlertDetailsDialog> {
  final _messageController = TextEditingController();
  String _selectedType = 'Emergency';

  final List<String> _emergencyTypes = [
    'Emergency',
    'Medical',
    'Safety Concern',
    'Need Help',
    'Other',
  ];

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Emergency Alert Details'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Alert Type',
              style: AppTypography.bodyLarge.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _selectedType,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
              ),
              items: _emergencyTypes.map((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _selectedType = value;
                  });
                }
              },
            ),
            const SizedBox(height: 16),
            Text(
              'Message (Optional)',
              style: AppTypography.bodyLarge.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _messageController,
              decoration: const InputDecoration(
                hintText: 'Add details about your situation',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, {
            'type': _selectedType,
            'message': _messageController.text.isNotEmpty
                ? _messageController.text
                : null,
          }),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.danger,
            foregroundColor: Colors.white,
          ),
          child: const Text('Send Alert'),
        ),
      ],
    );
  }
}
