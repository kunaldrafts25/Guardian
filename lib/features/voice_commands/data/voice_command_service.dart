/*
 * Guardian - Women's Safety App
 * © 2025 All Rights Reserved - Kunal Singh
 * Contact: kunalsingh2514@gmail.com
 */

import 'dart:async';
import 'package:guardian/core/utils/logger.dart';
import 'package:guardian/features/emergency/data/mock_emergency_repository.dart';
import 'package:guardian/features/guardian_mode/data/guardian_repository.dart';
import 'package:guardian/features/guardian_circle/data/guardian_circle_repository.dart';
import 'package:guardian/core/di/service_locator.dart';

/// Type of voice command
enum CommandType {
  /// Emergency SOS command
  emergency,

  /// Guardian mode command
  guardianMode,

  /// Alert guardian circle command
  alertCircle,

  /// Navigation command
  navigation,

  /// Safety check command
  safetyCheck,

  /// General app command
  general,

  /// Unknown command
  unknown,
}

/// Status of voice recognition
enum VoiceRecognitionStatus {
  /// Not started
  notStarted,

  /// Listening for commands
  listening,

  /// Processing command
  processing,

  /// Command recognized
  recognized,

  /// Command not recognized
  notRecognized,

  /// Error occurred
  error,
}

/// A service for handling voice commands
class VoiceCommandService {
  /// Stream controller for voice recognition status
  final StreamController<VoiceRecognitionStatus> _statusController =
      StreamController<VoiceRecognitionStatus>.broadcast();

  /// Stream controller for recognized commands
  final StreamController<String> _commandController =
      StreamController<String>.broadcast();

  /// Stream of voice recognition status
  Stream<VoiceRecognitionStatus> get statusStream => _statusController.stream;

  /// Stream of recognized commands
  Stream<String> get commandStream => _commandController.stream;

  /// Current voice recognition status
  VoiceRecognitionStatus _status = VoiceRecognitionStatus.notStarted;

  /// Whether voice recognition is active
  bool _isActive = false;

  /// Timer for simulating voice recognition
  Timer? _recognitionTimer;

  /// Get current status
  VoiceRecognitionStatus get status => _status;

  /// Get whether voice recognition is active
  bool get isActive => _isActive;

  /// Start voice recognition
  Future<bool> startListening() async {
    if (_isActive) {
      return true;
    }

    try {
      // In a real app, this would initialize the speech recognition API
      _isActive = true;
      _updateStatus(VoiceRecognitionStatus.listening);

      // For mock implementation, we'll simulate recognition after a delay
      _recognitionTimer = Timer(const Duration(seconds: 2), () {
        _updateStatus(VoiceRecognitionStatus.notStarted);
      });

      return true;
    } catch (e) {
      Logger.error('Failed to start voice recognition', e);
      _updateStatus(VoiceRecognitionStatus.error);
      return false;
    }
  }

  /// Stop voice recognition
  Future<bool> stopListening() async {
    if (!_isActive) {
      return true;
    }

    try {
      // In a real app, this would stop the speech recognition API
      _isActive = false;
      _recognitionTimer?.cancel();
      _updateStatus(VoiceRecognitionStatus.notStarted);

      return true;
    } catch (e) {
      Logger.error('Failed to stop voice recognition', e);
      return false;
    }
  }

  /// Process a voice command
  Future<bool> processCommand(String command) async {
    try {
      _updateStatus(VoiceRecognitionStatus.processing);

      // Notify listeners of the command
      _commandController.add(command);

      // Process the command
      final commandType = _getCommandType(command);
      final success = await _executeCommand(command, commandType);

      _updateStatus(success
          ? VoiceRecognitionStatus.recognized
          : VoiceRecognitionStatus.notRecognized);

      return success;
    } catch (e) {
      Logger.error('Failed to process voice command', e);
      _updateStatus(VoiceRecognitionStatus.error);
      return false;
    }
  }

  /// Get the type of command
  CommandType _getCommandType(String command) {
    final lowercaseCommand = command.toLowerCase();

    if (_containsAny(lowercaseCommand,
        ['emergency', 'sos', 'help me', 'danger', 'attack', 'urgent'])) {
      return CommandType.emergency;
    } else if (_containsAny(lowercaseCommand, [
      'guardian mode',
      'start guardian',
      'enable guardian',
      'activate guardian',
      'stop guardian',
      'disable guardian',
      'deactivate guardian'
    ])) {
      return CommandType.guardianMode;
    } else if (_containsAny(lowercaseCommand, [
      'alert circle',
      'notify circle',
      'tell my circle',
      'inform circle',
      'send alert',
      'alert guardians'
    ])) {
      return CommandType.alertCircle;
    } else if (_containsAny(lowercaseCommand, [
      'navigate',
      'directions',
      'map',
      'route',
      'take me to',
      'go to',
      'find route',
      'safe route'
    ])) {
      return CommandType.navigation;
    } else if (_containsAny(lowercaseCommand, [
      'safety check',
      'check in',
      'i am safe',
      'i\'m safe',
      'i am okay',
      'i\'m okay',
      'all good'
    ])) {
      return CommandType.safetyCheck;
    } else if (_containsAny(lowercaseCommand, [
      'open',
      'show',
      'go to',
      'launch',
      'start',
      'settings',
      'profile',
      'store',
      'community'
    ])) {
      return CommandType.general;
    } else {
      return CommandType.unknown;
    }
  }

