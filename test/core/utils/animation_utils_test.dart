/*
 * Guardian - Women's Safety App
 * © 2025 All Rights Reserved - Kunal Singh
 * Contact: kunalsingh2514@gmail.com
 */

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guardian/core/utils/animation_utils.dart';

void main() {
  group('AnimationUtils', () {
    late AnimationController controller;
    late Animation<double> animation;

    setUp(() {
      controller = AnimationController(
        duration: const Duration(milliseconds: 300),
        vsync: const TestVSync(),
      );
      animation = controller.drive(CurveTween(curve: Curves.easeInOut));
    });

    tearDown(() {
      controller.dispose();
    });

    testWidgets('fadeTransition creates a FadeTransition', (WidgetTester tester) async {
      final widget = AnimationUtils.fadeTransition(
        animation: animation,
        child: const SizedBox(),
      );

      await tester.pumpWidget(Directionality(
        textDirection: TextDirection.ltr,
        child: widget,
      ));
      expect(find.byType(FadeTransition), findsOneWidget);
    });

    testWidgets('slideTransition creates a SlideTransition', (WidgetTester tester) async {
      final widget = AnimationUtils.slideTransition(
        animation: animation,
        child: const SizedBox(),
      );

      await tester.pumpWidget(Directionality(
        textDirection: TextDirection.ltr,
        child: widget,
      ));
      expect(find.byType(SlideTransition), findsOneWidget);
    });

    testWidgets('scaleTransition creates a ScaleTransition', (WidgetTester tester) async {
      final widget = AnimationUtils.scaleTransition(
        animation: animation,
        child: const SizedBox(),
      );

      await tester.pumpWidget(Directionality(
        textDirection: TextDirection.ltr,
        child: widget,
      ));
      expect(find.byType(ScaleTransition), findsOneWidget);
    });

    testWidgets('fadeSlideTransition creates a FadeTransition and SlideTransition', 
        (WidgetTester tester) async {
      final widget = AnimationUtils.fadeSlideTransition(
        animation: animation,
        child: const SizedBox(),
      );

      await tester.pumpWidget(Directionality(
        textDirection: TextDirection.ltr,
        child: widget,
      ));
      expect(find.byType(FadeTransition), findsOneWidget);
      expect(find.byType(SlideTransition), findsOneWidget);
    });

    testWidgets('fadeScaleTransition creates a FadeTransition and ScaleTransition', 
        (WidgetTester tester) async {
      final widget = AnimationUtils.fadeScaleTransition(
        animation: animation,
        child: const SizedBox(),
      );

      await tester.pumpWidget(Directionality(
        textDirection: TextDirection.ltr,
        child: widget,
      ));
      expect(find.byType(FadeTransition), findsOneWidget);
      expect(find.byType(ScaleTransition), findsOneWidget);
    });
  });
}
