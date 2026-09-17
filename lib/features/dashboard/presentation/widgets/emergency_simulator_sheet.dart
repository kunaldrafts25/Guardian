/*
 * Guardian - Women's Safety App
 * AWS Emergency Scenario Simulator Sheet
 */

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:guardian/core/constants/app_colors.dart';
import 'package:guardian/core/providers/aws_incident_provider.dart';
import 'package:guardian/features/dashboard/presentation/widgets/community_alert_dialog.dart';

class EmergencySimulatorSheet extends ConsumerWidget {
  const EmergencySimulatorSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final incidentState = ref.watch(awsIncidentProvider);
    final notifier = ref.read(awsIncidentProvider.notifier);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.psychology, color: AppColors.primary),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'AWS Agentic Simulator',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Simulate sensor telemetry to test Amazon Bedrock reasoning & automated escalation.',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 20),

          // Scenario 1: Fall Detection
          _buildScenarioTile(
            context: context,
            title: 'Simulate Sudden Fall',
            subtitle: 'Triggers 4.8G motion spike. Agent assesses HIGH risk and prompts 15s verification.',
            icon: Icons.personal_injury,
            color: Colors.deepOrange,
            isLoading: incidentState.isLoading,
            onTap: () async {
              Navigator.pop(context);
              await notifier.simulateScenario('fall');
            },
          ),

          const SizedBox(height: 12),

          // Scenario 2: Prolonged Inactivity
          _buildScenarioTile(
            context: context,
            title: 'Simulate Inactivity Anomaly',
            subtitle: 'User stops moving for 120s in isolated zone. Agent assesses risk and verifies.',
            icon: Icons.bedtime,
            color: Colors.amber.shade800,
            isLoading: incidentState.isLoading,
            onTap: () async {
              Navigator.pop(context);
              await notifier.simulateScenario('inactivity');
            },
          ),

          const SizedBox(height: 12),

          // Scenario 3: Critical Direct SOS
          _buildScenarioTile(
            context: context,
            title: 'Simulate Direct SOS Event',
            subtitle: 'Immediate critical alert. Agent skips verification and dispatches SNS notification.',
            icon: Icons.emergency_share,
            color: AppColors.danger,
            isLoading: incidentState.isLoading,
            onTap: () async {
              Navigator.pop(context);
              await notifier.simulateScenario('sos');
            },
          ),

          const SizedBox(height: 12),

          // Scenario 4: Hardware Power Button 3-Tap Panic
          _buildScenarioTile(
            context: context,
            title: 'Simulate Power Button 3-Tap Panic',
            subtitle: 'Covert physical trigger (locked phone). Immediate CRITICAL (0.98) — 0s delay, community + contacts dispatched.',
            icon: Icons.power_settings_new_rounded,
            color: const Color(0xFF6A1B9A),
            isLoading: incidentState.isLoading,
            onTap: () async {
              Navigator.pop(context);
              await notifier.simulateHardwarePanic();
            },
          ),

          const SizedBox(height: 12),

          // Scenario 5: Simulate Nearby Good Samaritan Response
          _buildScenarioTile(
            context: context,
            title: 'Simulate Good Samaritan Response',
            subtitle: 'View incoming community rescue alert as a nearby helper — accept mission & unlock GPS.',
            icon: Icons.group_rounded,
            color: AppColors.success,
            isLoading: incidentState.isLoading,
            onTap: () async {
              Navigator.pop(context);
              // Show demo of the incoming Good Samaritan alert modal
              await CommunityAlertDialog.show(
                context,
                incidentId: incidentState.incidentId ?? 'demo_incident',
                approximateArea: 'Near Station Road / Market Cross',
                distanceHint: '~350m away from you',
                coRespondersCount: 2,
              );
            },
          ),

          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildScenarioTile({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required bool isLoading,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: isLoading ? null : onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade200),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}
