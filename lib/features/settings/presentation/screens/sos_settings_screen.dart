/*
 * Guardian 2.0 - Women's Safety App
 * © 2025 All Rights Reserved - Kunal Singh
 * 
 * SOS Settings Screen - Configure SOS behavior
 */

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:guardian/app/theme/app_theme.dart';
import 'package:guardian/core/providers/sos_settings_provider.dart';
import 'package:guardian/core/providers/sos_trigger_provider.dart';

class SosSettingsScreen extends ConsumerWidget {
  const SosSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(sosSettingsProvider);
    final triggerState = ref.watch(sosTriggerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('SOS Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Shake Detection Section
          _buildSectionHeader(context, 'Trigger Methods'),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Shake to SOS'),
                  subtitle: Text(
                    triggerState.shakeDetectionActive
                        ? 'Active - Shake device 3 times to trigger'
                        : 'Shake your device vigorously 3 times',
                  ),
                  value: settings.shakeToSosEnabled,
                  onChanged: (value) {
                    ref
                        .read(sosSettingsProvider.notifier)
                        .setShakeToSosEnabled(value);
                  },
                  secondary: Icon(
                    Icons.vibration,
                    color: settings.shakeToSosEnabled
                        ? AppColors.primary
                        : Colors.grey,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Countdown Section
          _buildSectionHeader(context, 'Countdown Timer'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Hold duration before SOS triggers',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[600],
                        ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: SosSettings.countdownOptions.map((seconds) {
                      final isSelected = settings.countdownSeconds == seconds;
                      return ChoiceChip(
                        label: Text('$seconds sec'),
                        selected: isSelected,
                        onSelected: (selected) {
                          if (selected) {
                            ref
                                .read(sosSettingsProvider.notifier)
                                .setCountdownSeconds(seconds);
                          }
                        },
                        selectedColor: Color.fromRGBO(
                            AppColors.primary.r.toInt(),
                            AppColors.primary.g.toInt(),
                            AppColors.primary.b.toInt(),
                            0.2),
                        labelStyle: TextStyle(
                          color: isSelected ? AppColors.primary : null,
                          fontWeight: isSelected ? FontWeight.bold : null,
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Feedback Section
          _buildSectionHeader(context, 'Feedback'),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Sound'),
                  subtitle: const Text('Play sound during countdown'),
                  value: settings.soundEnabled,
                  onChanged: (value) {
                    ref
                        .read(sosSettingsProvider.notifier)
                        .setSoundEnabled(value);
                  },
                  secondary: Icon(
                    settings.soundEnabled ? Icons.volume_up : Icons.volume_off,
                    color:
                        settings.soundEnabled ? AppColors.primary : Colors.grey,
                  ),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  title: const Text('Vibration'),
                  subtitle: const Text('Haptic feedback during countdown'),
                  value: settings.vibrationEnabled,
                  onChanged: (value) {
                    ref
                        .read(sosSettingsProvider.notifier)
                        .setVibrationEnabled(value);
                  },
                  secondary: Icon(
                    Icons.vibration,
                    color: settings.vibrationEnabled
                        ? AppColors.primary
                        : Colors.grey,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Custom Message Section
          _buildSectionHeader(context, 'Custom Message'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Add a custom message to your SOS alerts',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[600],
                        ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    initialValue: settings.customMessage,
                    decoration: InputDecoration(
                      hintText: 'e.g., I have a medical condition...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    maxLines: 3,
                    maxLength: 200,
                    onChanged: (value) {
                      ref
                          .read(sosSettingsProvider.notifier)
                          .setCustomMessage(value);
                    },
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Emergency Services Section
          _buildSectionHeader(context, 'Emergency Services'),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Open emergency dialer'),
                  subtitle: const Text(
                      'Open the selected emergency number in your phone dialer after SOS'),
                  value: settings.autoCallEmergency,
                  onChanged: (value) {
                    ref
                        .read(sosSettingsProvider.notifier)
                        .setAutoCallEmergency(value);
                  },
                  secondary: Icon(
                    Icons.phone_in_talk,
                    color: settings.autoCallEmergency
                        ? AppColors.sos
                        : Colors.grey,
                  ),
                ),
                if (settings.autoCallEmergency) ...[
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Emergency Number',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children:
                              SosSettings.emergencyNumbers.entries.map((entry) {
                            final isSelected =
                                settings.emergencyNumber == entry.value;
                            return ChoiceChip(
                              label: Text('${entry.key} (${entry.value})'),
                              selected: isSelected,
                              onSelected: (selected) {
                                if (selected) {
                                  ref
                                      .read(sosSettingsProvider.notifier)
                                      .setEmergencyNumber(entry.value);
                                }
                              },
                              selectedColor: Color.fromRGBO(
                                  AppColors.sos.r.toInt(),
                                  AppColors.sos.g.toInt(),
                                  AppColors.sos.b.toInt(),
                                  0.2),
                              labelStyle: TextStyle(
                                color: isSelected ? AppColors.sos : null,
                                fontWeight: isSelected ? FontWeight.bold : null,
                                fontSize: 12,
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 32),

          // Reset Button
          OutlinedButton.icon(
            onPressed: () => _showResetDialog(context, ref),
            icon: const Icon(Icons.restore),
            label: const Text('Reset to Defaults'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.grey[600],
              side: BorderSide(color: Colors.grey[400]!),
            ),
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
      ),
    );
  }

  void _showResetDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Settings'),
        content: const Text(
            'Are you sure you want to reset all SOS settings to their default values?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              ref.read(sosSettingsProvider.notifier).resetToDefaults();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Settings reset to defaults')),
              );
            },
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }
}
