/*
 * Guardian - Women's Safety App
 * © 2025 All Rights Reserved - Kunal Singh
 * Contact: kunalsingh2514@gmail.com
 */

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:guardian/core/constants/app_colors.dart';
import 'package:guardian/core/constants/app_typography.dart';
import 'package:guardian/core/providers/contacts_provider.dart';
import 'package:guardian/core/utils/location_utils.dart';
import 'package:guardian/features/dashboard/presentation/widgets/quick_access_fab.dart';
import 'package:url_launcher/url_launcher.dart';

/// A row of quick access FABs for the dashboard
class QuickAccessRow extends ConsumerWidget {
  const QuickAccessRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title
        Text(
          'Quick Access',
          style: AppTypography.heading4,
        ),
        const SizedBox(height: 16),

        // FABs Row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            QuickAccessFab(
              icon: Icons.share_location,
              label: 'Share Location',
              color: AppColors.accent,
              onTap: () => _shareLocation(context, ref),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _shareLocation(BuildContext context, WidgetRef ref) async {
    final contactState = ref.read(contactsProvider);
    final contact = contactState.primaryContact ??
        (contactState.contacts.isNotEmpty ? contactState.contacts.first : null);
    if (contact == null) {
      _showMessage(
          context, 'Add an emergency contact before sharing location.');
      return;
    }

    final position = await LocationUtils.getCurrentPosition();
    if (!context.mounted) return;
    if (position == null) {
      _showMessage(context,
          'Location is unavailable. Enable location services and try again.');
      return;
    }

    final locationUrl =
        'https://maps.google.com/?q=${position.latitude},${position.longitude}';
    final smsUri = Uri(
      scheme: 'sms',
      path: contact.phone,
      queryParameters: {
        'body': 'My current location: $locationUrl',
      },
    );
    if (!await canLaunchUrl(smsUri)) {
      if (context.mounted)
        _showMessage(context, 'Unable to open the SMS composer.');
      return;
    }
    await launchUrl(smsUri);
  }

  void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}
