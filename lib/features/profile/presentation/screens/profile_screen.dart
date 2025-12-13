/*
 * Guardian 2.0 - Women's Safety App
 * © 2025 All Rights Reserved - Kunal Singh
 * 
 * Profile Screen - Shows user profile with real Firestore data
 */

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:guardian/app/theme/app_theme.dart';
import 'package:guardian/core/providers/auth_provider.dart';
import 'package:guardian/core/providers/user_provider.dart';
import 'package:guardian/core/models/user_model.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userProfileAsync = ref.watch(userProfileStreamProvider);
    final firebaseUser = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          TextButton(
            onPressed: () {
              // TODO: Navigate to edit profile
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Edit profile coming soon!')),
              );
            },
            child: const Text('Edit'),
          ),
        ],
      ),
      body: userProfileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (profile) {
          // Fallback to Firebase user data if Firestore profile not found
          final displayName = profile?.displayName ?? firebaseUser?.displayName ?? 'Guardian User';
          final phoneNumber = profile?.phoneNumber ?? firebaseUser?.phoneNumber ?? 'No phone';
          final photoUrl = profile?.photoUrl ?? firebaseUser?.photoURL;
          final trustScore = profile?.trustScore ?? 0;
          final trustRank = profile?.trustRank ?? TrustRank.watcher;
          final pointsToNext = profile?.pointsToNextRank ?? 50;
          final helpedCount = profile?.helpedCount ?? 0;
          final sosUsedCount = profile?.sosUsedCount ?? 0;
          final walkSessionsCount = profile?.walkSessionsCount ?? 0;
          final isPhoneVerified = profile?.isPhoneVerified ?? true;
          final isIdVerified = profile?.isIdVerified ?? false;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Profile Avatar
                Center(
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 60,
                        backgroundColor: AppColors.primary.withOpacity(0.2),
                        backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
                        child: photoUrl == null
                            ? Text(
                                displayName[0].toUpperCase(),
                                style: TextStyle(
                                  fontSize: 48,
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              )
                            : null,
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: const Icon(Icons.camera_alt, color: Colors.white, size: 16),
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Name
                Text(
                  displayName,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                
                // Phone
                Text(
                  phoneNumber,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.grey,
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Trust Score Card
                Card(
                  color: AppColors.guardian.withOpacity(0.1),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.star, color: AppColors.guardian, size: 32),
                            const SizedBox(width: 8),
                            Text(
                              '$trustScore',
                              style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppColors.guardian,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Trust Points',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.guardian.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _trustRankName(trustRank).toUpperCase(),
                            style: TextStyle(
                              color: AppColors.guardian,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        LinearProgressIndicator(
                          value: _progressForRank(trustScore, trustRank),
                          backgroundColor: Colors.grey[300],
                          valueColor: AlwaysStoppedAnimation<Color>(AppColors.guardian),
                        ),
                        const SizedBox(height: 8),
                        if (trustRank != TrustRank.guardianAngel)
                          Text(
                            '$pointsToNext more points to ${_nextRankName(trustRank)}',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
                          )
                        else
                          Text(
                            'Maximum rank achieved! 🏆',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.guardian),
                          ),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Stats
                Row(
                  children: [
                    Expanded(child: _StatCard(title: 'Helped', value: '$helpedCount', icon: Icons.volunteer_activism)),
                    const SizedBox(width: 12),
                    Expanded(child: _StatCard(title: 'SOS Used', value: '$sosUsedCount', icon: Icons.emergency)),
                    const SizedBox(width: 12),
                    Expanded(child: _StatCard(title: 'Walks', value: '$walkSessionsCount', icon: Icons.directions_walk)),
                  ],
                ),
                
                const SizedBox(height: 24),
                
                // Verification Status
                Card(
                  child: Column(
                    children: [
                      ListTile(
                        leading: Icon(
                          Icons.phone_android, 
                          color: isPhoneVerified ? AppColors.success : Colors.grey,
                        ),
                        title: const Text('Phone Verified'),
                        trailing: Icon(
                          isPhoneVerified ? Icons.check_circle : Icons.radio_button_unchecked,
                          color: isPhoneVerified ? AppColors.success : Colors.grey,
                        ),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: Icon(
                          Icons.badge, 
                          color: isIdVerified ? AppColors.success : Colors.grey,
                        ),
                        title: const Text('ID Verification'),
                        subtitle: isIdVerified 
                            ? const Text('Verified ✓')
                            : const Text('Verify for +100 trust points'),
                        trailing: Icon(
                          isIdVerified ? Icons.check_circle : Icons.chevron_right,
                          color: isIdVerified ? AppColors.success : null,
                        ),
                        onTap: isIdVerified ? null : () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('ID verification coming soon!')),
                          );
                        },
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

  String _trustRankName(TrustRank rank) {
    switch (rank) {
      case TrustRank.watcher: return 'Watcher';
      case TrustRank.walker: return 'Walker';
      case TrustRank.responder: return 'Responder';
      case TrustRank.sentinel: return 'Sentinel';
      case TrustRank.guardianAngel: return 'Guardian Angel';
    }
  }

  String _nextRankName(TrustRank rank) {
    switch (rank) {
      case TrustRank.watcher: return 'Walker';
      case TrustRank.walker: return 'Responder';
      case TrustRank.responder: return 'Sentinel';
      case TrustRank.sentinel: return 'Guardian Angel';
      case TrustRank.guardianAngel: return '';
    }
  }

  double _progressForRank(int score, TrustRank rank) {
    switch (rank) {
      case TrustRank.watcher: return score / 50;
      case TrustRank.walker: return (score - 50) / 150;
      case TrustRank.responder: return (score - 200) / 300;
      case TrustRank.sentinel: return (score - 500) / 500;
      case TrustRank.guardianAngel: return 1.0;
    }
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
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: AppColors.primary),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              title,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
