/*
 * Guardian 2.0 - Women's Safety App
 * © 2025 All Rights Reserved - Kunal Singh
 * 
 * Quick Actions Screen - Quick access to safety features
 */

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:guardian/app/theme/app_theme.dart';
import 'package:guardian/core/providers/check_in_provider.dart';
import 'package:guardian/core/providers/sos_settings_provider.dart';

class QuickActionsScreen extends ConsumerWidget {
  const QuickActionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final checkInState = ref.watch(checkInProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quick Actions'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Active check-in banner
            if (checkInState.isActive) ...[
              _buildCheckInBanner(context, ref, checkInState),
              const SizedBox(height: 24),
            ],

            // Check-In Timer Section
            Text(
              'Check-In Timer',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              '"I\'ll be home by X" - contacts notified if you don\'t check in',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey,
                  ),
            ),
            const SizedBox(height: 12),
            _buildCheckInSection(context, ref, checkInState),

            const SizedBox(height: 32),

            // Shake to SOS Section
            Text(
              'Shake to SOS',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Shake your phone 3 times quickly to trigger SOS',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey,
                  ),
            ),
            const SizedBox(height: 12),
            _buildShakeSection(context, ref),
          ],
        ),
      ),
    );
  }

  Widget _buildCheckInBanner(
      BuildContext context, WidgetRef ref, CheckInState state) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: state.isOverdue
            ? AppColors.error.withOpacity(0.1)
            : AppColors.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: state.isOverdue ? AppColors.error : AppColors.primary,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                state.isOverdue ? Icons.warning : Icons.timer,
                color: state.isOverdue ? AppColors.error : AppColors.primary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      state.isOverdue ? 'Check-In Overdue!' : 'Check-In Active',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: state.isOverdue
                            ? AppColors.error
                            : AppColors.primary,
                      ),
                    ),
                    Text(
                      state.isOverdue
                          ? '${state.overdueMinutes} minutes overdue'
                          : '${state.remainingTimeFormatted} remaining',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    if (state.nativeScheduled && !state.exactAlarm)
                      Text(
                        'Android may delay this check-in because exact alarms are unavailable.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.warning,
                            ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () =>
                      ref.read(checkInProvider.notifier).cancelTimer(),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => ref.read(checkInProvider.notifier).checkIn(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                  ),
                  child: const Text('I\'m Safe'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCheckInSection(
      BuildContext context, WidgetRef ref, CheckInState state) {
    if (state.isActive) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const Icon(Icons.timer, size: 48, color: AppColors.primary),
              const SizedBox(height: 8),
              Text(
                state.remainingTimeFormatted,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              if (state.destination != null) ...[
                const SizedBox(height: 4),
                Text('To: ${state.destination}'),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => ref
                          .read(checkInProvider.notifier)
                          .extendTimer(const Duration(minutes: 15)),
                      child: const Text('+15 min'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () =>
                          ref.read(checkInProvider.notifier).checkIn(),
                      child: const Text('Check In'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text('How long until you arrive?'),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: CheckInPresets.durations
                  .map(
                    (duration) => ActionChip(
                      label: Text(CheckInPresets.formatDuration(duration)),
                      onPressed: () {
                        ref.read(checkInProvider.notifier).startTimer(
                              duration: duration,
                            );
                      },
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShakeSection(BuildContext context, WidgetRef ref) {
    final enabled = ref.watch(shakeToSosEnabledProvider);
    return Card(
      child: ListTile(
        leading: const Icon(Icons.vibration, color: AppColors.warning),
        title: const Text('Shake to SOS'),
        subtitle: const Text('Shake 3 times in 2 seconds to trigger'),
        trailing: Switch(
          value: enabled,
          onChanged: (value) => ref
              .read(sosSettingsProvider.notifier)
              .setShakeToSosEnabled(value),
          activeColor: AppColors.primary,
        ),
      ),
    );
  }
}
