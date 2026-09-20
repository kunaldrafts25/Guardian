import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guardian/app/theme/app_theme.dart';
import 'package:guardian/core/widgets/guardian_ui.dart';

void main() {
  test('Guardian themes reserve the error role for emergency color', () {
    expect(AppTheme.lightTheme.colorScheme.error, AppColors.emergency);
    expect(AppTheme.darkTheme.colorScheme.error, AppColors.emergencyDark);
    expect(AppTheme.lightTheme.colorScheme.primary, AppColors.brand);
    expect(AppTheme.darkTheme.colorScheme.primary, AppColors.brandDark);
  });

  testWidgets('status pill exposes a plain-language semantic status',
      (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: const Scaffold(
          body: GuardianStatusPill(
            label: 'Protection ready',
            tone: GuardianStatusTone.success,
          ),
        ),
      ),
    );

    expect(
      find.bySemanticsLabel(RegExp(r'Status: Protection ready')),
      findsOneWidget,
    );
    expect(find.text('Protection ready'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('action card remains usable at 320px and 200% text scale',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: Scaffold(
            body: GuardianActionCard(
              icon: Icons.timer_outlined,
              title: 'Start a safety check-in',
              description:
                  'Set a time for Guardian to check that you are safe.',
              onTap: () => tapped = true,
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    await tester.tap(find.byType(GuardianActionCard));
    expect(tapped, isTrue);
  });
}
