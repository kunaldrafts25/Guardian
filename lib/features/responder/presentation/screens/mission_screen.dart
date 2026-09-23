import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:guardian/core/services/responder_service.dart';
import 'package:url_launcher/url_launcher.dart';

class MissionScreen extends StatefulWidget {
  final String missionId;

  const MissionScreen({super.key, required this.missionId});

  @override
  State<MissionScreen> createState() => _MissionScreenState();
}

class _MissionScreenState extends State<MissionScreen> {
  ResponderMission? _mission;
  bool _loading = true;
  bool _acting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final mission =
          await ResponderService.instance.getMission(widget.missionId);
      if (mounted) setState(() => _mission = mission);
    } catch (error) {
      if (mounted) setState(() => _error = _cleanError(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _accept() async {
    final mission = _mission!;
    await _run(() async {
      final result =
          await ResponderService.instance.acceptInvitation(mission.incidentId);
      _mission = result.mission;
      if (!result.grantAvailable && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Mission was already accepted; no new location grant was issued.'),
          ),
        );
      }
    });
  }

  Future<void> _confirmAccept() async {
    final accepted = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Before you accept',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              const Text(
                'Guardian will request a short-lived precise-location grant for navigation. Access is revoked when you arrive, withdraw, or the incident ends.',
              ),
              const SizedBox(height: 12),
              const Text(
                'Stay in public areas. Do not confront anyone. Call emergency services if immediate danger is visible.',
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Accept and continue'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Not now'),
              ),
            ],
          ),
        ),
      ),
    );
    if (accepted == true) await _accept();
  }

  Future<void> _callEmergencyServices() async {
    final uri = Uri(scheme: 'tel', path: '112');
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        setState(() =>
            _error = 'Unable to open the phone dialer. Call 112 manually.');
      }
    }
  }

  Future<void> _transition(String status) async {
    await _run(() async {
      _mission = await ResponderService.instance.transition(
        _mission!.missionId,
        status,
      );
    });
  }

  Future<void> _navigate() async {
    await _run(() async {
      final location =
          await ResponderService.instance.getAuthorizedLocation(_mission!);
      final Uri uri;
      if (!kIsWeb && Platform.isIOS) {
        uri = Uri.parse(
          'https://maps.apple.com/?daddr=${location.latitude},${location.longitude}&dirflg=w',
        );
      } else {
        uri = Uri.parse(
          'geo:${location.latitude},${location.longitude}?q=${location.latitude},${location.longitude}(Guardian%20assistance)',
        );
      }
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched) {
        final webUri = Uri.parse(
          'https://www.google.com/maps/dir/?api=1&destination=${location.latitude},${location.longitude}',
        );
        if (!await launchUrl(webUri, mode: LaunchMode.externalApplication)) {
        throw StateError('No navigation application is available.');
        }
      }
    });
  }

  Future<void> _run(Future<void> Function() operation) async {
    if (_acting) return;
    setState(() {
      _acting = true;
      _error = null;
    });
    try {
      await operation();
    } catch (error) {
      if (mounted) setState(() => _error = _cleanError(error));
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Responder mission')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _mission == null
              ? _Failure(
                  message: _error ?? 'Mission is unavailable', retry: _load)
              : _content(context, _mission!),
    );
  }

  Widget _content(BuildContext context, ResponderMission mission) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  mission.status.replaceAll('_', ' '),
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Stay in public areas, do not confront anyone, and contact local emergency services if immediate danger is visible.',
                ),
                if (mission.approximateLatitude != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Approximate area before acceptance: '
                    '${mission.approximateLatitude!.toStringAsFixed(2)}, '
                    '${mission.approximateLongitude!.toStringAsFixed(2)}',
                  ),
                ],
                const SizedBox(height: 8),
                Text('Transport evidence: ${mission.deliveryStatus}'),
              ],
            ),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(_error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error)),
        ],
        const SizedBox(height: 20),
        ..._actions(mission),
        const SizedBox(height: 24),
        OutlinedButton.icon(
          onPressed: _acting ? null : _callEmergencyServices,
          icon: const Icon(Icons.local_police_outlined),
          label: const Text('Call emergency services'),
        ),
        if (_acting) ...[
          const SizedBox(height: 16),
          const Center(child: CircularProgressIndicator()),
        ],
      ],
    );
  }

  List<Widget> _actions(ResponderMission mission) => switch (mission.status) {
        'INVITED' => [
            FilledButton.icon(
              onPressed: _acting ? null : _confirmAccept,
              icon: const Icon(Icons.volunteer_activism),
              label: const Text('Accept request'),
            ),
          ],
        'ACCEPTED' => [
            FilledButton.icon(
              onPressed: _acting ? null : () => _transition('EN_ROUTE'),
              icon: const Icon(Icons.directions_walk),
              label: const Text('Start journey'),
            ),
            TextButton(
              onPressed: _acting ? null : () => _transition('WITHDRAWN'),
              child: const Text('Withdraw safely'),
            ),
          ],
        'EN_ROUTE' => [
            FilledButton.icon(
              onPressed: _acting ? null : _navigate,
              icon: const Icon(Icons.navigation),
              label: const Text('Open secure navigation'),
            ),
            OutlinedButton.icon(
              onPressed: _acting ? null : () => _transition('ARRIVED'),
              icon: const Icon(Icons.location_on),
              label: const Text('I have arrived'),
            ),
            TextButton(
              onPressed: _acting ? null : () => _transition('WITHDRAWN'),
              child: const Text('Withdraw safely'),
            ),
          ],
        'ARRIVED' => [
            FilledButton.icon(
              onPressed: _acting ? null : () => _transition('COMPLETED'),
              icon: const Icon(Icons.task_alt),
              label: const Text('Complete mission'),
            ),
            TextButton(
              onPressed: _acting ? null : () => _transition('WITHDRAWN'),
              child: const Text('Withdraw safely'),
            ),
          ],
        _ => [
            const Card(
              child: ListTile(
                leading: Icon(Icons.lock_outline),
                title: Text('This mission is closed'),
                subtitle: Text('Precise-location access has been revoked.'),
              ),
            ),
          ],
      };

  String _cleanError(Object error) =>
      error.toString().replaceFirst('Exception: ', '');
}

class _Failure extends StatelessWidget {
  final String message;
  final Future<void> Function() retry;

  const _Failure({required this.message, required this.retry});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48),
              const SizedBox(height: 12),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              OutlinedButton(onPressed: retry, child: const Text('Retry')),
            ],
          ),
        ),
      );
}
