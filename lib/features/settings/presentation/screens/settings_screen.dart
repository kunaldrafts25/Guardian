/*
 * Guardian - Women's Safety App
 * © 2025 All Rights Reserved - Kunal Singh
 * Contact: kunalsingh2514@gmail.com
 */

import 'package:flutter/material.dart';
import 'package:guardian/core/constants/app_colors.dart';
import 'package:guardian/core/constants/app_strings.dart';
import 'package:guardian/features/auth/data/auth_repository.dart';
import 'package:guardian/features/auth/presentation/screens/login_screen.dart';
import 'package:guardian/features/settings/presentation/screens/emergency_contacts_screen.dart';
import 'package:guardian/features/settings/presentation/screens/profile_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _authRepository = AuthRepository();
  bool _isDarkMode = false;
  bool _notificationsEnabled = true;
  bool _locationTrackingEnabled = true;
  bool _recordAudioEnabled = true;
  bool _recordVideoEnabled = false;

  Future<void> _signOut() async {
    try {
      await _authRepository.signOut();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error signing out: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  void _showSignOutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _signOut();
            },
            style: TextButton.styleFrom(
              foregroundColor: AppColors.danger,
            ),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }

  void _navigateToProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ProfileScreen(),
      ),
    );
  }

  void _navigateToEmergencyContacts() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const EmergencyContactsScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.settings),
      ),
      body: ListView(
        children: [
          // Profile section
          ListTile(
            leading: const CircleAvatar(
              backgroundColor: AppColors.primary,
              child: Icon(
                Icons.person,
                color: Colors.white,
              ),
            ),
            title: const Text(
              AppStrings.profile,
              style: TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
            subtitle: const Text('Edit your profile information'),
            trailing: const Icon(Icons.chevron_right),
            onTap: _navigateToProfile,
          ),
          const Divider(),

          // Account settings
          const Padding(
            padding: EdgeInsets.only(left: 16, top: 16, bottom: 8),
            child: Text(
              'Account',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.contacts),
            title: const Text(AppStrings.emergencyContacts),
            trailing: const Icon(Icons.chevron_right),
            onTap: _navigateToEmergencyContacts,
          ),
          const Divider(),

          // App settings
          const Padding(
            padding: EdgeInsets.only(left: 16, top: 16, bottom: 8),
            child: Text(
              'App Settings',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          SwitchListTile(
            title: const Text(AppStrings.notifications),
            subtitle: const Text('Receive alerts and notifications'),
            secondary: const Icon(Icons.notifications),
            value: _notificationsEnabled,
            onChanged: (value) {
              setState(() {
                _notificationsEnabled = value;
              });
            },
          ),
          const Divider(),
          SwitchListTile(
            title: const Text(AppStrings.theme),
            subtitle: const Text('Dark mode'),
            secondary: const Icon(Icons.dark_mode),
            value: _isDarkMode,
            onChanged: (value) {
              setState(() {
                _isDarkMode = value;
              });
              // TODO: Implement theme switching
            },
          ),
          const Divider(),

          // Privacy settings
          const Padding(
            padding: EdgeInsets.only(left: 16, top: 16, bottom: 8),
            child: Text(
              'Privacy',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          SwitchListTile(
            title: const Text('Location Tracking'),
            subtitle: const Text('Allow background location tracking'),
            secondary: const Icon(Icons.location_on),
            value: _locationTrackingEnabled,
            onChanged: (value) {
              setState(() {
                _locationTrackingEnabled = value;
              });
            },
          ),
          const Divider(),
          SwitchListTile(
            title: const Text('Record Audio'),
            subtitle: const Text('Record audio during emergency'),
            secondary: const Icon(Icons.mic),
            value: _recordAudioEnabled,
            onChanged: (value) {
              setState(() {
                _recordAudioEnabled = value;
              });
            },
          ),
          const Divider(),
          SwitchListTile(
            title: const Text('Record Video'),
            subtitle: const Text('Record video during emergency'),
            secondary: const Icon(Icons.videocam),
            value: _recordVideoEnabled,
            onChanged: (value) {
              setState(() {
                _recordVideoEnabled = value;
              });
            },
          ),
          const Divider(),

          // Help and support
          const Padding(
            padding: EdgeInsets.only(left: 16, top: 16, bottom: 8),
            child: Text(
              'Help & Support',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.help),
            title: const Text(AppStrings.help),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // TODO: Navigate to help screen
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.info),
            title: const Text(AppStrings.about),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // TODO: Navigate to about screen
            },
          ),
          const Divider(),

          // Sign out
          Padding(
            padding: const EdgeInsets.all(16),
            child: ElevatedButton(
              onPressed: _showSignOutDialog,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.danger,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: const Text(
                AppStrings.logout,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
