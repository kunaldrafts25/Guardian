/*
 * Guardian - Women's Safety App
 * © 2025 All Rights Reserved - Kunal Singh
 * Contact: kunalsingh2514@gmail.com
 */

import 'dart:async';
import 'dart:math';
import 'package:geolocator/geolocator.dart';
import 'package:guardian/core/services/mock_data_service.dart';
import 'package:guardian/core/utils/logger.dart';
import 'package:guardian/core/utils/location_utils.dart';
import 'package:intl/intl.dart';

/// Risk level assessment
enum RiskLevel {
  /// Low risk situation
  low,

  /// Medium risk situation
  medium,

  /// High risk situation
  high,
}

/// A service for AI-based safety features
class AIService {
  static final AIService _instance = AIService._internal();

  /// Timer for periodic risk assessment
  Timer? _assessmentTimer;

  /// Stream controller for risk level updates
  final StreamController<RiskLevel> _riskLevelController =
      StreamController<RiskLevel>.broadcast();

  /// Stream controller for safety suggestions
  final StreamController<String> _safetySuggestionController =
      StreamController<String>.broadcast();

  /// Current risk level
  RiskLevel _currentRiskLevel = RiskLevel.low;

  /// Location history for pattern detection
  final List<Position> _locationHistory = [];

  /// Maximum location history size
  static const int _maxLocationHistorySize = 20;

  /// Factory constructor
  factory AIService() {
    return _instance;
  }

  /// Internal constructor
  AIService._internal();

  /// Get the current risk level
  RiskLevel get currentRiskLevel => _currentRiskLevel;

  /// Stream of risk level updates
  Stream<RiskLevel> get riskLevelStream => _riskLevelController.stream;

  /// Stream of safety suggestions
  Stream<String> get safetySuggestionStream =>
      _safetySuggestionController.stream;

  /// Initialize the service
  Future<void> initialize() async {
    // Start periodic risk assessment
    _startPeriodicAssessment();

    // Load unsafe areas from mock database
    await _loadUnsafeAreas();
  }

  /// Start periodic risk assessment
  void _startPeriodicAssessment() {
    // Cancel any existing timer
    _assessmentTimer?.cancel();

    // Start new timer (every 2 minutes)
    _assessmentTimer = Timer.periodic(
      const Duration(minutes: 2),
      (_) => _performRiskAssessment(),
    );

    // Perform initial assessment
    _performRiskAssessment();
  }

  /// Perform risk assessment
  Future<void> _performRiskAssessment() async {
    try {
      final position = await LocationUtils.getCurrentPosition();
      if (position == null) return;

      // Add to location history
      _addToLocationHistory(position);

      // Calculate risk factors
      final timeRiskFactor = _calculateTimeRiskFactor();
      final locationRiskFactor = await _calculateLocationRiskFactor(position);
      final movementRiskFactor = _calculateMovementRiskFactor();

      // Calculate overall risk level
      final overallRiskFactor =
          (timeRiskFactor + locationRiskFactor + movementRiskFactor) / 3;

      // Determine risk level
      RiskLevel newRiskLevel;
      if (overallRiskFactor < 0.3) {
        newRiskLevel = RiskLevel.low;
      } else if (overallRiskFactor < 0.7) {
        newRiskLevel = RiskLevel.medium;
      } else {
        newRiskLevel = RiskLevel.high;
      }

      // Update risk level if changed
      if (newRiskLevel != _currentRiskLevel) {
        _currentRiskLevel = newRiskLevel;
        _riskLevelController.add(_currentRiskLevel);

        // Generate safety suggestion based on risk level
        final suggestion = _generateSafetySuggestion(newRiskLevel);
        _safetySuggestionController.add(suggestion);
      }

      // Update assessment time (no need to store)
    } catch (e) {
      Logger.error('Error performing risk assessment', e);
    }
  }

  /// Add position to location history
  void _addToLocationHistory(Position position) {
    _locationHistory.add(position);

    // Trim history if too large
    if (_locationHistory.length > _maxLocationHistorySize) {
      _locationHistory.removeAt(0);
    }
  }

