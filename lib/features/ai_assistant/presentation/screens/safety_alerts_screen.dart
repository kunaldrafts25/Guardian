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
import 'package:guardian/features/ai_assistant/data/ai_repository.dart';
import 'package:guardian/features/ai_assistant/data/models/ai_model.dart';
import 'package:guardian/features/ai_assistant/presentation/widgets/alert_card.dart';
import 'package:guardian/features/map/presentation/screens/map_screen_mock.dart';
import 'package:intl/intl.dart';

class SafetyAlertsScreen extends StatefulWidget {
  const SafetyAlertsScreen({super.key});

  @override
  State<SafetyAlertsScreen> createState() => _SafetyAlertsScreenState();
}

class _SafetyAlertsScreenState extends State<SafetyAlertsScreen> {
  final AIRepository _repository = sl<AIRepository>();

  List<SafetyAlert> _alerts = [];
  bool _isLoading = true;
  String _selectedFilter = 'All';

  final List<String> _filters = [
    'All',
    'Unread',
    'High Risk',
    'Medium Risk',
    'Low Risk',
  ];

  @override
  void initState() {
    super.initState();
    _loadAlerts();
  }

  Future<void> _loadAlerts() async {
    try {
      setState(() {
        _isLoading = true;
      });

      final alerts = await _repository.getSafetyAlerts();

      setState(() {
        _alerts = alerts;
        _isLoading = false;
      });
    } catch (e) {
      Logger.error('Failed to load safety alerts', e);

      setState(() {
        _isLoading = false;
      });
    }
  }

  List<SafetyAlert> _getFilteredAlerts() {
    if (_selectedFilter == 'All') {
      return _alerts.where((alert) => !alert.isDismissed).toList();
    } else if (_selectedFilter == 'Unread') {
      return _alerts
          .where((alert) => !alert.isRead && !alert.isDismissed)
          .toList();
    } else {
      // Filter by risk level
      final riskLevel = _getRiskLevelFromFilter(_selectedFilter);
      return _alerts
          .where((alert) => alert.riskLevel == riskLevel && !alert.isDismissed)
          .toList();
    }
  }

  RiskLevel _getRiskLevelFromFilter(String filter) {
    switch (filter) {
      case 'High Risk':
        return RiskLevel.high;
      case 'Medium Risk':
        return RiskLevel.medium;
      case 'Low Risk':
        return RiskLevel.low;
      default:
        return RiskLevel.low;
    }
  }

  Future<void> _viewAlert(SafetyAlert alert) async {
    try {
      // Mark alert as read
      if (!alert.isRead) {
        await _repository.markAlertAsRead(alert.id);

        // Update local state
        setState(() {
          final index = _alerts.indexWhere((a) => a.id == alert.id);
          if (index >= 0) {
            _alerts[index] = alert.copyWith(isRead: true);
          }
        });
      }

      // Show alert details
      if (mounted) {
        _showAlertDetails(alert);
      }
    } catch (e) {
      Logger.error('Failed to view alert', e);
    }
  }

