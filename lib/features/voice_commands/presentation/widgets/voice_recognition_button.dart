/*
 * Guardian - Women's Safety App
 * © 2025 All Rights Reserved - Kunal Singh
 * Contact: kunalsingh2514@gmail.com
 */

import 'package:flutter/material.dart';
import 'package:guardian/core/constants/app_colors.dart';

/// A button widget for voice recognition
class VoiceRecognitionButton extends StatefulWidget {
  /// Whether voice recognition is active
  final bool isListening;

  /// Callback when the button is pressed
  final VoidCallback onPressed;

  /// Size of the button
  final double size;

  const VoiceRecognitionButton({
    super.key,
    required this.isListening,
    required this.onPressed,
    this.size = 80,
  });

  @override
  State<VoiceRecognitionButton> createState() => _VoiceRecognitionButtonState();
}

class _VoiceRecognitionButtonState extends State<VoiceRecognitionButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _setupAnimations() {
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.9).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeInOut),
      ),
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.5, 1.0, curve: Curves.easeInOut),
      ),
    );

    if (widget.isListening) {
      _animationController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(VoiceRecognitionButton oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.isListening != oldWidget.isListening) {
      if (widget.isListening) {
        _animationController.repeat(reverse: true);
      } else {
        _animationController.stop();
        _animationController.reset();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onPressed,
      child: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          final scale = widget.isListening
              ? _pulseAnimation.value
              : _scaleAnimation.value;

          return Transform.scale(
            scale: scale,
            child: child,
          );
        },
        child: Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.isListening ? AppColors.primary : Colors.white,
            border: Border.all(
              color: AppColors.primary,
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.3),
                blurRadius: 10,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Icon(
            widget.isListening ? Icons.mic : Icons.mic_none,
            color: widget.isListening ? Colors.white : AppColors.primary,
            size: widget.size * 0.5,
          ),
        ),
      ),
    );
  }
}