  /// Calculate risk factor based on time of day (0.0 - 1.0)
  double _calculateTimeRiskFactor() {
    final now = DateTime.now();
    final hour = now.hour;

    // Higher risk at night (8 PM - 5 AM)
    if (hour >= 20 || hour < 5) {
      return 0.8;
    }

    // Medium risk in evening/early morning (5 AM - 7 AM, 6 PM - 8 PM)
    if ((hour >= 5 && hour < 7) || (hour >= 18 && hour < 20)) {
      return 0.5;
    }

    // Lower risk during daytime
    return 0.2;
  }

  /// Calculate risk factor based on location (0.0 - 1.0)
  Future<double> _calculateLocationRiskFactor(Position position) async {
    try {
      // Check if location is in an unsafe area
      final isInUnsafeArea = await _isInUnsafeArea(position);
      if (isInUnsafeArea) {
        return 0.9;
      }

      // Check if location is isolated (mock implementation)
      final isIsolated = _isLocationIsolated(position);
      if (isIsolated) {
        return 0.7;
      }

      // Default risk factor
      return 0.3;
    } catch (e) {
      Logger.error('Error calculating location risk factor', e);
      return 0.5; // Default to medium risk on error
    }
  }

  /// Calculate risk factor based on movement patterns (0.0 - 1.0)
  double _calculateMovementRiskFactor() {
    if (_locationHistory.length < 3) {
      return 0.3; // Not enough data
    }

    try {
      // Check for erratic movement
      final isErratic = _isMovementErratic();
      if (isErratic) {
        return 0.8;
      }

      // Check if stationary for too long in unusual location
      final isStationaryTooLong = _isStationaryTooLong();
      if (isStationaryTooLong) {
        return 0.6;
      }

      // Default risk factor
      return 0.2;
    } catch (e) {
      Logger.error('Error calculating movement risk factor', e);
      return 0.3;
    }
  }

  /// Check if location is in an unsafe area
  Future<bool> _isInUnsafeArea(Position position) async {
    try {
      // In a real app, this would query a database of unsafe areas
      // For this mock, we'll use a simple check

      final incidents = await MockDataService.getCollection('incidents');

      // Check if there are any incidents reported nearby
      for (final incident in incidents) {
        if (incident.containsKey('location')) {
          final incidentLat = incident['location']['latitude'] as double;
          final incidentLng = incident['location']['longitude'] as double;

          final distance = Geolocator.distanceBetween(
            position.latitude,
            position.longitude,
            incidentLat,
            incidentLng,
          );

          // If incident is within 200 meters, consider it an unsafe area
          if (distance < 200) {
            return true;
          }
        }
      }

      return false;
    } catch (e) {
      Logger.error('Error checking if location is in unsafe area', e);
      return false;
    }
  }

  /// Check if location is isolated (mock implementation)
  bool _isLocationIsolated(Position position) {
    // In a real app, this would use population density data
    // For this mock, we'll use a random factor
    final random = Random();
    return random.nextDouble() < 0.2; // 20% chance of being "isolated"
  }

  /// Check if movement is erratic
  bool _isMovementErratic() {
    if (_locationHistory.length < 3) {
      return false;
    }

    // Calculate average speed and direction changes
    double totalSpeedChange = 0;
    double totalDirectionChange = 0;

    for (int i = 1; i < _locationHistory.length - 1; i++) {
      final prev = _locationHistory[i - 1];
      final current = _locationHistory[i];
      final next = _locationHistory[i + 1];

      // Speed change
      final prevSpeed = current.speed - prev.speed;
      final nextSpeed = next.speed - current.speed;
      totalSpeedChange += (prevSpeed - nextSpeed).abs();

      // Direction change (simplified)
      final prevBearing = Geolocator.bearingBetween(
        prev.latitude,
        prev.longitude,
        current.latitude,
        current.longitude,
      );

      final nextBearing = Geolocator.bearingBetween(
        current.latitude,
        current.longitude,
        next.latitude,
        next.longitude,
      );

      final directionChange = (nextBearing - prevBearing).abs();
      totalDirectionChange += directionChange;
    }

    final avgSpeedChange = totalSpeedChange / (_locationHistory.length - 2);
    final avgDirectionChange =
        totalDirectionChange / (_locationHistory.length - 2);

    // Thresholds for erratic movement
    return avgSpeedChange > 5 || avgDirectionChange > 45;
  }