  /// Execute a command
  Future<bool> _executeCommand(String command, CommandType type) async {
    switch (type) {
      case CommandType.emergency:
        return _handleEmergencyCommand(command);
      case CommandType.guardianMode:
        return _handleGuardianModeCommand(command);
      case CommandType.alertCircle:
        return _handleAlertCircleCommand(command);
      case CommandType.navigation:
        return _handleNavigationCommand(command);
      case CommandType.safetyCheck:
        return _handleSafetyCheckCommand(command);
      case CommandType.general:
        return _handleGeneralCommand(command);
      case CommandType.unknown:
        return false;
    }
  }

  /// Handle emergency command
  Future<bool> _handleEmergencyCommand(String command) async {
    try {
      final emergencyRepository = sl<EmergencyRepository>();

      // Trigger emergency alert
      await emergencyRepository.createEmergencyAlert(
        type: 'sos',
        latitude: 37.7749, // Default latitude (San Francisco)
        longitude: -122.4194, // Default longitude (San Francisco)
        message: 'Emergency alert triggered by voice command',
      );

      return true;
    } catch (e) {
      Logger.error('Failed to handle emergency command', e);
      return false;
    }
  }

  /// Handle guardian mode command
  Future<bool> _handleGuardianModeCommand(String command) async {
    try {
      final guardianRepository = sl<GuardianRepository>();
      final lowercaseCommand = command.toLowerCase();

      if (_containsAny(
          lowercaseCommand, ['start', 'enable', 'activate', 'turn on'])) {
        // Start guardian mode
        await guardianRepository.startGuardianSession(['default-guardian-id']);
      } else if (_containsAny(
          lowercaseCommand, ['stop', 'disable', 'deactivate', 'turn off'])) {
        // Stop guardian mode
        await guardianRepository.endGuardianSession();
      }

      return true;
    } catch (e) {
      Logger.error('Failed to handle guardian mode command', e);
      return false;
    }
  }

  /// Handle alert circle command
  Future<bool> _handleAlertCircleCommand(String command) async {
    try {
      final circleRepository = sl<GuardianCircleRepository>();

      // Get default circle
      final circles = await circleRepository.getGuardianCircles();
      if (circles.isEmpty) {
        return false;
      }

      // Send alert to default circle
      await circleRepository.sendEmergencyAlert(
        emergencyType: 'voice_command',
        message: 'Voice command alert: $command',
        circleIds: [circles.first.id],
      );

      return true;
    } catch (e) {
      Logger.error('Failed to handle alert circle command', e);
      return false;
    }
  }

  /// Handle navigation command
  Future<bool> _handleNavigationCommand(String command) async {
    // In a real app, this would parse the destination and navigate
    // For this mock implementation, we'll just return success
    return true;
  }

  /// Handle safety check command
  Future<bool> _handleSafetyCheckCommand(String command) async {
    try {
      final circleRepository = sl<GuardianCircleRepository>();

      // Get default circle
      final circles = await circleRepository.getGuardianCircles();
      if (circles.isEmpty) {
        return false;
      }

      // Send safety check to default circle
      // Use sendEmergencyAlert with a safety type
      await circleRepository.sendEmergencyAlert(
        emergencyType: 'safety_check',
        message: 'I am safe. Voice command: $command',
        circleIds: [circles.first.id],
      );

      return true;
    } catch (e) {
      Logger.error('Failed to handle safety check command', e);
      return false;
    }
  }

  /// Handle general command
  Future<bool> _handleGeneralCommand(String command) async {
    // In a real app, this would navigate to different screens
    // For this mock implementation, we'll just return success
    return true;
  }

  /// Update voice recognition status
  void _updateStatus(VoiceRecognitionStatus status) {
    _status = status;
    _statusController.add(status);
  }

  /// Check if a string contains any of the given keywords
  bool _containsAny(String text, List<String> keywords) {
    return keywords.any((keyword) => text.contains(keyword));
  }

  /// Get a list of example commands
  List<String> getExampleCommands() {
    return [
      'Emergency SOS',
      'Start Guardian Mode',
      'Stop Guardian Mode',
      'Alert my Guardian Circle',
      'I am safe',
      'Navigate to the nearest safe zone',
      'Open the safety store',
    ];
  }

  /// Simulate voice recognition for testing
  Future<bool> simulateVoiceCommand(String command) async {
    _updateStatus(VoiceRecognitionStatus.listening);

    // Simulate processing delay
    await Future.delayed(const Duration(milliseconds: 500));

    return processCommand(command);
  }

  /// Dispose resources
  void dispose() {
    _recognitionTimer?.cancel();
    _statusController.close();
    _commandController.close();
  }
}
