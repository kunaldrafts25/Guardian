import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:guardian/app/theme/app_theme.dart';
import 'package:guardian/core/providers/contacts_provider.dart';
import 'package:guardian/core/providers/emergency_provider.dart';
import 'package:guardian/core/providers/sos_settings_provider.dart';
import 'package:guardian/core/providers/sos_trigger_provider.dart';
import 'package:guardian/core/services/sos_sound_service.dart';
import 'package:guardian/core/widgets/guardian_ui.dart';

class EmergencyScreen extends ConsumerStatefulWidget {
  const EmergencyScreen({super.key});

  @override
  ConsumerState<EmergencyScreen> createState() => _EmergencyScreenState();
}

class _EmergencyScreenState extends ConsumerState<EmergencyScreen> {
  Timer? _countdownTimer;
  int _countdown = 0;
  bool _isHolding = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(sosTriggerProvider);
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _startHold() {
    if (_isHolding) return;
    final settings = ref.read(sosSettingsProvider);
    if (settings.vibrationEnabled) HapticFeedback.mediumImpact();
    setState(() {
      _isHolding = true;
      _countdown = settings.countdownSeconds;
    });
    ref.read(emergencyProvider.notifier).startCountdown();

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || !_isHolding) {
        timer.cancel();
        return;
      }
      if (_countdown > 1) {
        setState(() => _countdown--);
        ref.read(emergencyProvider.notifier).updateCountdown(_countdown);
        if (settings.vibrationEnabled) HapticFeedback.lightImpact();
        if (settings.soundEnabled) SosSoundService.instance.playCountdownBeep();
      } else {
        _activateEmergency();
      }
    });
  }

  void _activateEmergency() {
    _countdownTimer?.cancel();
    final settings = ref.read(sosSettingsProvider);
    if (settings.vibrationEnabled) HapticFeedback.heavyImpact();
    if (settings.soundEnabled) SosSoundService.instance.playSOSActivation();
    ref.read(emergencyProvider.notifier).triggerEmergency();
    if (mounted) {
      setState(() {
        _isHolding = false;
        _countdown = 0;
      });
    }
  }

  void _cancelHold() {
    if (!_isHolding) return;
    _countdownTimer?.cancel();
    ref.read(emergencyProvider.notifier).cancelCountdown();
    setState(() {
      _isHolding = false;
      _countdown = 0;
    });
  }

  Future<void> _confirmSafe() async {
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.outline,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text('Confirm you are safe',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(
                'This ends live emergency updates. Only confirm when you no longer need help.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('I am safe — end incident'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Keep incident active'),
              ),
            ],
          ),
        ),
      ),
    );
    if (confirmed == true) {
      ref.read(emergencyProvider.notifier).cancelEmergency();
    }
  }

  @override
  Widget build(BuildContext context) {
    final emergency = ref.watch(emergencyProvider);
    final contacts = ref.watch(contactsProvider).contacts;
    final settings = ref.watch(sosSettingsProvider);

    return PopScope(
      canPop: !emergency.isActive,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && emergency.isActive) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'The incident stays active. Confirm “I am safe” to end it.'),
            ),
          );
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(emergency.isActive ? 'Active incident' : 'Emergency SOS'),
        ),
        body: SafeArea(
          top: false,
          child: emergency.isActive
              ? _ActiveIncident(
                  emergency: emergency,
                  onCallPolice: () => ref
                      .read(emergencyProvider.notifier)
                      .callEmergencyServices(),
                  onShareLocation: () =>
                      ref.read(emergencyProvider.notifier).shareLocation(),
                  onSafe: _confirmSafe,
                )
              : emergency.state == SosState.error
                  ? _ErrorState(
                      message: emergency.errorMessage,
                      onRetry: () =>
                          ref.read(emergencyProvider.notifier).clearError(),
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                      children: [
                        Text(
                          _isHolding ? 'Keep holding' : 'Help is one hold away',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _isHolding
                              ? 'Release before the countdown ends to cancel.'
                              : 'Press and hold. Guardian will count down before sending the alert.',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                        const SizedBox(height: 36),
                        _HoldControl(
                          isHolding: _isHolding,
                          countdown: _countdown,
                          totalSeconds: settings.countdownSeconds,
                          onLongPressStart: _startHold,
                          onLongPressEnd: _cancelHold,
                        ),
                        if (_isHolding) ...[
                          const SizedBox(height: 16),
                          GuardianDangerButton(
                            label: 'Send now',
                            icon: Icons.send_rounded,
                            onPressed: _activateEmergency,
                          ),
                          const SizedBox(height: 4),
                          TextButton(
                            onPressed: _cancelHold,
                            child: const Text('Cancel countdown'),
                          ),
                        ],
                        const SizedBox(height: 36),
                        _ReadinessSummary(contactCount: contacts.length),
                        const SizedBox(height: 16),
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('What Guardian will do',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium),
                                const SizedBox(height: 14),
                                const _InfoRow(
                                  icon: Icons.location_on_outlined,
                                  text:
                                      'Capture the best available location evidence.',
                                ),
                                const SizedBox(height: 12),
                                const _InfoRow(
                                  icon: Icons.outbox_outlined,
                                  text:
                                      'Attempt dispatch to configured contacts and record provider acceptance.',
                                ),
                                const SizedBox(height: 12),
                                const _InfoRow(
                                  icon: Icons.sync_rounded,
                                  text:
                                      'Keep durable local evidence and sync queued actions when connectivity returns.',
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
        ),
      ),
    );
  }
}

class _HoldControl extends StatelessWidget {
  const _HoldControl({
    required this.isHolding,
    required this.countdown,
    required this.totalSeconds,
    required this.onLongPressStart,
    required this.onLongPressEnd,
  });

