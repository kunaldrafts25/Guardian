/*
 * Guardian - Women's Safety App
 * Good Samaritan Community Emergency Alert Modal
 */

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:guardian/core/constants/app_colors.dart';
import 'package:guardian/core/providers/aws_incident_provider.dart';
import 'package:guardian/features/community/presentation/screens/mission_navigation_screen.dart';

class CommunityAlertDialog extends ConsumerStatefulWidget {
  final String incidentId;
  final String approximateArea;
  final String distanceHint;
  final int coRespondersCount;

  const CommunityAlertDialog({
    super.key,
    required this.incidentId,
    this.approximateArea = 'Near Station Road / Market Cross',
    this.distanceHint = '~350m away from you',
    this.coRespondersCount = 2,
  });

  static Future<void> show(
    BuildContext context, {
    required String incidentId,
    String approximateArea = 'Near Station Road / Market Cross',
    String distanceHint = '~350m away from you',
    int coRespondersCount = 2,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => CommunityAlertDialog(
        incidentId: incidentId,
        approximateArea: approximateArea,
        distanceHint: distanceHint,
        coRespondersCount: coRespondersCount,
      ),
    );
  }

  @override
  ConsumerState<CommunityAlertDialog> createState() => _CommunityAlertDialogState();
}

class _CommunityAlertDialogState extends ConsumerState<CommunityAlertDialog> {
  bool _isAccepting = false;
  Map<String, dynamic>? _acceptedMission;

  Future<void> _handleAccept() async {
    setState(() => _isAccepting = true);
    final res = await ref.read(awsIncidentProvider.notifier).acceptMission(
          responderId: 'resp_01',
        );
    setState(() {
      _isAccepting = false;
      _acceptedMission = res;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 16,
      backgroundColor: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.danger.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.campaign_rounded,
                    color: AppColors.danger,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'COMMUNITY SOS ALERT',
                        style: TextStyle(
                          color: AppColors.danger,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _acceptedMission != null
                            ? 'Mission En Route'
                            : 'Nearby Person Needs Help',
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Obfuscated Location Card (Differential Geo-Obfuscation)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.divider),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.location_on_rounded, color: AppColors.primary, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          widget.approximateArea,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          widget.distanceHint,
                          style: const TextStyle(
                            color: AppColors.primaryDark,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.success.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.groups_rounded, color: AppColors.success, size: 14),
                            const SizedBox(width: 4),
                            Text(
                              '${widget.coRespondersCount} Helpers Moving',
                              style: const TextStyle(
                                color: AppColors.success,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
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
            const SizedBox(height: 12),

            // Anti-Abuse Safety Guidance
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF9E6),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.shield_outlined, color: AppColors.warning, size: 16),
                      SizedBox(width: 6),
                      Text(
                        'Guardian Anti-Abuse Shield Active',
                        style: TextStyle(
                          color: Color(0xFF8A6000),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 6),
                  Text(
                    '• Never approach alone in isolated areas — wait for your co-responder.\n'
                    '• Do NOT physically engage. Use presence, noise & flashlight.\n'
                    '• Tamper-proof cloud audio & GPS blackbox is recording.',
                    style: TextStyle(
                      color: Color(0xFF6B4A00),
                      fontSize: 11,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),

            // Mission accepted — precision GPS unlocked
            if (_acceptedMission != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.check_circle_rounded, color: AppColors.success, size: 18),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Precision GPS Unlocked!\nMove to rendezvous — co-responder is on the way.',
                        style: TextStyle(
                          color: AppColors.success,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 16),

            // Action Buttons
            if (_acceptedMission == null) ...[
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isAccepting ? null : () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textSecondary,
                        side: const BorderSide(color: AppColors.divider),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('Decline'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: _isAccepting ? null : _handleAccept,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.danger,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      icon: _isAccepting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2),
                            )
                          : const Icon(Icons.directions_run_rounded, size: 18),
                      label: Text(_isAccepting ? 'Accepting...' : 'Accept & Help'),
                    ),
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: () {
                  final precLoc = _acceptedMission?['precision_location'] as Map?;
                  final lat = (precLoc?['latitude'] as num?)?.toDouble() ?? 19.0760;
                  final lng = (precLoc?['longitude'] as num?)?.toDouble() ?? 72.8777;
                  final pin = _acceptedMission?['verification_pin']?.toString() ?? '8429';

                  Navigator.of(context).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => MissionNavigationScreen(
                        incidentId: widget.incidentId,
                        victimLatitude: lat,
                        victimLongitude: lng,
                        approximateArea: widget.approximateArea,
                        verificationPin: pin,
                        coRespondersCount: widget.coRespondersCount,
                      ),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape:
                      RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                icon: const Icon(Icons.navigation_rounded, size: 18),
                label: const Text('Navigate to Rendezvous'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
