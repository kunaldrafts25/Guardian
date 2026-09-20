import 'package:flutter/material.dart';
import 'package:guardian/core/services/aws_incident_service.dart';

class IncidentTimelineScreen extends StatefulWidget {
  final String incidentId;

  const IncidentTimelineScreen({super.key, required this.incidentId});

  @override
  State<IncidentTimelineScreen> createState() => _IncidentTimelineScreenState();
}

class _IncidentTimelineScreenState extends State<IncidentTimelineScreen> {
  late Future<_IncidentEvidence> _evidence;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _evidence = _loadEvidence();
  }

  Future<_IncidentEvidence> _loadEvidence() async {
    final service = AwsIncidentService.instance;
    final values = await Future.wait([
      service.getIncident(widget.incidentId),
      service.getIncidentTimeline(widget.incidentId),
    ]);
    return _IncidentEvidence(
      Map<String, dynamic>.from(values[0] as Map),
      (values[1] as List).cast<Map<String, dynamic>>(),
    );
  }

  Future<void> _refresh() async {
    setState(_reload);
    await _evidence;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Incident evidence')),
      body: FutureBuilder<_IncidentEvidence>(
        future: _evidence,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      snapshot.error.toString().replaceFirst('Exception: ', ''),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: _refresh,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }
          final evidence = snapshot.data!;
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.shield_outlined),
                    title: Text(
                        evidence.incident['state']?.toString() ?? 'UNKNOWN'),
                    subtitle: Text(
                      'Trigger: ${evidence.incident['event_type'] ?? 'unknown'}\n'
                      'Only persisted events and provider evidence are shown.',
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                if (evidence.timeline.isEmpty)
                  const Card(
                    child: ListTile(
                      title: Text('No timeline evidence available yet'),
                    ),
                  ),
                for (final event in evidence.timeline)
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.check_circle_outline),
                      title: Text(
                        (event['event_type'] ?? 'event')
                            .toString()
                            .replaceAll('_', ' '),
                      ),
                      subtitle: Text(
                        '${event['details'] ?? 'No additional evidence'}\n'
                        '${event['timestamp'] ?? ''}',
                      ),
                      isThreeLine: true,
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _IncidentEvidence {
  final Map<String, dynamic> incident;
  final List<Map<String, dynamic>> timeline;

  const _IncidentEvidence(this.incident, this.timeline);
}
