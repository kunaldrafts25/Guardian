/*
 * Guardian 2.0 - Women's Safety App
 * © 2025 All Rights Reserved - Kunal Singh
 * 
 * Emergency Screen - SOS trigger with countdown
 */

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:guardian/app/theme/app_theme.dart';
import 'package:guardian/core/providers/emergency_provider.dart';
import 'package:guardian/core/providers/sos_settings_provider.dart';
import 'package:guardian/core/providers/contacts_provider.dart';
import 'package:guardian/core/providers/sos_trigger_provider.dart';
import 'package:guardian/core/services/sos_sound_service.dart';

class EmergencyScreen extends ConsumerStatefulWidget {
  const EmergencyScreen({super.key});

  @override
  ConsumerState<EmergencyScreen> createState() => _EmergencyScreenState();
}

class _EmergencyScreenState extends ConsumerState<EmergencyScreen> {
  Timer? _countdownTimer;
  late int _countdown;
  bool _isHolding = false;

  @override
  void initState() {
    super.initState();
    // Initialize shake detection
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(sosTriggerProvider); // Initialize trigger provider
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _startHold() {
    final settings = ref.read(sosSettingsProvider);

    // Haptic feedback
    if (settings.vibrationEnabled) {
      HapticFeedback.mediumImpact();
    }

    setState(() {
      _isHolding = true;
      _countdown = settings.countdownSeconds;
    });

    ref.read(emergencyProvider.notifier).startCountdown();

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdown > 1) {
        setState(() => _countdown--);
        ref.read(emergencyProvider.notifier).updateCountdown(_countdown);
        // Haptic tick
        if (settings.vibrationEnabled) {
          HapticFeedback.lightImpact();
        }
        // Sound beep
        if (settings.soundEnabled) {
          SosSoundService.instance.playCountdownBeep();
        }
      } else {
        timer.cancel();
        // Heavy haptic for trigger
        if (settings.vibrationEnabled) {
          HapticFeedback.heavyImpact();
        }
        // Alarm sound on activation
        if (settings.soundEnabled) {
          SosSoundService.instance.playSOSActivation();
        }
        // Trigger emergency
        ref.read(emergencyProvider.notifier).triggerEmergency();
        setState(() => _isHolding = false);
      }
    });
  }

  void _cancelHold() {
    _countdownTimer?.cancel();
    ref.read(emergencyProvider.notifier).cancelCountdown();
    final settings = ref.read(sosSettingsProvider);
    setState(() {
      _isHolding = false;
      _countdown = settings.countdownSeconds;
    });
  }

  void _cancelEmergency() {
    ref.read(emergencyProvider.notifier).cancelEmergency();
  }

  Future<void> _callPolice() async {
    await ref.read(emergencyProvider.notifier).callEmergencyServices();
  }

  Future<void> _shareLocation() async {
    await ref.read(emergencyProvider.notifier).shareLocation();
  }

  @override
  Widget build(BuildContext context) {
    final emergencyState = ref.watch(emergencyProvider);
    final contacts = ref.watch(contactsProvider).contacts;
    final isActive = emergencyState.isActive;

    return Scaffold(
      backgroundColor: isActive ? AppColors.sos : null,
      appBar: AppBar(
        title: const Text('Emergency'),
        backgroundColor: isActive ? AppColors.sos : null,
        foregroundColor: isActive ? Colors.white : null,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isActive) ...[
                // Active Emergency State
                const SizedBox(height: 40),
                const Icon(
                  Icons.warning_rounded,
                  size: 80,
                  color: Colors.white,
                ),
                const SizedBox(height: 24),
                Text(
                  'EMERGENCY ACTIVE',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 16),
                Text(
                  '${emergencyState.notifiedContacts.length} SMS dispatches accepted',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.white70,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Delivery is not confirmed until a receipt or acknowledgement arrives',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white60,
                      ),
                ),
                const SizedBox(height: 24),

                // Notified contacts list
                Card(
                  color: const Color.fromRGBO(255, 255, 255, 0.15),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'SMS dispatch status:',
                          style:
                              Theme.of(context).textTheme.titleSmall?.copyWith(
                                    color: Colors.white70,
                                  ),
                        ),
                        const SizedBox(height: 8),
                        if (emergencyState.sosAlert?.contactStatuses.isEmpty ??
                            true)
                          const Text(
                            'No contacts configured',
                            style: TextStyle(color: Colors.white60),
                          )
                        else
                          ...emergencyState.sosAlert!.contactStatuses
                              .map((status) => Padding(
                                    padding:
                                        const EdgeInsets.symmetric(vertical: 4),
                                    child: Row(
                                      children: [
                                        Icon(
                                          status.smsSent
                                              ? Icons.outbox
                                              : Icons.error_outline,
                                          color: Colors.white,
                                          size: 16,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            '${status.contact.name} — ${status.smsSent ? 'accepted by device' : 'dispatch failed'}',
                                            style: const TextStyle(
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  )),
                      ],
                    ),
                  ),
                ),

                // Quick Action Buttons
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _callPolice,
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              const Color.fromRGBO(255, 255, 255, 0.2),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        icon: const Icon(Icons.local_police),
                        label: const Text('Call Police'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _shareLocation,
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              const Color.fromRGBO(255, 255, 255, 0.2),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        icon: const Icon(Icons.share_location),
                        label: const Text('Share Location'),
                      ),
                    ),
                  ],
                ),

                // Live Location Info
                if (emergencyState.currentLocation != null) ...[
                  const SizedBox(height: 16),
                  Card(
                    color: const Color.fromRGBO(255, 255, 255, 0.15),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          const Icon(Icons.gps_fixed,
                              color: Colors.white, size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Live Location Active',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  '${emergencyState.currentLocation!.latitude.toStringAsFixed(6)}, ${emergencyState.currentLocation!.longitude.toStringAsFixed(6)}',
                                  style: const TextStyle(
                                      color: Colors.white70, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 32),
                OutlinedButton(
                  onPressed: _cancelEmergency,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white, width: 2),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 48, vertical: 16),
                  ),
                  child: const Text('I\'m Safe - Cancel'),
                ),
              ] else if (emergencyState.state == SosState.error) ...[
                // Error State
                const SizedBox(height: 40),
                Icon(
                  Icons.error_outline,
                  size: 80,
                  color: AppColors.sos,
                ),
                const SizedBox(height: 24),
                Text(
                  'Error',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: AppColors.sos,
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 16),
                Text(
                  emergencyState.errorMessage ?? 'Something went wrong',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Colors.grey[700],
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: () {
                    ref.read(emergencyProvider.notifier).clearError();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 32, vertical: 16),
                  ),
                  child: const Text('Try Again'),
                ),
              ] else ...[
                // Normal State
                Text(
                  'Emergency Mode',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Hold the button below to activate emergency mode',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Colors.grey,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 48),

                // Large SOS Button with Countdown
                GestureDetector(
                  onLongPressStart: (_) => _startHold(),
                  onLongPressEnd: (_) {
                    if (_isHolding && _countdown > 0) {
                      _cancelHold();
                    }
                  },
                  onLongPressCancel: _cancelHold,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: _isHolding ? 220 : 200,
                    height: _isHolding ? 220 : 200,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _isHolding
                          ? Color.fromRGBO(
                              AppColors.sos.r.toInt(),
                              AppColors.sos.g.toInt(),
                              AppColors.sos.b.toInt(),
                              0.8)
                          : AppColors.sos,
                      boxShadow: [
                        BoxShadow(
                          color: _isHolding ? AppColors.sos : AppColors.sosGlow,
                          blurRadius: _isHolding ? 60 : 40,
                          spreadRadius: _isHolding ? 25 : 15,
                        ),
                      ],
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (_isHolding) ...[
                            Text(
                              '$_countdown',
                              style: Theme.of(context)
                                  .textTheme
                                  .displayLarge
                                  ?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                            Text(
                              'Release to cancel',
                              style: TextStyle(
                                  color: Colors.white70, fontSize: 12),
                            ),
                          ] else ...[
                            const Icon(
                              Icons.emergency,
                              size: 60,
                              color: Colors.white,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'SOS',
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineLarge
                                  ?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 24),
                Text(
                  _isHolding
                      ? 'Keep holding...'
                      : 'Hold for 3 seconds to activate',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: _isHolding ? AppColors.sos : Colors.grey,
                        fontWeight:
                            _isHolding ? FontWeight.bold : FontWeight.normal,
                      ),
                ),

                const SizedBox(height: 48),

                // Emergency contacts summary
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.people, color: AppColors.primary),
                            const SizedBox(width: 8),
                            Text(
                              'Emergency Contacts',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                            const Spacer(),
                            Text(
                              '${contacts.length}/5',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (contacts.isEmpty)
                          Text(
                            'No emergency contacts added yet',
                            style: TextStyle(color: Colors.grey),
                          )
                        else
                          ...contacts.take(3).map((c) => Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 4),
                                child: Row(
                                  children: [
                                    Icon(Icons.person,
                                        size: 16, color: Colors.grey),
                                    const SizedBox(width: 8),
                                    Text(c.name),
                                    if (c.isPrimary) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Color.fromRGBO(
                                              AppColors.primary.r.toInt(),
                                              AppColors.primary.g.toInt(),
                                              AppColors.primary.b.toInt(),
                                              0.1),
                                          borderRadius:
                                              BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          'Primary',
                                          style: const TextStyle(
                                              fontSize: 10,
                                              color: AppColors.primary),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              )),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // What happens section
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'When you trigger SOS:',
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                        ),
                        const SizedBox(height: 12),
                        _buildInfoRow(
                          Icons.location_on,
                          'Available location is included in emergency messages',
                        ),
                        _buildInfoRow(
                          Icons.sms,
                          'Guardian attempts SMS dispatch to each configured contact',
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}
