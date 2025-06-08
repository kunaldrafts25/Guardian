/*
 * Guardian - Women's Safety App
 * © 2025 All Rights Reserved - Kunal Singh
 * Contact: kunalsingh2514@gmail.com
 */

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:guardian/core/constants/app_colors.dart';
import 'package:guardian/core/constants/app_strings.dart';
import 'package:guardian/core/constants/app_typography.dart';
import 'package:guardian/core/di/service_locator.dart';
import 'package:guardian/core/services/ai_service.dart';
import 'package:guardian/core/services/safety_notification_manager.dart';
import 'package:guardian/core/widgets/emergency_button.dart';
import 'package:guardian/core/widgets/safety_alert.dart';
import 'package:guardian/features/community/presentation/screens/community_screen.dart';
import 'package:guardian/features/dashboard/presentation/widgets/dashboard_card.dart';
import 'package:guardian/features/dashboard/presentation/widgets/quick_access_row.dart';
import 'package:guardian/features/dashboard/presentation/widgets/safety_status_card.dart';
import 'package:guardian/features/guardian_mode/presentation/screens/guardian_mode_screen.dart';
import 'package:guardian/features/guardian_circle/presentation/screens/guardian_circle_screen.dart';
import 'package:guardian/features/incident_reporting/presentation/screens/report_incident_screen.dart';
import 'package:guardian/features/safe_zones/presentation/screens/safe_zones_screen.dart';
import 'package:guardian/features/store/presentation/screens/store_screen.dart';
import 'package:guardian/features/ai_assistant/presentation/screens/ai_chat_screen.dart';
import 'package:guardian/features/ai_assistant/presentation/screens/safety_advice_screen.dart';
import 'package:guardian/features/ai_assistant/presentation/screens/safety_alerts_screen.dart';
import 'package:guardian/features/voice_commands/presentation/screens/voice_commands_screen.dart';
import 'package:guardian/features/ngo_integration/presentation/screens/ngo_list_screen.dart';
import 'package:guardian/features/map/presentation/screens/map_screen_mock.dart';
import 'package:guardian/features/safety_tips/data/safety_tip_model.dart';
import 'package:guardian/features/safety_tips/presentation/screens/safety_tips_list_screen.dart';
import 'package:guardian/features/safety_tips/presentation/widgets/safety_tips_carousel.dart';
import 'package:guardian/features/settings/presentation/screens/settings_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _currentIndex = 0;
  final List<Widget> _screens = [
    const _DashboardHomeScreen(),
    const MapScreen(),
    const CommunityScreen(),
    const StoreScreen(),
    const SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textSecondary,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.map),
            label: 'Map',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people),
            label: 'Community',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.shopping_bag),
            label: 'Store',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}

class _DashboardHomeScreen extends StatefulWidget {
  const _DashboardHomeScreen();

  @override
  State<_DashboardHomeScreen> createState() => _DashboardHomeScreenState();
}

class _DashboardHomeScreenState extends State<_DashboardHomeScreen> {
  bool _safetyModeEnabled = false;
  final SafetyNotificationManager _safetyManager =
      sl<SafetyNotificationManager>();
  StreamSubscription<Map<String, dynamic>>? _safetyAlertSubscription;
  Map<String, dynamic>? _currentSafetyAlert;
  bool _showSafetyAlert = false;

  @override
  void initState() {
    super.initState();
    _initializeSafetyManager();
  }

  @override
  void dispose() {
    _safetyAlertSubscription?.cancel();
    super.dispose();
  }

  Future<void> _initializeSafetyManager() async {
    await _safetyManager.initialize();

    // Listen for safety alerts
    _safetyAlertSubscription =
        _safetyManager.safetyAlertStream.listen((alertData) {
      setState(() {
        _currentSafetyAlert = alertData;
        _showSafetyAlert = true;
      });
    });

    // Trigger initial risk assessment
    await _safetyManager.triggerRiskAssessment();
  }

  void _dismissSafetyAlert() {
    setState(() {
      _showSafetyAlert = false;
    });
  }

