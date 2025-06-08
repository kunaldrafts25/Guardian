/*
 * Guardian - Women's Safety App
 * © 2025 All Rights Reserved - Kunal Singh
 * Contact: kunalsingh2514@gmail.com
 */

import 'dart:io';
import 'package:geolocator/geolocator.dart';
import 'package:guardian/core/services/mock_auth_service.dart';
import 'package:guardian/core/services/mock_data_service.dart';
import 'package:guardian/core/utils/logger.dart';
import 'package:guardian/features/incident_reporting/data/models/incident_report_model.dart';
import 'package:guardian/features/incident_reporting/data/services/media_recording_service.dart';
import 'package:path/path.dart' as path;

/// Repository for handling incident reporting functionality
class IncidentRepository {
  static const String _incidentsCollection = 'incidents';
  static const String _evidenceCollection = 'evidence';
  
  final MediaRecordingService _mediaService = MediaRecordingService();
  
  /// Initialize the repository
  Future<void> init() async {
    await _mediaService.initialize();
  }
  
  /// Get all incident reports for the current user
  Future<List<IncidentReport>> getIncidentReports() async {
    try {
      final user = MockAuthService.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }
      
      final incidents = await MockDataService.getCollection(_incidentsCollection);
      
      return incidents
          .where((incident) => incident['userId'] == user.uid)
          .map((incident) => IncidentReport.fromMap(incident))
          .toList();
    } catch (e) {
      Logger.error('Failed to get incident reports', e);
      return [];
    }
  }
  
  /// Get a specific incident report by ID
  Future<IncidentReport?> getIncidentReport(String id) async {
    try {
      final incidentData = await MockDataService.getDocument(_incidentsCollection, id);
      
      if (incidentData == null) {
        return null;
      }
      
      return IncidentReport.fromMap(incidentData);
    } catch (e) {
      Logger.error('Failed to get incident report', e);
      return null;
    }
  }
  
  /// Create a new incident report
  Future<String?> createIncidentReport({
    required String incidentType,
    required String description,
    required Position position,
    String? address,
    required DateTime incidentTime,
    required bool isAnonymous,
    required bool sharedWithAuthorities,
    List<EvidenceFile>? evidenceFiles,
    String? notes,
  }) async {
    try {
      final user = MockAuthService.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }
      
      final report = IncidentReport(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        userId: isAnonymous ? 'anonymous' : user.uid,
        incidentType: incidentType,
        description: description,
        location: {
          'latitude': position.latitude,
          'longitude': position.longitude,
        },
        address: address,
        incidentTime: incidentTime,
        reportTime: DateTime.now(),
        status: IncidentReportStatus.submitted,
        evidenceFiles: evidenceFiles ?? [],
        isAnonymous: isAnonymous,
        sharedWithAuthorities: sharedWithAuthorities,
        notes: notes,
      );
      
      final reportId = await MockDataService.addDocument(
        _incidentsCollection,
        report.toMap(),
      );
      
      return reportId;
    } catch (e) {
      Logger.error('Failed to create incident report', e);
      return null;
    }
  }
  
  /// Update an existing incident report
  Future<bool> updateIncidentReport(IncidentReport report) async {
    try {
      return await MockDataService.updateDocument(
        _incidentsCollection,
        report.id,
        report.toMap(),
      );
    } catch (e) {
      Logger.error('Failed to update incident report', e);
      return false;
    }
  }
  
  /// Delete an incident report
  Future<bool> deleteIncidentReport(String id) async {
    try {
      // Get the report to delete associated evidence files
      final report = await getIncidentReport(id);
      
      if (report != null) {
        // Delete evidence files
        for (final evidence in report.evidenceFiles) {
          await MockDataService.deleteDocument(_evidenceCollection, evidence.id);
          
          // Delete local file if it exists
          if (evidence.localPath != null) {
            final file = File(evidence.localPath!);
            if (await file.exists()) {
              await file.delete();
            }
          }
        }
      }
      
      // Delete the report
      return await MockDataService.deleteDocument(_incidentsCollection, id);
    } catch (e) {
      Logger.error('Failed to delete incident report', e);
      return false;
    }
  }
  
  /// Record audio evidence
  Future<EvidenceFile?> recordAudioEvidence() async {
    try {
      // Start recording
      final audioPath = await _mediaService.startAudioRecording();
      
      if (audioPath == null) {
        throw Exception('Failed to start audio recording');
      }
      
      // Return null for now, the actual evidence file will be created when recording is stopped
      return null;
    } catch (e) {
      Logger.error('Failed to record audio evidence', e);
      return null;
    }
  }
  
  /// Stop recording audio evidence
  Future<EvidenceFile?> stopAudioRecording() async {
    try {
      // Stop recording
      final audioPath = await _mediaService.stopAudioRecording();
      
      if (audioPath == null) {
        throw Exception('Failed to stop audio recording');
      }
      
      // Create evidence file
      final file = File(audioPath);
      final fileSize = await file.length();
      
      final evidence = EvidenceFile(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        type: EvidenceType.audio,
        fileUrl: 'mock://audio/${path.basename(audioPath)}',
        localPath: audioPath,
        fileSize: fileSize,
        durationSeconds: 0, // We don't have actual duration info in this mock
        timestamp: DateTime.now(),
        isUploaded: false,
      );
      
      // Save evidence to mock database
      await MockDataService.addDocument(
        _evidenceCollection,
        evidence.toMap(),
      );
      
      return evidence;
    } catch (e) {
      Logger.error('Failed to stop audio recording', e);
      return null;
    }
  }
  
  /// Record video evidence
  Future<EvidenceFile?> recordVideoEvidence() async {
    try {
      // Start recording
      final videoPath = await _mediaService.startVideoRecording();
      
      if (videoPath == null) {
        throw Exception('Failed to start video recording');
      }
      
      // Return null for now, the actual evidence file will be created when recording is stopped
      return null;
    } catch (e) {
      Logger.error('Failed to record video evidence', e);
      return null;
    }
  }
  
  /// Stop recording video evidence
  Future<EvidenceFile?> stopVideoRecording() async {
    try {
      // Stop recording
      final videoPath = await _mediaService.stopVideoRecording();
      
      if (videoPath == null) {
        throw Exception('Failed to stop video recording');
      }
      
      // Create evidence file
      final file = File(videoPath);
      final fileSize = await file.length();
      
      final evidence = EvidenceFile(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        type: EvidenceType.video,
        fileUrl: 'mock://video/${path.basename(videoPath)}',
        localPath: videoPath,
        fileSize: fileSize,
        durationSeconds: 0, // We don't have actual duration info in this mock
        timestamp: DateTime.now(),
        isUploaded: false,
      );
      
      // Save evidence to mock database
      await MockDataService.addDocument(
        _evidenceCollection,
        evidence.toMap(),
      );
      
      return evidence;
    } catch (e) {
      Logger.error('Failed to stop video recording', e);
      return null;
    }
  }
  
  /// Take a photo as evidence
  Future<EvidenceFile?> takePhotoEvidence() async {
    try {
      // Take photo
      final photoPath = await _mediaService.takePhoto();
      
      if (photoPath == null) {
        throw Exception('Failed to take photo');
      }
      
      // Create evidence file
      final file = File(photoPath);
      final fileSize = await file.length();
      
      final evidence = EvidenceFile(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        type: EvidenceType.image,
        fileUrl: 'mock://image/${path.basename(photoPath)}',
        localPath: photoPath,
        fileSize: fileSize,
        timestamp: DateTime.now(),
        isUploaded: false,
      );
      
      // Save evidence to mock database
      await MockDataService.addDocument(
        _evidenceCollection,
        evidence.toMap(),
      );
      
      return evidence;
    } catch (e) {
      Logger.error('Failed to take photo evidence', e);
      return null;
    }
  }
  
  /// Upload evidence to storage
  Future<bool> uploadEvidence(EvidenceFile evidence) async {
    try {
      // In a real app, this would upload the file to Firebase Storage
      // For this mock, we'll just simulate a successful upload
      
      // Update evidence file to mark as uploaded
      final updatedEvidence = evidence.copyWith(isUploaded: true);
      
      return await MockDataService.updateDocument(
        _evidenceCollection,
        evidence.id,
        updatedEvidence.toMap(),
      );
    } catch (e) {
      Logger.error('Failed to upload evidence', e);
      return false;
    }
  }
  
  /// Dispose resources
  void dispose() {
    _mediaService.dispose();
  }
}
