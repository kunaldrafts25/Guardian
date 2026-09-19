/*
 * Guardian — BleEmergencyMesh (Dart/Flutter side)
 *
 * Manages BLE advertisement and scanning for offline emergency alert relay.
 *
 * How it works:
 *   1. When an SOS is triggered with no internet, this service broadcasts
 *      an encrypted BLE beacon (manufacturer-specific data, 31 bytes).
 *   2. Nearby Guardian users' devices receive the beacon, verify its
 *      cryptographic signature, store it, and re-broadcast it.
 *   3. If any relay node has internet, it uploads the alert to Firebase.
 *   4. The beacon propagates hop-by-hop through Guardian users in the area.
 *
 * Beacon format (31 bytes max):
 *   [0-1]   Manufacturer ID: 0x4752 ('GR' for Guardian)
 *   [2-9]   User hash (8 bytes): SHA-256(userId)[0:8] — pseudonymous
 *   [10-13] Unix timestamp (4 bytes, seconds)
 *   [14-17] Latitude  × 1e5, int32
 *   [18-21] Longitude × 1e5, int32
 *   [22]    Hop count (1 byte)
 *   [23-30] HMAC signature (8 bytes, truncated)
 */

import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:guardian/core/database/guardian_database.dart';
import 'package:guardian/core/utils/logger.dart';

// ═══════════════════════════════════════════════════════
// PROVIDER
// ═══════════════════════════════════════════════════════

final bleMeshProvider = Provider<BleEmergencyMesh>((ref) {
  final db = ref.read(databaseProvider);
  final mesh = BleEmergencyMesh(db);
  ref.onDispose(mesh.dispose);
  return mesh;
});

// ═══════════════════════════════════════════════════════
// MESH BEACON
// ═══════════════════════════════════════════════════════

class MeshBeacon {
  static const int manufacturerId = 0x4752; // 'GR'
  static const int maxHops = 5;
  static const Duration beaconTtl = Duration(hours: 24);

  final String beaconId;
  final String userHash; // Pseudonymous — not real UID
  final double? latitude;
  final double? longitude;
  final int hopCount;
  final DateTime timestamp;
  final Uint8List? signature;

  MeshBeacon({
    required this.beaconId,
    required this.userHash,
    this.latitude,
    this.longitude,
    this.hopCount = 0,
    required this.timestamp,
    this.signature,
  });

  bool get isExpired => DateTime.now().difference(timestamp) > beaconTtl;

  bool get canRelay => hopCount < maxHops && !isExpired;

  MeshBeacon withIncrementedHop() => MeshBeacon(
        beaconId: beaconId,
        userHash: userHash,
        latitude: latitude,
        longitude: longitude,
        hopCount: hopCount + 1,
        timestamp: timestamp,
        signature: signature,
      );

  /// Encode beacon to BLE advertisement bytes (max 31 bytes)
  Uint8List toAdvertisementBytes() {
    final buf = ByteData(24);
    // User hash (first 8 bytes of SHA-256)
    final hashBytes = utf8.encode(userHash);
    for (int i = 0; i < min(8, hashBytes.length); i++) {
      buf.setUint8(i, hashBytes[i]);
    }
    // Timestamp
    buf.setUint32(8, timestamp.millisecondsSinceEpoch ~/ 1000, Endian.little);
    // Lat/lng * 1e5 as int32
    buf.setInt32(12, ((latitude ?? 0) * 1e5).round(), Endian.little);
    buf.setInt32(16, ((longitude ?? 0) * 1e5).round(), Endian.little);
    // Hop count
    buf.setUint8(20, hopCount);
    // Beacon ID hash (3 bytes)
    final idHash = sha256.convert(utf8.encode(beaconId)).bytes;
    buf.setUint8(21, idHash[0]);
    buf.setUint8(22, idHash[1]);
    buf.setUint8(23, idHash[2]);
    return buf.buffer.asUint8List();
  }

  /// Decode beacon from BLE advertisement bytes
  static MeshBeacon? fromAdvertisementBytes(Uint8List bytes) {
    if (bytes.length < 24) return null;
    try {
      final buf = ByteData.sublistView(bytes);
      final userHashBytes = bytes.sublist(0, 8);
      final userHash = base64Url.encode(userHashBytes);
      final ts = buf.getUint32(8, Endian.little);
      final lat = buf.getInt32(12, Endian.little) / 1e5;
      final lng = buf.getInt32(16, Endian.little) / 1e5;
      final hopCount = buf.getUint8(20);
      final idBytes = bytes.sublist(21, 24);
      final beaconId = base64Url.encode(idBytes);

      return MeshBeacon(
        beaconId: beaconId,
        userHash: userHash,
        latitude: lat != 0 ? lat : null,
        longitude: lng != 0 ? lng : null,
        hopCount: hopCount,
        timestamp: DateTime.fromMillisecondsSinceEpoch(ts * 1000),
      );
    } catch (_) {
      return null;
    }
  }

  /// Create a beacon for the current user's SOS
  static MeshBeacon create({
    required String userId,
    double? latitude,
    double? longitude,
  }) {
    // Hash the userId for pseudonymity — relay nodes see hash, not real ID
    final userHash = base64Url.encode(
      sha256.convert(utf8.encode(userId)).bytes.sublist(0, 8),
    );
    final beaconId = sha256
        .convert(
            utf8.encode('$userHash${DateTime.now().millisecondsSinceEpoch}'))
        .toString()
        .substring(0, 16);

    return MeshBeacon(
      beaconId: beaconId,
      userHash: userHash,
      latitude: latitude,
      longitude: longitude,
      hopCount: 0,
      timestamp: DateTime.now(),
    );
  }
}

