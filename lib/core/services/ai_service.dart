import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:guardian/core/services/aws_incident_service.dart';
import 'package:guardian/core/utils/location_utils.dart';
import 'package:guardian/core/utils/logger.dart';

enum RiskLevel { low, medium, high }

/// Device telemetry risk engine and AWS Bedrock assistant facade.
/// It never fabricates incidents, locations, responders, or AI responses.
class AIService {
  static final AIService _instance = AIService._internal();
  factory AIService() => _instance;
  AIService._internal();

  Timer? _assessmentTimer;
  final _riskLevelController = StreamController<RiskLevel>.broadcast();
  final _suggestionController = StreamController<String>.broadcast();
  final List<Position> _locationHistory = [];
  RiskLevel _currentRiskLevel = RiskLevel.low;

  RiskLevel get currentRiskLevel => _currentRiskLevel;
  Stream<RiskLevel> get riskLevelStream => _riskLevelController.stream;
  Stream<String> get safetySuggestionStream => _suggestionController.stream;

  Future<void> initialize() async {
    _assessmentTimer?.cancel();
    _assessmentTimer = Timer.periodic(
      const Duration(minutes: 2),
      (_) => _performRiskAssessment(),
    );
    await _performRiskAssessment();
  }

  Future<void> _performRiskAssessment() async {
    try {
      final position = await LocationUtils.getCurrentPosition();
      if (position == null) return;
      _locationHistory.add(position);
      if (_locationHistory.length > 20) _locationHistory.removeAt(0);

      final hour = DateTime.now().hour;
      final nightRisk = hour >= 20 || hour < 5;
      final movementRisk = _locationHistory.length >= 3 &&
          _locationHistory.skip(_locationHistory.length - 3).every(
                (item) => item.speed.abs() < 0.5,
              );
      final next = nightRisk && movementRisk
          ? RiskLevel.high
          : nightRisk || movementRisk
              ? RiskLevel.medium
              : RiskLevel.low;

      if (next != _currentRiskLevel) {
        _currentRiskLevel = next;
        _riskLevelController.add(next);
        _suggestionController.add(_suggestionFor(next));
      }
    } catch (error, stackTrace) {
      Logger.error('Risk assessment failed', error, stackTrace);
    }
  }

  String _suggestionFor(RiskLevel level) {
    final time = DateFormat('HH:mm').format(DateTime.now());
    switch (level) {
      case RiskLevel.low:
        return 'No elevated device-telemetry risk detected at $time.';
      case RiskLevel.medium:
        return 'Stay aware of your surroundings and keep a trusted contact informed.';
      case RiskLevel.high:
        return 'Move to a populated, well-lit place and use SOS if you feel threatened.';
    }
  }

  Future<void> triggerRiskAssessment() => _performRiskAssessment();

  Future<String> getResponse(String message) {
    return AwsIncidentService.instance.askSafetyCompanion(message);
  }

  Future<String> generateLocationAdvice({
    required double latitude,
    required double longitude,
    required String safetyLevel,
    String? address,
  }) {
    return getResponse(
      'Give concise safety guidance for safety level $safetyLevel at '
      '${address ?? '$latitude,$longitude'}.',
    );
  }

  Future<String> generateSafetyAlert({
    required double latitude,
    required double longitude,
    required String safetyLevel,
    String? address,
  }) {
    return getResponse(
      'Draft a concise safety alert for level $safetyLevel at '
      '${address ?? '$latitude,$longitude'}.',
    );
  }

  void dispose() {
    _assessmentTimer?.cancel();
    _riskLevelController.close();
    _suggestionController.close();
  }
}
