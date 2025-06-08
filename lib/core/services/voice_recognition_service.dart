/*
 * Guardian - Women's Safety App
 * © 2025 All Rights Reserved - Kunal Singh
 * Contact: kunalsingh2514@gmail.com
 */

import 'dart:async';
import 'package:flutter/services.dart';
import 'package:guardian/core/services/emergency_service.dart';
import 'package:guardian/core/utils/logger.dart';
import 'package:permission_handler/permission_handler.dart';

/// A service for voice recognition and emergency trigger
class VoiceRecognitionService {
  static const MethodChannel _channel = MethodChannel('com.guardian/voice_recognition');
  static bool _isListening = false;
  static final List<String> _triggerPhrases = [
    'help',
    'emergency',
    'sos',
    'save me',
    'danger',
    'help me',
  ];
  
  /// Check if the service is currently listening
  static bool get isListening => _isListening;
  
  /// Get the list of trigger phrases
  static List<String> get triggerPhrases => _triggerPhrases;
  
  /// Start listening for voice commands
  static Future<bool> startListening() async {
    if (_isListening) return true;
    
    try {
      // Check microphone permission
      final status = await Permission.microphone.request();
      if (!status.isGranted) {
        Logger.warning('Microphone permission not granted');
        return false;
      }
      
      // Start listening
      final bool result = await _channel.invokeMethod('startVoiceRecognition');
      _isListening = result;
      
      if (result) {
        Logger.info('Voice recognition started');
        
        // Set up method call handler
        _channel.setMethodCallHandler(_handleMethodCall);
      }
      
      return result;
    } on PlatformException catch (e) {
      Logger.error('Failed to start voice recognition', e.message);
      return false;
    }
  }
  
  /// Stop listening for voice commands
  static Future<bool> stopListening() async {
    if (!_isListening) return true;
    
    try {
      final bool result = await _channel.invokeMethod('stopVoiceRecognition');
      _isListening = !result;
      
      if (result) {
        Logger.info('Voice recognition stopped');
      }
      
      return result;
    } on PlatformException catch (e) {
      Logger.error('Failed to stop voice recognition', e.message);
      return false;
    }
  }
  
  /// Add a custom trigger phrase
  static void addTriggerPhrase(String phrase) {
    if (phrase.isNotEmpty && !_triggerPhrases.contains(phrase.toLowerCase())) {
      _triggerPhrases.add(phrase.toLowerCase());
      Logger.info('Added trigger phrase: $phrase');
    }
  }
  
  /// Remove a trigger phrase
  static void removeTriggerPhrase(String phrase) {
    if (_triggerPhrases.contains(phrase.toLowerCase())) {
      _triggerPhrases.remove(phrase.toLowerCase());
      Logger.info('Removed trigger phrase: $phrase');
    }
  }
  
  /// Handle method calls from the platform
  static Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onSpeechRecognized':
        final String text = call.arguments['text'];
        return _processSpeechResult(text);
      default:
        Logger.warning('Unknown method ${call.method}');
    }
  }
  
  /// Process speech recognition result
  static Future<void> _processSpeechResult(String text) async {
    Logger.info('Speech recognized: $text');
    
    // Check if the text contains any trigger phrases
    final lowerText = text.toLowerCase();
    for (final phrase in _triggerPhrases) {
      if (lowerText.contains(phrase)) {
        Logger.info('Trigger phrase detected: $phrase');
        await _triggerEmergency();
        break;
      }
    }
  }
  
  /// Trigger emergency alert
  static Future<void> _triggerEmergency() async {
    try {
      final alertId = await EmergencyService.triggerEmergencyAlert();
      if (alertId != null) {
        Logger.info('Emergency alert triggered by voice: $alertId');
      } else {
        Logger.error('Failed to trigger emergency alert by voice');
      }
    } catch (e) {
      Logger.error('Error triggering emergency alert by voice', e);
    }
  }
  
  /// Simulate voice recognition for testing
  static Future<void> simulateVoiceRecognition(String text) async {
    Logger.info('Simulating voice recognition: $text');
    await _processSpeechResult(text);
  }
}

