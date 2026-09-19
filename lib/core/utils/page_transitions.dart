/*
 * Guardian - Women's Safety App
 * © 2025 All Rights Reserved - Kunal Singh
 * Contact: kunalsingh2514@gmail.com
 */

import 'package:flutter/material.dart';

/// Custom page transitions for the app
class PageTransitions {
  /// Create a fade transition
  static PageRouteBuilder<T> fade<T>({
    required Widget page,
    Duration duration = const Duration(milliseconds: 300),
  }) {
    return PageRouteBuilder<T>(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionDuration: duration,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: animation,
          child: child,
        );
      },
    );
  }

  /// Create a slide transition
  static PageRouteBuilder<T> slide<T>({
    required Widget page,
    Duration duration = const Duration(milliseconds: 300),
    SlideDirection direction = SlideDirection.fromRight,
  }) {
    return PageRouteBuilder<T>(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionDuration: duration,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        Offset begin;

        switch (direction) {
          case SlideDirection.fromRight:
            begin = const Offset(1.0, 0.0);
            break;
          case SlideDirection.fromLeft:
            begin = const Offset(-1.0, 0.0);
            break;
          case SlideDirection.fromTop:
            begin = const Offset(0.0, -1.0);
            break;
          case SlideDirection.fromBottom:
            begin = const Offset(0.0, 1.0);
            break;
        }

        return SlideTransition(
          position: Tween<Offset>(
            begin: begin,
            end: Offset.zero,
          ).animate(
            CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            ),
          ),
          child: child,
        );
      },
    );
  }

  /// Create a scale transition
  static PageRouteBuilder<T> scale<T>({
    required Widget page,
    Duration duration = const Duration(milliseconds: 300),
    Alignment alignment = Alignment.center,
  }) {
    return PageRouteBuilder<T>(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionDuration: duration,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return ScaleTransition(
          scale: Tween<double>(
            begin: 0.0,
            end: 1.0,
          ).animate(
            CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            ),
          ),
          alignment: alignment,
          child: child,
        );
      },
    );
  }

  /// Create a fade and slide transition
  static PageRouteBuilder<T> fadeSlide<T>({
    required Widget page,
    Duration duration = const Duration(milliseconds: 300),
    SlideDirection direction = SlideDirection.fromRight,
  }) {
    return PageRouteBuilder<T>(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionDuration: duration,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        Offset begin;

        switch (direction) {
          case SlideDirection.fromRight:
            begin = const Offset(0.2, 0.0);
            break;
          case SlideDirection.fromLeft:
            begin = const Offset(-0.2, 0.0);
            break;
          case SlideDirection.fromTop:
            begin = const Offset(0.0, -0.2);
            break;
          case SlideDirection.fromBottom:
            begin = const Offset(0.0, 0.2);
            break;
        }

        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: begin,
              end: Offset.zero,
            ).animate(
              CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              ),
            ),
            child: child,
          ),
        );
      },
    );
  }

  /// Create a fade and scale transition
  static PageRouteBuilder<T> fadeScale<T>({
    required Widget page,
    Duration duration = const Duration(milliseconds: 300),
    Alignment alignment = Alignment.center,
  }) {
    return PageRouteBuilder<T>(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionDuration: duration,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween<double>(
              begin: 0.8,
              end: 1.0,
            ).animate(
              CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              ),
            ),
            alignment: alignment,
            child: child,
          ),
        );
      },
    );
  }

  /// Create a rotation transition
  static PageRouteBuilder<T> rotation<T>({
    required Widget page,
    Duration duration = const Duration(milliseconds: 500),
    Alignment alignment = Alignment.center,
  }) {
    return PageRouteBuilder<T>(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionDuration: duration,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return RotationTransition(
          turns: Tween<double>(
            begin: 0.5,
            end: 1.0,
          ).animate(
            CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            ),
          ),
          child: FadeTransition(
            opacity: animation,
            child: child,
          ),
        );
      },
    );
  }
}

/// Slide direction enum
enum SlideDirection {
  fromRight,
  fromLeft,
  fromTop,
  fromBottom,
}