  /// Check if stationary for too long in unusual location
  bool _isStationaryTooLong() {
    if (_locationHistory.length < 3) {
      return false;
    }

    // Check if all recent locations are very close to each other
    bool isStationary = true;
    final lastPosition = _locationHistory.last;

    for (int i = _locationHistory.length - 2;
        i >= _locationHistory.length - 4;
        i--) {
      if (i < 0) break;

      final distance = Geolocator.distanceBetween(
        lastPosition.latitude,
        lastPosition.longitude,
        _locationHistory[i].latitude,
        _locationHistory[i].longitude,
      );

      if (distance > 20) {
        // More than 20 meters
        isStationary = false;
        break;
      }
    }

    // If stationary, check if it's an unusual time or location
    if (isStationary) {
      final now = DateTime.now();
      final hour = now.hour;

      // Unusual time (late night)
      if (hour >= 23 || hour < 5) {
        return true;
      }

      // In a real app, we would check if this is an unusual location
      // For this mock, we'll use a random factor
      final random = Random();
      return random.nextDouble() < 0.3; // 30% chance of being "unusual"
    }

    return false;
  }

  /// Generate safety suggestion based on risk level
  String _generateSafetySuggestion(RiskLevel riskLevel) {
    final now = DateTime.now();
    final timeString = DateFormat('HH:mm').format(now);

    switch (riskLevel) {
      case RiskLevel.low:
        return 'You\'re in a safe area at $timeString. Enjoy your day!';

      case RiskLevel.medium:
        final suggestions = [
          'Stay aware of your surroundings at $timeString.',
          'Consider sharing your location with a trusted contact.',
          'Keep your phone charged and accessible.',
          'Stay in well-lit and populated areas.',
        ];
        return suggestions[Random().nextInt(suggestions.length)];

      case RiskLevel.high:
        final suggestions = [
          'This area has reported incidents. Consider taking a different route.',
          'It\'s $timeString and getting dark. Consider using a ride-sharing service.',
          'Share your live location with a trusted contact now.',
          'Stay in public, well-lit areas and remain vigilant.',
          'Consider activating Guardian Mode for enhanced safety.',
        ];
        return suggestions[Random().nextInt(suggestions.length)];
    }
  }

  /// Load unsafe areas from mock database
  Future<void> _loadUnsafeAreas() async {
    try {
      // In a real app, this would load unsafe areas from a database
      // For this mock, we'll use the incidents collection
      await MockDataService.getCollection('incidents');
    } catch (e) {
      Logger.error('Error loading unsafe areas', e);
    }
  }

  /// Manually trigger a risk assessment
  Future<void> triggerRiskAssessment() async {
    await _performRiskAssessment();
  }

  /// Dispose resources
  void dispose() {
    _assessmentTimer?.cancel();
    _riskLevelController.close();
    _safetySuggestionController.close();
  }

  /// Get AI response to a user message
  Future<String> getResponse(String message) async {
    try {
      // In a real app, this would call an AI API like OpenAI
      // For this mock, we'll use predefined responses

      final lowercaseMessage = message.toLowerCase();

      // Check for safety-related keywords
      if (lowercaseMessage.contains('safe') ||
          lowercaseMessage.contains('danger') ||
          lowercaseMessage.contains('scared') ||
          lowercaseMessage.contains('afraid') ||
          lowercaseMessage.contains('help')) {
        return _getSafetyResponse(message);
      }

      // Check for location-related keywords
      if (lowercaseMessage.contains('location') ||
          lowercaseMessage.contains('where') ||
          lowercaseMessage.contains('area') ||
          lowercaseMessage.contains('place')) {
        return await _getLocationResponse();
      }

      // Check for emergency-related keywords
      if (lowercaseMessage.contains('emergency') ||
          lowercaseMessage.contains('sos') ||
          lowercaseMessage.contains('attack') ||
          lowercaseMessage.contains('urgent')) {
        return _getEmergencyResponse();
      }

      // General response
      return _getGeneralResponse(message);
    } catch (e) {
      Logger.error('Error getting AI response', e);
      return 'I apologize, but I encountered an error processing your request. Please try again.';
    }
  }

