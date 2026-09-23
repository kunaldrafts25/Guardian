import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:guardian/app/routes.dart';
import 'package:guardian/app/theme/app_theme.dart';
import 'package:guardian/core/providers/auth_provider.dart';
import 'package:guardian/core/providers/contacts_provider.dart';
import 'package:guardian/core/providers/emergency_provider.dart';
import 'package:guardian/core/providers/settings_provider.dart';
import 'package:guardian/core/widgets/guardian_ui.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulseScale;
  late final Animation<double> _pulseOpacity;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

    _pulseScale = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _pulseOpacity = Tween<double>(begin: 0.28, end: 0.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final contacts = ref.watch(contactsProvider).contacts;
    final emergency = ref.watch(emergencyProvider);
    final locationMode = ref.watch(locationModeProvider);
    final isResponder = ref.watch(authServiceProvider).isResponder;
    final firstName = _firstName(user?.displayName);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final status = emergency.isActive
        ? _ProtectionStatus(
            title: 'Incident active',
            subtitle: 'Emergency dispatch and live coordinates broadcasting.',
            badgeLabel: 'Active SOS',
            tone: GuardianStatusTone.emergency,
            icon: Icons.emergency_rounded,
            onTap: () => context.push(Routes.emergency),
          )
        : contacts.isEmpty
            ? _ProtectionStatus(
                title: 'Setup incomplete',
                subtitle: 'Add at least one emergency contact before an SOS.',
                badgeLabel: 'Action needed',
                tone: GuardianStatusTone.warning,
                icon: Icons.person_add_alt_1_rounded,
                onTap: () => context.push(Routes.contacts),
              )
            : _ProtectionStatus(
                title: 'Protection ready & active',
                subtitle:
                    '${contacts.length} contact${contacts.length == 1 ? '' : 's'} ready • ${_humanize(locationMode.name)} location',
                badgeLabel: 'Zone secure',
                tone: GuardianStatusTone.success,
                icon: Icons.verified_user_outlined,
                onTap: () => context.push(Routes.readiness),
              );

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: isDark ? AppColors.brandContainerDark : AppColors.brandContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: SvgPicture.asset(
                  isDark ? 'assets/icons/guardian_symbol_dark.svg' : 'assets/icons/guardian_symbol.svg',
                  width: 20,
                  height: 20,
                  placeholderBuilder: (ctx) => Icon(
                    Icons.shield_rounded,
                    size: 18,
                    color: isDark ? AppColors.brandDark : AppColors.brand,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'Guardian',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Profile and Settings',
            icon: CircleAvatar(
              radius: 16,
              backgroundColor: isDark ? AppColors.brandContainerDark : AppColors.brandContainer,
              child: Text(
                firstName != null && firstName.isNotEmpty
                    ? firstName[0].toUpperCase()
                    : 'G',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: isDark ? AppColors.brandDark : AppColors.brand,
                ),
              ),
            ),
            onPressed: () => context.push(Routes.profile),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        top: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isCompact = constraints.maxWidth < 360;
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                // Greeting and reassurance
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            firstName == null ? 'Hi there' : 'Hi, $firstName',
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              Container(
                                width: 7,
                                height: 7,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isDark ? AppColors.brandDark : AppColors.brand,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'Monitored safe space • Calm protection',
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Reassuring Protection Status Banner
                _ProtectionBanner(status: status),
                const SizedBox(height: 16),

                // Centered Prominent SOS Emergency Card
                _SosEmergencyCard(
                  active: emergency.isActive,
                  pulseScale: _pulseScale,
                  pulseOpacity: _pulseOpacity,
                  onTap: () {
                    HapticFeedback.heavyImpact();
                    context.push(Routes.emergency);
                  },
                ),
                const SizedBox(height: 18),

                // Bento Quick Action Grid (Responsive: 2-column or stacked for <360px)
                if (isCompact) ...[
                  _CheckInBentoCard(onTap: () => context.push(Routes.quickActions)),
                  const SizedBox(height: 10),
                  _CircleBentoCard(
                    contactsCount: contacts.length,
                    onTap: () => context.push(Routes.contacts),
                  ),
                ] else ...[
                  Row(
                    children: [
                      Expanded(
                        child: _CheckInBentoCard(onTap: () => context.push(Routes.quickActions)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _CircleBentoCard(
                          contactsCount: contacts.length,
                          onTap: () => context.push(Routes.contacts),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 20),

                // Safety Tools Section Header
                const GuardianSectionHeader(title: 'Safety diagnostics & tools'),
                const SizedBox(height: 10),

                // Readiness Diagnostic
                GuardianActionCard(
                  icon: Icons.health_and_safety_outlined,
                  title: 'Protection readiness',
                  description: '6 of 7 systems operational • Verify hardware and SMS durability.',
                  onTap: () => context.push(Routes.readiness),
                  tone: GuardianStatusTone.neutral,
                ),
                const SizedBox(height: 10),

                // Safe Zones
                GuardianActionCard(
                  icon: Icons.location_on_outlined,
                  title: 'Saved places & zones',
                  description: 'Manage safe routes, geofences, and quiet areas.',
                  onTap: () => context.push(Routes.safeZones),
                ),

                // Volunteer responder mission inbox
                if (isResponder) ...[
                  const SizedBox(height: 10),
                  GuardianActionCard(
                    icon: Icons.volunteer_activism_outlined,
                    title: 'Responder requests',
                    description: 'Review nearby invitations you are authorized to see.',
                    onTap: () => context.push(Routes.responderInbox),
                    tone: GuardianStatusTone.success,
                  ),
                ],
              ],
            );
          },
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
    required this.subtitle,
    required this.badgeLabel,
    required this.tone,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final String badgeLabel;
  final GuardianStatusTone tone;
  final IconData icon;
  final VoidCallback onTap;
}

class _ProtectionBanner extends StatelessWidget {
  const _ProtectionBanner({required this.status});

  final _ProtectionStatus status;

  @override
  Widget build(BuildContext context) {
    final toneColor = guardianToneColor(context, status.tone);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final containerColor = status.tone == GuardianStatusTone.emergency
        ? (isDark ? AppColors.emergencyContainerDark : AppColors.emergencyContainer)
        : status.tone == GuardianStatusTone.warning
            ? (isDark ? const Color(0xFF422B14) : const Color(0xFFFAF1E3))
            : (isDark ? AppColors.brandContainerDark : AppColors.brandContainer);

    return InkWell(
      onTap: status.onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: containerColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: toneColor.withValues(alpha: 0.25),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: toneColor,
                shape: BoxShape.circle,
              ),
              child: Icon(status.icon, size: 18, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    status.title,
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    status.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontSize: 12,
                      color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceDark : AppColors.surface,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: isDark ? AppColors.borderDark : AppColors.border,
                ),
              ),
              child: Text(
                status.badgeLabel,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: toneColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SosEmergencyCard extends StatelessWidget {
  const _SosEmergencyCard({
    required this.active,
    required this.pulseScale,
    required this.pulseOpacity,
    required this.onTap,
  });

  final bool active;
  final Animation<double> pulseScale;
  final Animation<double> pulseOpacity;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final emergencyColor = theme.colorScheme.error;

    return Semantics(
      button: true,
      label: active
          ? 'Emergency incident is active. Tap to view live incident details and controls.'
          : 'Emergency SOS. Hold to activate emergency dispatch.',
      child: Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(
            color: active
                ? emergencyColor.withValues(alpha: 0.6)
                : (isDark ? AppColors.borderDark : AppColors.border),
            width: active ? 1.5 : 1.0,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
          child: Column(
            children: [
              // Top security note
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'EMERGENCY ASSISTANCE',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                      color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.surfaceMutedDark : AppColors.surfaceMuted,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.lock_outline_rounded,
                          size: 11,
                          color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Pin Lock Armed',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Animated Concentric Pulse Button
              Center(
                child: SizedBox(
                  width: 156,
                  height: 156,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Animated pulse ring 1
                      AnimatedBuilder(
                        animation: pulseScale,
                        builder: (context, child) {
                          return Transform.scale(
                            scale: pulseScale.value,
                            child: Container(
                              width: 156,
                              height: 156,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: emergencyColor.withValues(alpha: pulseOpacity.value),
                              ),
                            ),
                          );
                        },
                      ),
                      // Inner soft ring
                      Container(
                        width: 130,
                        height: 130,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: emergencyColor.withValues(alpha: 0.16),
                        ),
                      ),
                      // Primary SOS Circle Button
                      Material(
                        color: emergencyColor,
                        shape: const CircleBorder(),
                        elevation: 4,
                        shadowColor: emergencyColor.withValues(alpha: 0.4),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: onTap,
                          child: Container(
                            width: 108,
                            height: 108,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isDark
                                    ? AppColors.surfaceDark
                                    : AppColors.surface,
                                width: 3.5,
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  active ? Icons.warning_amber_rounded : Icons.crisis_alert_rounded,
                                  size: 34,
                                  color: Colors.white,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  active ? 'VIEW' : 'SOS',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Reassurance guidance text
              Text(
                active ? 'Emergency incident is active' : 'Press and hold for SOS',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                active
                    ? 'Review active dispatch, live GPS coordinates, and evidence.'
                    : 'Hold 3s to alert emergency contacts & dispatch with real-time location.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 14),

              // Delay safety note
              Container(
                padding: const EdgeInsets.only(top: 10),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      color: isDark ? AppColors.borderDark : AppColors.dividerColor,
                    ),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.verified_user_outlined,
                      size: 13,
                      color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'Accidental tap safety delay enabled',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CheckInBentoCard extends StatelessWidget {
  const _CheckInBentoCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = isDark ? AppColors.brandDark : AppColors.brand;

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isDark ? AppColors.borderDark : AppColors.border,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: isDark ? AppColors.surfaceMutedDark : AppColors.surfaceMuted,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.timer_outlined, size: 20, color: primary),
              ),
              const SizedBox(height: 12),
              Text(
                'Safety check-in',
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                'Automated timer for your walk or evening transit.',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontSize: 11,
                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Set timer',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: primary,
                    ),
                  ),
                  Icon(Icons.arrow_forward_rounded, size: 14, color: primary),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CircleBentoCard extends StatelessWidget {
  const _CircleBentoCard({
    required this.contactsCount,
    required this.onTap,
  });

  final int contactsCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = isDark ? AppColors.brandDark : AppColors.brand;
    final earth = isDark ? AppColors.secondaryAccentDark : AppColors.secondaryAccent;

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isDark ? AppColors.borderDark : AppColors.border,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: earth.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.people_outline_rounded, size: 20, color: earth),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: contactsCount > 0
                          ? (isDark ? AppColors.brandContainerDark : AppColors.brandContainer)
                          : (isDark ? const Color(0xFF422B14) : const Color(0xFFFAF1E3)),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      contactsCount > 0 ? '$contactsCount Ready' : '0 Added',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: contactsCount > 0
                            ? primary
                            : (isDark ? AppColors.warningDark : AppColors.warning),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Guardian circle',
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                contactsCount > 0
                    ? 'Trusted guardians notified instantly if SOS fires.'
                    : 'Add trusted guardians who receive live alerts.',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontSize: 11,
                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'View circle',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: primary,
                    ),
                  ),
                  Icon(Icons.arrow_forward_rounded, size: 14, color: primary),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}


