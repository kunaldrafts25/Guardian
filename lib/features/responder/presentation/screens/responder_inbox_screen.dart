import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:guardian/app/routes.dart';
import 'package:guardian/core/services/responder_service.dart';

class ResponderInboxScreen extends StatefulWidget {
  const ResponderInboxScreen({super.key});

  @override
  State<ResponderInboxScreen> createState() => _ResponderInboxScreenState();
}

class _ResponderInboxScreenState extends State<ResponderInboxScreen> {
  late Future<List<ResponderMission>> _missions;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _missions = ResponderService.instance.listMissions();
  }

  Future<void> _refresh() async {
    setState(_reload);
    await _missions;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Responder requests')),
      body: FutureBuilder<List<ResponderMission>>(
        future: _missions,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _InboxMessage(
              icon: Icons.verified_user_outlined,
              title: 'Responder access unavailable',
              message: _cleanError(snapshot.error!),
              action: _refresh,
            );
          }
          final missions = snapshot.data ?? const [];
          if (missions.isEmpty) {
            return _InboxMessage(
              icon: Icons.notifications_none,
              title: 'No requests right now',
              message:
                  'Only time-limited requests selected for your approved account appear here.',
              action: _refresh,
            );
          }
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: missions.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final mission = missions[index];
                return Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      child: Icon(
                        mission.status == 'INVITED'
                            ? Icons.notification_important_outlined
                            : Icons.health_and_safety_outlined,
                      ),
                    ),
                    title: Text(_statusLabel(mission.status)),
                    subtitle: Text(_description(mission)),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push(
                      '${Routes.responderMission}/${Uri.encodeComponent(mission.missionId)}',
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  String _description(ResponderMission mission) {
    final lat = mission.approximateLatitude;
    final lng = mission.approximateLongitude;
    if (lat != null && lng != null) {
      return 'Approximate area available • exact location is hidden';
    }
    return 'Exact location remains hidden until acceptance';
  }

  String _statusLabel(String status) => switch (status) {
        'INVITED' => 'Nearby assistance requested',
        'ACCEPTED' => 'Accepted — ready to depart',
        'EN_ROUTE' => 'Navigation active',
        'ARRIVED' => 'Arrival reported',
        'COMPLETED' => 'Mission completed',
        'WITHDRAWN' => 'Mission withdrawn',
        'CANCELLED' => 'Request cancelled',
        'EXPIRED' => 'Request expired',
        _ => status.replaceAll('_', ' '),
      };

  String _cleanError(Object error) =>
      error.toString().replaceFirst('Exception: ', '');
}

class _InboxMessage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final Future<void> Function() action;

  const _InboxMessage({
    required this.icon,
    required this.title,
    required this.message,
    required this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56),
            const SizedBox(height: 16),
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: action,
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh'),
            ),
          ],
        ),
      ),
    );
  }
}
