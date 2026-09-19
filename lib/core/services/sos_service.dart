/*
 * Guardian 2.0 - Women's Safety App
 * © 2025 All Rights Reserved - Kunal Singh
 * 
 * SOS Service - Unified SOS orchestration service
 * 
 * This service coordinates all emergency functions:
 * - Location tracking
 * - SMS alerts
 * - Push notifications
 * - Emergency state management
 * - Local emergency state management
 */

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:guardian/core/models/user_model.dart';
import 'package:guardian/core/utils/location_utils.dart';
import 'package:guardian/core/utils/logger.dart';
import 'package:url_launcher/url_launcher.dart';

// Method channel to native SmsManager (automatic SMS — no user tap)
const MethodChannel _smsChannel = MethodChannel('com.guardian/sms');
const MethodChannel _serviceChannel = MethodChannel('com.guardian/service');

/// SOS trigger source
enum SosTriggerSource {
  button, // Manual button press
  hardwarePower, // Covert hardware-button panic gesture
  shake, // Shake detection
  widget, // Home screen widget
  voiceCommand, // Voice command
  scheduled, // Check-in timer expired
}

/// SOS alert status
enum SosAlertStatus {
  pending, // Alert created but not sent
  sending, // Currently sending alerts
  active, // Alerts sent, emergency active
  resolved, // User marked safe
  cancelled, // User cancelled before sending
  failed, // Failed to send alerts
}

/// Individual contact alert status
class ContactAlertStatus {
  final EmergencyContact contact;
  final bool smsSent;
  final bool pushSent;
  final DateTime? sentAt;
  final String? error;

  const ContactAlertStatus({
    required this.contact,
    this.smsSent = false,
    this.pushSent = false,
    this.sentAt,
    this.error,
  });

  ContactAlertStatus copyWith({
    bool? smsSent,
    bool? pushSent,
    DateTime? sentAt,
    String? error,
  }) {
    return ContactAlertStatus(
      contact: contact,
      smsSent: smsSent ?? this.smsSent,
      pushSent: pushSent ?? this.pushSent,
      sentAt: sentAt ?? this.sentAt,
      error: error ?? this.error,
    );
  }
}

/// Active SOS alert data
class SosAlert {
  final String id;
  final SosTriggerSource source;
  final SosAlertStatus status;
  final DateTime startedAt;
  final DateTime? resolvedAt;
  final Position? initialLocation;
  final Position? currentLocation;
  final List<ContactAlertStatus> contactStatuses;
  final String? customMessage;

  const SosAlert({
    required this.id,
    required this.source,
    required this.status,
    required this.startedAt,
    this.resolvedAt,
    this.initialLocation,
    this.currentLocation,
    this.contactStatuses = const [],
    this.customMessage,
  });

  SosAlert copyWith({
    SosAlertStatus? status,
    DateTime? resolvedAt,
    Position? currentLocation,
    List<ContactAlertStatus>? contactStatuses,
  }) {
    return SosAlert(
      id: id,
      source: source,
      status: status ?? this.status,
      startedAt: startedAt,
      resolvedAt: resolvedAt ?? this.resolvedAt,
      initialLocation: initialLocation,
      currentLocation: currentLocation ?? this.currentLocation,
      contactStatuses: contactStatuses ?? this.contactStatuses,
      customMessage: customMessage,
    );
  }

  /// Get Google Maps link for current location
  String get locationLink {
    final lat = currentLocation?.latitude ?? initialLocation?.latitude;
    final lng = currentLocation?.longitude ?? initialLocation?.longitude;
    if (lat == null || lng == null) return '';
    return 'https://maps.google.com/?q=$lat,$lng';
  }

  /// Count of successfully notified contacts
  int get notifiedCount =>
      contactStatuses.where((c) => c.smsSent || c.pushSent).length;
}

/// Callback types
typedef SosAlertCallback = void Function(SosAlert alert);
typedef LocationUpdateCallback = void Function(Position position);

/// SOS Service - Main orchestrator for emergency alerts
class SosService {
  static SosService? _instance;
  static SosService get instance => _instance ??= SosService._();

  SosService._();