  /// Get safety-related response
  String _getSafetyResponse(String message) {
    final responses = [
      'Your safety is my top priority. [SAFETY_ADVICE][SAFETY_ADVICE_TITLE]Personal Safety Tips[/SAFETY_ADVICE_TITLE][SAFETY_ADVICE_CONTENT]Always be aware of your surroundings, especially in unfamiliar areas. Keep your phone charged and share your location with trusted contacts when traveling alone. Consider using the Guardian Mode feature for enhanced safety monitoring.[/SAFETY_ADVICE_CONTENT][/SAFETY_ADVICE] Is there a specific safety concern you\'d like me to address?',
      'I understand safety is important to you. [SAFETY_ADVICE][SAFETY_ADVICE_TITLE]Safety in Public Places[/SAFETY_ADVICE_TITLE][SAFETY_ADVICE_CONTENT]Stay in well-lit, populated areas when possible. Trust your instincts - if something feels wrong, remove yourself from the situation. Keep valuables concealed and maintain awareness of exit routes in any location.[/SAFETY_ADVICE_CONTENT][/SAFETY_ADVICE] Would you like more specific advice for your situation?',
      'I\'m here to help you stay safe. [SAFETY_ADVICE][SAFETY_ADVICE_TITLE]Nighttime Safety Practices[/SAFETY_ADVICE_TITLE][SAFETY_ADVICE_CONTENT]When out at night, stick to well-lit paths and avoid shortcuts through isolated areas. Consider using ride-sharing services instead of walking alone. The Guardian app\'s SOS feature can be activated quickly if you feel threatened.[/SAFETY_ADVICE_CONTENT][/SAFETY_ADVICE] Is there anything specific about your safety concerns I can help with?',
    ];

    return responses[Random().nextInt(responses.length)];
  }

  /// Get location-related response
  Future<String> _getLocationResponse() async {
    try {
      final position = await LocationUtils.getCurrentPosition();

      if (position == null) {
        return 'I couldn\'t access your current location. Please make sure location services are enabled.';
      }

      final address = await LocationUtils.getAddressFromPosition(position);

      return 'Based on your current location${address != null ? ' near $address' : ''}, [SAFETY_ADVICE][SAFETY_ADVICE_TITLE]Location-Specific Safety Tips[/SAFETY_ADVICE_TITLE][SAFETY_ADVICE_CONTENT]Stay on main roads and well-lit paths. Be aware that unfamiliar areas may have different safety considerations. Consider checking the Safe Zones map in the app to identify community-verified safe areas nearby.[/SAFETY_ADVICE_CONTENT][/SAFETY_ADVICE] Would you like me to help you find the nearest safe zone?';
    } catch (e) {
      Logger.error('Error getting location response', e);
      return 'I couldn\'t analyze your location right now. [SAFETY_ADVICE][SAFETY_ADVICE_TITLE]General Location Safety[/SAFETY_ADVICE_TITLE][SAFETY_ADVICE_CONTENT]Regardless of where you are, stay aware of your surroundings and trust your instincts. If you feel unsafe, move to a more populated area or business.[/SAFETY_ADVICE_CONTENT][/SAFETY_ADVICE]';
    }
  }

  /// Get emergency-related response
  String _getEmergencyResponse() {
    return 'This sounds like an emergency situation. If you\'re in immediate danger, please use the SOS button in the app or call emergency services directly. [SAFETY_ADVICE][SAFETY_ADVICE_TITLE]Emergency Response[/SAFETY_ADVICE_TITLE][SAFETY_ADVICE_CONTENT]Stay calm and find a safe location if possible. Use the Guardian app\'s emergency features to alert your trusted contacts. Remember that your safety is the priority - leave any belongings behind if necessary to reach safety.[/SAFETY_ADVICE_CONTENT][/SAFETY_ADVICE] Would you like me to help you activate the emergency alert feature?';
  }

