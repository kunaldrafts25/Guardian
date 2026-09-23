import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guardian/app/theme/app_theme.dart';
import 'package:guardian/core/widgets/guardian_ui.dart';

void main() {
  group('Warm Guardian Safety Theme & Palette Integrity', () {
    test('strictly removes blue and enforces forest green and coral-red', () {
      final light = AppTheme.lightTheme;
      final dark = AppTheme.darkTheme;

      // Primary is forest green
      expect(light.colorScheme.primary, const Color(0xFF244D3C));
      expect(dark.colorScheme.primary, const Color(0xFF82B89D));

      // Error is coral-red
      expect(light.colorScheme.error, const Color(0xFFC6424E));
      expect(dark.colorScheme.error, const Color(0xFFF06B74));

      // Light background is warm porcelain
      expect(light.scaffoldBackgroundColor, const Color(0xFFF7F5EF));
      expect(dark.scaffoldBackgroundColor, const Color(0xFF101613));

      // Ensure no legacy blues in primary or secondary
      expect(light.colorScheme.primary.toARGB32() != 0xFF1976D2, isTrue);
      expect(light.colorScheme.primary.toARGB32() != 0xFF2196F3, isTrue);
      expect(light.colorScheme.secondary.toARGB32() != 0xFF2196F3, isTrue);
    });

    testWidgets('verifies tone color mappings have zero blue', (tester) async {
      late BuildContext capturedContext;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Builder(
            builder: (context) {
              capturedContext = context;
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(guardianToneColor(capturedContext, GuardianStatusTone.emergency),
          AppColors.emergency);
      expect(guardianToneColor(capturedContext, GuardianStatusTone.success),
          AppColors.success);
      expect(guardianToneColor(capturedContext, GuardianStatusTone.warning),
          AppColors.warning);
      expect(guardianToneColor(capturedContext, GuardianStatusTone.neutral),
          AppColors.secondaryAccent);
    });

    testWidgets('GuardianActionCard renders without overflow at 320px width',
        (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      var tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: GuardianActionCard(
              icon: Icons.shield_outlined,
              title: 'Start a safety check-in',
              description: 'Guardian will verify that you are safe.',
              onTap: () => tapped = true,
            ),
          ),
        ),
      );

      expect(find.text('Start a safety check-in'), findsOneWidget);
      await tester.tap(find.byType(GuardianActionCard));
      expect(tapped, isTrue);
      expect(tester.takeException(), isNull);
    });

    testWidgets('GuardianStatusPill displays semantic status label',
        (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const Scaffold(
            body: GuardianStatusPill(
              label: 'Protection Ready',
              tone: GuardianStatusTone.success,
            ),
          ),
        ),
      );

      expect(find.text('Protection Ready'), findsOneWidget);
      expect(
        find.bySemanticsLabel(RegExp(r'Status: Protection Ready')),
        findsOneWidget,
      );
      semantics.dispose();
    });

    testWidgets('GuardianDangerButton renders with accessible touch target',
        (tester) async {
      var pressed = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: GuardianDangerButton(
              label: 'Call emergency services',
              icon: Icons.local_police_outlined,
              onPressed: () => pressed = true,
            ),
          ),
        ),
      );

      final button = find.byType(ElevatedButton);
      expect(button, findsOneWidget);
      final size = tester.getSize(button);
      expect(size.height >= 48, isTrue);

      await tester.tap(button);
      expect(pressed, isTrue);
    });
  });
}
