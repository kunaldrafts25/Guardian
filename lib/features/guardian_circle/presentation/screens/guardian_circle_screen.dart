/*
 * Guardian - Women's Safety App
 * © 2025 All Rights Reserved - Kunal Singh
 * Contact: kunalsingh2514@gmail.com
 */

import 'package:flutter/material.dart';
import 'package:guardian/core/constants/app_colors.dart';
import 'package:guardian/core/constants/app_typography.dart';
import 'package:guardian/core/utils/logger.dart';
import 'package:guardian/core/widgets/custom_app_bar.dart';
import 'package:guardian/core/widgets/loading_indicator.dart';
import 'package:guardian/features/guardian_circle/data/guardian_circle_repository.dart';
import 'package:guardian/features/guardian_circle/data/models/guardian_circle_model.dart';
import 'package:guardian/features/guardian_circle/presentation/screens/add_circle_screen.dart';
import 'package:guardian/features/guardian_circle/presentation/screens/circle_details_screen.dart';
import 'package:guardian/features/guardian_circle/presentation/widgets/circle_card.dart';
import 'package:guardian/features/guardian_circle/presentation/widgets/emergency_alert_button.dart';

class GuardianCircleScreen extends StatefulWidget {
  const GuardianCircleScreen({super.key});

  @override
  State<GuardianCircleScreen> createState() => _GuardianCircleScreenState();
}

class _GuardianCircleScreenState extends State<GuardianCircleScreen> {
  final GuardianCircleRepository _repository = GuardianCircleRepository();

  List<GuardianCircle> _circles = [];
  bool _isLoading = true;
  bool _hasError = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadCircles();
  }

  Future<void> _loadCircles() async {
    try {
      setState(() {
        _isLoading = true;
        _hasError = false;
        _errorMessage = null;
      });

      final circles = await _repository.getGuardianCircles();

      setState(() {
        _circles = circles;
        _isLoading = false;
      });
    } catch (e) {
      Logger.error('Failed to load guardian circles', e);

      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = 'Failed to load guardian circles. Please try again.';
      });
    }
  }

  Future<void> _createDefaultCircle() async {
    try {
      setState(() {
        _isLoading = true;
      });

      final circleId = await _repository.createGuardianCircle(
        name: 'My Guardian Circle',
        description: 'Default guardian circle',
        isDefault: true,
      );

      if (circleId == null) {
        throw Exception('Failed to create default circle');
      }

      await _loadCircles();
    } catch (e) {
      Logger.error('Failed to create default circle', e);

      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = 'Failed to create default circle. Please try again.';
      });
    }
  }

  Future<void> _navigateToAddCircle() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => const AddCircleScreen(),
      ),
    );

    if (result == true) {
      await _loadCircles();
    }
  }

  Future<void> _navigateToCircleDetails(GuardianCircle circle) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => CircleDetailsScreen(circle: circle),
      ),
    );

    if (result == true) {
      await _loadCircles();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: 'Guardian Circles',
      ),
      body: _isLoading
          ? const Center(child: LoadingIndicator())
          : _buildContent(),
      floatingActionButton: FloatingActionButton(
        onPressed: _navigateToAddCircle,
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildContent() {
    if (_hasError) {
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
              _errorMessage ?? 'An error occurred',
              style: AppTypography.bodyLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loadCircles,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_circles.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.people_outline,
              size: 64,
              color: AppColors.primary,
            ),
            const SizedBox(height: 16),
            Text(
              'No Guardian Circles',
              style: AppTypography.heading3,
            ),
            const SizedBox(height: 8),
            Text(
              'Create a circle to add trusted contacts who can help you in emergencies',
              style: AppTypography.bodyLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _createDefaultCircle,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
              child: const Text('Create Default Circle'),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Emergency Alert Button
        Padding(
          padding: const EdgeInsets.all(16),
          child: EmergencyAlertButton(
            circles: _circles,
            onAlertSent: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content:
                      Text('Emergency alert sent to your guardian circles'),
                  backgroundColor: AppColors.success,
                ),
              );
            },
          ),
        ),

        // Circles List
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _circles.length,
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: CircleCard(
                  circle: _circles[index],
                  onTap: () => _navigateToCircleDetails(_circles[index]),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

