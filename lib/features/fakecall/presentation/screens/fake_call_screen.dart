/*
 * Guardian 2.0 - Women's Safety App
 * © 2025 All Rights Reserved - Kunal Singh
 * 
 * Fake Call Screen - Simulates incoming call UI
 */

import 'package:flutter/material.dart';
import 'package:guardian/core/services/fake_call_service.dart';
import 'package:guardian/app/theme/app_theme.dart';

class FakeCallScreen extends StatefulWidget {
  final FakeCaller caller;
  
  const FakeCallScreen({super.key, required this.caller});

  @override
  State<FakeCallScreen> createState() => _FakeCallScreenState();
}

class _FakeCallScreenState extends State<FakeCallScreen> 
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  bool _isAnswered = false;
  int _callDuration = 0;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
    
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _answerCall() {
    setState(() => _isAnswered = true);
    _pulseController.stop();
    
    // Start call duration timer
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (mounted && _isAnswered) {
        setState(() => _callDuration++);
        return true;
      }
      return false;
    });
  }

  void _endCall() {
    FakeCallService.endCall();
    Navigator.of(context).pop();
  }

  String _formatDuration(int seconds) {
    final mins = seconds ~/ 60;
    final secs = seconds % 60;
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(),
            
            // Caller info
            if (!_isAnswered)
              const Text(
                'Incoming Call',
                style: TextStyle(color: Colors.grey, fontSize: 16),
              ),
            
            if (_isAnswered)
              Text(
                _formatDuration(_callDuration),
                style: const TextStyle(color: Colors.grey, fontSize: 16),
              ),
            
            const SizedBox(height: 20),
            
            // Avatar
            ScaleTransition(
              scale: _isAnswered 
                  ? const AlwaysStoppedAnimation(1.0) 
                  : _pulseAnimation,
              child: CircleAvatar(
                radius: 60,
                backgroundColor: AppColors.primary.withOpacity(0.3),
                child: Text(
                  widget.caller.name[0].toUpperCase(),
                  style: const TextStyle(
                    fontSize: 48,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Caller name
            Text(
              widget.caller.name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
            
            const SizedBox(height: 8),
            
            // Phone number
            Text(
              widget.caller.number,
              style: const TextStyle(color: Colors.grey, fontSize: 18),
            ),
            
            const Spacer(),
            const Spacer(),
            
            // Action buttons
            if (!_isAnswered)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Decline
                  _buildCallButton(
                    icon: Icons.call_end,
                    color: Colors.red,
                    label: 'Decline',
                    onPressed: _endCall,
                  ),
                  
                  // Answer
                  _buildCallButton(
                    icon: Icons.call,
                    color: Colors.green,
                    label: 'Answer',
                    onPressed: _answerCall,
                  ),
                ],
              ),
            
            if (_isAnswered)
              _buildCallButton(
                icon: Icons.call_end,
                color: Colors.red,
                label: 'End Call',
                onPressed: _endCall,
                size: 70,
              ),
            
            const SizedBox(height: 60),
          ],
        ),
      ),
    );
  }

  Widget _buildCallButton({
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onPressed,
    double size = 60,
  }) {
    return Column(
      children: [
        GestureDetector(
          onTap: onPressed,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: size * 0.5),
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(color: Colors.white)),
      ],
    );
  }
}
