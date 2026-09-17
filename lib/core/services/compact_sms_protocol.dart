/*
 * Guardian 2.0 - Women's Safety App
 * Compact GSM SMS Protocol for Zero-Network Environments
 * 
 * Compresses rich emergency telemetry into a single standard 160-character
 * GSM SMS payload that works without mobile data, Wi-Fi, or cloud connectivity.
 */

import 'dart:convert';
import 'package:crypto/crypto.dart';

class CompactEmergencyPayload {
  final String version;
  final String userHash;
  final double latitude;
  final double longitude;
  final int accuracyMeters;
  final int batteryPercent;
  final String eventCode;
  final int timestampSeconds;

  const CompactEmergencyPayload({
    this.version = 'V2',
    required this.userHash,
    required this.latitude,
    required this.longitude,
    required this.accuracyMeters,
    required this.batteryPercent,
    required this.eventCode,
    required this.timestampSeconds,
  });

  /// Encodes payload into ultra-compact string:
  /// GRD!|V2|A7F19C|19.07601,72.87772|8m|42%|PANIC_PWR|1726588200
  String encode() {
    final latStr = latitude.toStringAsFixed(5);
    final lngStr = longitude.toStringAsFixed(5);
    final raw =
        'GRD!|$version|$userHash|$latStr,$lngStr|${accuracyMeters}m|$batteryPercent%|$eventCode|$timestampSeconds';
    return raw;
  }

  /// Decodes payload from inbound SMS gateway or peer phone
  static CompactEmergencyPayload? decode(String smsBody) {
    if (!smsBody.startsWith('GRD!|')) return null;

    try {
      final parts = smsBody.split('|');
      if (parts.length < 8) return null;

      final ver = parts[1];
      final hash = parts[2];
      final coords = parts[3].split(',');
      final lat = double.parse(coords[0]);
      final lng = double.parse(coords[1]);
      final acc = int.parse(parts[4].replaceAll('m', ''));
      final batt = int.parse(parts[5].replaceAll('%', ''));
      final code = parts[6];
      final ts = int.parse(parts[7]);

      return CompactEmergencyPayload(
        version: ver,
        userHash: hash,
        latitude: lat,
        longitude: lng,
        accuracyMeters: acc,
        batteryPercent: batt,
        eventCode: code,
        timestampSeconds: ts,
      );
    } catch (_) {
      return null;
    }
  }

  /// Generates human-readable link for emergency contacts
  String toGoogleMapsLink() {
    return 'https://maps.google.com/?q=$latitude,$longitude';
  }

  /// Generates a 6-character pseudonymous hash from user ID
  static String computeUserHash(String userId) {
    final bytes = utf8.encode(userId);
    final digest = sha256.convert(bytes);
    return digest.toString().substring(0, 6).toUpperCase();
  }
}
