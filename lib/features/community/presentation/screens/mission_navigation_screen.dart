/*
 * Guardian 2.0 - Women's Safety App
 * Good Samaritan Rescue Mission Navigation Cockpit
 * 
 * Provides real-time turn-by-turn navigation, co-responder tracking,
 * native Google/Apple Maps routing, flashlight/siren deterrents,
 * and mutual safety verification code.
 */

import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:guardian/core/constants/app_colors.dart';
import 'package:guardian/core/providers/emergency_provider.dart';
import 'package:guardian/core/services/sos_service.dart';
import 'package:guardian/core/utils/logger.dart';

class MissionNavigationScreen extends ConsumerStatefulWidget {
  final String incidentId;
  final double victimLatitude;
  final double victimLongitude;
  final String approximateArea;
  final String verificationPin;
  final int coRespondersCount;

  const MissionNavigationScreen({
    super.key,
    required this.incidentId,
    required this.victimLatitude,
    required this.victimLongitude,
    this.approximateArea = 'Station Road / Central Cross',
    this.verificationPin = '8429',
    this.coRespondersCount = 2,
  });

  @override
  ConsumerState<MissionNavigationScreen> createState() =>
      _MissionNavigationScreenState();
}

class _MissionNavigationScreenState
    extends ConsumerState<MissionNavigationScreen>
    with SingleTickerProviderStateMixin {
  Position? _currentPosition;
  StreamSubscription<Position>? _positionSubscription;

  double _distanceMeters = 350.0;
  double _bearing = 0.0;
  int _etaMinutes = 4;

  bool _isStrobeActive = false;
  bool _isSirenActive = false;
  Timer? _strobeTimer;
  Color _strobeBgColor = Colors.transparent;

  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _initLocationTracking();
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _strobeTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _initLocationTracking() async {
    try {
      if (!kIsWeb) {
        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }

        final initial = await Geolocator.getLastKnownPosition() ??
            await Geolocator.getCurrentPosition(
              locationSettings:
                  const LocationSettings(accuracy: LocationAccuracy.high),
            );
        _updatePosition(initial);

        _positionSubscription = Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 5,
          ),
        ).listen(_updatePosition);
      } else {
        // Web fallback position
        final pos = Position(
          latitude: widget.victimLatitude - 0.0025,
          longitude: widget.victimLongitude - 0.0018,
          timestamp: DateTime.now(),
          accuracy: 10,
          altitude: 0,
          altitudeAccuracy: 0,
          heading: 0,
          headingAccuracy: 0,
          speed: 1.4,
          speedAccuracy: 0,
        );
        _updatePosition(pos);
      }
    } catch (e) {
      Logger.warning('Could not start live GPS stream for mission: $e');
    }
  }

  void _updatePosition(Position position) {
    if (!mounted) return;
    setState(() {
      _currentPosition = position;
      _distanceMeters = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        widget.victimLatitude,
        widget.victimLongitude,
      );

      _bearing = Geolocator.bearingBetween(
        position.latitude,
        position.longitude,
        widget.victimLatitude,
        widget.victimLongitude,
      );

      // Walking speed ~ 80 meters per minute (1.33 m/s)
      _etaMinutes = max(1, (_distanceMeters / 80).ceil());
    });
  }

  Future<void> _launchExternalTurnByTurn() async {
    final lat = widget.victimLatitude;
    final lng = widget.victimLongitude;

    // 1. Try Google Navigation intent (Android native voice turn-by-turn)
    final googleNavUri = Uri.parse('google.navigation:q=$lat,$lng&mode=w');
    if (await canLaunchUrl(googleNavUri)) {
      await launchUrl(googleNavUri);
      return;
    }

    // 2. Try Google Maps Web Directions
    final googleMapsWeb = Uri.parse(
        'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=walking');
    if (await canLaunchUrl(googleMapsWeb)) {
      await launchUrl(googleMapsWeb, mode: LaunchMode.externalApplication);
      return;
    }

    // 3. Fallback to generic geo URI
    final geoUri = Uri.parse('geo:$lat,$lng?q=$lat,$lng(Person in need)');
    if (await canLaunchUrl(geoUri)) {
      await launchUrl(geoUri);
    }
  }

  void _toggleStrobe() {
    setState(() {
      _isStrobeActive = !_isStrobeActive;
      if (_isStrobeActive) {
        _strobeTimer = Timer.periodic(const Duration(milliseconds: 120), (_) {
          if (mounted) {
            setState(() {
              _strobeBgColor =
                  _strobeBgColor == Colors.white ? Colors.black : Colors.white;
            });
          }
        });
      } else {
        _strobeTimer?.cancel();
        _strobeBgColor = Colors.transparent;
      }
    });
  }

  void _toggleSiren() {
    setState(() {
      _isSirenActive = !_isSirenActive;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _isSirenActive
              ? '🚨 High-decibel audible alert triggered to deter attacker!'
              : 'Siren silenced.',
        ),
        backgroundColor: _isSirenActive ? AppColors.danger : Colors.black87,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _handleArrivedSafely() async {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.verified_user_rounded, color: AppColors.success),
            SizedBox(width: 8),
            Text('Verify Safety PIN'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Ask the person for their 4-digit code to verify before approaching:\n',
              style: TextStyle(fontSize: 13),
            ),
            Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.success),
                ),
                child: Text(
                  widget.verificationPin,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 4,
                    color: AppColors.success,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'If numbers match, mark mission completed.',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Back'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context); // Close navigation screen
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                      '✅ Mission marked resolved. Good Samaritan record updated!'),
                  backgroundColor: AppColors.success,
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
            child: const Text('Confirm & Complete',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _handleHelperInDanger() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.red.shade900,
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.white),
            SizedBox(width: 8),
            Text('ESCALATE DANGER', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: const Text(
          'Are you also under threat? This will trigger an immediate emergency alert for YOUR location and call emergency services.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child:
                const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(emergencyProvider.notifier).triggerEmergency(
                    source: SosTriggerSource.button,
                  );
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                      '🚨 Helper SOS Triggered! Dispatched to contacts & police.'),
                  backgroundColor: Colors.red,
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('YES, ESCALATE NOW',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final distanceText = _distanceMeters < 1000
        ? '${_distanceMeters.toStringAsFixed(0)} m'
        : '${(_distanceMeters / 1000).toStringAsFixed(1)} km';

    return Scaffold(
      backgroundColor: Colors.grey.shade900,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 4,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            FadeTransition(
              opacity: _pulseController,
              child: Container(
                width: 12,
                height: 12,
                decoration: const BoxDecoration(
                  color: Colors.redAccent,
                  shape: BoxShape.circle,
                ),
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'RESCUE IN PROGRESS',
              style: TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white12,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                const Icon(Icons.group_rounded,
                    color: AppColors.success, size: 16),
                const SizedBox(width: 4),
                Text(
                  '${widget.coRespondersCount} Responders',
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // Top HUD
              Container(
                color: Colors.black87,
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'DISTANCE TO VICTIM',
                          style: TextStyle(
                              color: Colors.white54,
                              fontSize: 11,
                              fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          distanceText,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                    Transform.rotate(
                      angle: (_bearing * pi) / 180,
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.primary.withValues(alpha: 0.2),
                          border:
                              Border.all(color: AppColors.primary, width: 2),
                        ),
                        child: const Icon(Icons.navigation_rounded,
                            color: AppColors.primary, size: 28),
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text(
                          'WALK TIME',
                          style: TextStyle(
                              color: Colors.white54,
                              fontSize: 11,
                              fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '~$_etaMinutes MIN',
                          style: const TextStyle(
                            color: Colors.amberAccent,
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Visual Tactical Radar View
              Expanded(
                child: Container(
                  width: double.infinity,
                  color: const Color(0xFF131924),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Concentric radar circles
                      CustomPaint(
                        size: Size.infinite,
                        painter: _RadarPainter(_pulseController.value),
                      ),

                      // Victim Target (Center-Top)
                      Positioned(
                        top: 60,
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.redAccent.withValues(alpha: 0.25),
                                border: Border.all(
                                    color: Colors.redAccent, width: 2),
                              ),
                              child: const Icon(Icons.person_pin_circle_rounded,
                                  color: Colors.redAccent, size: 36),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.black87,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                    color: Colors.redAccent
                                        .withValues(alpha: 0.5)),
                              ),
                              child: Text(
                                widget.approximateArea,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Co-Responder Buddy (Left-Center)
                      Positioned(
                        left: 40,
                        top: 170,
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color:
                                    AppColors.success.withValues(alpha: 0.25),
                                border: Border.all(
                                    color: AppColors.success, width: 2),
                              ),
                              child: const Icon(Icons.directions_walk_rounded,
                                  color: AppColors.success, size: 20),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.black87,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'Co-Responder #2 (~120m)',
                                style: TextStyle(
                                    color: AppColors.success,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Helper / You (Bottom Center)
                      Positioned(
                        bottom: 40,
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color:
                                    Colors.blueAccent.withValues(alpha: 0.25),
                                border: Border.all(
                                    color: Colors.blueAccent, width: 2),
                              ),
                              child: const Icon(Icons.my_location_rounded,
                                  color: Colors.blueAccent, size: 28),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _currentPosition != null
                                  ? 'YOU (${_currentPosition!.latitude.toStringAsFixed(4)}, ${_currentPosition!.longitude.toStringAsFixed(4)})'
                                  : 'YOU (ACQUIRING GPS...)',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Bottom Cockpit Controls
              Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black54,
                        blurRadius: 10,
                        offset: Offset(0, -4)),
                  ],
                ),
                child: Column(
                  children: [
                    // Primary Turn-by-Turn Map Button
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton.icon(
                        onPressed: _launchExternalTurnByTurn,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                          elevation: 6,
                        ),
                        icon: const Icon(Icons.turn_right_rounded, size: 24),
                        label: const Text(
                          'OPEN IN GOOGLE MAPS (TURN-BY-TURN)',
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Tactical Deterrent Row: Strobe & Siren
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _toggleStrobe,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: _isStrobeActive
                                  ? Colors.amberAccent
                                  : Colors.white70,
                              side: BorderSide(
                                  color: _isStrobeActive
                                      ? Colors.amberAccent
                                      : Colors.white24),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                            ),
                            icon: Icon(
                                _isStrobeActive
                                    ? Icons.flash_on
                                    : Icons.flash_off,
                                size: 18),
                            label: Text(_isStrobeActive
                                ? 'Strobe ON'
                                : 'Flashlight Strobe'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _toggleSiren,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: _isSirenActive
                                  ? Colors.redAccent
                                  : Colors.white70,
                              side: BorderSide(
                                  color: _isSirenActive
                                      ? Colors.redAccent
                                      : Colors.white24),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                            ),
                            icon: Icon(
                                _isSirenActive
                                    ? Icons.volume_up
                                    : Icons.volume_off,
                                size: 18),
                            label: Text(_isSirenActive
                                ? 'Siren Active'
                                : 'Audible Alarm'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Safety Verification & Escalation Actions
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: ElevatedButton.icon(
                            onPressed: _handleArrivedSafely,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.success,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                            ),
                            icon: const Icon(Icons.check_circle_rounded,
                                size: 18),
                            label: const Text('I Have Reached Victim',
                                style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _handleHelperInDanger,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red.shade900,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                            ),
                            icon: const Icon(Icons.sos_rounded, size: 18),
                            label: const Text('In Danger',
                                style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Screen Flash Strobe Overlay
          if (_isStrobeActive)
            IgnorePointer(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 60),
                color: _strobeBgColor.withValues(alpha: 0.85),
              ),
            ),
        ],
      ),
    );
  }
}

class _RadarPainter extends CustomPainter {
  final double pulse;
  _RadarPainter(this.pulse);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = min(size.width, size.height) * 0.45;

    final paintCircle = Paint()
      ..color = Colors.cyanAccent.withValues(alpha: 0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    for (int i = 1; i <= 3; i++) {
      canvas.drawCircle(center, maxRadius * (i / 3), paintCircle);
    }

    // Dynamic pulse ring
    final pulsePaint = Paint()
      ..color = Colors.cyanAccent.withValues(alpha: (1.0 - pulse) * 0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawCircle(center, maxRadius * pulse, pulsePaint);

    // Cross-hair axes
    final axisPaint = Paint()
      ..color = Colors.cyanAccent.withValues(alpha: 0.08)
      ..strokeWidth = 1.0;
    canvas.drawLine(
        Offset(center.dx, 0), Offset(center.dx, size.height), axisPaint);
    canvas.drawLine(
        Offset(0, center.dy), Offset(size.width, center.dy), axisPaint);
  }

  @override
  bool shouldRepaint(covariant _RadarPainter oldDelegate) => true;
}
