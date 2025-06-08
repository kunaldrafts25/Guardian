/*
 * Guardian - Women's Safety App
 * © 2025 All Rights Reserved - Kunal Singh
 * Contact: kunalsingh2514@gmail.com
 */

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guardian/core/widgets/custom_app_bar.dart';

void main() {
  group('CustomAppBar', () {
    testWidgets('renders correctly with title', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: CustomAppBar(
              title: 'Test Title',
            ),
          ),
        ),
      );

      // Verify title is displayed
      expect(find.text('Test Title'), findsOneWidget);
    });

    testWidgets('renders back button when showBackButton is true', (WidgetTester tester) async {
      bool backButtonPressed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: CustomAppBar(
              title: 'Test Title',
              showBackButton: true,
              onBackPressed: () {
                backButtonPressed = true;
              },
            ),
          ),
        ),
      );

      // Verify back button is displayed
      expect(find.byIcon(Icons.arrow_back), findsOneWidget);

      // Tap back button
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pump();

      // Verify callback was called
      expect(backButtonPressed, true);
    });

    testWidgets('does not render back button when showBackButton is false', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: CustomAppBar(
              title: 'Test Title',
              showBackButton: false,
            ),
          ),
        ),
      );

      // Verify back button is not displayed
      expect(find.byIcon(Icons.arrow_back), findsNothing);
    });

    testWidgets('renders actions correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: CustomAppBar(
              title: 'Test Title',
              actions: [
                IconButton(
                  icon: const Icon(Icons.settings),
                  onPressed: () {},
                ),
                IconButton(
                  icon: const Icon(Icons.notifications),
                  onPressed: () {},
                ),
              ],
            ),
          ),
        ),
      );

      // Verify actions are displayed
      expect(find.byIcon(Icons.settings), findsOneWidget);
      expect(find.byIcon(Icons.notifications), findsOneWidget);
    });

    testWidgets('renders custom leading widget', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: CustomAppBar(
              title: 'Test Title',
              leading: const Icon(Icons.menu),
            ),
          ),
        ),
      );

      // Verify custom leading widget is displayed
      expect(find.byIcon(Icons.menu), findsOneWidget);
    });

    testWidgets('applies custom styles', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: CustomAppBar(
              title: 'Test Title',
              backgroundColor: Colors.red,
              elevation: 8.0,
              centerTitle: true,
            ),
          ),
        ),
      );

      // Verify custom styles are applied
      final appBar = tester.widget<CustomAppBar>(find.byType(CustomAppBar));
      expect(appBar.backgroundColor, Colors.red);
      expect(appBar.elevation, 8.0);
      expect(appBar.centerTitle, true);
    });

    testWidgets('renders with custom title style', (WidgetTester tester) async {
      const customStyle = TextStyle(
        fontSize: 24.0,
        fontWeight: FontWeight.bold,
        color: Colors.blue,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: CustomAppBar(
              title: 'Test Title',
              titleStyle: customStyle,
            ),
          ),
        ),
      );

      // Verify title has custom style
      final titleWidget = tester.widget<Text>(find.text('Test Title'));
      expect(titleWidget.style, customStyle);
    });

    testWidgets('handles onTap callback', (WidgetTester tester) async {
      bool appBarTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: CustomAppBar(
              title: 'Test Title',
              onTap: () {
                appBarTapped = true;
              },
            ),
          ),
        ),
      );

      // Tap the app bar title
      await tester.tap(find.text('Test Title'));
      await tester.pump();

      // Verify callback was called
      expect(appBarTapped, true);
    });
  });
}