  // Current active alert
  SosAlert? _activeAlert;
  Future<SosAlert?>? _triggerInFlight;
  SosAlert? get activeAlert => _activeAlert;
  bool get hasActiveAlert =>
      _activeAlert != null &&
      (_activeAlert!.status == SosAlertStatus.active ||
          _activeAlert!.status == SosAlertStatus.sending);

  // Location tracking
  StreamSubscription<Position>? _locationSubscription;

  // Callbacks
  final List<SosAlertCallback> _alertListeners = [];
  final List<LocationUpdateCallback> _locationListeners = [];

  /// Register alert listener
  void addAlertListener(SosAlertCallback callback) {
    _alertListeners.add(callback);
  }

  /// Remove alert listener
  void removeAlertListener(SosAlertCallback callback) {
    _alertListeners.remove(callback);
  }

  /// Register location listener
  void addLocationListener(LocationUpdateCallback callback) {
    _locationListeners.add(callback);
  }

  /// Remove location listener
  void removeLocationListener(LocationUpdateCallback callback) {
    _locationListeners.remove(callback);
  }

  /// Notify all alert listeners
  void _notifyAlertListeners() {
    if (_activeAlert != null) {
      for (final callback in _alertListeners) {
        callback(_activeAlert!);
      }
    }
  }

  Future<SosAlert?> triggerSos({
    required List<EmergencyContact> contacts,
    required SosTriggerSource source,
    String? customMessage,
    String? userName,
  }) async {
    if (hasActiveAlert) {
      Logger.warning('SOS already active, ignoring trigger');
      return _activeAlert;
    }
    final inFlight = _triggerInFlight;
    if (inFlight != null) {
      Logger.warning('SOS trigger already in progress; joining it');
      return inFlight;
    }
    final operation = _triggerSosInternal(
      contacts: contacts,
      source: source,
      customMessage: customMessage,
      userName: userName,
    );
    _triggerInFlight = operation;
    try {
      return await operation;
    } finally {
      if (identical(_triggerInFlight, operation)) _triggerInFlight = null;
    }
  }

  Future<SosAlert?> _triggerSosInternal({
    required List<EmergencyContact> contacts,
    required SosTriggerSource source,
    String? customMessage,
    String? userName,
  }) async {
    Logger.info('🚨 SOS TRIGGERED via ${source.name}');

    // Get current location — try Geolocator first, fall back to native service cache
    Position? position;
    try {
      position = await LocationUtils.getCurrentPosition();
      if (position != null) {
        Logger.info(
            '📍 Location acquired (accuracy: ${position.accuracy.toStringAsFixed(0)}m)');
      } else {
        // Fallback: request last-known location from foreground service
        Logger.warning('📍 Could not get fresh GPS — using cached location');
        final cached =
            await _serviceChannel.invokeMethod<Map>('getLastLocation');
        if (cached != null) {
          position = Position(
            latitude: (cached['latitude'] as num).toDouble(),
            longitude: (cached['longitude'] as num).toDouble(),
            accuracy: (cached['accuracy'] as num).toDouble(),
            altitude: 0,
            heading: 0,
            speed: 0,
            speedAccuracy: 0,
            altitudeAccuracy: 0,
            headingAccuracy: 0,
            timestamp: DateTime.now(),
          );
          Logger.info(
              '📍 Using cached location (accuracy: ${position.accuracy.toStringAsFixed(0)}m)');
        }
      }
    } catch (e) {
      Logger.error('📍 Location error', e);
    }

    // Create alert
    final alertId = DateTime.now().millisecondsSinceEpoch.toString();
    _activeAlert = SosAlert(
      id: alertId,
      source: source,
      status: SosAlertStatus.sending,
      startedAt: DateTime.now(),
      initialLocation: position,
      currentLocation: position,
      customMessage: customMessage,
      contactStatuses:
          contacts.map((c) => ContactAlertStatus(contact: c)).toList(),
    );

    _notifyAlertListeners();

    // Send alerts to all contacts
    final updatedStatuses = <ContactAlertStatus>[];

    for (final contactStatus in _activeAlert!.contactStatuses) {
      final result = await _sendAlertToContact(
        contact: contactStatus.contact,
        position: position,
        userName: userName ?? 'Guardian',
        customMessage: customMessage,
      );
      updatedStatuses.add(result);
    }

    // Update alert with results
    _activeAlert = _activeAlert!.copyWith(
      status: SosAlertStatus.active,
      contactStatuses: updatedStatuses,
    );

    _notifyAlertListeners();

    // Start location tracking
    _startLocationTracking();

    Logger.info(
        'SOS active. ${_activeAlert!.notifiedCount}/${contacts.length} SMS dispatches accepted by the device');

    return _activeAlert;
  }

