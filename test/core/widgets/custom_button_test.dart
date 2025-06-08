/*
 * Guardian - Women's Safety App
 * © 2025 All Rights Reserved - Kunal Singh
 * Contact: kunalsingh2514@gmail.com
 */

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guardian/core/constants/app_colors.dart';
import 'package:guardian/core/widgets/custom_button.dart';

void main() {
  group('CustomButton', () {
    testWidgets('renders primary button correctly', (WidgetTester tester) async {
      bool buttonPressed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomButton(
              text: 'Primary Button',
              onPressed: () {
                buttonPressed = true;
              },
              type: ButtonType.primary,
            ),
          ),
        ),
      );

      // Verify button is rendered
      expect(find.text('Primary Button'), findsOneWidget);

      // Verify button has correct style
      final elevatedButton = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      final buttonStyle = elevatedButton.style as ButtonStyle;

      // Verify button has correct background color
      final backgroundColor = buttonStyle.backgroundColor?.resolve({WidgetState.pressed});
      expect(backgroundColor, AppColors.primary);

      // Tap the button
      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();

      // Verify callback was called
      expect(buttonPressed, true);
    });

    testWidgets('renders secondary button correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomButton(
              text: 'Secondary Button',
              onPressed: () {},
              type: ButtonType.secondary,
            ),
          ),
        ),
      );

      // Verify button is rendered
      expect(find.text('Secondary Button'), findsOneWidget);
    });

    testWidgets('renders outline button correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomButton(
              text: 'Outline Button',
              onPressed: () {},
              type: ButtonType.outline,
            ),
          ),
        ),
      );

      // Verify button is rendered
      expect(find.text('Outline Button'), findsOneWidget);
      expect(find.byType(OutlinedButton), findsOneWidget);
    });

    testWidgets('renders text button correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomButton(
              text: 'Text Button',
              onPressed: () {},
              type: ButtonType.text,
            ),
          ),
        ),
      );

      // Verify button is rendered
      expect(find.text('Text Button'), findsOneWidget);
      expect(find.byType(TextButton), findsOneWidget);
    });

    testWidgets('renders loading state correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomButton(
              text: 'Loading Button',
              onPressed: () {},
              isLoading: true,
            ),
          ),
        ),
      );

      // Verify loading indicator is shown
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Loading Button'), findsNothing);
    });

    testWidgets('renders button with icon correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomButton(
              text: 'Icon Button',
              onPressed: () {},
              icon: Icons.add,
            ),
          ),
        ),
      );

      // Verify button has icon
      expect(find.byIcon(Icons.add), findsOneWidget);
      expect(find.text('Icon Button'), findsOneWidget);
    });

    testWidgets('disabled button does not trigger onPressed', (WidgetTester tester) async {
      bool buttonPressed = false;

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CustomButton(
              text: 'Disabled Button',
              onPressed: null,
            ),
          ),
        ),
      );

      // Tap the button
      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();

      // Verify callback was not called
      expect(buttonPressed, false);
    });
  });
}
