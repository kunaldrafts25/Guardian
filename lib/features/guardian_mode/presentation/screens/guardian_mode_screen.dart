/*
 * Guardian - Women's Safety App
 * © 2025 All Rights Reserved - Kunal Singh
 * Contact: kunalsingh2514@gmail.com
 */

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:guardian/core/constants/app_colors.dart';
import 'package:guardian/core/constants/app_typography.dart';
import 'package:guardian/core/di/service_locator.dart';
import 'package:guardian/core/utils/logger.dart';
import 'package:guardian/core/widgets/custom_app_bar.dart';
import 'package:guardian/core/widgets/loading_indicator.dart';
import 'package:guardian/features/guardian_mode/data/guardian_repository.dart';
import 'package:guardian/features/guardian_mode/data/models/guardian_contact_model.dart';
import 'package:guardian/features/guardian_mode/data/models/guardian_session_model.dart';
import 'package:guardian/features/guardian_mode/presentation/widgets/guardian_contact_card.dart';
import 'package:guardian/features/guardian_mode/presentation/widgets/guardian_status_card.dart';

class GuardianModeScreen extends StatefulWidget {
  const GuardianModeScreen({super.key});

  @override
  State<GuardianModeScreen> createState() => _GuardianModeScreenState();
}

class _GuardianModeScreenState extends State<GuardianModeScreen> {
  final GuardianRepository _repository = sl<GuardianRepository>();
  final Completer<GoogleMapController> _mapController = Completer();

  List<GuardianContact> _contacts = [];
  List<GuardianContact> _selectedContacts = [];
  bool _isLoading = true;
  bool _isStartingSession = false;
  GuardianSession? _activeSession;

  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};

  StreamSubscription<GuardianSession?>? _sessionSubscription;

  @override
  void initState() {
    super.initState();
    _loadContacts();
    _listenToActiveSession();
  }

  @override
  void dispose() {
    _sessionSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadContacts() async {
    try {
      setState(() {
        _isLoading = true;
      });

      final contacts = await _repository.getGuardianContacts();

      setState(() {
        _contacts = contacts;
        _isLoading = false;
      });
    } catch (e) {
      Logger.error('Failed to load guardian contacts', e);
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _listenToActiveSession() {
    _sessionSubscription = _repository.activeSessionStream.listen((session) {
      setState(() {
        _activeSession = session;
        if (session != null) {
          _updateMapWithSessionData(session);
        }
      });
    });
  }

  void _updateMapWithSessionData(GuardianSession session) {
    if (session.locationHistory.isEmpty) return;

    // Create markers
    final markers = <Marker>{};
    final lastLocation = session.lastLocation;

    if (lastLocation != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('current_location'),
          position:
              LatLng(lastLocation['latitude']!, lastLocation['longitude']!),
          infoWindow: const InfoWindow(title: 'Current Location'),
        ),
      );
    }

    // Create polyline from location history
    final List<LatLng> polylinePoints = [];

    for (final location in session.locationHistory) {
      polylinePoints.add(
        LatLng(location['latitude'], location['longitude']),
      );
    }

    final polylines = <Polyline>{
      Polyline(
        polylineId: const PolylineId('route'),
        points: polylinePoints,
        color: AppColors.primary,
        width: 5,
      ),
    };

    setState(() {
      _markers = markers;
      _polylines = polylines;
    });

    // Move camera to current location
    if (lastLocation != null) {
      _moveCamera(
        LatLng(lastLocation['latitude']!, lastLocation['longitude']!),
      );
    }
  }

  Future<void> _moveCamera(LatLng target) async {
    final GoogleMapController controller = await _mapController.future;
    controller.animateCamera(CameraUpdate.newLatLngZoom(target, 15));
  }

  Future<void> _startGuardianSession() async {
    if (_selectedContacts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one guardian contact'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    setState(() {
      _isStartingSession = true;
    });

    try {
      final guardianIds = _selectedContacts.map((c) => c.id).toList();
      final session = await _repository.startGuardianSession(guardianIds);

      if (session == null) {
        throw Exception('Failed to start guardian session');
      }

      setState(() {
        _activeSession = session;
        _isStartingSession = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Guardian session started successfully'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      Logger.error('Failed to start guardian session', e);

      setState(() {
        _isStartingSession = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to start guardian session: ${e.toString()}'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  Future<void> _endGuardianSession() async {
    try {
      final success = await _repository.endGuardianSession();

      if (!success) {
        throw Exception('Failed to end guardian session');
      }

      setState(() {
        _activeSession = null;
        _selectedContacts = [];
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Guardian session ended successfully'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      Logger.error('Failed to end guardian session', e);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to end guardian session: ${e.toString()}'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  void _toggleContactSelection(GuardianContact contact) {
    setState(() {
      if (_selectedContacts.contains(contact)) {
        _selectedContacts.remove(contact);
      } else {
        _selectedContacts.add(contact);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: 'Live Guardian Mode',
        actions: [
          if (_activeSession != null)
            IconButton(
              icon: const Icon(Icons.stop_circle_outlined),
              onPressed: _endGuardianSession,
              tooltip: 'End Session',
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: LoadingIndicator())
          : _buildContent(),
      bottomNavigationBar:
          _activeSession == null ? _buildStartSessionButton() : null,
    );
  }

  Widget _buildContent() {
    if (_activeSession != null) {
      return _buildActiveSessionView();
    } else {
      return _buildContactSelectionView();
    }
  }

  Widget _buildContactSelectionView() {
    if (_contacts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.people_outline,
              size: 64,
              color: AppColors.primary,
            ),
            const SizedBox(height: 16),
            Text(
              'No guardian contacts found',
              style: AppTypography.heading3,
            ),
            const SizedBox(height: 8),
            Text(
              'Add trusted contacts to use Live Guardian Mode',
              style: AppTypography.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                // Navigate to add contact screen
                // TODO: Implement navigation
              },
              icon: const Icon(Icons.add),
              label: const Text('Add Guardian Contact'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Select Guardian Contacts',
          style: AppTypography.heading3,
        ),
        const SizedBox(height: 8),
        Text(
          'Choose trusted contacts who will monitor your location during this session',
          style: AppTypography.bodyMedium,
        ),
        const SizedBox(height: 24),
        ...List.generate(
          _contacts.length,
          (index) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: GuardianContactCard(
              contact: _contacts[index],
              isSelected: _selectedContacts.contains(_contacts[index]),
              onTap: () => _toggleContactSelection(_contacts[index]),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActiveSessionView() {
    return Column(
      children: [
        Expanded(
          child: GoogleMap(
            initialCameraPosition: const CameraPosition(
              target: LatLng(20.5937, 78.9629), // Default to India
              zoom: 5,
            ),
            markers: _markers,
            polylines: _polylines,
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            mapToolbarEnabled: false,
            zoomControlsEnabled: true,
            onMapCreated: (GoogleMapController controller) {
              _mapController.complete(controller);
            },
          ),
        ),
        if (_activeSession != null)
          GuardianStatusCard(
            session: _activeSession!,
            guardians: _selectedContacts,
          ),
      ],
    );
  }

  Widget _buildStartSessionButton() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: ElevatedButton(
          onPressed: _selectedContacts.isEmpty || _isStartingSession
              ? null
              : _startGuardianSession,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: _isStartingSession
              ? const SizedBox(
                  height: 24,
                  width: 24,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : Text(
                  'Start Guardian Session (${_selectedContacts.length} selected)',
                  style: AppTypography.buttonMedium.copyWith(
                    color: Colors.white,
                  ),
                ),
        ),
      ),
    );
  }
}
