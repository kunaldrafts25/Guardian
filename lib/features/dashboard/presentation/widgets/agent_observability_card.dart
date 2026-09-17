/*
 * Guardian - Women's Safety App
 * AWS Agent Observability & Interactive Verification Card
 */

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:guardian/core/constants/app_colors.dart';
import 'package:guardian/core/providers/aws_incident_provider.dart';

class AgentObservabilityCard extends ConsumerWidget {
  const AgentObservabilityCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final incident = ref.watch(awsIncidentProvider);
    final notifier = ref.read(awsIncidentProvider.notifier);

    if (incident.currentIncident == null) {
      return const SizedBox.shrink();
    }

    final state = incident.state;
    final isVerifying = incident.isVerifying;
    final isResponding = incident.isResponding;
    final isResolved = incident.isResolved;

    Color badgeColor;
    switch (state) {
      case 'SUSPECTED':
        badgeColor = Colors.orange;
        break;
      case 'VERIFYING':
        badgeColor = Colors.amber.shade800;
        break;
      case 'RESPONDING':
        badgeColor = AppColors.danger;
        break;
      case 'RESOLVED':
        badgeColor = Colors.green;
        break;
      default:
        badgeColor = Colors.grey;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: badgeColor.withValues(alpha: 0.4), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: badgeColor.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Agent ID + State Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: badgeColor,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'AWS Bedrock Agent',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  state,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: badgeColor,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Pipeline progress bar (OBSERVE -> ASSESS -> VERIFY -> RESPOND)
          _buildPipelineProgress(state),

          const SizedBox(height: 14),

          // Anomaly & Risk metrics
          Row(
            children: [
              Expanded(
                child: _buildMetricTile(
                  label: 'Event Type',
                  value: incident.eventType,
                  icon: Icons.sensors,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMetricTile(
                  label: 'Risk Level',
                  value: '${incident.riskLevel} (${incident.riskScore})',
                  icon: Icons.security,
                  highlight: incident.riskLevel == 'HIGH' || incident.riskLevel == 'CRITICAL',
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Rationale box
          if (incident.agentRationale.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.auto_awesome, size: 14, color: AppColors.primary),
                      const SizedBox(width: 6),
                      Text(
                        'Decision: ${incident.agentDecision}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    incident.agentRationale,
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.3),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],

          // Interactive Verification UI (if in VERIFYING state)
          if (isVerifying) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.amber.shade200),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      SizedBox(
                        width: 32,
                        height: 32,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            CircularProgressIndicator(
                              value: incident.verificationSecondsRemaining / 15.0,
                              strokeWidth: 3,
                              color: Colors.amber.shade800,
                              backgroundColor: Colors.amber.shade100,
                            ),
                            Text(
                              '${incident.verificationSecondsRemaining}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.amber.shade900,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Potential incident detected! Are you OK?',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => notifier.confirmImOk(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                          child: const Text("I'M OK", style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => notifier.escalateNeedHelp(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.danger,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                          child: const Text("NEED HELP", style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Contact Alert Notification (if in RESPONDING state)
          if (isResponding) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.notification_important, color: AppColors.danger, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Escalated! Alerts dispatched to emergency contacts via AWS SNS.',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton.icon(
                    onPressed: () => notifier.acknowledgeAlert(),
                    icon: const Icon(Icons.check_circle_outline, size: 16),
                    label: const Text('Simulate Contact Acknowledgment'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade700,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Resolved UI (if in RESOLVED state)
          if (isResolved) ...[
            Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.green, size: 18),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Incident resolved & stored in audit trail.',
                    style: TextStyle(fontSize: 12, color: Colors.green, fontWeight: FontWeight.w600),
                  ),
                ),
                TextButton(
                  onPressed: () => notifier.clearIncident(),
                  child: const Text('Dismiss', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ],

          // Timeline link
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => _showTimelineBottomSheet(context, incident.timeline),
              icon: const Icon(Icons.history, size: 16),
              label: Text('Audit Trail (${incident.timeline.length} events)', style: const TextStyle(fontSize: 12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPipelineProgress(String currentState) {
    final stages = ['OBSERVE', 'ASSESS', 'VERIFY', 'RESPOND'];
    int activeIndex = 0;
    if (currentState == 'SUSPECTED') activeIndex = 1;
    if (currentState == 'VERIFYING') activeIndex = 2;
    if (currentState == 'RESPONDING' || currentState == 'RESOLVED') activeIndex = 3;

    return Row(
      children: List.generate(stages.length * 2 - 1, (index) {
        if (index.isOdd) {
          final step = index ~/ 2;
          final isPast = step < activeIndex;
          return Expanded(
            child: Container(
              height: 2,
              color: isPast ? AppColors.primary : Colors.grey.shade300,
            ),
          );
        }

        final step = index ~/ 2;
        final isCurrent = step == activeIndex;
        final isPast = step <= activeIndex;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: isCurrent
                ? AppColors.primary
                : (isPast ? AppColors.primary.withValues(alpha: 0.2) : Colors.grey.shade200),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            stages[step],
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.bold,
              color: isCurrent ? Colors.white : (isPast ? AppColors.primary : Colors.grey.shade600),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildMetricTile({
    required String label,
    required String value,
    required IconData icon,
    bool highlight = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: highlight ? Colors.red : Colors.grey.shade700),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: highlight ? Colors.red : Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showTimelineBottomSheet(BuildContext context, List<Map<String, dynamic>> timeline) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('DynamoDB Audit Trail', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                ],
              ),
              const SizedBox(height: 10),
              Expanded(
                child: timeline.isEmpty
                    ? const Center(child: Text('No events recorded yet.'))
                    : ListView.separated(
                        itemCount: timeline.length,
                        separatorBuilder: (_, __) => const Divider(),
                        itemBuilder: (_, i) {
                          final e = timeline[i];
                          return ListTile(
                            dense: true,
                            leading: CircleAvatar(
                              radius: 14,
                              backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                              child: Text('${i + 1}', style: const TextStyle(fontSize: 11, color: AppColors.primary)),
                            ),
                            title: Text(e['event_type'] ?? 'event', style: const TextStyle(fontWeight: FontWeight.w600)),
                            subtitle: Text(e['details'] ?? e['state'] ?? '', style: const TextStyle(fontSize: 12)),
                            trailing: Text(
                              (e['actor'] ?? 'SYSTEM').toString(),
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
