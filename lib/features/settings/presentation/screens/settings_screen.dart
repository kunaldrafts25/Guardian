/*
 * Guardian 2.0 - Women's Safety App
 * © 2025 All Rights Reserved - Kunal Singh
 * 
 * Settings Screen
 */

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:guardian/app/theme/app_theme.dart';
import 'package:guardian/app/routes.dart';
import 'package:guardian/core/models/user_model.dart';
import 'package:guardian/core/providers/settings_provider.dart';
import 'package:guardian/core/providers/auth_provider.dart';
import 'package:guardian/core/providers/sos_settings_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final locationMode = ref.watch(locationModeProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        children: [
          // Location Mode Section
          _SectionHeader(title: 'Privacy & Location'),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              children: [
                ListTile(
                  leading: Icon(Icons.location_off,
                      color: locationMode == LocationMode.ghost
                          ? AppColors.primary
                          : Colors.grey),
                  title: const Text('Ghost Mode'),
                  subtitle: const Text('Location only during SOS'),
                  trailing: Radio<LocationMode>(
                    value: LocationMode.ghost,
                    groupValue: locationMode,
                    onChanged: (value) => ref
                        .read(locationModeProvider.notifier)
                        .setLocationMode(value!),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: Icon(Icons.smart_toy,
                      color: locationMode == LocationMode.smart
                          ? AppColors.primary
                          : Colors.grey),
                  title: const Text('Smart Mode'),
                  subtitle: const Text('Auto-activate at night'),
                  trailing: Radio<LocationMode>(
                    value: LocationMode.smart,
                    groupValue: locationMode,
                    onChanged: (value) => ref
                        .read(locationModeProvider.notifier)
                        .setLocationMode(value!),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: Icon(Icons.shield,
                      color: locationMode == LocationMode.guardian
                          ? AppColors.primary
                          : Colors.grey),
                  title: const Text('Guardian Mode'),
                  subtitle: const Text('Always on (higher battery use)'),
                  trailing: Radio<LocationMode>(
                    value: LocationMode.guardian,
                    groupValue: locationMode,
                    onChanged: (value) => ref
                        .read(locationModeProvider.notifier)
                        .setLocationMode(value!),
                  ),
                ),
              ],
            ),
          ),

          // Appearance Section
          _SectionHeader(title: 'Appearance'),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.brightness_6),
                  title: const Text('Theme'),
                  subtitle: Text(_getThemeName(themeMode)),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _showThemeDialog(context, ref, themeMode),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.language),
                  title: const Text('Language'),
                  subtitle: const Text('English'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {},
                ),
              ],
            ),
          ),

          // Safety Section
          _SectionHeader(title: 'Safety'),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              children: [
                SwitchListTile(
                  secondary: const Icon(Icons.vibration),
                  title: const Text('Shake to SOS'),
                  subtitle: const Text('Shake phone to trigger emergency'),
                  value: ref.watch(shakeToSosEnabledProvider),
                  onChanged: (value) => ref
                      .read(sosSettingsProvider.notifier)
                      .setShakeToSosEnabled(value),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.place),
                  title: const Text('Safe Zones'),
                  subtitle: const Text('Manage your safe locations'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push(Routes.safeZones),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.flash_on),
                  title: const Text('Quick Actions'),
                  subtitle: const Text('Check-in timer and SOS controls'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push(Routes.quickActions),
                ),
              ],
            ),
          ),

          // Account Section
          _SectionHeader(title: 'Account'),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.devices),
                  title: const Text('Signed-in devices'),
                  subtitle: const Text('Review and revoke account sessions'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push(Routes.sessions),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.help_outline),
                  title: const Text('Help & Support'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {},
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: const Text('About Guardian'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {},
                ),
                const Divider(height: 1),
                ListTile(
                  leading: Icon(Icons.logout, color: AppColors.error),
                  title: Text('Sign Out',
                      style: TextStyle(color: AppColors.error)),
                  onTap: () async {
                    await ref.read(signOutProvider)();
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),
          Center(
            child: Text(
              'Guardian v2.0.0',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Colors.grey),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  String _getThemeName(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'Light';
      case ThemeMode.dark:
        return 'Dark';
      case ThemeMode.system:
        return 'System default';
    }
  }

  void _showThemeDialog(
      BuildContext context, WidgetRef ref, ThemeMode currentMode) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Choose Theme'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: ThemeMode.values.map((mode) {
            return RadioListTile<ThemeMode>(
              title: Text(_getThemeName(mode)),
              value: mode,
              groupValue: currentMode,
              onChanged: (value) {
                ref.read(themeModeProvider.notifier).setThemeMode(value!);
                Navigator.pop(context);
              },
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Colors.grey,
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }
}
