/*
 * Guardian - Women's Safety App
 * © 2025 All Rights Reserved - Kunal Singh
 * Contact: kunalsingh2514@gmail.com
 */

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:guardian/core/services/ai_service.dart';
import 'package:guardian/core/utils/logger.dart';
import 'package:guardian/core/widgets/safety_alert.dart';

/// A service for managing safety notifications and alerts
class SafetyNotificationManager {
  static final SafetyNotificationManager _instance = SafetyNotificationManager._internal();
  
  /// AI service for risk assessment
  final AIService _aiService = AIService();
  
  /// Stream subscription for risk level updates
  StreamSubscription<RiskLevel>? _riskLevelSubscription;
  
  /// Stream subscription for safety suggestions
  StreamSubscription<String>? _safetySuggestionSubscription;
  
  /// Current risk level
  RiskLevel _currentRiskLevel = RiskLevel.low;
  
  /// Current safety suggestion
  String? _currentSafetySuggestion;
  
  /// Stream controller for safety alerts
  final StreamController<Map<String, dynamic>> _safetyAlertController = 
      StreamController<Map<String, dynamic>>.broadcast();
  
  /// Factory constructor
  factory SafetyNotificationManager() {
    return _instance;
  }
  
  /// Internal constructor
  SafetyNotificationManager._internal();
  
  /// Stream of safety alerts
  Stream<Map<String, dynamic>> get safetyAlertStream => _safetyAlertController.stream;
  
  /// Get the current risk level
  RiskLevel get currentRiskLevel => _currentRiskLevel;
  
  /// Get the current safety suggestion
  String? get currentSafetySuggestion => _currentSafetySuggestion;
  
  /// Initialize the manager
  Future<void> initialize() async {
    try {
      // Initialize AI service
      await _aiService.initialize();
      
      // Listen for risk level updates
      _riskLevelSubscription = _aiService.riskLevelStream.listen(_handleRiskLevelChange);
      
      // Listen for safety suggestions
      _safetySuggestionSubscription = _aiService.safetySuggestionStream.listen(_handleSafetySuggestion);
      
      Logger.info('Safety notification manager initialized');
    } catch (e) {
      Logger.error('Failed to initialize safety notification manager', e);
    }
  }
  
  /// Handle risk level changes
  void _handleRiskLevelChange(RiskLevel riskLevel) {
    _currentRiskLevel = riskLevel;
    
    // Only show alerts for medium and high risk levels
    if (riskLevel != RiskLevel.low) {
      _triggerRiskLevelAlert(riskLevel);
    }
  }
  
  /// Handle safety suggestions
  void _handleSafetySuggestion(String suggestion) {
    _currentSafetySuggestion = suggestion;
    
    // Show safety suggestion alert
    _triggerSafetySuggestionAlert(suggestion);
  }
  
  /// Trigger a risk level alert
  void _triggerRiskLevelAlert(RiskLevel riskLevel) {
    final alertData = {
      'type': 'risk_level',
      'risk_level': riskLevel,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
    
    _safetyAlertController.add(alertData);
  }
  
  /// Trigger a safety suggestion alert
  void _triggerSafetySuggestionAlert(String suggestion) {
    final alertData = {
      'type': 'suggestion',
      'suggestion': suggestion,
      'risk_level': _currentRiskLevel,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
    
    _safetyAlertController.add(alertData);
  }
  
  /// Show a safety alert dialog
  Future<void> showSafetyAlertDialog(BuildContext context, {
    required RiskLevel riskLevel,
    required String message,
    String? actionText,
    VoidCallback? onAction,
  }) async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(_getTitleForRiskLevel(riskLevel)),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('Dismiss'),
          ),
          if (actionText != null && onAction != null)
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                onAction();
              },
              child: Text(actionText),
            ),
        ],
      ),
    );
  }
  
  /// Show a safety alert snackbar
  void showSafetyAlertSnackBar(BuildContext context, {
    required RiskLevel riskLevel,
    required String message,
    Duration duration = const Duration(seconds: 5),
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              _getIconForRiskLevel(riskLevel),
              color: Colors.white,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(message),
            ),
          ],
        ),
        backgroundColor: _getColorForRiskLevel(riskLevel),
        duration: duration,
        action: SnackBarAction(
          label: 'Dismiss',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }
  
  /// Build a safety alert widget
  Widget buildSafetyAlert({
    required RiskLevel riskLevel,
    required String message,
    VoidCallback? onDismiss,
    VoidCallback? onAction,
    String? actionText,
  }) {
    return SafetyAlert(
      riskLevel: riskLevel,
      message: message,
      onDismiss: onDismiss,
      onAction: onAction,
      actionText: actionText,
    );
  }
  
  /// Get the title for a risk level
  String _getTitleForRiskLevel(RiskLevel riskLevel) {
    switch (riskLevel) {
      case RiskLevel.low:
        return 'Safety Tip';
      case RiskLevel.medium:
        return 'Safety Alert';
      case RiskLevel.high:
        return 'Warning';
    }
  }
  
  /// Get the icon for a risk level
  IconData _getIconForRiskLevel(RiskLevel riskLevel) {
    switch (riskLevel) {
      case RiskLevel.low:
        return Icons.check_circle;
      case RiskLevel.medium:
        return Icons.info;
      case RiskLevel.high:
        return Icons.warning;
    }
  }
  
  /// Get the color for a risk level
  Color _getColorForRiskLevel(RiskLevel riskLevel) {
    switch (riskLevel) {
      case RiskLevel.low:
        return Colors.green;
      case RiskLevel.medium:
        return Colors.orange;
      case RiskLevel.high:
        return Colors.red;
    }
  }
  
  /// Manually trigger a risk assessment
  Future<void> triggerRiskAssessment() async {
    await _aiService.triggerRiskAssessment();
  }
  
  /// Dispose resources
  void dispose() {
    _riskLevelSubscription?.cancel();
    _safetySuggestionSubscription?.cancel();
    _safetyAlertController.close();
  }
}