  /// Get general response
  String _getGeneralResponse(String message) {
    final responses = [
      'I\'m your Guardian AI assistant, here to help you stay safe. How can I assist you today?',
      'Thank you for your message. I\'m designed to provide safety advice and assistance. Is there something specific you\'d like help with?',
      'I\'m here to support your safety needs. I can provide advice, help you use the app\'s features, or answer questions about personal safety. What would you like to know?',
      'I\'m listening and ready to help. For the most effective assistance, please share any safety concerns or questions you have.',
    ];

    return responses[Random().nextInt(responses.length)];
  }

  /// Generate location-based safety advice
  Future<String> generateLocationAdvice({
    required double latitude,
    required double longitude,
    required String safetyLevel,
    String? address,
  }) async {
    try {
      // In a real app, this would use an AI model with location context
      // For this mock, we'll use predefined advice based on safety level

      final locationContext = address != null ? ' in $address' : '';

      switch (safetyLevel) {
        case 'very_safe':
          return 'This area$locationContext is considered very safe by the community. Continue to practice standard safety awareness, but this location has a strong safety record. Enjoy your time here!';

        case 'safe':
          return 'You\'re currently$locationContext, which is generally considered safe. As always, remain aware of your surroundings and follow basic safety practices, especially after dark.';

        case 'moderate':
          return 'Your current location$locationContext has a moderate safety rating. Stay alert and aware of your surroundings. Consider using the Guardian Mode feature for additional safety monitoring, especially during evening hours.';

        case 'caution':
          return 'Exercise caution in this area$locationContext. Community reports indicate varying safety levels depending on time of day. Stick to well-lit, populated areas and consider sharing your location with trusted contacts while here.';

        case 'unsafe':
          return 'This location$locationContext has been flagged as potentially unsafe by community reports. If possible, consider alternative routes or locations. Stay in public areas, remain vigilant, and keep your Guardian Circle updated on your whereabouts.';

        case 'very_unsafe':
          return 'Warning: You\'re in an area$locationContext with significant safety concerns reported by the community. If possible, leave this area or use caution. Activate Guardian Mode, stay in well-lit public places, and consider using transportation services rather than walking.';

        default:
          return 'I don\'t have specific safety information for this location$locationContext. As a general precaution, stay aware of your surroundings and trust your instincts.';
      }
    } catch (e) {
      Logger.error('Error generating location advice', e);
      return 'I couldn\'t generate specific advice for your location. As a general safety practice, stay aware of your surroundings and use the app\'s safety features when needed.';
    }
  }

  /// Generate safety alert
  Future<String> generateSafetyAlert({
    required double latitude,
    required double longitude,
    required String safetyLevel,
    String? address,
  }) async {
    try {
      // In a real app, this would use an AI model with location context
      // For this mock, we'll use predefined alerts based on safety level

      final locationContext = address != null ? ' in $address' : '';

      switch (safetyLevel) {
        case 'caution':
          return 'Safety Alert: Exercise caution$locationContext. This area has time-specific safety concerns, particularly ${_isNightTime() ? 'during nighttime hours' : 'during certain hours'}. Stay in well-lit, populated areas and remain vigilant.';

        case 'unsafe':
          return 'Safety Alert: Your current location$locationContext has been reported as having safety concerns by community members. Consider using main roads, staying in public areas, and sharing your location with trusted contacts.';

        case 'very_unsafe':
          return 'Urgent Safety Alert: You\'ve entered an area$locationContext with significant safety concerns. If possible, consider leaving this area or using transportation services. Activate Guardian Mode for enhanced safety monitoring.';

        default:
          return 'Safety Notice: While I don\'t have specific alerts for this location$locationContext, always practice general safety awareness, especially in unfamiliar areas.';
      }
    } catch (e) {
      Logger.error('Error generating safety alert', e);
      return 'Safety Alert: I\'ve detected potential safety concerns but couldn\'t analyze the specific details. Please remain vigilant and use the app\'s safety features if needed.';
    }
  }

  /// Check if current time is night time
  bool _isNightTime() {
    final hour = DateTime.now().hour;
    return hour >= 20 || hour < 6;
  }
}
