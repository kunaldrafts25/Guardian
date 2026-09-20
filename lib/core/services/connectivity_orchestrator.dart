import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:guardian/core/utils/logger.dart';

final connectivityProvider = Provider<ConnectivityOrchestrator>((ref) {
  final orchestrator = ConnectivityOrchestrator();
  ref.onDispose(orchestrator.dispose);
  return orchestrator;
});

final connectivityStateProvider = StreamProvider<ConnectivityLayer>((ref) {
  return ref.read(connectivityProvider).connectivityStream;
});

enum ConnectivityLayer { internet, offline }

extension ConnectivityLayerExt on ConnectivityLayer {
  String get displayName =>
      this == ConnectivityLayer.internet ? 'Online' : 'Offline';

  bool get canReachCloud => this == ConnectivityLayer.internet;
}

/// Tracks platform-reported network availability. API requests remain the
/// authority for cloud reachability; failures stay in the durable local queue.
class ConnectivityOrchestrator {
  final Connectivity _connectivity = Connectivity();
  ConnectivityLayer _currentLayer = ConnectivityLayer.offline;
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  final _controller = StreamController<ConnectivityLayer>.broadcast();

  ConnectivityLayer get currentLayer => _currentLayer;
  Stream<ConnectivityLayer> get connectivityStream => _controller.stream;

  ConnectivityOrchestrator() {
    _initialize();
  }

  Future<void> _initialize() async {
    _updateLayer(await _connectivity.checkConnectivity());
    _subscription = _connectivity.onConnectivityChanged.listen(_updateLayer);
  }

  void _updateLayer(List<ConnectivityResult> results) {
    final hasNetwork =
        results.any((result) => result != ConnectivityResult.none);
    final next =
        hasNetwork ? ConnectivityLayer.internet : ConnectivityLayer.offline;
    if (next == _currentLayer) return;
    _currentLayer = next;
    _controller.add(next);
    Logger.info('Connectivity changed: ${next.displayName}');
  }

  List<AlertTransport> getAlertTransports() => _currentLayer.canReachCloud
      ? const [
          AlertTransport.cloud,
          AlertTransport.sms,
          AlertTransport.localStorage,
        ]
      : const [AlertTransport.sms, AlertTransport.localStorage];

  void dispose() {
    _subscription?.cancel();
    _controller.close();
  }
}

enum AlertTransport { cloud, sms, localStorage }

extension AlertTransportExt on AlertTransport {
  String get displayName {
    switch (this) {
      case AlertTransport.cloud:
        return 'Internet';
      case AlertTransport.sms:
        return 'SMS';
      case AlertTransport.localStorage:
        return 'Local Queue';
    }
  }
}
