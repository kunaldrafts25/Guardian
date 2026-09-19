/*
 * Guardian - Women's Safety App
 * © 2025 All Rights Reserved - Kunal Singh
 * Contact: kunalsingh2514@gmail.com
 */

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guardian/core/widgets/error_display.dart';

void main() {
  group('ErrorDisplay', () {
    testWidgets('renders error message', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ErrorDisplay(
              message: 'An error occurred',
            ),
          ),
        ),
      );

      // Verify error message is displayed
      expect(find.text('An error occurred'), findsOneWidget);
    });

    testWidgets('renders error icon by default', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ErrorDisplay(
              message: 'An error occurred',
            ),
          ),
        ),
      );

      // Verify error icon is displayed
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
    });

    testWidgets('renders custom icon when provided',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ErrorDisplay(
              message: 'An error occurred',
              icon: Icons.warning,
            ),
          ),
        ),
      );

      // Verify custom icon is displayed
      expect(find.byIcon(Icons.warning), findsOneWidget);
    });

    testWidgets('renders retry button when onRetry is provided',
        (WidgetTester tester) async {
      bool retryPressed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ErrorDisplay(
              message: 'An error occurred',
              onRetry: () {
                retryPressed = true;
              },
            ),
          ),
        ),
      );

      // Verify retry button is displayed
      expect(find.text('Retry'), findsOneWidget);

      // Tap retry button
      await tester.tap(find.text('Retry'));
      await tester.pump();

      // Verify callback was called
      expect(retryPressed, true);
    });

    testWidgets('does not render retry button when onRetry is not provided',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ErrorDisplay(
              message: 'An error occurred',
            ),
          ),
        ),
      );

      // Verify retry button is not displayed
      expect(find.text('Retry'), findsNothing);
    });

    testWidgets('applies custom styles', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ErrorDisplay(
              message: 'An error occurred',
              messageStyle: TextStyle(color: Colors.red),
              iconColor: Colors.orange,
              iconSize: 40.0,
            ),
          ),
        ),
      );

      // Verify custom styles are applied
      final icon = tester.widget<Icon>(find.byIcon(Icons.error_outline));
      expect(icon.color, Colors.orange);
      expect(icon.size, 40.0);

      final text = tester.widget<Text>(find.text('An error occurred'));
      expect(text.style?.color, Colors.red);
    });
  });
}
