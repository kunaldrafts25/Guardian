import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guardian/app/theme/app_theme.dart';
import 'package:guardian/core/providers/auth_provider.dart';
import 'package:guardian/core/services/aws_auth_service.dart';
import 'package:guardian/features/auth/presentation/screens/login_screen.dart';
import 'package:mocktail/mocktail.dart';

class MockAwsAuthService extends Mock implements AwsAuthService {}

class TestGoogleSignInNotifier extends GoogleSignInNotifier {
  TestGoogleSignInNotifier(
    super.authService, {
    GoogleSignInState initialState = GoogleSignInState.idle,
    String? initialError,
  }) {
    state = initialState;
    if (initialError != null) {
      // simulate error
    }
  }

  void setStateForTest(GoogleSignInState newState) {
    state = newState;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockAwsAuthService mockAuthService;

  setUp(() {
    mockAuthService = MockAwsAuthService();
  });

  Widget buildTestableWidget({
    List<Override> overrides = const [],
  }) {
    return ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        home: const LoginScreen(),
      ),
    );
  }

  group('LoginScreen UI Tests', () {
    testWidgets('renders the Google-only production sign-in surface',
        (tester) async {
      await tester.pumpWidget(
        buildTestableWidget(
          overrides: [
            authServiceProvider.overrideWithValue(mockAuthService),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Welcome to Guardian'), findsOneWidget);
      expect(
        find.text('Sign in securely with your Google account.'),
        findsOneWidget,
      );
      expect(find.text('Continue with Google'), findsOneWidget);
      expect(
        find.text(
          'Phone OTP sign-in is not used. Emergency contact phone numbers are separate from account authentication.',
        ),
        findsOneWidget,
      );

      // Phone OTP controls must not return accidentally.
      expect(find.text('OR CONTINUE WITH PHONE'), findsNothing);
      expect(find.text('Mobile number'), findsNothing);
      expect(find.text('Send verification code'), findsNothing);
    });

    testWidgets('displays loading indicator during Google sign-in',
        (tester) async {
      final notifier = TestGoogleSignInNotifier(
        mockAuthService,
        initialState: GoogleSignInState.authenticating,
      );

      await tester.pumpWidget(
        buildTestableWidget(
          overrides: [
            authServiceProvider.overrideWithValue(mockAuthService),
            googleSignInStateProvider.overrideWith((ref) => notifier),
          ],
        ),
      );
      await tester.pump();

      // Button should show a CircularProgressIndicator
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      // The text "Continue with Google" is replaced by the loader during in-flight sign in
      expect(find.text('Continue with Google'), findsNothing);
    });

    testWidgets('calls signIn and handles cancellation gracefully',
        (tester) async {
      when(() => mockAuthService.signInWithGoogle())
          .thenAnswer((_) async => null);

      await tester.pumpWidget(
        buildTestableWidget(
          overrides: [
            authServiceProvider.overrideWithValue(mockAuthService),
          ],
        ),
      );
      await tester.pumpAndSettle();

      final googleButton = find.text('Continue with Google');
      expect(googleButton, findsOneWidget);
      await tester.tap(googleButton);
      await tester.pumpAndSettle();

      verify(() => mockAuthService.signInWithGoogle()).called(1);
      // Button still present, returned to idle
      expect(find.text('Continue with Google'), findsOneWidget);
    });
  });
}
