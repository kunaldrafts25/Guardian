/*
 * Guardian — ConnectivityOrchestrator
 *
 * Manages the 5-layer connectivity stack for offline-first operation.
 * Automatically selects the best available transport for SOS alerts:
 *
 *   LAYER 5: Firebase / Internet         (full features, syncs everything)
 *   LAYER 4: Cellular SMS (no data)      (SmsManager, no data plan needed)
 *   LAYER 3: WiFi Direct (P2P, 200m)     (no carrier, high bandwidth)
 *   LAYER 2: BLE Mesh (multi-hop relay)  (no carrier, hop-by-hop to internet)
 *   LAYER 1: Local queue (retry later)   (last resort — guaranteed no loss)
 *
 * Riverpod provider: connectivityProvider
 */

import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:guardian/core/utils/logger.dart';

// ═══════════════════════════════════════════════════════
// PROVIDERS
// ═══════════════════════════════════════════════════════

final connectivityProvider = Provider<ConnectivityOrchestrator>((ref) {
  final orchestrator = ConnectivityOrchestrator();
  ref.onDispose(orchestrator.dispose);
  return orchestrator;
});

/// Stream provider for real-time connectivity state
final connectivityStateProvider = StreamProvider<ConnectivityLayer>((ref) {
  return ref.read(connectivityProvider).connectivityStream;
});

// ═══════════════════════════════════════════════════════
// CONNECTIVITY LAYERS (ordered best → worst)
// ═══════════════════════════════════════════════════════

enum ConnectivityLayer {
  /// Full internet — Firebase, FCM, live location sharing
  internet,

  /// Cellular voice/SMS only — no data — SMS via SmsManager works
  cellularSmsOnly,

  /// WiFi Direct P2P — no carrier needed, ~200m range
  wifiDirect,

  /// BLE mesh — no carrier, relays through nearby Guardian users
  bleMesh,

  /// Completely offline — store locally and retry when any layer returns
  offline,
}

extension ConnectivityLayerExt on ConnectivityLayer {
  String get displayName {
    switch (this) {
      case ConnectivityLayer.internet:      return 'Online';
      case ConnectivityLayer.cellularSmsOnly: return 'SMS Only';
      case ConnectivityLayer.wifiDirect:    return 'WiFi Direct';
      case ConnectivityLayer.bleMesh:       return 'BLE Mesh';
      case ConnectivityLayer.offline:       return 'Offline';
    }
  }

  bool get canReachFirebase =>
      this == ConnectivityLayer.internet;

  bool get canSendSms =>
      this == ConnectivityLayer.internet ||
      this == ConnectivityLayer.cellularSmsOnly;

  bool get canReachMesh =>
      this == ConnectivityLayer.bleMesh ||
      this == ConnectivityLayer.wifiDirect;
}

// ═══════════════════════════════════════════════════════
// ORCHESTRATOR
// ═══════════════════════════════════════════════════════

class ConnectivityOrchestrator {
  final Connectivity _connectivity = Connectivity();
  ConnectivityLayer _currentLayer = ConnectivityLayer.offline;
  StreamSubscription? _sub;
  final _controller = StreamController<ConnectivityLayer>.broadcast();

  ConnectivityLayer get currentLayer => _currentLayer;
  Stream<ConnectivityLayer> get connectivityStream => _controller.stream;

  ConnectivityOrchestrator() {
    _init();
  }

  Future<void> _init() async {
    // Get initial state
    final results = await _connectivity.checkConnectivity();
    _updateLayer(results);

    // Subscribe to changes
    _sub = _connectivity.onConnectivityChanged.listen(_updateLayer);
  }

  void _updateLayer(List<ConnectivityResult> results) {
    ConnectivityLayer layer;

    if (results.contains(ConnectivityResult.wifi) ||
        results.contains(ConnectivityResult.mobile) ||
        results.contains(ConnectivityResult.ethernet)) {
      layer = ConnectivityLayer.internet;
    } else if (results.contains(ConnectivityResult.none)) {
      // No network — check if BLE is available (handled by BleEmergencyMesh)
      layer = ConnectivityLayer.bleMesh; // Optimistic — BLE likely available
    } else {
      layer = ConnectivityLayer.offline;
    }

    if (layer != _currentLayer) {
      _currentLayer = layer;
      _controller.add(layer);
      Logger.info('📶 Connectivity changed: ${layer.displayName}');
    }
  }

  // ─────────────────────────────────────────────────
  // Alert Routing
  // ─────────────────────────────────────────────────

  /// Determines which layers to use for sending an SOS alert.
  /// Returns ordered list of transports to try.
  List<AlertTransport> getAlertTransports() {
    final transports = <AlertTransport>[];

    switch (_currentLayer) {
      case ConnectivityLayer.internet:
        transports.addAll([
          AlertTransport.firebase,
          AlertTransport.sms,          // Always send SMS too — belt and suspenders
          AlertTransport.bleMesh,      // Broadcast mesh beacon for Guardian users nearby
        ]);
        break;

      case ConnectivityLayer.cellularSmsOnly:
        transports.addAll([
          AlertTransport.sms,
          AlertTransport.bleMesh,      // Mesh relay might reach someone with internet
        ]);
        break;

      case ConnectivityLayer.wifiDirect:
        transports.addAll([
          AlertTransport.wifiDirect,
          AlertTransport.bleMesh,
          AlertTransport.localStorage, // Queue for when internet returns
        ]);
        break;

      case ConnectivityLayer.bleMesh:
        transports.addAll([
          AlertTransport.bleMesh,
          AlertTransport.localStorage,
        ]);
        break;

      case ConnectivityLayer.offline:
        transports.addAll([
          AlertTransport.localStorage, // Store; will send when connectivity returns
        ]);
        break;
    }

    return transports;
  }

  void dispose() {
    _sub?.cancel();
    _controller.close();
  }
}

// ═══════════════════════════════════════════════════════
// TRANSPORT TYPES
// ═══════════════════════════════════════════════════════

enum AlertTransport {
  firebase,      // Firestore + FCM push to contacts
  sms,           // Native SmsManager (no internet needed)
  bleMesh,       // BLE broadcast beacon (relayed by nearby Guardian users)
  wifiDirect,    // WiFi P2P to a nearby device with internet
  localStorage,  // Queue locally; sync when connectivity returns
}

extension AlertTransportExt on AlertTransport {
  String get displayName {
    switch (this) {
      case AlertTransport.firebase:      return 'Internet';
      case AlertTransport.sms:          return 'SMS';
      case AlertTransport.bleMesh:      return 'BLE Mesh';
      case AlertTransport.wifiDirect:   return 'WiFi Direct';
      case AlertTransport.localStorage: return 'Local Queue';
    }
  }
}