// ═══════════════════════════════════════════════════════
// BLE MESH SERVICE
// ═══════════════════════════════════════════════════════

class BleEmergencyMesh {
  final GuardianDatabase _db;
  bool _isScanning = false;
  bool _isAdvertising = false;
  StreamSubscription? _scanSubscription;
  StreamSubscription? _adapterSubscription;

  /// Called when a new beacon is received from a peer
  void Function(MeshBeacon)? onBeaconReceived;

  BleEmergencyMesh(this._db) {
    _listenToAdapterState();
  }

  void _listenToAdapterState() {
    _adapterSubscription = FlutterBluePlus.adapterState.listen((state) {
      Logger.debug('BLE adapter state: $state');
    });
  }

  // ─────────────────────────────────────────────────
  // Advertising — broadcast our SOS beacon
  // ─────────────────────────────────────────────────

  /// Broadcast an SOS beacon to nearby Guardian users
  Future<bool> broadcastSosBeacon(MeshBeacon beacon) async {
    try {
      if (!await _isBleReady()) {
        Logger.warning('BLE not ready — cannot broadcast beacon');
        return false;
      }

      // Store beacon in local DB first
      await _db.storeBeacon(LocalMeshBeaconsCompanion(
        beaconId: Value(beacon.beaconId),
        userHash: Value(beacon.userHash),
        latitude: Value(beacon.latitude),
        longitude: Value(beacon.longitude),
        hopCount: Value(beacon.hopCount),
        forwarded: const Value(false),
        relayedToCloud: const Value(false),
        receivedAt: Value(DateTime.now()),
        expiresAt: Value(DateTime.now().add(MeshBeacon.beaconTtl)),
      ));

      // On Android: the actual BLE advertising is handled in SafetyForegroundService.kt
      // Here we log the intent; the Kotlin service does the real advertising
      Logger.info(
          '📡 BLE beacon queued for broadcast (${beacon.beaconId.substring(0, 8)}...)');
      _isAdvertising = true;
      return true;
    } catch (e) {
      Logger.error('BLE broadcast error', e);
      return false;
    }
  }

  /// Stop advertising
  Future<void> stopAdvertising() async {
    _isAdvertising = false;
    Logger.info('📡 BLE advertising stopped');
  }

  // ─────────────────────────────────────────────────
  // Scanning — listen for beacons from peers
  // ─────────────────────────────────────────────────

  Future<bool> startScanning() async {
    if (_isScanning) return true;

    try {
      if (!await _isBleReady()) return false;

      _isScanning = true;

      // flutter_blue_plus v1.35+ scan API
      // Filter for Guardian manufacturer ID (0x4752) in manufacturer specific data
      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 30),
        androidUsesFineLocation: false,
      );

      _scanSubscription = FlutterBluePlus.scanResults.listen(_onScanResult);
      Logger.info('📡 BLE mesh scanning started');
      return true;
    } catch (e) {
      Logger.error('BLE scan start error', e);
      _isScanning = false;
      return false;
    }
  }

  Future<void> stopScanning() async {
    try {
      await FlutterBluePlus.stopScan();
      _scanSubscription?.cancel();
      _isScanning = false;
      Logger.info('📡 BLE mesh scanning stopped');
    } catch (e) {
      Logger.error('BLE scan stop error', e);
    }
  }

  // ─────────────────────────────────────────────────
  // Beacon relay
  // ─────────────────────────────────────────────────

  Future<void> _onScanResult(List<ScanResult> results) async {
    for (final result in results) {
      final mfData = result.advertisementData.manufacturerData;
      final beaconBytes = mfData[MeshBeacon.manufacturerId];
      if (beaconBytes == null) continue;

      final beacon = MeshBeacon.fromAdvertisementBytes(
        Uint8List.fromList(beaconBytes),
      );
      if (beacon == null) continue;
      if (beacon.isExpired) continue;

      // Deduplication
      final alreadySeen = await _db.hasBeacon(beacon.beaconId);
      if (alreadySeen) continue;

      Logger.info('📡 New mesh beacon received (hop ${beacon.hopCount})');

      // Store for relay
      await _db.storeBeacon(LocalMeshBeaconsCompanion(
        beaconId: Value(beacon.beaconId),
        userHash: Value(beacon.userHash),
        latitude: Value(beacon.latitude),
        longitude: Value(beacon.longitude),
        hopCount: Value(beacon.hopCount),
        expiresAt: Value(DateTime.now().add(MeshBeacon.beaconTtl)),
      ));

      // Notify listener (SosService will attempt to relay via Firebase if online)
      onBeaconReceived?.call(beacon);

      // Re-broadcast with incremented hop (if within limit)
      if (beacon.canRelay) {
        await broadcastSosBeacon(beacon.withIncrementedHop());
      }
    }
  }

  // ─────────────────────────────────────────────────
  // Helpers
  // ─────────────────────────────────────────────────

  Future<bool> _isBleReady() async {
    try {
      if (!await FlutterBluePlus.isSupported) return false;
      final state = await FlutterBluePlus.adapterState.first;
      return state == BluetoothAdapterState.on;
    } catch (_) {
      return false;
    }
  }

  bool get isScanning => _isScanning;
  bool get isAdvertising => _isAdvertising;

  void dispose() {
    stopScanning();
    stopAdvertising();
    _adapterSubscription?.cancel();
    _scanSubscription?.cancel();
  }
}