  Future<void> _dismissAlert(SafetyAlert alert) async {
    try {
      final success = await _repository.dismissAlert(alert.id);

      if (success) {
        // Update local state
        setState(() {
          final index = _alerts.indexWhere((a) => a.id == alert.id);
          if (index >= 0) {
            _alerts[index] = alert.copyWith(isDismissed: true);
          }
        });
      }
    } catch (e) {
      Logger.error('Failed to dismiss alert', e);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to dismiss alert: ${e.toString()}'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  void _showAlertDetails(SafetyAlert alert) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        expand: false,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _buildRiskLevelIcon(alert.riskLevel),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        alert.title,
                        style: AppTypography.heading3.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Generated on ${DateFormat('MMM dd, yyyy').format(alert.createdAt)}',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 16),
                Text(
                  alert.content,
                  style: AppTypography.bodyLarge,
                ),
                const SizedBox(height: 24),

                // Location context
                if (alert.locationContext != null &&
                    alert.locationContext!.containsKey('address') &&
                    alert.locationContext!['address'] != null) ...[
                  Text(
                    'Location',
                    style: AppTypography.bodyLarge.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    alert.locationContext!['address'] as String,
                    style: AppTypography.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 16),
                ],

                // Action button
                if (alert.actionText != null) ...[
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _handleAlertAction(alert),
                      icon: const Icon(Icons.directions),
                      label: Text(alert.actionText!),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Dismiss button
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _dismissAlert(alert);
                    },
                    icon: const Icon(Icons.close),
                    label: const Text('Dismiss Alert'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                      side: const BorderSide(color: AppColors.textSecondary),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Disclaimer
                Text(
                  'This alert is generated by AI based on community safety data and may not reflect current conditions. Always use your best judgment.',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textSecondary,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _handleAlertAction(SafetyAlert alert) {
    if (alert.actionData == null) return;

    final action = alert.actionData!['action'] as String?;

    if (action == 'view_safe_routes' &&
        alert.actionData!.containsKey('latitude') &&
        alert.actionData!.containsKey('longitude')) {
      // Close bottom sheet
      Navigator.pop(context);

      // Navigate to map
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const MapScreen(),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: 'Safety Alerts',
      ),
      body: Column(
        children: [
          // Filters
          SizedBox(
            height: 50,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _filters.length,
              itemBuilder: (context, index) {
                final filter = _filters[index];
                final isSelected = filter == _selectedFilter;

                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(filter),
                    selected: isSelected,
                    selectedColor: AppColors.primary.withOpacity(0.2),
                    labelStyle: AppTypography.bodyMedium.copyWith(
                      color: isSelected
                          ? AppColors.primary
                          : AppColors.textPrimary,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                    onSelected: (selected) {
                      if (selected) {
                        setState(() {
                          _selectedFilter = filter;
                        });
                      }
                    },
                  ),
                );
              },
            ),
          ),

          // Alerts list
          Expanded(
            child: _isLoading
                ? const Center(child: LoadingIndicator())
                : _buildAlertsList(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _generateNewAlert();
        },
        backgroundColor: AppColors.primary,
        tooltip: 'Generate new alert',
        child: const Icon(Icons.refresh),
      ),
    );
  }

  Widget _buildAlertsList() {
    final filteredAlerts = _getFilteredAlerts();

    if (filteredAlerts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.notifications_none,
              size: 64,
              color: AppColors.textSecondary,
            ),
            const SizedBox(height: 16),
            Text(
              'No alerts found',
              style: AppTypography.heading4.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _selectedFilter == 'All'
                  ? 'You don\'t have any active safety alerts'
                  : 'No $_selectedFilter alerts available',
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadAlerts,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: filteredAlerts.length,
        itemBuilder: (context, index) {
          final alert = filteredAlerts[index];

          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: AlertCard(
              alert: alert,
              onTap: () => _viewAlert(alert),
              onDismiss: () => _dismissAlert(alert),
            ),
          );
        },
      ),
    );
  }

  Future<void> _generateNewAlert() async {
    // Generate a new predictive alert
    final alert = await _repository.generatePredictiveAlert();

    if (alert != null && mounted) {
      setState(() {
        _alerts.add(alert);
      });

      // Use a separate method to show the snackbar to avoid BuildContext issues
      _showSnackBar('New safety alert generated');
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.info,
      ),
    );
  }

  Widget _buildRiskLevelIcon(RiskLevel riskLevel) {
    Color color;
    IconData icon;

    switch (riskLevel) {
      case RiskLevel.high:
        color = Colors.red;
        icon = Icons.warning_amber_rounded;
        break;
      case RiskLevel.medium:
        color = Colors.orange;
        icon = Icons.warning_outlined;
        break;
      case RiskLevel.low:
      default:
        color = Colors.blue;
        icon = Icons.info_outline;
        break;
    }

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(
        icon,
        color: color,
        size: 24,
      ),
    );
  }
}
