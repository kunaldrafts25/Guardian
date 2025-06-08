/*
 * Guardian - Women's Safety App
 * © 2025 All Rights Reserved - Kunal Singh
 * Contact: kunalsingh2514@gmail.com
 */

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:guardian/core/constants/app_colors.dart';
import 'package:guardian/core/constants/app_typography.dart';
import 'package:guardian/core/services/emergency_service.dart';

class EmergencyButton extends StatefulWidget {
  final double size;
  final VoidCallback? onPressed;
  final bool showLabel;

  const EmergencyButton({
    super.key,
    this.size = 80,
    this.onPressed,
    this.showLabel = true,
  });

  @override
  State<EmergencyButton> createState() => _EmergencyButtonState();
}

class _EmergencyButtonState extends State<EmergencyButton> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _pulseAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    HapticFeedback.mediumImpact();
    setState(() {
      _isPressed = true;
    });
    _animationController.stop();
  }

  void _handleTapUp(TapUpDetails details) {
    setState(() {
      _isPressed = false;
    });
    _animationController.repeat(reverse: true);
  }

  void _handleTapCancel() {
    setState(() {
      _isPressed = false;
    });
    _animationController.repeat(reverse: true);
  }

  void _triggerEmergency() async {
    // Provide haptic feedback
    HapticFeedback.vibrate();

    if (widget.onPressed != null) {
      widget.onPressed!();
    } else {
      // Default behavior: trigger emergency alert
      final alertId = await EmergencyService.triggerEmergencyAlert();

      // Check if the widget is still mounted before using context
      if (!mounted) return;

      if (alertId != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Emergency alert sent!'),
            backgroundColor: AppColors.accent,
            duration: Duration(seconds: 3),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to send emergency alert. Please try again.'),
            backgroundColor: AppColors.accent,
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTapDown: _handleTapDown,
          onTapUp: _handleTapUp,
          onTapCancel: _handleTapCancel,
          onLongPress: _triggerEmergency,
          child: AnimatedBuilder(
            animation: _animationController,
            builder: (context, child) {
              return Stack(
                alignment: Alignment.center,
                children: [
                  // Outer pulsing circle
                  if (!_isPressed)
                    Transform.scale(
                      scale: _pulseAnimation.value,
                      child: Container(
                        width: widget.size + 20,
                        height: widget.size + 20,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.accent.withOpacity(0.2),
                        ),
                      ),
                    ),

                  // Main button
                  Transform.scale(
                    scale: _isPressed ? 0.9 : 1.0,
                    child: Container(
                      width: widget.size,
                      height: widget.size,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _isPressed ? AppColors.accent.withOpacity(0.8) : AppColors.accent,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.accent.withOpacity(0.3),
                            blurRadius: 12,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.warning_rounded,
                          color: Colors.white,
                          size: 40,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        if (widget.showLabel) ...[
          const SizedBox(height: 12),
          Text(
            'SOS',
            style: AppTypography.heading4.copyWith(
              color: AppColors.accent,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Long press to activate',
            style: AppTypography.caption.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ],
    );
  }
}
