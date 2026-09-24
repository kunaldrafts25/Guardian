/*
 * Guardian 2.0 - Women's Safety App
 * © 2025 All Rights Reserved - Kunal Singh
 * 
 * Voice Recognition Service - Native speech recognition for SOS trigger
 */

import 'dart:async';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:guardian/core/utils/logger.dart';

/// Callback for when trigger phrase is detected
typedef TriggerCallback = void Function(String phrase);

/// Voice Recognition Service using speech_to_text package
class VoiceRecognitionService {
  static VoiceRecognitionService? _instance;
  static VoiceRecognitionService get instance =>
      _instance ??= VoiceRecognitionService._();

  VoiceRecognitionService._();

  final SpeechToText _speech = SpeechToText();
  bool _isInitialized = false;
  bool _isListening = false;
  TriggerCallback? _onTriggerDetected;

  /// Trigger phrases that will activate SOS
  /// P1-11: Voice SOS is experimental/foreground-only. Generic words like "help" 
  /// are removed to prevent false positives. Specific wake phrases required.
  final List<String> _triggerPhrases = [
    'guardian help',
    'guardian emergency',
    'guardian sos',
    'guardian save me',
    'guardian bachao', // Hindi
    'guardian madad', // Hindi
  ];

  /// Check if listening
  bool get isListening => _isListening;

  /// Get trigger phrases
  List<String> get triggerPhrases => List.unmodifiable(_triggerPhrases);

  /// Initialize speech recognition
  Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      // Request microphone permission
      final status = await Permission.microphone.request();
      if (!status.isGranted) {
        Logger.warning('🎤 Microphone permission denied');
        return false;
      }

      _isInitialized = await _speech.initialize(
        onStatus: _onStatus,
        onError: _onError,
        debugLogging: false,
      );

      if (_isInitialized) {
        Logger.info('🎤 Voice recognition initialized');
      } else {
        Logger.warning('🎤 Voice recognition not available on this device');
      }

      return _isInitialized;
    } catch (e) {
      Logger.error('🎤 Failed to initialize voice recognition', e);
      return false;
    }
  }

  /// Start listening for voice commands
  Future<bool> startListening({TriggerCallback? onTrigger}) async {
    if (_isListening) return true;

    if (!_isInitialized) {
      final initialized = await initialize();
      if (!initialized) return false;
    }

    _onTriggerDetected = onTrigger;

    try {
      await _speech.listen(
        onResult: _onSpeechResult,
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 3),
        partialResults: true,
        localeId: 'en_US',
        cancelOnError: false,
        listenMode: ListenMode.confirmation,
      );

      _isListening = true;
      Logger.info('🎤 Voice recognition started');
      return true;
    } catch (e) {
      Logger.error('🎤 Failed to start listening', e);
      return false;
    }
  }

  /// Stop listening
  Future<void> stopListening() async {
    if (!_isListening) return;

    await _speech.stop();
    _isListening = false;
    Logger.info('🎤 Voice recognition stopped');
  }

  /// Add custom trigger phrase
  void addTriggerPhrase(String phrase) {
    final lower = phrase.toLowerCase().trim();
    if (lower.isNotEmpty && !_triggerPhrases.contains(lower)) {
      _triggerPhrases.add(lower);
      Logger.info('🎤 Added trigger phrase: $lower');
    }
  }

  /// Remove trigger phrase
  void removeTriggerPhrase(String phrase) {
    final lower = phrase.toLowerCase().trim();
    if (_triggerPhrases.remove(lower)) {
      Logger.info('🎤 Removed trigger phrase: $lower');
    }
  }

  /// Handle speech recognition result
  void _onSpeechResult(SpeechRecognitionResult result) {
    final text = result.recognizedWords.toLowerCase();
    Logger.debug('🎤 Heard: $text');

    // Check for trigger phrases
    for (final phrase in _triggerPhrases) {
      if (text.contains(phrase)) {
        Logger.info('🎤 TRIGGER PHRASE DETECTED: $phrase');
        _onTriggerDetected?.call(phrase);

        // Stop listening after trigger to prevent repeated triggers
        stopListening();
        break;
      }
    }

    // Auto-restart listening if it stops
    if (result.finalResult && _isListening) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (!_speech.isListening && _isListening) {
          startListening(onTrigger: _onTriggerDetected);
        }
      });
    }
  }

  /// Handle status changes
  void _onStatus(String status) {
    Logger.debug('🎤 Status: $status');
    if (status == 'notListening' && _isListening) {
      // Restart if we should still be listening
      Future.delayed(const Duration(seconds: 1), () {
        if (_isListening) {
          startListening(onTrigger: _onTriggerDetected);
        }
      });
    }
  }

  /// Handle errors
  void _onError(dynamic error) {
    Logger.error('🎤 Error: $error');
  }

  /// Dispose resources
  void dispose() {
    stopListening();
    _instance = null;
  }
}