  void _handleSafetyAlertAction() {
    if (_currentSafetyAlert != null) {
      final riskLevel = _currentSafetyAlert!['risk_level'] as RiskLevel;

      if (riskLevel == RiskLevel.high) {
        // For high risk, navigate to Guardian Mode
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const GuardianModeScreen(),
          ),
        );
      } else {
        // For medium risk, navigate to Map
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const MapScreen(),
          ),
        );
      }
    }

    _dismissSafetyAlert();
  }

  Widget _buildSafetyAlert() {
    if (_currentSafetyAlert == null) {
      return const SizedBox.shrink();
    }

    final alertType = _currentSafetyAlert!['type'] as String;
    final riskLevel = _currentSafetyAlert!['risk_level'] as RiskLevel;
    String message = '';
    String? actionText;

    if (alertType == 'suggestion') {
      message = _currentSafetyAlert!['suggestion'] as String;

      if (riskLevel == RiskLevel.high) {
        actionText = 'Enable Guardian Mode';
      } else if (riskLevel == RiskLevel.medium) {
        actionText = 'View Map';
      }
    } else {
      // Default message based on risk level
      switch (riskLevel) {
        case RiskLevel.low:
          message = 'You\'re in a safe area.';
          break;
        case RiskLevel.medium:
          message = 'Be cautious in this area.';
          actionText = 'View Map';
          break;
        case RiskLevel.high:
          message = 'This area has reported incidents. Stay alert.';
          actionText = 'Enable Guardian Mode';
          break;
      }
    }

    return SafetyAlert(
      riskLevel: riskLevel,
      message: message,
      onDismiss: _dismissSafetyAlert,
      onAction: actionText != null ? _handleSafetyAlertAction : null,
      actionText: actionText,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.dashboard),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications),
            onPressed: () {
              // TODO: Navigate to notifications screen
            },
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Safety Status Card
              SafetyStatusCard(
                isSafetyModeEnabled: _safetyModeEnabled,
                onToggleSafetyMode: (value) {
                  setState(() {
                    _safetyModeEnabled = value;
                  });
                },
              ),
              const SizedBox(height: 16),

              // Safety Alert
              if (_showSafetyAlert && _currentSafetyAlert != null) ...[
                _buildSafetyAlert(),
                const SizedBox(height: 16),
              ],
              const SizedBox(height: 8),

              // Emergency Button
              Center(
                child: Column(
                  children: [
                    Text(
                      'Emergency SOS',
                      style: AppTypography.heading3,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Long press the button below in case of emergency',
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const EmergencyButton(size: 100),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Quick Access FABs
              const QuickAccessRow(),
              const SizedBox(height: 24),

              // Safety Tools
              Text(
                'Safety Tools',
                style: AppTypography.heading3,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: DashboardCard(
                      icon: Icons.timer,
                      title: 'Panic Timer',
                      color: AppColors.warning,
                      onTap: () {
                        // TODO: Show panic timer dialog
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: DashboardCard(
                      icon: Icons.safety_check,
                      title: 'Safety Check',
                      color: AppColors.success,
                      onTap: () {
                        // TODO: Show safety check dialog
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: DashboardCard(
                      icon: Icons.contact_phone,
                      title: 'Emergency Contacts',
                      color: AppColors.info,
                      onTap: () {
                        // TODO: Navigate to emergency contacts screen
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: DashboardCard(
                      icon: Icons.history,
                      title: 'Alert History',
                      color: AppColors.primary,
                      onTap: () {
                        // TODO: Navigate to alert history screen
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: DashboardCard(
                      icon: Icons.visibility,
                      title: 'Live Guardian Mode',
                      color: AppColors.accent,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const GuardianModeScreen(),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: DashboardCard(
                      icon: Icons.report_problem,
                      title: 'Report Incident',
                      color: AppColors.warning,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const ReportIncidentScreen(),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: DashboardCard(
                      icon: Icons.people,
                      title: 'Guardian Circle',
                      color: AppColors.info,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const GuardianCircleScreen(),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: DashboardCard(
                      icon: Icons.location_on,
                      title: 'Safe Zones',
                      color: AppColors.success,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const SafeZonesScreen(),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Store & NGOs
              Text(
                'Resources',
                style: AppTypography.heading3,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: DashboardCard(
                      icon: Icons.shopping_bag,
                      title: 'Safety Store',
                      color: AppColors.secondary,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const StoreScreen(),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: DashboardCard(
                      icon: Icons.volunteer_activism,
                      title: 'Safety Organizations',
                      color: AppColors.info,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const NGOListScreen(),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // AI Assistant
              Text(
                'AI Safety Assistant',
                style: AppTypography.heading3,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: DashboardCard(
                      icon: Icons.chat,
                      title: 'AI Assistant',
                      color: AppColors.accent,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const AIChatScreen(),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: DashboardCard(
                      icon: Icons.tips_and_updates,
                      title: 'Safety Advice',
                      color: AppColors.info,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const SafetyAdviceScreen(),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: DashboardCard(
                      icon: Icons.notifications,
                      title: 'Safety Alerts',
                      color: AppColors.warning,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const SafetyAlertsScreen(),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: DashboardCard(
                      icon: Icons.mic,
                      title: 'Voice Commands',
                      color: AppColors.secondary,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const VoiceCommandsScreen(),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Device Status
              Text(
                'Device Status',
                style: AppTypography.heading3,
              ),
              const SizedBox(height: 16),
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.bluetooth,
                            color: AppColors.secondary,
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'Safety Device',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.danger.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'Not Connected',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.danger,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          // TODO: Navigate to device connection screen
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.secondary,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Connect Device'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Safety Tips Carousel
              SafetyTipsCarousel(
                tips: sampleSafetyTips.take(5).toList(),
                onSeeAllTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SafetyTipsListScreen(),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
