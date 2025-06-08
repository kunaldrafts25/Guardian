/*
 * Guardian - Women's Safety App
 * © 2025 All Rights Reserved - Kunal Singh
 * Contact: kunalsingh2514@gmail.com
 */

import 'dart:async';
import 'dart:io';

import 'package:guardian/core/utils/logger.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:camera/camera.dart';

/// A service for recording audio and video evidence
class MediaRecordingService {
  static final MediaRecordingService _instance =
      MediaRecordingService._internal();

  /// Camera controller for video recording
  CameraController? _cameraController;

  /// Mock audio recorder
  final _audioRecorder = _MockAudioRecorder();

  /// Available cameras
  List<CameraDescription>? _cameras;

  /// Whether audio recording is in progress
  bool _isRecordingAudio = false;

  /// Whether video recording is in progress
  bool _isRecordingVideo = false;

  /// Path to the current audio recording
  String? _currentAudioPath;

  /// Path to the current video recording
  String? _currentVideoPath;

  /// Factory constructor
  factory MediaRecordingService() {
    return _instance;
  }

  /// Internal constructor
  MediaRecordingService._internal();

  /// Initialize the service
  Future<void> initialize() async {
    try {
      // Initialize cameras
      _cameras = await availableCameras();
    } catch (e) {
      Logger.error('Failed to initialize cameras', e);
    }
  }

  /// Check if audio recording is in progress
  bool get isRecordingAudio => _isRecordingAudio;

  /// Check if video recording is in progress
  bool get isRecordingVideo => _isRecordingVideo;

  /// Get the current audio recording path
  String? get currentAudioPath => _currentAudioPath;

  /// Get the current video recording path
  String? get currentVideoPath => _currentVideoPath;

  /// Check and request audio recording permissions
  Future<bool> checkAudioPermission() async {
    final status = await Permission.microphone.request();
    return status.isGranted;
  }

  /// Check and request video recording permissions
  Future<bool> checkVideoPermission() async {
    final cameraStatus = await Permission.camera.request();
    final microphoneStatus = await Permission.microphone.request();
    return cameraStatus.isGranted && microphoneStatus.isGranted;
  }

  /// Start recording audio
  Future<String?> startAudioRecording() async {
    try {
      if (_isRecordingAudio) {
        return _currentAudioPath;
      }

      // Check permission
      final hasPermission = await checkAudioPermission();
      if (!hasPermission) {
        throw Exception('Microphone permission not granted');
      }

      // Get directory for storing recordings
      final directory = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      _currentAudioPath = '${directory.path}/audio_$timestamp.m4a';

      // Configure recorder
      // Use simplified API for Record
      if (_currentAudioPath != null) {
        await _audioRecorder.start(
          path: _currentAudioPath!,
        );
      } else {
        throw Exception('Audio path is null');
      }

      _isRecordingAudio = true;
      Logger.info('Started audio recording at $_currentAudioPath');

      return _currentAudioPath;
    } catch (e) {
      Logger.error('Failed to start audio recording', e);
      _currentAudioPath = null;
      return null;
    }
  }

  /// Stop recording audio
  Future<String?> stopAudioRecording() async {
    try {
      if (!_isRecordingAudio) {
        return null;
      }

      final path = await _audioRecorder.stop();
      _isRecordingAudio = false;

      Logger.info('Stopped audio recording, saved at $path');
      return path;
    } catch (e) {
      Logger.error('Failed to stop audio recording', e);
      return null;
    }
  }

  /// Start recording video
  Future<String?> startVideoRecording() async {
    try {
      if (_isRecordingVideo) {
        return _currentVideoPath;
      }

      // Check permission
      final hasPermission = await checkVideoPermission();
      if (!hasPermission) {
        throw Exception('Camera or microphone permission not granted');
      }

      // Initialize camera if needed
      if (_cameraController == null ||
          !_cameraController!.value.isInitialized) {
        if (_cameras == null || _cameras!.isEmpty) {
          throw Exception('No cameras available');
        }

        _cameraController = CameraController(
          _cameras!.first,
          ResolutionPreset.medium,
          enableAudio: true,
        );

        await _cameraController!.initialize();
      }

      // Get directory for storing recordings
      final directory = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      _currentVideoPath = '${directory.path}/video_$timestamp.mp4';

      // Start recording
      await _cameraController!.startVideoRecording();

      _isRecordingVideo = true;
      Logger.info('Started video recording');

      return _currentVideoPath;
    } catch (e) {
      Logger.error('Failed to start video recording', e);
      _currentVideoPath = null;
      return null;
    }
  }

  /// Stop recording video
  Future<String?> stopVideoRecording() async {
    try {
      if (!_isRecordingVideo || _cameraController == null) {
        return null;
      }

      final file = await _cameraController!.stopVideoRecording();
      _isRecordingVideo = false;

      // Move the file to our path
      if (_currentVideoPath != null) {
        final videoFile = File(file.path);
        await videoFile.copy(_currentVideoPath!);
      }

      Logger.info('Stopped video recording, saved at $_currentVideoPath');
      return _currentVideoPath;
    } catch (e) {
      Logger.error('Failed to stop video recording', e);
      return null;
    }
  }

  /// Take a photo
  Future<String?> takePhoto() async {
    try {
      // Check permission
      final permissionStatus = await Permission.camera.request();
      if (permissionStatus != PermissionStatus.granted) {
        throw Exception('Camera permission not granted');
      }

      // Initialize camera if needed
      if (_cameraController == null ||
          !_cameraController!.value.isInitialized) {
        if (_cameras == null || _cameras!.isEmpty) {
          throw Exception('No cameras available');
        }

        _cameraController = CameraController(
          _cameras!.first,
          ResolutionPreset.high,
          enableAudio: false,
        );

        await _cameraController!.initialize();
      }

      // Take photo
      final xFile = await _cameraController!.takePicture();

      // Get directory for storing photos
      final directory = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final photoPath = '${directory.path}/photo_$timestamp.jpg';

      // Move the file to our path
      final photoFile = File(xFile.path);
      await photoFile.copy(photoPath);

      Logger.info('Photo taken, saved at $photoPath');
      return photoPath;
    } catch (e) {
      Logger.error('Failed to take photo', e);
      return null;
    }
  }

  /// Dispose resources
  Future<void> dispose() async {
    await _audioRecorder.dispose();
    await _cameraController?.dispose();
    _cameraController = null;
  }
}

/// A simple mock audio recorder for testing
class _MockAudioRecorder {
  /// Start recording audio
  Future<void> start({required String path}) async {
    // Mock implementation
    Logger.info('Mock audio recording started at $path');
    return;
  }

  /// Stop recording audio
  Future<String> stop() async {
    // Mock implementation
    Logger.info('Mock audio recording stopped');
    return 'mock_audio_path.m4a';
  }

  /// Dispose resources
  Future<void> dispose() async {
    // Mock implementation
    Logger.info('Mock audio recorder disposed');
    return;
  }
}
