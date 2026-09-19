import 'dart:math';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:guardian/core/database/guardian_database.dart';
import 'package:guardian/core/models/safe_zone_model.dart';

class SafeZoneState {
  final List<SafeZone> zones;
  final bool isLoading;
  final String? errorMessage;
  final SafeZone? currentZone;
  final bool isInSafeZone;

  const SafeZoneState({
    this.zones = const [],
    this.isLoading = false,
    this.errorMessage,
    this.currentZone,
    this.isInSafeZone = false,
  });

  SafeZoneState copyWith({
    List<SafeZone>? zones,
    bool? isLoading,
    String? errorMessage,
    SafeZone? currentZone,
    bool clearCurrentZone = false,
    bool? isInSafeZone,
  }) =>
      SafeZoneState(
        zones: zones ?? this.zones,
        isLoading: isLoading ?? this.isLoading,
        errorMessage: errorMessage,
        currentZone: clearCurrentZone ? null : currentZone ?? this.currentZone,
        isInSafeZone: isInSafeZone ?? this.isInSafeZone,
      );

  int get count => zones.length;
  static const int maxZones = 10;
  bool get canAddMore => zones.length < maxZones;
}

class SafeZoneNotifier extends StateNotifier<SafeZoneState> {
  final GuardianDatabase _database;

  SafeZoneNotifier(this._database)
      : super(const SafeZoneState(isLoading: true)) {
    _load();
  }

  SafeZone _fromRow(LocalSafeZone row) => SafeZone(
        id: row.id.toString(),
        name: row.name,
        latitude: row.latitude,
        longitude: row.longitude,
        radius: row.radiusMeters,
        type: SafeZoneType.values.firstWhere(
          (type) => type.name == row.type,
          orElse: () => SafeZoneType.custom,
        ),
        isActive: row.isActive,
        notifyOnExit: row.alertOnExit,
        createdAt: row.createdAt,
      );

  LocalSafeZonesCompanion _values(SafeZone zone) => LocalSafeZonesCompanion(
        name: Value(zone.name),
        latitude: Value(zone.latitude),
        longitude: Value(zone.longitude),
        radiusMeters: Value(zone.radius),
        type: Value(zone.type.name),
        alertOnExit: Value(zone.notifyOnExit),
        isActive: Value(zone.isActive),
        createdAt: Value(zone.createdAt),
      );

  Future<void> _load() async {
    try {
      final rows = await _database.getAllSafeZones();
      state = state.copyWith(
        zones: rows.map(_fromRow).toList(),
        isLoading: false,
      );
    } catch (error) {
      state = state.copyWith(isLoading: false, errorMessage: error.toString());
    }
  }

  Future<void> addZone(SafeZone zone) async {
    if (!state.canAddMore) return;
    final id = await _database.insertSafeZone(_values(zone));
    state = state.copyWith(zones: [...state.zones, zone.copyWith(id: '$id')]);
  }

  Future<void> updateZone(String id, SafeZone zone) async {
    final numericId = int.tryParse(id);
    if (numericId == null) return;
    await _database.updateSafeZone(numericId, _values(zone));
    state = state.copyWith(
      zones: [
        for (final item in state.zones)
          if (item.id == id) zone else item
      ],
    );
  }

  Future<void> removeZone(String id) async {
    final numericId = int.tryParse(id);
    if (numericId == null) return;
    await _database.deleteSafeZone(numericId);
    state = state.copyWith(
      zones: state.zones.where((zone) => zone.id != id).toList(),
    );
  }

  Future<void> toggleZone(String id) async {
    final index = state.zones.indexWhere((item) => item.id == id);
    if (index < 0) return;
    final zone = state.zones[index];
    await updateZone(id, zone.copyWith(isActive: !zone.isActive));
  }

  SafeZone? checkPosition(double latitude, double longitude) {
    for (final zone in state.zones.where((zone) => zone.isActive)) {
      if (_distance(latitude, longitude, zone.latitude, zone.longitude) <=
          zone.radius) {
        state = state.copyWith(currentZone: zone, isInSafeZone: true);
        return zone;
      }
    }
    state = state.copyWith(clearCurrentZone: true, isInSafeZone: false);
    return null;
  }

  double _distance(double lat1, double lon1, double lat2, double lon2) {
    const radius = 6371000.0;
    double radians(double value) => value * pi / 180;
    final dLat = radians(lat2 - lat1);
    final dLon = radians(lon2 - lon1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(radians(lat1)) * cos(radians(lat2)) * sin(dLon / 2) * sin(dLon / 2);
    return radius * 2 * atan2(sqrt(a), sqrt(1 - a));
  }
}

final safeZoneProvider =
    StateNotifierProvider<SafeZoneNotifier, SafeZoneState>((ref) {
  return SafeZoneNotifier(ref.watch(databaseProvider));
});

final isInSafeZoneProvider =
    Provider<bool>((ref) => ref.watch(safeZoneProvider).isInSafeZone);
final currentSafeZoneProvider =
    Provider<SafeZone?>((ref) => ref.watch(safeZoneProvider).currentZone);
final safeZoneCountProvider =
    Provider<int>((ref) => ref.watch(safeZoneProvider).count);