  /// Restores durable incident state after process recreation without
  /// dispatching messages a second time.
  void restoreActiveAlert(SosAlert alert) {
    if (alert.status != SosAlertStatus.active &&
        alert.status != SosAlertStatus.sending) {
      throw ArgumentError.value(alert.status, 'alert', 'Alert is not active');
    }
    if (hasActiveAlert && _activeAlert!.id != alert.id) {
      Logger.warning('An active SOS is already loaded; restore ignored');
      return;
    }
    _activeAlert = alert;
    _notifyAlertListeners();
    _startLocationTracking();
  }

  /// Send alert to a single contact
  Future<ContactAlertStatus> _sendAlertToContact({
    required EmergencyContact contact,
    required Position? position,
    required String userName,
    String? customMessage,
  }) async {
    bool smsSent = false;
    String? error;

    try {
      // Build SMS message
      final message = _buildSosMessage(
        userName: userName,
        position: position,
        customMessage: customMessage,
      );

      // Send SMS automatically via native SmsManager — no user tap required
      smsSent = await _sendSmsNative(
        phone: contact.phone,
        message: message,
      );

      if (smsSent) {
        Logger.info('📱 Emergency SMS dispatched to contact');
      } else {
        Logger.warning('📱 SMS failed for a contact');
        error = 'Failed to send SMS';
      }
    } catch (e) {
      Logger.error('📱 SMS error for a contact', e);
      error = e.toString();
    }

    return ContactAlertStatus(
      contact: contact,
      smsSent: smsSent,
      pushSent: false, // FCM requires backend
      sentAt: smsSent ? DateTime.now() : null,
      error: error,
    );
  }

  /// Build SOS message with location
  String _buildSosMessage({
    required String userName,
    required Position? position,
    String? customMessage,
  }) {
    final buffer = StringBuffer();

    buffer.writeln('🚨 EMERGENCY ALERT 🚨');
    buffer.writeln('$userName needs help!');

    if (customMessage != null && customMessage.isNotEmpty) {
      buffer.writeln(customMessage);
    }

    if (position != null) {
      buffer.writeln();
      buffer.writeln('📍 Location:');
      buffer.writeln(
          'https://maps.google.com/?q=${position.latitude},${position.longitude}');
    } else {
      buffer.writeln();
      buffer.writeln('📍 Location unavailable');
    }

    buffer.writeln();
    buffer.writeln('Sent via Guardian Safety App');

    return buffer.toString();
  }

  /// Send SMS automatically via Android SmsManager method channel.
  /// No user interaction required — SMS is dispatched silently.
  /// On iOS: falls back to url_launcher (iOS limitation, no SmsManager equivalent).
  Future<bool> _sendSmsNative({
    required String phone,
    required String message,
  }) async {
    if (kIsWeb) {
      Logger.debug('📱 [WEB] SMS not available on web');
      return false;
    }

    try {
      // Android: use SmsManager for automatic silent sending
      final result = await _smsChannel.invokeMethod<Map>(
        'sendEmergencySms',
        {
          'phones': [phone],
          'message': message
        },
      );

      if (result != null && result['allSuccess'] == true) {
        Logger.info('📱 Emergency SMS dispatched via SmsManager');
        return true;
      } else {
        // Fallback to url_launcher (iOS or SmsManager error)
        return await _sendSmsUrlLauncher(phone: phone, message: message);
      }
    } on MissingPluginException {
      // Running on iOS or test — fall back to url_launcher
      return await _sendSmsUrlLauncher(phone: phone, message: message);
    } catch (e) {
      Logger.error('SMS native send error', e);
      return await _sendSmsUrlLauncher(phone: phone, message: message);
    }
  }

