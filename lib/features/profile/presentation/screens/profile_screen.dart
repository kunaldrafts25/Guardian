/*
 * Guardian - Mobile Safety App
 * Profile Screen - Authenticated Profile & Readiness Status
 */

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:guardian/app/routes.dart';
import 'package:guardian/app/theme/app_theme.dart';
import 'package:guardian/core/providers/auth_provider.dart';
import 'package:guardian/core/providers/user_provider.dart';
import 'package:guardian/core/widgets/guardian_ui.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userProfileAsync = ref.watch(userProfileStreamProvider);
    final sessionUser = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
      ),
      body: userProfileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (profile) {
          final displayName = profile?.displayName ??
              sessionUser?.displayName ??
              'Guardian User';
          final phoneNumber =
              profile?.phoneNumber ?? sessionUser?.phoneNumber ?? 'No phone';
          final photoUrl = profile?.photoUrl ?? sessionUser?.photoURL;
          final helpedCount = profile?.helpedCount ?? 0;
          final sosUsedCount = profile?.sosUsedCount ?? 0;
          final walkSessionsCount = profile?.walkSessionsCount ?? 0;
          final isPhoneVerified = profile?.isPhoneVerified ?? true;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Profile Avatar
                Center(
                  child: CircleAvatar(
                    radius: 54,
                    backgroundColor: AppColors.brandContainer,
                    backgroundImage:
                        photoUrl != null ? NetworkImage(photoUrl) : null,
                    child: photoUrl == null
                        ? Text(
                            displayName.isNotEmpty
                                ? displayName[0].toUpperCase()
                                : 'G',
                            style: const TextStyle(
                              fontSize: 44,
                              color: AppColors.brand,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        : null,
                  ),
                ),
                const SizedBox(height: 16),

                // Name
                Text(
                  displayName,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 4),

                // Phone
                Text(
                  phoneNumber,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),

                const SizedBox(height: 24),

                // Verification & Protection Status Card
                Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: const BorderSide(color: AppColors.border),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: AppColors.brand.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.verified_user_rounded,
                              color: AppColors.brand),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Guardian Identity',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                isPhoneVerified
                                    ? 'Phone verified • Emergency active'
                                    : 'Phone verification pending',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        GuardianStatusPill(
                          label: isPhoneVerified ? 'Verified' : 'Pending',
                          tone: isPhoneVerified
                              ? GuardianStatusTone.success
                              : GuardianStatusTone.warning,
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Truthful Safety Activity Counters
                Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        title: 'Assisted',
                        value: '$helpedCount',
                        icon: Icons.volunteer_activism_outlined,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatCard(
                        title: 'SOS Recorded',
                        value: '$sosUsedCount',
                        icon: Icons.emergency_outlined,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatCard(
                        title: 'Walk Checks',
                        value: '$walkSessionsCount',
                        icon: Icons.directions_walk_rounded,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Account settings / Navigation Actions
                Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: const BorderSide(color: AppColors.border),
                  ),
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.phone_android_rounded),
                        title: const Text('Phone Number'),
                        subtitle: Text(phoneNumber),
                        trailing: Icon(
                          isPhoneVerified
                              ? Icons.check_circle_rounded
                              : Icons.error_outline_rounded,
                          color: isPhoneVerified
                              ? AppColors.success
                              : AppColors.warning,
                        ),
                      ),
                      const Divider(height: 1, indent: 56),
                      ListTile(
                        leading: const Icon(Icons.people_outline_rounded),
                        title: const Text('Guardian Circle'),
                        subtitle: const Text('Manage emergency contacts'),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => context.push(Routes.contacts),
                      ),
                      const Divider(height: 1, indent: 56),
                      ListTile(
                        leading: const Icon(Icons.health_and_safety_outlined),
                        title: const Text('Protection Readiness'),
                        subtitle: const Text('Hardware and sensor checklist'),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => context.push(Routes.readiness),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 16),
        child: Column(
          children: [
            Icon(icon, color: AppColors.brand, size: 26),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 2),
            Text(
              title,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
