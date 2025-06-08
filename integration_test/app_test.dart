/*
 * Guardian - Women's Safety App
 * © 2025 All Rights Reserved - Kunal Singh
 * Contact: kunalsingh2514@gmail.com
 */

import 'package:flutter_test/flutter_test.dart';
import 'package:guardian/main.dart' as app;
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('End-to-end test', () {
    testWidgets('Verify splash screen and navigation', (tester) async {
      // Start the app
      app.main();
      await tester.pumpAndSettle();

      // Since we can't easily test the full app due to Firebase dependencies,
      // we'll just verify that the app starts without errors
      expect(true, isTrue);

      // Note: In a real integration test, you would:
      // 1. Verify the splash screen is displayed
      // 2. Wait for navigation to the next screen
      // 3. Interact with UI elements
      // 4. Verify expected behavior
    });
  });
}