  /// iOS / web fallback: open SMS app with pre-filled message.
  /// This requires user to tap Send — unavoidable on iOS.
  Future<bool> _sendSmsUrlLauncher({
    required String phone,
    required String message,
  }) async {
    try {
      final cleanPhone = phone.replaceAll(RegExp(r'[^\d+]'), '');
      final smsUri = Uri(
        scheme: 'sms',
        path: cleanPhone,
        queryParameters: {'body': message},
      );
      if (await canLaunchUrl(smsUri)) {
        await launchUrl(smsUri);
        return true;
      }
      return false;
    } catch (e) {
      Logger.error('SMS url_launcher fallback error', e);
      return false;
    }
  }

  /// Start continuous location tracking during emergency
  void _startLocationTracking() {
    _locationSubscription?.cancel();

    if (kIsWeb) {
      Logger.info('📍 Location tracking not available on web');
      return;
    }

    _locationSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, // Update every 10 meters
      ),
    ).listen(
      (position) {
        if (_activeAlert != null) {
          _activeAlert = _activeAlert!.copyWith(currentLocation: position);
          _notifyAlertListeners();

          for (final callback in _locationListeners) {
            callback(position);
          }

          Logger.debug(
              '📍 Location updated (accuracy: ${position.accuracy.toStringAsFixed(0)}m)');
        }
      },
      onError: (error) {
        Logger.error('📍 Location stream error', error);
      },
    );

    Logger.info('📍 Location tracking started');
  }

  /// Stop location tracking
  void _stopLocationTracking() {
    _locationSubscription?.cancel();
    _locationSubscription = null;
    Logger.info('📍 Location tracking stopped');
  }

  /// Cancel active SOS (before sending is complete)
  Future<void> cancelSos() async {
    if (_activeAlert == null) return;

    Logger.info('🚫 SOS cancelled by user');

    _activeAlert = _activeAlert!.copyWith(
      status: SosAlertStatus.cancelled,
      resolvedAt: DateTime.now(),
    );

    _notifyAlertListeners();
    _stopLocationTracking();
    _activeAlert = null;
  }

  /// Mark as safe - resolve active emergency
  Future<void> markAsSafe({String? userName}) async {
    if (_activeAlert == null) return;

    Logger.info('✅ User marked as safe');

    // Get contacts that were notified
    final notifiedContacts = _activeAlert!.contactStatuses
        .where((c) => c.smsSent)
        .map((c) => c.contact)
        .toList();

    _activeAlert = _activeAlert!.copyWith(
      status: SosAlertStatus.resolved,
      resolvedAt: DateTime.now(),
    );

    _notifyAlertListeners();
    _stopLocationTracking();

    // Send "I'm safe" notification to all contacts that were notified
    for (final contact in notifiedContacts) {
      await _sendSafetyConfirmation(
        contact: contact,
        userName: userName ?? 'Guardian',
      );
    }

    Logger.info(
        '✅ Safety confirmation sent to ${notifiedContacts.length} contacts');

    _activeAlert = null;
  }

  /// Send safety confirmation SMS
  Future<void> _sendSafetyConfirmation({
    required EmergencyContact contact,
    required String userName,
  }) async {
    final message = '✅ SAFE NOW\n\n'
        '$userName is now safe.\n\n'
        'The emergency alert has been resolved.\n\n'
        '- Guardian Safety App';

    try {
      await _sendSmsNative(phone: contact.phone, message: message);
      Logger.info('✅ Safety confirmation SMS dispatched');
    } catch (e) {
      Logger.error('Failed to send safety SMS', e);
    }
  }

  /// Share live location link
  Future<void> shareLiveLocation() async {
    if (_activeAlert?.locationLink.isEmpty ?? true) {
      Logger.warning('No location to share');
      return;
    }

    final Uri shareUri = Uri.parse(_activeAlert!.locationLink);
    if (await canLaunchUrl(shareUri)) {
      await launchUrl(shareUri, mode: LaunchMode.externalApplication);
    }
  }

  /// Call emergency services
  Future<void> callEmergencyServices({String number = '112'}) async {
    final Uri phoneUri = Uri(scheme: 'tel', path: number);
    if (await canLaunchUrl(phoneUri)) {
      await launchUrl(phoneUri);
      Logger.info('📞 Calling emergency services: $number');
    }
  }

  /// Dispose resources
  void dispose() {
    _stopLocationTracking();
    _alertListeners.clear();
    _locationListeners.clear();
    _activeAlert = null;
    _instance = null;
  }
}
