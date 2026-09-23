import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:guardian/app/theme/app_theme.dart';
import 'package:guardian/core/providers/contacts_provider.dart';
import 'package:guardian/core/services/aws_incident_service.dart';
import 'package:guardian/core/services/aws_auth_service.dart';
import 'package:guardian/core/services/aws_sns_service.dart';
import 'package:guardian/core/services/safety_service_bridge.dart';
import 'package:guardian/core/utils/permission_utils.dart';
import 'package:permission_handler/permission_handler.dart';

class ReadinessScreen extends ConsumerStatefulWidget {
  const ReadinessScreen({super.key});

  @override
  ConsumerState<ReadinessScreen> createState() => _ReadinessScreenState();
}

class _ReadinessScreenState extends ConsumerState<ReadinessScreen> {
  late Future<_Readiness> _readiness;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _readiness = _check();
  }

  Future<_Readiness> _check() async {
    final isAndroid = !kIsWeb && Platform.isAndroid;
    final location = await Permission.location.status;
    final notifications = await Permission.notification.status;
    final sms = isAndroid ? await Permission.sms.status : null;
    final bridge = SafetyServiceBridge();
    final serviceRunning = isAndroid ? await bridge.isRunning() : null;
    final batteryExempt =
        isAndroid ? await bridge.isBatteryOptimizationIgnored() : null;
    final backend = await AwsIncidentService.instance.checkHealth();
    return _Readiness(
      location: location.isGranted,
      notifications: notifications.isGranted,
      sms: sms?.isGranted,
      serviceRunning: serviceRunning,
      batteryExempt: batteryExempt,
      pushRegistered: AwsSnsService.deviceToken != null,
      backendReachable: backend,
    );
  }

  Future<void> _refresh() async {
    setState(_reload);
    await _readiness;
  }

  Future<void> _sendContactTest() async {
    final contact = ref.read(contactsProvider).primaryContact;
    if (contact == null) return;
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Send a real test SMS?'),
            content: Text(
              'Guardian will send one message to ${contact.name} (${contact.phone}). '
              'It will be clearly labelled “TEST — no emergency”. Carrier charges may apply.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Send test'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed) return;
    try {
      final result = await AwsAuthService.instance.post(
        '/notifications/contact-test',
        {'contact_id': contact.id},
      );
      if (!mounted) return;
      final accepted = result['provider_accepted'] == true;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            accepted
                ? 'The SMS provider accepted the test message. Delivery is not guaranteed.'
                : 'The test message was not accepted: ${result['error'] ?? 'unknown error'}',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(error.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final contactCount = ref.watch(contactsCountProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Protection readiness')),
      body: FutureBuilder<_Readiness>(
        future: _readiness,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final readiness = snapshot.data!;
          final checks = [
            _Check(
                'Trusted contact',
                contactCount > 0,
                contactCount > 0
                    ? '$contactCount configured'
                    : 'Add at least one real contact'),
            _Check(
                'Location permission',
                readiness.location,
                readiness.location
                    ? 'Available'
                    : 'Required for emergency location'),
            _Check(
                'Notification permission',
                readiness.notifications,
                readiness.notifications
                    ? 'Available'
                    : 'Required for responder and incident updates'),
            if (readiness.sms != null)
              _Check(
                  'SMS permission',
                  readiness.sms!,
                  readiness.sms!
                      ? 'Available'
                      : 'Device-side SMS fallback is disabled'),
            if (readiness.serviceRunning != null)
              _Check('Android protection service', readiness.serviceRunning!,
                  readiness.serviceRunning! ? 'Running' : 'Not running'),
            if (readiness.batteryExempt != null)
              _Check(
                  'Battery optimization',
                  readiness.batteryExempt!,
                  readiness.batteryExempt!
                      ? 'Unrestricted'
                      : 'May delay background protection'),
            _Check(
                'Push registration',
                readiness.pushRegistered,
                readiness.pushRegistered
                    ? 'Device token registered'
                    : 'No device push token'),
            _Check(
                'Guardian API',
                readiness.backendReachable,
                readiness.backendReachable
                    ? 'Reachable'
                    : 'Unavailable — local SOS remains usable'),
          ];
          final ready = checks.every((check) => check.passed);
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  color: ready
                      ? AppColors.brandContainer.withValues(alpha: 0.4)
                      : AppColors.emergencyContainer.withValues(alpha: 0.4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(
                      color: ready ? AppColors.brand : AppColors.emergency,
                      width: 1.5,
                    ),
                  ),
                  child: ListTile(
                    leading: Icon(
                      ready
                          ? Icons.verified_user_rounded
                          : Icons.warning_amber_rounded,
                      color: ready ? AppColors.brand : AppColors.emergency,
                      size: 32,
                    ),
                    title: Text(
                      ready ? 'Protection ready' : 'Protection degraded',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color:
                                ready ? AppColors.brand : AppColors.emergency,
                          ),
                    ),
                    subtitle: const Text(
                      'Guardian reports current evidence only; it does not guarantee delivery or universal hardware-trigger support.',
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                for (final check in checks)
                  Card(
                    child: ListTile(
                      leading: Icon(
                        check.passed
                            ? Icons.check_circle_rounded
                            : Icons.cancel_outlined,
                        color: check.passed
                            ? AppColors.success
                            : AppColors.warning,
                      ),
                      title: Text(check.name),
                      subtitle: Text(check.detail),
                    ),
                  ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: PermissionUtils.openAppSettings,
                  icon: const Icon(Icons.settings),
                  label: const Text('Open system settings'),
                ),
                if (contactCount > 0) ...[
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed: _sendContactTest,
                    icon: const Icon(Icons.sms_outlined),
                    label: const Text('Send non-emergency contact test'),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Check {
  final String name;
  final bool passed;
  final String detail;

  const _Check(this.name, this.passed, this.detail);
}

class _Readiness {
  final bool location;
  final bool notifications;
  final bool? sms;
  final bool? serviceRunning;
  final bool? batteryExempt;
  final bool pushRegistered;
  final bool backendReachable;

  const _Readiness({
    required this.location,
    required this.notifications,
    required this.sms,
    required this.serviceRunning,
    required this.batteryExempt,
    required this.pushRegistered,
    required this.backendReachable,
  });
}
