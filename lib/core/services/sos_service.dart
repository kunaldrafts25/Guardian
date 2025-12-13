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
 */

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:guardian/core/models/user_model.dart';
import 'package:guardian/core/utils/location_utils.dart';
import 'package:guardian/core/utils/logger.dart';
import 'package:url_launcher/url_launcher.dart';

/// SOS trigger source
enum SosTriggerSource {
  button,      // Manual button press
  shake,       // Shake detection
  widget,      // Home screen widget
  voiceCommand,// Voice command
  scheduled,   // Check-in timer expired
}

/// SOS alert status
enum SosAlertStatus {
  pending,     // Alert created but not sent
  sending,     // Currently sending alerts
  active,      // Alerts sent, emergency active
  resolved,    // User marked safe
  cancelled,   // User cancelled before sending
  failed,      // Failed to send alerts
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
  int get notifiedCount => contactStatuses.where((c) => c.smsSent || c.pushSent).length;
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
  SosAlert? get activeAlert => _activeAlert;
  bool get hasActiveAlert => _activeAlert != null && 
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

  /// Trigger SOS alert
  /// 
  /// [contacts] - List of emergency contacts to notify
  /// [source] - What triggered the SOS
  /// [customMessage] - Optional custom message to include
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

    Logger.info('🚨 SOS TRIGGERED via ${source.name}');

    // Get current location
    Position? position;
    try {
      position = await LocationUtils.getCurrentPosition();
      if (position != null) {
        Logger.info('📍 Location acquired: ${position.latitude}, ${position.longitude}');
      } else {
        Logger.warning('📍 Could not get location');
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
      contactStatuses: contacts.map((c) => ContactAlertStatus(contact: c)).toList(),
    );

    _notifyAlertListeners();

    // Send alerts to all contacts
    final updatedStatuses = <ContactAlertStatus>[];
    
    for (final contactStatus in _activeAlert!.contactStatuses) {
      final result = await _sendAlertToContact(
        contact: contactStatus.contact,
        position: position,
        userName: userName ?? 'Guardian User',
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

    Logger.info('✅ SOS Alert active. ${_activeAlert!.notifiedCount}/${contacts.length} contacts notified');

    return _activeAlert;
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

      // Send SMS via URL launcher
      smsSent = await _sendSms(
        phone: contact.phone,
        message: message,
      );

      if (smsSent) {
        Logger.info('📱 SMS sent to ${contact.name}');
      } else {
        Logger.warning('📱 SMS failed for ${contact.name}');
        error = 'Failed to send SMS';
      }
    } catch (e) {
      Logger.error('📱 SMS error for ${contact.name}', e);
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
      buffer.writeln('https://maps.google.com/?q=${position.latitude},${position.longitude}');
    } else {
      buffer.writeln();
      buffer.writeln('📍 Location unavailable');
    }
    
    buffer.writeln();
    buffer.writeln('Sent via Guardian Safety App');
    
    return buffer.toString();
  }

  /// Send SMS using URL launcher
  Future<bool> _sendSms({
    required String phone,
    required String message,
  }) async {
    try {
      // Clean phone number
      final cleanPhone = phone.replaceAll(RegExp(r'[^\d+]'), '');
      
      // Build SMS URI
      final smsUri = Uri(
        scheme: 'sms',
        path: cleanPhone,
        queryParameters: {'body': message},
      );

      // On web, we just log
      if (kIsWeb) {
        Logger.info('📱 [WEB] Would send SMS to $cleanPhone');
        return true;
      }

      // Try to launch SMS app
      if (await canLaunchUrl(smsUri)) {
        await launchUrl(smsUri);
        return true;
      } else {
        Logger.warning('Cannot launch SMS for $cleanPhone');
        return false;
      }
    } catch (e) {
      Logger.error('SMS launch error', e);
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
          
          Logger.debug('📍 Location updated: ${position.latitude}, ${position.longitude}');
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
  Future<void> markAsSafe() async {
    if (_activeAlert == null) return;

    Logger.info('✅ User marked as safe');

    _activeAlert = _activeAlert!.copyWith(
      status: SosAlertStatus.resolved,
      resolvedAt: DateTime.now(),
    );

    _notifyAlertListeners();
    _stopLocationTracking();

    // TODO: Send "I'm safe" notification to contacts

    _activeAlert = null;
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
