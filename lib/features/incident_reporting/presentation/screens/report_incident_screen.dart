/*
 * Guardian - Women's Safety App
 * © 2025 All Rights Reserved - Kunal Singh
 * Contact: kunalsingh2514@gmail.com
 */

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:guardian/core/constants/app_colors.dart';
import 'package:guardian/core/constants/app_typography.dart';
import 'package:guardian/core/di/service_locator.dart';
import 'package:guardian/core/utils/logger.dart';
import 'package:guardian/core/utils/location_utils.dart';
import 'package:guardian/core/widgets/custom_app_bar.dart';
import 'package:guardian/core/widgets/custom_button.dart';
import 'package:guardian/core/widgets/loading_indicator.dart';
import 'package:guardian/features/incident_reporting/data/incident_repository.dart';
import 'package:guardian/features/incident_reporting/data/models/incident_report_model.dart';
import 'package:guardian/features/incident_reporting/presentation/widgets/evidence_card.dart';
import 'package:guardian/features/incident_reporting/presentation/widgets/evidence_recorder.dart';
import 'package:intl/intl.dart';

class ReportIncidentScreen extends StatefulWidget {
  const ReportIncidentScreen({super.key});

  @override
  State<ReportIncidentScreen> createState() => _ReportIncidentScreenState();
}

class _ReportIncidentScreenState extends State<ReportIncidentScreen> {
  final IncidentRepository _repository = sl<IncidentRepository>();
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _addressController = TextEditingController();
  final _notesController = TextEditingController();

  String _selectedIncidentType = 'Harassment';
  DateTime _incidentDate = DateTime.now();
  TimeOfDay _incidentTime = TimeOfDay.now();
  Position? _currentPosition;
  // Removed unused field: String? _currentAddress;
  bool _isAnonymous = false;
  bool _shareWithAuthorities = true;
  bool _isLoading = false;
  bool _isSubmitting = false;

  final List<EvidenceFile> _evidenceFiles = [];

  final List<String> _incidentTypes = [
    'Harassment',
    'Stalking',
    'Assault',
    'Theft',
    'Suspicious Activity',
    'Unsafe Area',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    _initializeRepository();
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _addressController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _initializeRepository() async {
    await _repository.init();
  }

  Future<void> _getCurrentLocation() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final position = await LocationUtils.getCurrentPosition();

      if (position != null) {
        setState(() {
          _currentPosition = position;
        });

        // Try to get address
        final address = await LocationUtils.getAddressFromPosition(position);

        if (address != null) {
          setState(() {
            _addressController.text = address;
          });
        }
      }
    } catch (e) {
      Logger.error('Failed to get current location', e);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _incidentDate,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now(),
    );

