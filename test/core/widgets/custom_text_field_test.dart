/*
 * Guardian - Women's Safety App
 * © 2025 All Rights Reserved - Kunal Singh
 * Contact: kunalsingh2514@gmail.com
 */

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guardian/core/widgets/custom_text_field.dart';

void main() {
  group('CustomTextField', () {
    testWidgets('renders correctly with label and hint',
        (WidgetTester tester) async {
      final controller = TextEditingController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomTextField(
              label: 'Email',
              hint: 'Enter your email',
              controller: controller,
            ),
          ),
        ),
      );

      // Verify label and hint are rendered
      expect(find.text('Email'), findsOneWidget);
      expect(find.text('Enter your email'), findsOneWidget);
    });

    testWidgets('handles text input correctly', (WidgetTester tester) async {
      final controller = TextEditingController();
      String? onChangedValue;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomTextField(
              label: 'Email',
              controller: controller,
              onChanged: (value) {
                onChangedValue = value;
              },
            ),
          ),
        ),
      );

      // Enter text
      await tester.enterText(find.byType(TextFormField), 'test@example.com');

      // Verify controller has the text
      expect(controller.text, 'test@example.com');

      // Verify onChanged was called
      expect(onChangedValue, 'test@example.com');
    });

    testWidgets('shows prefix and suffix icons', (WidgetTester tester) async {
      final controller = TextEditingController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomTextField(
              label: 'Password',
              controller: controller,
              prefixIcon: const Icon(Icons.lock),
              suffixIcon: const Icon(Icons.visibility),
            ),
          ),
        ),
      );

      // Verify icons are rendered
      expect(find.byIcon(Icons.lock), findsOneWidget);
      expect(find.byIcon(Icons.visibility), findsOneWidget);
    });

    testWidgets('handles obscureText correctly', (WidgetTester tester) async {
      final controller = TextEditingController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomTextField(
              label: 'Password',
              controller: controller,
              obscureText: true,
            ),
          ),
        ),
      );

      // Enter text
      await tester.enterText(find.byType(TextFormField), 'password123');

      // Verify text is obscured (can't directly test this, but we can verify the controller has the text)
      expect(controller.text, 'password123');
    });

    testWidgets('calls onChanged callback', (WidgetTester tester) async {
      final controller = TextEditingController();
      String changedText = '';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomTextField(
              label: 'Name',
              controller: controller,
              onChanged: (value) {
                changedText = value;
              },
            ),
          ),
        ),
      );

      // Enter text
      await tester.enterText(find.byType(TextFormField), 'John Doe');

      // Verify onChanged was called
      expect(changedText, 'John Doe');
    });

    testWidgets('disabled state works correctly', (WidgetTester tester) async {
      final controller = TextEditingController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomTextField(
              label: 'Name',
              controller: controller,
              enabled: false,
            ),
          ),
        ),
      );

      // Verify field is disabled
      final textFormField =
          tester.widget<TextFormField>(find.byType(TextFormField));
      expect(textFormField.enabled, false);
    });

    testWidgets('validation works correctly', (WidgetTester tester) async {
      final controller = TextEditingController();
      final formKey = GlobalKey<FormState>();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Form(
              key: formKey,
              child: CustomTextField(
                label: 'Email',
                controller: controller,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter an email';
                  }
                  if (!value.contains('@')) {
                    return 'Please enter a valid email';
                  }
                  return null;
                },
              ),
            ),
          ),
        ),
      );

      // Enter invalid text
      await tester.enterText(find.byType(TextFormField), 'invalid-email');

      // Validate form
      formKey.currentState!.validate();
      await tester.pump();

      // Verify error message is shown
      expect(find.text('Please enter a valid email'), findsOneWidget);

      // Enter valid text
      await tester.enterText(find.byType(TextFormField), 'valid@example.com');

      // Validate form
      formKey.currentState!.validate();
      await tester.pump();

      // Verify error message is gone
      expect(find.text('Please enter a valid email'), findsNothing);
    });
  });
}
