/*
 * Guardian - Women's Safety App
 * © 2025 All Rights Reserved - Kunal Singh
 * Contact: kunalsingh2514@gmail.com
 */

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guardian/core/widgets/loading_indicator.dart';

void main() {
  group('LoadingIndicator', () {
    testWidgets('renders circular progress indicator by default', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: LoadingIndicator(),
          ),
        ),
      );
      
      // Verify circular progress indicator is displayed
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
    
    testWidgets('renders with custom color', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: LoadingIndicator(
              color: Colors.red,
            ),
          ),
        ),
      );
      
      // Verify custom color is applied
      final progressIndicator = tester.widget<CircularProgressIndicator>(
        find.byType(CircularProgressIndicator),
      );
      expect(progressIndicator.valueColor?.value, Colors.red);
    });
    
    testWidgets('renders with custom size', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: LoadingIndicator(
              size: 40.0,
            ),
          ),
        ),
      );
      
      // Verify custom size is applied
      final sizedBox = tester.widget<SizedBox>(
        find.ancestor(
          of: find.byType(CircularProgressIndicator),
          matching: find.byType(SizedBox),
        ).first,
      );
      expect(sizedBox.width, 40.0);
      expect(sizedBox.height, 40.0);
    });
    
    testWidgets('renders with custom stroke width', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: LoadingIndicator(
              strokeWidth: 5.0,
            ),
          ),
        ),
      );
      
      // Verify custom stroke width is applied
      final progressIndicator = tester.widget<CircularProgressIndicator>(
        find.byType(CircularProgressIndicator),
      );
      expect(progressIndicator.strokeWidth, 5.0);
    });
    
    testWidgets('renders with text when provided', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: LoadingIndicator(
              text: 'Loading...',
            ),
          ),
        ),
      );
      
      // Verify text is displayed
      expect(find.text('Loading...'), findsOneWidget);
    });
    
    testWidgets('renders in center when centered is true', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: LoadingIndicator(
              centered: true,
            ),
          ),
        ),
      );
      
      // Verify indicator is centered
      expect(find.byType(Center), findsOneWidget);
    });
  });
}