  final bool isHolding;
  final int countdown;
  final int totalSeconds;
  final VoidCallback onLongPressStart;
  final VoidCallback onLongPressEnd;

  @override
  Widget build(BuildContext context) {
    final emergency = Theme.of(context).colorScheme.error;
    final progress = totalSeconds <= 0
        ? 0.0
        : ((totalSeconds - countdown) / totalSeconds).clamp(0.0, 1.0);
    return Center(
      child: Semantics(
        button: true,
        label: isHolding
            ? 'SOS countdown. $countdown seconds remaining. Release to cancel.'
            : 'Hold to start SOS countdown',
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onLongPressStart: (_) => onLongPressStart(),
          onLongPressEnd: (_) => onLongPressEnd(),
          onLongPressCancel: onLongPressEnd,
          child: SizedBox(
            width: 208,
            height: 208,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox.expand(
                  child: CircularProgressIndicator(
                    value: isHolding ? progress : 0,
                    strokeWidth: 8,
                    backgroundColor: emergency.withValues(alpha: 0.15),
                    color: emergency,
                  ),
                ),
                Container(
                  width: 180,
                  height: 180,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: emergency,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (isHolding)
                        Text(
                          '$countdown',
                          style: Theme.of(context)
                              .textTheme
                              .displayLarge
                              ?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        )
                      else ...[
                        const Icon(Icons.sos_rounded,
                            size: 56, color: Colors.white),
                        const SizedBox(height: 6),
                        Text(
                          'HOLD',
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1.5,
                                  ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ReadinessSummary extends StatelessWidget {
  const _ReadinessSummary({required this.contactCount});

  final int contactCount;

  @override
  Widget build(BuildContext context) {
    final ready = contactCount > 0;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              ready
                  ? Icons.people_outline_rounded
                  : Icons.person_add_alt_1_rounded,
              color: guardianToneColor(
                context,
                ready ? GuardianStatusTone.success : GuardianStatusTone.warning,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ready
                        ? '$contactCount contacts configured'
                        : 'No contacts configured',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    ready
                        ? 'Guardian will attempt each configured delivery.'
                        : 'SOS can still record evidence, but nobody will receive a contact message.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActiveIncident extends StatelessWidget {
  const _ActiveIncident({
    required this.emergency,
    required this.onCallPolice,
    required this.onShareLocation,
    required this.onSafe,
  });

  final EmergencyState emergency;
  final Future<void> Function() onCallPolice;
  final Future<void> Function() onShareLocation;
  final VoidCallback onSafe;

  @override
  Widget build(BuildContext context) {
    final statuses = emergency.sosAlert?.contactStatuses ?? const [];
    final accepted = statuses.where((status) => status.smsSent).length;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      children: [
        Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: AppColors.emergency, width: 1.5),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const GuardianStatusPill(
                  label: 'Incident active',
                  tone: GuardianStatusTone.emergency,
                  icon: Icons.emergency_rounded,
                ),
                const SizedBox(height: 16),
                Text('Guardian is continuing emergency actions',
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                Text(
                  '$accepted of ${statuses.length} contact dispatches were accepted by the device or provider. Delivery is only confirmed when evidence arrives.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        GuardianDangerButton(
          label: 'Call emergency services',
          icon: Icons.local_police_outlined,
          onPressed: onCallPolice,
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: onShareLocation,
          icon: const Icon(Icons.share_location_outlined),
          label: const Text('Share current location'),
        ),
        const SizedBox(height: 24),
        const GuardianSectionHeader(title: 'Contact dispatch evidence'),
        const SizedBox(height: 10),
        if (statuses.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                  'No emergency contacts were configured for this incident.'),
            ),
          )
        else
          Card(
            child: Column(
              children: [
                for (var index = 0; index < statuses.length; index++) ...[
                  ListTile(
                    leading: Icon(
                      statuses[index].smsSent
                          ? Icons.outbox_rounded
                          : Icons.error_outline_rounded,
                      color: guardianToneColor(
                        context,
                        statuses[index].smsSent
                            ? GuardianStatusTone.success
                            : GuardianStatusTone.warning,
                      ),
                    ),
                    title: Text(statuses[index].contact.name),
                    subtitle: Text(
                      statuses[index].smsSent
                          ? 'Dispatch accepted — awaiting delivery evidence'
                          : 'Dispatch was not accepted',
                    ),
                  ),
                  if (index != statuses.length - 1)
                    const Divider(height: 1, indent: 56),
                ],
              ],
            ),
          ),
        if (emergency.currentLocation != null) ...[
          const SizedBox(height: 16),
          Card(
            child: ListTile(
              leading: const Icon(Icons.gps_fixed_rounded),
              title: const Text('Location evidence captured'),
              subtitle: const Text(
                'Precise coordinates are available to authorized emergency workflows.',
              ),
            ),
          ),
        ],
        const SizedBox(height: 28),
        ElevatedButton.icon(
          onPressed: onSafe,
          icon: const Icon(Icons.check_circle_outline_rounded),
          label: const Text('I am safe — End incident'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.brand,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 54),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      ],
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String? message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded,
                size: 56, color: Theme.of(context).colorScheme.error),
            const SizedBox(height: 16),
            Text('Emergency action needs attention',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              message ?? 'Guardian could not complete the requested action.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            ElevatedButton(onPressed: onRetry, child: const Text('Try again')),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 22, color: AppColors.brand),
        const SizedBox(width: 12),
        Expanded(
            child: Text(text, style: Theme.of(context).textTheme.bodyMedium)),
      ],
    );
  }
}