    if (picked != null && picked != _incidentDate) {
      setState(() {
        _incidentDate = picked;
      });
    }
  }

  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _incidentTime,
    );

    if (picked != null && picked != _incidentTime) {
      setState(() {
        _incidentTime = picked;
      });
    }
  }

  Future<void> _addAudioEvidence() async {
    final evidence = await Navigator.push<EvidenceFile>(
      context,
      MaterialPageRoute(
        builder: (context) => EvidenceRecorder(
          repository: _repository,
          evidenceType: EvidenceType.audio,
        ),
      ),
    );

    if (evidence != null) {
      setState(() {
        _evidenceFiles.add(evidence);
      });
    }
  }

  Future<void> _addVideoEvidence() async {
    final evidence = await Navigator.push<EvidenceFile>(
      context,
      MaterialPageRoute(
        builder: (context) => EvidenceRecorder(
          repository: _repository,
          evidenceType: EvidenceType.video,
        ),
      ),
    );

    if (evidence != null) {
      setState(() {
        _evidenceFiles.add(evidence);
      });
    }
  }

  Future<void> _addPhotoEvidence() async {
    try {
      final evidence = await _repository.takePhotoEvidence();

      if (evidence != null) {
        setState(() {
          _evidenceFiles.add(evidence);
        });
      }
    } catch (e) {
      Logger.error('Failed to take photo', e);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to take photo. Please try again.'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  void _removeEvidence(EvidenceFile evidence) {
    setState(() {
      _evidenceFiles.remove(evidence);
    });

    // Delete the local file if it exists
    if (evidence.localPath != null) {
      final file = File(evidence.localPath!);
      file.exists().then((exists) {
        if (exists) {
          file.delete();
        }
      });
    }
  }

  Future<void> _submitReport() async {
    if (_formKey.currentState?.validate() != true) {
      return;
    }

    if (_currentPosition == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Location is required. Please wait for location to be determined.'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      // Combine date and time
      final incidentDateTime = DateTime(
        _incidentDate.year,
        _incidentDate.month,
        _incidentDate.day,
        _incidentTime.hour,
        _incidentTime.minute,
      );

      final reportId = await _repository.createIncidentReport(
        incidentType: _selectedIncidentType,
        description: _descriptionController.text,
        position: _currentPosition!,
        address: _addressController.text,
        incidentTime: incidentDateTime,
        isAnonymous: _isAnonymous,
        sharedWithAuthorities: _shareWithAuthorities,
        evidenceFiles: _evidenceFiles,
        notes: _notesController.text.isNotEmpty ? _notesController.text : null,
      );

      if (reportId == null) {
        throw Exception('Failed to create report');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Incident reported successfully'),
            backgroundColor: AppColors.success,
          ),
        );

        Navigator.of(context).pop(true);
      }
    } catch (e) {
      Logger.error('Failed to submit report', e);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to submit report: ${e.toString()}'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: 'Report Incident',
      ),
      body: _isLoading
          ? const Center(
              child: LoadingIndicator(text: 'Getting your location...'))
          : _buildForm(),
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Incident Type
          Text(
            'Incident Type',
            style: AppTypography.heading4.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _selectedIncidentType,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            items: _incidentTypes.map((type) {
              return DropdownMenuItem<String>(
                value: type,
                child: Text(type),
              );
            }).toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  _selectedIncidentType = value;
                });
              }
            },
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please select an incident type';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          // Description
          Text(
            'Description',
            style: AppTypography.heading4.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _descriptionController,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: 'Describe what happened...',
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            maxLines: 4,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter a description';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          // Date and Time
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Date',
                      style: AppTypography.heading4.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: () => _selectDate(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              DateFormat('MMM dd, yyyy').format(_incidentDate),
                              style: AppTypography.bodyLarge,
                            ),
                            const Icon(Icons.calendar_today, size: 18),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Time',
                      style: AppTypography.heading4.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: () => _selectTime(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _incidentTime.format(context),
                              style: AppTypography.bodyLarge,
                            ),
                            const Icon(Icons.access_time, size: 18),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Location
          Text(
            'Location',
            style: AppTypography.heading4.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _addressController,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: 'Address or location description',
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
          if (_currentPosition != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Coordinates: ${_currentPosition!.latitude.toStringAsFixed(6)}, ${_currentPosition!.longitude.toStringAsFixed(6)}',
                style: AppTypography.caption.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          const SizedBox(height: 16),

          // Evidence
          Text(
            'Evidence',
            style: AppTypography.heading4.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _addAudioEvidence,
                  icon: const Icon(Icons.mic),
                  label: const Text('Audio'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _addVideoEvidence,
                  icon: const Icon(Icons.videocam),
                  label: const Text('Video'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _addPhotoEvidence,
                  icon: const Icon(Icons.photo_camera),
                  label: const Text('Photo'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          if (_evidenceFiles.isNotEmpty) ...[
            const SizedBox(height: 16),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _evidenceFiles.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: EvidenceCard(
                    evidence: _evidenceFiles[index],
                    onDelete: () => _removeEvidence(_evidenceFiles[index]),
                  ),
                );
              },
            ),
          ],
          const SizedBox(height: 16),

          // Additional Notes
          Text(
            'Additional Notes (Optional)',
            style: AppTypography.heading4.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _notesController,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: 'Any additional information...',
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            maxLines: 3,
          ),
          const SizedBox(height: 16),

          // Report Options
          CheckboxListTile(
            title: const Text('Report Anonymously'),
            subtitle: const Text('Your identity will not be shared'),
            value: _isAnonymous,
            onChanged: (value) {
              setState(() {
                _isAnonymous = value ?? false;
              });
            },
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
          ),
          CheckboxListTile(
            title: const Text('Share with Authorities'),
            subtitle:
                const Text('Report will be shared with local authorities'),
            value: _shareWithAuthorities,
            onChanged: (value) {
              setState(() {
                _shareWithAuthorities = value ?? true;
              });
            },
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
          ),
          const SizedBox(height: 24),

          // Submit Button
          CustomButton(
            text: 'Submit Report',
            onPressed: _submitReport,
            isLoading: _isSubmitting,
            type: ButtonType.primary,
            isFullWidth: true,
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
