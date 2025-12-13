/*
 * Guardian - Women's Safety App
 * © 2025 All Rights Reserved - Kunal Singh
 * Contact: kunalsingh2514@gmail.com
 */

import 'dart:async';
import 'package:guardian/core/services/mock_auth_service.dart';
import 'package:guardian/core/services/mock_data_service.dart';
import 'package:guardian/core/services/ai_service.dart' as ai_service;
import 'package:guardian/core/utils/logger.dart';
import 'package:guardian/core/utils/location_utils.dart';
import 'package:guardian/features/ai_assistant/data/models/ai_model.dart';

/// Repository for handling AI assistant functionality
class AIRepository {
  static const String _adviceCollection = 'safety_advice';
  static const String _chatCollection = 'ai_chats';
  static const String _alertsCollection = 'safety_alerts';

  final ai_service.AIService _aiService = ai_service.AIService();

  /// Stream controller for safety alerts
  final StreamController<SafetyAlert> _alertController =
      StreamController<SafetyAlert>.broadcast();

  /// Stream of safety alerts
  Stream<SafetyAlert> get alertStream => _alertController.stream;

  AIRepository();

  /// Get all safety advice for the user
  Future<List<SafetyAdvice>> getSafetyAdvice() async {
    try {
      final user = MockAuthService.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      final adviceData = await MockDataService.getCollection(_adviceCollection);

      return adviceData
          .where((advice) => advice['userId'] == user.uid)
          .map((advice) => SafetyAdvice.fromMap(advice))
          .toList();
    } catch (e) {
      Logger.error('Failed to get safety advice', e);
      return [];
    }
  }

  /// Get safety advice by ID
  Future<SafetyAdvice?> getSafetyAdviceById(String id) async {
    try {
      final adviceData =
          await MockDataService.getDocument(_adviceCollection, id);

      if (adviceData == null) {
        return null;
      }

      return SafetyAdvice.fromMap(adviceData);
    } catch (e) {
      Logger.error('Failed to get safety advice by ID', e);
      return null;
    }
  }

  /// Mark safety advice as read
  Future<bool> markAdviceAsRead(String id) async {
    try {
      final advice = await getSafetyAdviceById(id);

      if (advice == null) {
        return false;
      }

      final updatedAdvice = advice.copyWith(isRead: true);

      return await MockDataService.updateDocument(
        _adviceCollection,
        id,
        updatedAdvice.toMap(),
      );
    } catch (e) {
      Logger.error('Failed to mark advice as read', e);
      return false;
    }
  }

  /// Get chat history for the user
  Future<List<ChatMessage>> getChatHistory() async {
    try {
      final user = MockAuthService.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      final chatData =
          await MockDataService.getDocument(_chatCollection, user.uid);

      if (chatData == null) {
        return [];
      }

      final messages = (chatData['messages'] as List?)
              ?.map((message) => ChatMessage.fromMap(message))
              .toList() ??
          [];

      // Sort by timestamp
      messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));

