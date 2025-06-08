/*
 * Guardian - Women's Safety App
 * © 2025 All Rights Reserved - Kunal Singh
 * Contact: kunalsingh2514@gmail.com
 */

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:guardian/core/constants/app_colors.dart';
import 'package:guardian/core/constants/app_typography.dart';
import 'package:guardian/core/widgets/custom_app_bar.dart';
import 'package:guardian/core/widgets/custom_button.dart';
import 'package:guardian/features/incident_reporting/data/incident_repository.dart';
import 'package:guardian/features/incident_reporting/data/models/incident_report_model.dart';

/// A screen for recording audio or video evidence
class EvidenceRecorder extends StatefulWidget {
  /// The incident repository
  final IncidentRepository repository;

  /// The type of evidence to record
  final EvidenceType evidenceType;

  const EvidenceRecorder({
    super.key,
    required this.repository,
    required this.evidenceType,
  });

  @override
  State<EvidenceRecorder> createState() => _EvidenceRecorderState();
}

class _EvidenceRecorderState extends State<EvidenceRecorder> {
  bool _isRecording = false;
  bool _isProcessing = false;
  Duration _recordingDuration = Duration.zero;
  Timer? _timer;
  EvidenceFile? _recordedEvidence;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _startRecording() async {
    setState(() {
      _isProcessing = true;
    });

    try {
      if (widget.evidenceType == EvidenceType.audio) {
        await widget.repository.recordAudioEvidence();
      } else if (widget.evidenceType == EvidenceType.video) {
        await widget.repository.recordVideoEvidence();
      }

      setState(() {
        _isRecording = true;
        _recordingDuration = Duration.zero;
        _isProcessing = false;
      });

      _startTimer();
    } catch (e) {
      setState(() {
        _isProcessing = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to start recording: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  Future<void> _stopRecording() async {
    _timer?.cancel();

    setState(() {
      _isProcessing = true;
    });

    try {
      if (widget.evidenceType == EvidenceType.audio) {
        _recordedEvidence = await widget.repository.stopAudioRecording();
      } else if (widget.evidenceType == EvidenceType.video) {
        _recordedEvidence = await widget.repository.stopVideoRecording();
      }

      setState(() {
        _isRecording = false;
        _isProcessing = false;
      });
    } catch (e) {
      setState(() {
        _isProcessing = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to stop recording: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _recordingDuration = Duration(seconds: timer.tick);
      });
    });
  }

  void _saveEvidence() {
    Navigator.of(context).pop(_recordedEvidence);
  }

  void _discardEvidence() {
    Navigator.of(context).pop();
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: widget.evidenceType == EvidenceType.audio
            ? 'Record Audio'
            : 'Record Video',
      ),
      body: _recordedEvidence != null
          ? _buildReviewScreen()
          : _buildRecordingScreen(),
    );
  }

  Widget _buildRecordingScreen() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              widget.evidenceType == EvidenceType.audio
                  ? Icons.mic
                  : Icons.videocam,
              size: 80,
              color: _isRecording ? AppColors.danger : AppColors.primary,
            ),
            const SizedBox(height: 24),
            Text(
              _isRecording
                  ? 'Recording in progress...'
                  : 'Press the button to start recording',
              style: AppTypography.heading3,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            if (_isRecording)
              Text(
                _formatDuration(_recordingDuration),
                style: AppTypography.heading2.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.danger,
                ),
              ),
            const SizedBox(height: 48),
            _isProcessing
                ? const CircularProgressIndicator()
                : ElevatedButton(
                    onPressed: _isRecording ? _stopRecording : _startRecording,
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          _isRecording ? AppColors.danger : AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 16,
                      ),
                      shape: const CircleBorder(),
                      minimumSize: const Size(80, 80),
                    ),
                    child: Icon(
                      _isRecording ? Icons.stop : Icons.play_arrow,
                      size: 40,
                    ),
                  ),
            const SizedBox(height: 24),
            Text(
              _isRecording ? 'Tap to stop recording' : 'Tap to start recording',
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReviewScreen() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.check_circle,
            size: 80,
            color: AppColors.success,
          ),
          const SizedBox(height: 24),
          Text(
            widget.evidenceType == EvidenceType.audio
                ? 'Audio Recording Complete'
                : 'Video Recording Complete',
            style: AppTypography.heading3,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            'Your recording has been saved. Would you like to use it as evidence?',
            style: AppTypography.bodyLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 48),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CustomButton(
                text: 'Discard',
                onPressed: _discardEvidence,
                type: ButtonType.outline,
              ),
              const SizedBox(width: 16),
              CustomButton(
                text: 'Save as Evidence',
                onPressed: _saveEvidence,
                type: ButtonType.primary,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
