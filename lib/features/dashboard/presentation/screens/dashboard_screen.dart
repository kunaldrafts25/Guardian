import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:guardian/app/routes.dart';
import 'package:guardian/core/providers/auth_provider.dart';
import 'package:guardian/core/providers/contacts_provider.dart';
import 'package:guardian/core/providers/emergency_provider.dart';
import 'package:guardian/core/providers/settings_provider.dart';
import 'package:guardian/core/widgets/guardian_ui.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final contacts = ref.watch(contactsProvider).contacts;
    final emergency = ref.watch(emergencyProvider);
    final locationMode = ref.watch(locationModeProvider);
    final isResponder = ref.watch(authServiceProvider).isResponder;
    final firstName = _firstName(user?.displayName);

    final status = emergency.isActive
        ? _ProtectionStatus(
            title: 'Incident active',
            description: 'Emergency actions and live status are available now.',
            actionLabel: 'View incident',
            tone: GuardianStatusTone.emergency,
            icon: Icons.emergency_rounded,
            onTap: () => context.push(Routes.emergency),
          )
        : contacts.isEmpty
            ? _ProtectionStatus(
                title: 'Action needed',
                description:
                    'Add at least one emergency contact before an SOS.',
                actionLabel: 'Add contact',
                tone: GuardianStatusTone.warning,
                icon: Icons.person_add_alt_1_rounded,
                onTap: () => context.push(Routes.contacts),
              )
            : _ProtectionStatus(
                title: 'Protection ready',
                description:
                    '${contacts.length} contact${contacts.length == 1 ? '' : 's'} ready • ${_humanize(locationMode.name)} location',
                actionLabel: 'Review',
                tone: GuardianStatusTone.success,
                icon: Icons.verified_user_outlined,
                onTap: () => context.push(Routes.readiness),
              );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Guardian'),
        actions: [
          IconButton(
            tooltip: 'Profile',
            icon: const Icon(Icons.account_circle_outlined),
            onPressed: () => context.push(Routes.profile),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            Text(
              firstName == null ? 'Your safety at a glance' : 'Hi, $firstName',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 4),
            Text(
              'Everything important, without the noise.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 20),
            _ProtectionStatusCard(status: status),
            const SizedBox(height: 20),
            _EmergencyEntry(
              active: emergency.isActive,
              onTap: () => context.push(Routes.emergency),
            ),
            const SizedBox(height: 24),
            const GuardianSectionHeader(title: 'Quick actions'),
            const SizedBox(height: 10),
            GuardianActionCard(
              icon: Icons.timer_outlined,
              title: 'Start a safety check-in',
              description:
                  'Set a time for Guardian to check that you are safe.',
              onTap: () => context.push(Routes.quickActions),
            ),
            const SizedBox(height: 10),
            GuardianActionCard(
              icon: Icons.people_outline_rounded,
              title: 'View your circle',
              description: contacts.isEmpty
                  ? 'Add people who should receive emergency updates.'
                  : '${contacts.length} emergency contact${contacts.length == 1 ? '' : 's'} configured.',
              onTap: () => context.push(Routes.contacts),
              tone: contacts.isEmpty
                  ? GuardianStatusTone.warning
                  : GuardianStatusTone.neutral,
            ),
            const SizedBox(height: 24),
            const GuardianSectionHeader(title: 'More safety tools'),
            const SizedBox(height: 10),
            GuardianActionCard(
              icon: Icons.health_and_safety_outlined,
              title: 'Safety readiness',
              description: 'Review permissions, contacts, and service access.',
              onTap: () => context.push(Routes.readiness),
            ),
            const SizedBox(height: 10),
            GuardianActionCard(
              icon: Icons.location_on_outlined,
              title: 'Saved places',
              description: 'Manage locations that matter to your safety.',
              onTap: () => context.push(Routes.safeZones),
            ),
            if (isResponder) ...[
              const SizedBox(height: 10),
              GuardianActionCard(
                icon: Icons.volunteer_activism_outlined,
                title: 'Responder requests',
                description:
                    'Review nearby invitations you are allowed to see.',
                onTap: () => context.push(Routes.responderInbox),
                tone: GuardianStatusTone.success,
              ),
            ],
          ],
        ),
      ),
    );
  }

  static String? _firstName(String? displayName) {
    final value = displayName?.trim();
    if (value == null || value.isEmpty) return null;
    return value.split(RegExp(r'\s+')).first;
  }

  static String _humanize(String value) {
    if (value.isEmpty) return value;
    return '${value[0].toUpperCase()}${value.substring(1).toLowerCase()}';
  }
}

class _ProtectionStatus {
  const _ProtectionStatus({
    required this.title,
    required this.description,
    required this.actionLabel,
    required this.tone,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String description;
  final String actionLabel;
  final GuardianStatusTone tone;
  final IconData icon;
  final VoidCallback onTap;
}

class _ProtectionStatusCard extends StatelessWidget {
  const _ProtectionStatusCard({required this.status});

  final _ProtectionStatus status;

  @override
  Widget build(BuildContext context) {
    final toneColor = guardianToneColor(context, status.tone);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: toneColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(status.icon, color: toneColor),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GuardianStatusPill(label: status.title, tone: status.tone),
                  const SizedBox(height: 10),
                  Text(
                    status.description,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: status.onTap,
                      child: Text(status.actionLabel),
                    ),
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

class _EmergencyEntry extends StatelessWidget {
  const _EmergencyEntry({required this.active, required this.onTap});

  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final emergency = Theme.of(context).colorScheme.error;
    return Semantics(
      button: true,
      label: active
          ? 'Open active emergency incident'
          : 'Open emergency controls. You will need to hold to send an SOS.',
      child: Card(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Column(
              children: [
                Container(
                  width: 144,
                  height: 144,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: emergency,
                    border: Border.all(
                      color: emergency.withValues(alpha: 0.25),
                      width: 8,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.sos_rounded,
                          size: 46, color: Colors.white),
                      const SizedBox(height: 4),
                      Text(
                        active ? 'VIEW' : 'SOS',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1,
                            ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  active ? 'Emergency incident is active' : 'Emergency help',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  active
                      ? 'Open the incident to see confirmed actions.'
                      : 'Open, then hold to prevent accidental alerts.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