      return messages;
    } catch (e) {
      Logger.error('Failed to get chat history', e);
      return [];
    }
  }

  /// Send a message to the AI assistant
  Future<ChatMessage?> sendMessage(String message) async {
    try {
      final user = MockAuthService.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Create user message
      final userMessage = ChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        content: message,
        isUserMessage: true,
      );

      // Add user message to chat history
      await _addMessageToHistory(userMessage);

      // Get AI response
      final aiResponse = await _aiService.getResponse(message);

      // Check if response contains safety advice
      final containsAdvice = aiResponse.contains('[SAFETY_ADVICE]');
      String? adviceId;

      if (containsAdvice) {
        // Extract and save advice
        final adviceTitle = _extractAdviceTitle(aiResponse);
        final adviceContent = _extractAdviceContent(aiResponse);

        final advice = SafetyAdvice(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          title: adviceTitle,
          content: adviceContent,
          type: AdviceType.situation,
          riskLevel: RiskLevel.medium,
          isPersonalized: true,
          tags: ['ai_generated', 'chat_response'],
        );

        adviceId = await _saveAdvice(advice);
      }

      // Clean response (remove advice markers)
      final cleanResponse = _cleanResponse(aiResponse);

      // Create AI message
      final aiMessage = ChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        content: cleanResponse,
        isUserMessage: false,
        containsAdvice: containsAdvice,
        adviceId: adviceId,
      );

      // Add AI message to chat history
      await _addMessageToHistory(aiMessage);

      return aiMessage;
    } catch (e) {
      Logger.error('Failed to send message', e);
      return null;
    }
  }

  /// Add a message to chat history
  Future<bool> _addMessageToHistory(ChatMessage message) async {
    try {
      final user = MockAuthService.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Get current chat history
      final messages = await getChatHistory();

      // Add new message
      messages.add(message);

      // Save updated chat history
      final chatDoc =
          await MockDataService.getDocument(_chatCollection, user.uid);

      if (chatDoc != null && chatDoc.isNotEmpty) {
        return await MockDataService.updateDocument(
          _chatCollection,
          user.uid,
          {'messages': messages.map((m) => m.toMap()).toList()},
        );
      } else {
        final chatId = await MockDataService.addDocument(
          _chatCollection,
          {
            'userId': user.uid,
            'messages': messages.map((m) => m.toMap()).toList(),
          },
        );
        return chatId.isNotEmpty;
      }
    } catch (e) {
      Logger.error('Failed to add message to history', e);
      return false;
    }
  }

  /// Extract advice title from AI response
  String _extractAdviceTitle(String response) {
    const startMarker = '[SAFETY_ADVICE_TITLE]';
    const endMarker = '[/SAFETY_ADVICE_TITLE]';

    final startIndex = response.indexOf(startMarker);
    final endIndex = response.indexOf(endMarker);

    if (startIndex >= 0 && endIndex > startIndex) {
      return response
          .substring(
            startIndex + startMarker.length,
            endIndex,
          )
          .trim();
    }

    return 'Safety Advice';
  }

  /// Extract advice content from AI response
  String _extractAdviceContent(String response) {
    const startMarker = '[SAFETY_ADVICE_CONTENT]';
    const endMarker = '[/SAFETY_ADVICE_CONTENT]';

    final startIndex = response.indexOf(startMarker);
    final endIndex = response.indexOf(endMarker);

    if (startIndex >= 0 && endIndex > startIndex) {
      return response
          .substring(
            startIndex + startMarker.length,
            endIndex,
          )
          .trim();
    }

    // If markers not found, extract between general markers
    const generalStartMarker = '[SAFETY_ADVICE]';
    const generalEndMarker = '[/SAFETY_ADVICE]';

    final generalStartIndex = response.indexOf(generalStartMarker);
    final generalEndIndex = response.indexOf(generalEndMarker);

    if (generalStartIndex >= 0 && generalEndIndex > generalStartIndex) {
      return response
          .substring(
            generalStartIndex + generalStartMarker.length,
            generalEndIndex,
          )
          .trim();
    }

    return 'No specific advice content found.';
  }

  /// Clean AI response by removing advice markers
  String _cleanResponse(String response) {
    String cleaned = response;

    // Remove all advice markers
    final markers = [
      '[SAFETY_ADVICE]',
      '[/SAFETY_ADVICE]',
      '[SAFETY_ADVICE_TITLE]',
      '[/SAFETY_ADVICE_TITLE]',
      '[SAFETY_ADVICE_CONTENT]',
      '[/SAFETY_ADVICE_CONTENT]',
    ];

    for (final marker in markers) {
      cleaned = cleaned.replaceAll(marker, '');
    }

    return cleaned.trim();
  }

  /// Save safety advice
  Future<String?> _saveAdvice(SafetyAdvice advice) async {
    try {
      final user = MockAuthService.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Add user ID to advice
      final adviceWithUser = advice.toMap()..['userId'] = user.uid;

      return await MockDataService.addDocument(
        _adviceCollection,
        adviceWithUser,
      );
    } catch (e) {
      Logger.error('Failed to save advice', e);
      return null;
    }
  }

  /// Get all safety alerts for the user
  Future<List<SafetyAlert>> getSafetyAlerts() async {
    try {
      final user = MockAuthService.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      final alertsData = await MockDataService.getCollection(_alertsCollection);

      return alertsData
          .where((alert) => alert['userId'] == user.uid)
          .map((alert) => SafetyAlert.fromMap(alert))
          .toList();
    } catch (e) {
      Logger.error('Failed to get safety alerts', e);
      return [];
    }
  }

  /// Get safety alert by ID
  Future<SafetyAlert?> getSafetyAlertById(String id) async {
    try {
      final alertData =
          await MockDataService.getDocument(_alertsCollection, id);

      if (alertData == null) {
        return null;
      }

      return SafetyAlert.fromMap(alertData);
    } catch (e) {
      Logger.error('Failed to get safety alert by ID', e);
      return null;
    }
  }

  /// Mark safety alert as read
  Future<bool> markAlertAsRead(String id) async {
    try {
      final alert = await getSafetyAlertById(id);

      if (alert == null) {
        return false;
      }

      final updatedAlert = alert.copyWith(isRead: true);

      return await MockDataService.updateDocument(
        _alertsCollection,
        id,
        updatedAlert.toMap(),
      );
    } catch (e) {
      Logger.error('Failed to mark alert as read', e);
      return false;
    }
  }

  /// Dismiss safety alert
  Future<bool> dismissAlert(String id) async {
    try {
      final alert = await getSafetyAlertById(id);

      if (alert == null) {
        return false;
      }

      final updatedAlert = alert.copyWith(isDismissed: true);

      return await MockDataService.updateDocument(
        _alertsCollection,
        id,
        updatedAlert.toMap(),
      );
    } catch (e) {
      Logger.error('Failed to dismiss alert', e);
      return false;
    }
  }

  /// Generate location-based safety advice
  Future<SafetyAdvice?> generateLocationAdvice() async {
    try {
      final position = await LocationUtils.getCurrentPosition();

      if (position == null) {
        throw Exception('Failed to get current location');
      }

      // TODO: Integrate with SafeZoneProvider for safety level
      const safetyLevel = 'moderate';

      // Get address
      final address = await LocationUtils.getAddressFromPosition(position);

      // Generate advice based on safety level
      final advice = await _aiService.generateLocationAdvice(
        latitude: position.latitude,
        longitude: position.longitude,
        safetyLevel: safetyLevel,
        address: address,
      );

      // Create safety advice
      final safetyAdvice = SafetyAdvice(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: 'Safety Advice for ${address ?? 'Current Location'}',
        content: advice,
        type: AdviceType.location,
        riskLevel: _getRiskLevelFromSafetyLevel(safetyLevel),
        isPersonalized: true,
        tags: ['location_based', 'ai_generated'],
        locationContext: {
          'latitude': position.latitude,
          'longitude': position.longitude,
          'address': address,
          'safetyLevel': safetyLevel,
        },
      );

      // Save advice
      final adviceId = await _saveAdvice(safetyAdvice);

      if (adviceId == null) {
        return null;
      }

      return safetyAdvice;
    } catch (e) {
      Logger.error('Failed to generate location advice', e);
      return null;
    }
  }

  /// Generate predictive safety alert
  Future<SafetyAlert?> generatePredictiveAlert() async {
    try {
      final position = await LocationUtils.getCurrentPosition();

      if (position == null) {
        throw Exception('Failed to get current location');
      }

      // TODO: Integrate with SafeZoneProvider for safety level
      const safetyLevel = 'moderate';

      // Only generate alert for unsafe areas
      if (safetyLevel == 'safe' || safetyLevel == 'very_safe') {
        return null;
      }

      // Get address
      final address = await LocationUtils.getAddressFromPosition(position);

      // Generate alert content
      final alertContent = await _aiService.generateSafetyAlert(
        latitude: position.latitude,
        longitude: position.longitude,
        safetyLevel: safetyLevel,
        address: address,
      );

      // Create safety alert
      final safetyAlert = SafetyAlert(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: 'Safety Alert for ${address ?? 'Current Location'}',
        content: alertContent,
        riskLevel: _getRiskLevelFromSafetyLevel(safetyLevel),
        locationContext: {
          'latitude': position.latitude,
          'longitude': position.longitude,
          'address': address,
          'safetyLevel': safetyLevel,
        },
        actionText: 'View Safe Routes',
        actionData: {
          'action': 'view_safe_routes',
          'latitude': position.latitude,
          'longitude': position.longitude,
        },
      );

      // Save alert
      final user = MockAuthService.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Add user ID to alert
      final alertWithUser = safetyAlert.toMap()..['userId'] = user.uid;

      final alertId = await MockDataService.addDocument(
        _alertsCollection,
        alertWithUser,
      );

      if (alertId.isEmpty) {
        return null;
      }

      // Notify listeners
      _alertController.add(safetyAlert);

      return safetyAlert;
    } catch (e) {
      Logger.error('Failed to generate predictive alert', e);
      return null;
    }
  }

  /// Get risk level from safety level
  RiskLevel _getRiskLevelFromSafetyLevel(String safetyLevel) {
    switch (safetyLevel) {
      case 'very_unsafe':
      case 'unsafe':
        return RiskLevel.high;
      case 'moderate':
      case 'caution':
        return RiskLevel.medium;
      case 'safe':
      case 'very_safe':
        return RiskLevel.low;
      default:
        return RiskLevel.low;
    }
  }

  /// Dispose resources
  void dispose() {
    _alertController.close();
  }
}
