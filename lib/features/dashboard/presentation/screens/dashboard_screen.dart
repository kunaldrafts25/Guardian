/*
 * Guardian 2.0 - Women's Safety App
 * © 2025 All Rights Reserved - Kunal Singh
 * 
 * Dashboard Screen - Main Home Screen
 */

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../app/routes.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/providers/settings_provider.dart';
import '../../../../core/providers/emergency_provider.dart';
import '../../../../core/providers/user_provider.dart';
import '../../../../core/services/sos_service.dart';
import '../widgets/agent_observability_card.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final profile = ref.watch(userProfileStreamProvider).valueOrNull;
    final locationMode = ref.watch(locationModeProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Guardian'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_outline),
            onPressed: () => context.push(Routes.profile),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Welcome Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Hello, ${user?.displayName ?? 'Guardian'}! 👋',
                        style:
                            Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.success.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    color: AppColors.success,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '${locationMode.name.toUpperCase()} Mode',
                                  style: TextStyle(
                                    color: AppColors.success,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // AWS Bedrock Agent Observability & Live State Card
              const AgentObservabilityCard(),

              // SOS Button (Large, Prominent)
              Center(
                child: GestureDetector(
                  onTap: () => context.push(Routes.emergency),
                  onLongPress: () {
                    // Trigger actual SOS via provider
                    ref.read(emergencyProvider.notifier).triggerEmergency(
                          source: SosTriggerSource.button,
                        );
                  },
                  child: Container(
                    width: 180,
                    height: 180,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.sos,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.sosGlow,
                          blurRadius: 30,
                          spreadRadius: 10,
                        ),
                      ],
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.emergency,
                            size: 50,
                            color: Colors.white,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'SOS',
                            style: Theme.of(context)
                                .textTheme
                                .headlineMedium
                                ?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          Text(
                            'Hold for emergency',
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Colors.white70,
                                    ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // Quick Actions
              Text(
                'Quick Actions',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 12),

              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.5,
                children: [
                  _QuickActionCard(
                    icon: Icons.people,
                    title: 'Guardian Circle',
                    subtitle: 'Emergency contacts',
                    color: AppColors.secondary,
                    onTap: () => context.push(Routes.contacts),
                  ),
                  _QuickActionCard(
                    icon: Icons.shield,
                    title: 'Safe Zones',
                    subtitle: 'Manage locations',
                    color: AppColors.success,
                    onTap: () => context.push(Routes.safeZones),
                  ),
                  _QuickActionCard(
                    icon: Icons.timer,
                    title: 'Check-In Timer',
                    subtitle: 'I\'ll be home by',
                    color: AppColors.warning,
                    onTap: () => context.push(Routes.quickActions),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Trust Score Card
              Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppColors.guardian.withOpacity(0.2),
                    child: Icon(Icons.star, color: AppColors.guardian),
                  ),
                  title: const Text('Your Trust Score'),
                  subtitle: Text(
                    '${profile?.trustRankDisplayName ?? 'Watcher'} • '
                    '${profile?.trustScore ?? 0} points',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push(Routes.profile),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(height: 6),
              Flexible(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Flexible(
                child: Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey,
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
