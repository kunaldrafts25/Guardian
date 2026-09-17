/*
 * Guardian — API Keys
 *
 * ALL keys are injected at build time via --dart-define.
 * NO real keys are hardcoded here.
 *
 * Build command (development):
 *   flutter run \
 *     --dart-define=GOOGLE_MAPS_API_KEY=YOUR_KEY_HERE \
 *     --dart-define=FIREBASE_API_KEY=YOUR_KEY_HERE
 *
 * Build command (CI/CD — keys come from environment variables):
 *   flutter build apk \
 *     --dart-define=GOOGLE_MAPS_API_KEY=$GOOGLE_MAPS_API_KEY \
 *     --dart-define=FIREBASE_API_KEY=$FIREBASE_API_KEY
 *
 * To rotate a key: update it in your CI/CD secret store, not here.
 */

class ApiKeys {
  ApiKeys._(); // Prevent instantiation

  /// Google Maps API key — injected at build time
  static const String googleMaps = String.fromEnvironment(
    'GOOGLE_MAPS_API_KEY',
    defaultValue: '',
  );

  /// Firebase API key — injected at build time
  /// Note: firebase_options.dart also uses --dart-define values
  static const String firebaseApi = String.fromEnvironment(
    'FIREBASE_API_KEY',
    defaultValue: '',
  );

  /// Check if all required keys are present at startup
  static bool get areKeysConfigured =>
      googleMaps.isNotEmpty && firebaseApi.isNotEmpty;

  /// Throw if keys are missing (call in main() during development)
  static void assertKeysPresent() {
    assert(
      googleMaps.isNotEmpty,
      '\n\n🔑 GOOGLE_MAPS_API_KEY is not set.\n'
      'Run: flutter run --dart-define=GOOGLE_MAPS_API_KEY=YOUR_KEY\n',
    );
  }
}
