/*
 * Guardian - Women's Safety App
 * © 2025 All Rights Reserved - Kunal Singh
 * Contact: kunalsingh2514@gmail.com
 */

import 'package:flutter/material.dart';

/// Animation utilities for the app
class AnimationUtils {
  /// Create a fade transition
  static Widget fadeTransition({
    required Animation<double> animation,
    required Widget child,
  }) {
    return FadeTransition(
      opacity: animation,
      child: child,
    );
  }

  /// Create a slide transition
  static Widget slideTransition({
    required Animation<double> animation,
    required Widget child,
    SlideDirection direction = SlideDirection.fromBottom,
  }) {
    final Tween<Offset> offsetTween = _getOffsetTween(direction);

    return SlideTransition(
      position: animation.drive(offsetTween),
      child: child,
    );
  }

  /// Create a scale transition
  static Widget scaleTransition({
    required Animation<double> animation,
    required Widget child,
    Alignment alignment = Alignment.center,
  }) {
    return ScaleTransition(
      scale: animation,
      alignment: alignment,
      child: child,
    );
  }

  /// Create a combined fade and slide transition
  static Widget fadeSlideTransition({
    required Animation<double> animation,
    required Widget child,
    SlideDirection direction = SlideDirection.fromBottom,
  }) {
    final Tween<Offset> offsetTween = _getOffsetTween(direction);
    final curvedAnimation = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOut,
    );

    return FadeTransition(
      opacity: curvedAnimation,
      child: SlideTransition(
        position: curvedAnimation.drive(offsetTween),
        child: child,
      ),
    );
  }

  /// Create a combined fade and scale transition
  static Widget fadeScaleTransition({
    required Animation<double> animation,
    required Widget child,
    Alignment alignment = Alignment.center,
  }) {
    final curvedAnimation = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOut,
    );

    return FadeTransition(
      opacity: curvedAnimation,
      child: ScaleTransition(
        scale: curvedAnimation,
        alignment: alignment,
        child: child,
      ),
    );
  }

  /// Create a pulse animation
  static Widget pulseAnimation({
    required Widget child,
    Duration duration = const Duration(seconds: 1),
    double minScale = 0.95,
    double maxScale = 1.05,
  }) {
    return _PulseAnimationWidget(
      duration: duration,
      minScale: minScale,
      maxScale: maxScale,
      child: child,
    );
  }

  /// Create a bounce animation
  static Widget bounceAnimation({
    required Widget child,
    Duration duration = const Duration(milliseconds: 500),
    double height = 20,
  }) {
    return _BounceAnimationWidget(
      duration: duration,
      height: height,
      child: child,
    );
  }

  /// Create a shake animation
  static Widget shakeAnimation({
    required Widget child,
    Duration duration = const Duration(milliseconds: 500),
    double offset = 10,
  }) {
    return _ShakeAnimationWidget(
      duration: duration,
      offset: offset,
      child: child,
    );
  }

  /// Get offset tween based on slide direction
  static Tween<Offset> _getOffsetTween(SlideDirection direction) {
    switch (direction) {
      case SlideDirection.fromTop:
        return Tween<Offset>(begin: const Offset(0, -1), end: Offset.zero);
      case SlideDirection.fromBottom:
        return Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero);
      case SlideDirection.fromLeft:
        return Tween<Offset>(begin: const Offset(-1, 0), end: Offset.zero);
      case SlideDirection.fromRight:
        return Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero);
    }
  }
}

/// Slide direction enum
enum SlideDirection {
  fromTop,
  fromBottom,
  fromLeft,
  fromRight,
}

/// Pulse animation widget
class _PulseAnimationWidget extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final double minScale;
  final double maxScale;

  const _PulseAnimationWidget({
    required this.child,
    required this.duration,
    required this.minScale,
    required this.maxScale,
  });

  @override
  State<_PulseAnimationWidget> createState() => _PulseAnimationWidgetState();
}

class _PulseAnimationWidgetState extends State<_PulseAnimationWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    )..repeat(reverse: true);

    _animation = Tween<double>(
      begin: widget.minScale,
      end: widget.maxScale,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Transform.scale(
          scale: _animation.value,
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

/// Bounce animation widget
class _BounceAnimationWidget extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final double height;

  const _BounceAnimationWidget({
    required this.child,
    required this.duration,
    required this.height,
  });

  @override
  State<_BounceAnimationWidget> createState() => _BounceAnimationWidgetState();
}

class _BounceAnimationWidgetState extends State<_BounceAnimationWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    )..repeat(reverse: true);

    _animation = Tween<double>(
      begin: 0,
      end: widget.height,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.bounceOut,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, -_animation.value),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

/// Shake animation widget
class _ShakeAnimationWidget extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final double offset;

  const _ShakeAnimationWidget({
    required this.child,
    required this.duration,
    required this.offset,
  });

  @override
  State<_ShakeAnimationWidget> createState() => _ShakeAnimationWidgetState();
}

class _ShakeAnimationWidgetState extends State<_ShakeAnimationWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );

    _animation = Tween<double>(
      begin: -widget.offset,
      end: widget.offset,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.elasticIn,
      ),
    );

    _controller.forward().then((_) {
      _controller.reverse();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(_animation.value, 0),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}
