/*
 * Guardian - Women's Safety App
 * AWS Authentication Service
 * Replaces Firebase Auth with AWS Cognito (phone OTP)
 * Works in dev mode without any AWS credentials configured.
 */

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:guardian/core/utils/logger.dart';
import 'package:guardian/core/services/safety_service_bridge.dart';

/// Storage keys
const _kUserId = 'aws_user_id';
const _kAccessToken = 'aws_access_token';
const _kIdToken = 'aws_id_token';
const _kRefreshToken = 'aws_refresh_token';
const _kPhone = 'aws_user_phone';
const _kEmail = 'aws_user_email';
const _kDisplayName = 'aws_user_display_name';
const _kPhotoUrl = 'aws_user_photo_url';
const _kAuthProvider = 'aws_auth_provider';
const _kSessionId = 'guardian_session_id';

/// Canonical authentication lifecycle states for mobile UI and services.
enum AuthStatus {
  signedOut,
  authenticating,
  authenticated,
  refreshing,
  reauthenticationRequired,
}

class AwsAuthUser {
  final String uid;
  final String? phoneNumber;
  final String? displayName;
  final String? photoURL;
  final String? email;
  final String? authProvider;

  const AwsAuthUser({
    required this.uid,
    this.phoneNumber,
    this.displayName,
    this.photoURL,
    this.email,
    this.authProvider,
  });

  AwsAuthUser copyWith({
    String? displayName,
    String? photoURL,
    String? email,
    String? authProvider,
  }) =>
      AwsAuthUser(
        uid: uid,
        phoneNumber: phoneNumber,
        displayName: displayName ?? this.displayName,
        photoURL: photoURL ?? this.photoURL,
        email: email ?? this.email,
        authProvider: authProvider ?? this.authProvider,
      );
}

class AuthenticatedSession {
  final String id;
  final String deviceLabel;
  final String platform;
  final String status;
  final DateTime? createdAt;
  final DateTime? lastSeenAt;
  final bool isCurrent;

  const AuthenticatedSession({
    required this.id,
    required this.deviceLabel,
    required this.platform,
    required this.status,
    required this.createdAt,
    required this.lastSeenAt,
    required this.isCurrent,
  });

  factory AuthenticatedSession.fromJson(Map<String, dynamic> json) =>
      AuthenticatedSession(
        id: json['session_id'] as String,
        deviceLabel:
            json['device_label'] as String? ?? 'Guardian mobile device',
        platform: json['platform'] as String? ?? 'unknown',
        status: json['status'] as String? ?? 'revoked',
        createdAt: DateTime.tryParse(json['created_at'] as String? ?? ''),
        lastSeenAt: DateTime.tryParse(json['last_seen_at'] as String? ?? ''),
        isCurrent: json['current'] as bool? ?? false,
      );
}

/// AWS Cognito Authentication Service
/// Communicates with the Guardian FastAPI backend which proxies Cognito calls.
class AwsAuthService {
  static final AwsAuthService instance = AwsAuthService._internal();
  factory AwsAuthService() => instance;
  AwsAuthService._internal();

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  /// The backend API base URL — injected at build time via --dart-define
  static const String _apiBase = String.fromEnvironment(
    'AWS_API_ENDPOINT',
    defaultValue:
        'https://3v1rfjbkq1.execute-api.ap-south-1.amazonaws.com/Prod',
  );

  String get _baseUrl {
    if (_apiBase.isNotEmpty) {
      final endpoint = _apiBase.replaceAll(RegExp(r'/$'), '');
      if (kReleaseMode && !endpoint.startsWith('https://')) {
        throw StateError('AWS_API_ENDPOINT must use HTTPS in release builds.');
      }
      return endpoint;
    }
    if (kReleaseMode) {
      throw StateError('AWS_API_ENDPOINT is required in release builds.');
    }
    if (kIsWeb) return 'http://localhost:8000';
    // Physical Android device — use Wi-Fi IP of dev machine
    return 'http://192.168.0.100:8000';
  }

  /// The resolved base URL for API requests.
  String get baseUrl => _baseUrl;

  // ─── Cached state ───────────────────────────────────────────────────────
  String? _userId;
  String? _accessToken;
  String? _phone;
  String? _sessionId;
  String? _pendingSession; // Cognito auth session for OTP verification
  AwsAuthUser? _currentUser;
  Future<bool>? _refreshInFlight;
  final StreamController<AwsAuthUser?> _authStateController =
      StreamController<AwsAuthUser?>.broadcast();

  AuthStatus _authStatus = AuthStatus.signedOut;
  final StreamController<AuthStatus> _authStatusController =
      StreamController<AuthStatus>.broadcast();

  String? get currentUserId => _userId;
  String? get currentPhone => _phone;
  String? get accessToken => _accessToken;
  String? get sessionId => _sessionId;
  AuthStatus get authStatus => _authStatus;
  Stream<AuthStatus> get authStatusChanges => _authStatusController.stream;
  bool get isSignedIn => _authStatus == AuthStatus.authenticated;
  bool get isReauthenticationRequired =>
      _authStatus == AuthStatus.reauthenticationRequired;
  AwsAuthUser? get currentUser => _currentUser;
  Stream<AwsAuthUser?> get authStateChanges => _authStateController.stream;

  void _updateAuthStatus(AuthStatus status) {
    if (_authStatus != status) {
      _authStatus = status;
      _authStatusController.add(status);
    }
  }

  Set<String> get roles {
    final token = _accessToken;
    if (token == null) return const {};
    try {
      final parts = token.split('.');
      if (parts.length != 3) return const {};
      final payload = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
      ) as Map<String, dynamic>;
      final claim = payload['cognito:groups'];
      if (claim is List) {
        return claim.map((value) => value.toString()).toSet();
      }
      if (claim is String) {
        return claim
            .split(',')
            .map((value) => value.trim())
            .where((value) => value.isNotEmpty)
            .toSet();
      }
    } catch (_) {
      // Invalid/opaque tokens have no client-trusted roles. The API remains
      // authoritative for every responder operation.
    }
    return const {};
  }

  bool get isResponder => roles.contains('responder');

  Future<void> _syncNativeEmergencyAuth() async {
    final accessToken = _accessToken;
    final sessionId = _sessionId;
    if (accessToken == null ||
        accessToken.isEmpty ||
        sessionId == null ||
        sessionId.isEmpty) {
      return;
    }
    try {
      final refreshToken = await _storage.read(key: _kRefreshToken);
      await SafetyServiceBridge.updateEmergencyAuth(
        accessToken: accessToken,
        refreshToken: refreshToken,
        sessionId: sessionId,
        apiEndpoint: baseUrl,
      );
    } catch (error) {
      Logger.warning('AwsAuthService: native emergency auth sync failed: $error');
    }
  }

  // ─── Initialization ─────────────────────────────────────────────────────

  /// Call this at app startup to restore cached session.
  Future<void> initialize() async {
    try {
      _userId = await _storage.read(key: _kUserId);
      _accessToken = await _storage.read(key: _kAccessToken);
      _phone = await _storage.read(key: _kPhone);
      _sessionId = await _storage.read(key: _kSessionId);
      final email = await _storage.read(key: _kEmail);
      final displayName = await _storage.read(key: _kDisplayName);
      final photoUrl = await _storage.read(key: _kPhotoUrl);
      final authProvider = await _storage.read(key: _kAuthProvider);

      if (_userId != null &&
          _userId!.isNotEmpty &&
          _accessToken != null &&
          _accessToken!.isNotEmpty) {
        _currentUser = AwsAuthUser(
          uid: _userId!,
          phoneNumber: _phone,
          email: email,
          displayName: displayName,
          photoURL: photoUrl,
          authProvider: authProvider,
        );
        if (_isJwtExpired(_accessToken!)) {
          _updateAuthStatus(AuthStatus.refreshing);
          final refreshed = await refreshSession();
          if (!refreshed) {
            Logger.warning(
              'AwsAuthService: could not refresh token at startup; session requires reauthentication.',
            );
            _updateAuthStatus(AuthStatus.reauthenticationRequired);
          } else {
            _updateAuthStatus(AuthStatus.authenticated);
          }
        } else {
          _updateAuthStatus(AuthStatus.authenticated);
        }
      } else if (_userId != null || _accessToken != null) {
        await _clearLocalSession();
        _updateAuthStatus(AuthStatus.signedOut);
      } else {
        _updateAuthStatus(AuthStatus.signedOut);
      }
      if (_authStatus == AuthStatus.authenticated) {
        await _syncNativeEmergencyAuth();
      }
      _authStateController.add(_currentUser);
      Logger.info('AwsAuthService: restored user=$_userId (authStatus=$_authStatus)');
    } catch (e) {
      Logger.warning('AwsAuthService: could not restore session: $e');
    }
  }

  // ─── Google Sign-In Flow ──────────────────────────────────────────────────

  /// Sign in with Google (Gmail) credentials.
  /// Launches native Google sign-in dialog and sends the verified ID token to the backend.
  Future<AwsAuthUser?> signInWithGoogle({
    GoogleSignIn? customGoogleSignIn,
    String? mockIdToken,
  }) async {
    Logger.info('AwsAuthService: initiating Google sign-in');
    String? idToken = mockIdToken;

    if (idToken == null) {
      final googleSignIn = customGoogleSignIn ??
          GoogleSignIn(
            scopes: ['email', 'profile'],
            serverClientId:
                '530178096868-v6q66826igipjpc2jlq7q95ipfu2bnev.apps.googleusercontent.com',
          );

      final account = await googleSignIn.signIn();
      if (account == null) {
        Logger.info('AwsAuthService: Google sign-in was cancelled by user');
        return null;
      }

      final auth = await account.authentication;
      idToken = auth.idToken;
    }

    if (idToken == null || idToken.isEmpty) {
      throw Exception('Failed to obtain Google verification token.');
    }

    final resp = await _post('/auth/google', {
      'id_token': idToken,
      'device_label':
          'Guardian ${kIsWeb ? 'web' : defaultTargetPlatform.name} device',
      'platform': kIsWeb ? 'web' : defaultTargetPlatform.name,
    });

    if (resp['user_id'] != null) {
      await _persistSession(resp);
    }

    return _currentUser;
  }

  // ─── Phone OTP Flow ─────────────────────────────────────────────────────

  /// Step 1: Send OTP to phone number via Cognito SMS.
  /// Returns the session token needed for verification.
  Future<Map<String, dynamic>> sendOtp(String phoneNumber) async {
    Logger.info('AwsAuthService: sending OTP to $phoneNumber');
    final resp = await _post('/auth/send-otp', {'phone_number': phoneNumber});

    if (resp['session'] != null) {
      _pendingSession = resp['session'] as String;
      _phone = phoneNumber;
    }

    return resp;
  }

  /// Step 2: Verify the OTP code.
  /// On success, stores tokens securely and returns user info.
  Future<Map<String, dynamic>> verifyOtp(String otp) async {
    if (_phone == null || _pendingSession == null) {
      throw Exception('No pending OTP session. Call sendOtp() first.');
    }

    Logger.info('AwsAuthService: verifying OTP');
    final resp = await _post('/auth/verify-otp', {
      'phone_number': _phone!,
      'otp_code': otp,
      'session': _pendingSession!,
      'device_label':
          'Guardian ${kIsWeb ? 'web' : defaultTargetPlatform.name} device',
      'platform': kIsWeb ? 'web' : defaultTargetPlatform.name,
    });

    if (resp['user_id'] != null) {
      await _persistSession(resp);
    }

    return resp;
  }

  /// Refresh expired access token using the stored refresh token.
  Future<bool> refreshSession() {
    final inFlight = _refreshInFlight;
    if (inFlight != null) return inFlight;
    _updateAuthStatus(AuthStatus.refreshing);
    final operation = _refreshSessionInternal();
    _refreshInFlight = operation;
    return operation.then((success) {
      if (success) {
        _updateAuthStatus(AuthStatus.authenticated);
      } else {
        if (_userId != null) {
          _updateAuthStatus(AuthStatus.reauthenticationRequired);
        } else {
          _updateAuthStatus(AuthStatus.signedOut);
        }
      }
      return success;
    }).whenComplete(() {
      if (identical(_refreshInFlight, operation)) _refreshInFlight = null;
    });
  }

  Future<bool> _refreshSessionInternal() async {
    final refreshToken = await _storage.read(key: _kRefreshToken);
    if (refreshToken == null || _userId == null || _sessionId == null) {
      return false;
    }

    try {
      final resp = await _post(
          '/auth/refresh',
          {
            'refresh_token': refreshToken,
            'session_id': _sessionId,
          },
          retryUnauthorized: false);
      if (resp['access_token'] != null) {
        _accessToken = resp['access_token'] as String;
        await _storage.write(key: _kAccessToken, value: _accessToken);
        await _storage.write(key: _kIdToken, value: resp['id_token'] ?? '');
        Logger.info('AwsAuthService: tokens refreshed');
        await _syncNativeEmergencyAuth();
        return true;
      }
    } catch (e) {
      Logger.warning('AwsAuthService: token refresh failed: $e');
    }
    return false;
  }

  /// Sign out — revokes tokens and clears local storage.
  Future<void> signOut() async {
    if (_currentUser?.authProvider == 'google') {
      try {
        await GoogleSignIn().signOut();
      } catch (_) {}
    }
    if (_accessToken != null) {
      try {
        await _post('/auth/sign-out', const {});
      } catch (e) {
        Logger.warning('AwsAuthService: sign-out API error: $e');
      }
    }
    await _clearLocalSession();
    _authStateController.add(null);
    Logger.info('AwsAuthService: signed out');

  }

  Future<List<AuthenticatedSession>> listSessions() async {
    final response = await _get('/auth/sessions');
    final sessions = response['sessions'] as List<dynamic>? ?? const [];
    return sessions
        .whereType<Map<String, dynamic>>()
        .map(AuthenticatedSession.fromJson)
        .toList(growable: false);
  }

  Future<void> revokeSession(String sessionId) async {
    await _delete('/auth/sessions/${Uri.encodeComponent(sessionId)}');
    if (sessionId == _sessionId) {
      await _clearLocalSession();
      _authStateController.add(null);
    }
  }

  bool _isJwtExpired(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return false;
      final payload = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
      ) as Map<String, dynamic>;
      final expiry = (payload['exp'] as num?)?.toInt();
      if (expiry == null) return false;
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      return expiry <= now + 60;
    } catch (_) {
      return false;
    }
  }

  Future<void> _clearLocalSession() async {
    _userId = null;
    _accessToken = null;
    _phone = null;
    _sessionId = null;
    _pendingSession = null;
    _currentUser = null;
    _updateAuthStatus(AuthStatus.signedOut);
    for (final key in [
      _kUserId,
      _kAccessToken,
      _kIdToken,
      _kRefreshToken,
      _kPhone,
      _kEmail,
      _kDisplayName,
      _kPhotoUrl,
      _kAuthProvider,
      _kSessionId,
    ]) {
      await _storage.delete(key: key);
    }
    await SafetyServiceBridge.clearEmergencySnapshot();
  }

  // ─── User Profile ────────────────────────────────────────────────────────

  /// Fetch the current user's profile from DynamoDB via the backend.
  Future<Map<String, dynamic>?> getUserProfile() async {
    if (_userId == null) return null;
    try {
      final resp = await _get('/users/$_userId');
      return resp;
    } catch (e) {
      Logger.warning('AwsAuthService: get profile failed: $e');
      return null;
    }
  }

  /// Update user profile fields in DynamoDB.
  Future<bool> updateProfile(Map<String, dynamic> data) async {
    if (_userId == null) return false;
    try {
      await _put('/users/$_userId', data);
      if (_currentUser != null) {
        _currentUser = _currentUser!.copyWith(
          displayName: data['display_name'] as String?,
          photoURL: data['photo_url'] as String?,
        );
        _authStateController.add(_currentUser);
      }
      return true;
    } catch (e) {
      Logger.warning('AwsAuthService: update profile failed: $e');
      return false;
    }
  }

  /// Save emergency contacts to DynamoDB.
  Future<bool> saveEmergencyContacts(
      List<Map<String, dynamic>> contacts) async {
    if (_userId == null) return false;
    try {
      await _post('/users/$_userId/contacts', {'contacts': contacts});
      return true;
    } catch (e) {
      Logger.warning('AwsAuthService: save contacts failed: $e');
      return false;
    }
  }

  /// Register this device for push notifications via AWS SNS.
  Future<String?> registerDevice(String deviceToken,
      {String platform = 'android'}) async {
    if (_userId == null) return null;
    try {
      final resp = await _post('/users/$_userId/device', {
        'device_token': deviceToken,
        'platform': platform,
      });
      final arn = resp['endpoint_arn'] as String?;
      Logger.info('AwsAuthService: device registered, ARN=$arn');
      return arn;
    } catch (e) {
      Logger.warning('AwsAuthService: device registration failed: $e');
      return null;
    }
  }

  // ─── Internal HTTP Helpers ───────────────────────────────────────────────

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (_accessToken != null) 'Authorization': 'Bearer $_accessToken',
        if (_sessionId != null) 'X-Guardian-Session-ID': _sessionId!,
      };

  Future<Map<String, dynamic>> post(String path, Map<String, dynamic> body) =>
      _post(path, body);

  Future<Map<String, dynamic>> get(String path) => _get(path);

  Future<Map<String, dynamic>> put(String path, Map<String, dynamic> body) =>
      _put(path, body);

  Future<Map<String, dynamic>> delete(String path) => _delete(path);

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> body, {
    bool retryUnauthorized = true,
  }) async {
    return _request(
      path: path,
      timeout: const Duration(seconds: 15),
      retryUnauthorized: retryUnauthorized,
      send: (url) => http.post(url, headers: _headers, body: jsonEncode(body)),
    );
  }

  Future<Map<String, dynamic>> _get(String path) async {
    return _request(
      path: path,
      timeout: const Duration(seconds: 10),
      send: (url) => http.get(url, headers: _headers),
    );
  }

  Future<Map<String, dynamic>> _put(
      String path, Map<String, dynamic> body) async {
    return _request(
      path: path,
      timeout: const Duration(seconds: 10),
      send: (url) => http.put(url, headers: _headers, body: jsonEncode(body)),
    );
  }

  Future<Map<String, dynamic>> _delete(String path) async {
    return _request(
      path: path,
      timeout: const Duration(seconds: 10),
      send: (url) => http.delete(url, headers: _headers),
    );
  }

  Future<Map<String, dynamic>> _request({
    required String path,
    required Duration timeout,
    required Future<http.Response> Function(Uri url) send,
    bool retryUnauthorized = true,
  }) async {
    final url = Uri.parse('$_baseUrl$path');
    var response = await send(url).timeout(timeout);
    if (response.statusCode == 401 &&
        retryUnauthorized &&
        !_isPublicAuthPath(path) &&
        await refreshSession()) {
      response = await send(url).timeout(timeout);
    }
    final Object? decoded =
        response.body.isEmpty ? null : jsonDecode(response.body);
    final data = decoded is Map<String, dynamic>
        ? decoded
        : <String, dynamic>{'data': decoded};
    if (response.statusCode >= 400) {
      final structuredError = data['error'];
      final message = (structuredError is Map<String, dynamic>
              ? structuredError['message']
              : data['detail'])
          ?.toString();
      if (response.statusCode == 401 && !_isPublicAuthPath(path)) {
        final lower = (message ?? '').toLowerCase();
        if (lower.contains('revoked') ||
            lower.contains('invalid session') ||
            lower.contains('session expired')) {
          await _clearLocalSession();
          _authStateController.add(null);
        }
      }
      throw Exception(message ?? 'Request failed: ${response.statusCode}');
    }
    return data;
  }

  bool _isPublicAuthPath(String path) =>
      path == '/auth/send-otp' ||
      path == '/auth/verify-otp' ||
      path == '/auth/google' ||
      path == '/auth/refresh';

  Future<void> _persistSession(Map<String, dynamic> resp) async {
    _userId = resp['user_id'] as String;
    _accessToken = resp['access_token'] as String?;
    _sessionId = resp['session_id'] as String?;
    _phone = resp['phone'] as String? ?? _phone;
    final email = resp['email'] as String?;
    final displayName = resp['display_name'] as String?;
    final photoUrl = resp['photo_url'] as String?;
    final authProvider = resp['auth_provider'] as String? ??
        (_phone != null && _phone!.isNotEmpty ? 'phone' : 'cognito');

    _currentUser = AwsAuthUser(
      uid: _userId!,
      phoneNumber: _phone,
      email: email,
      displayName: displayName,
      photoURL: photoUrl,
      authProvider: authProvider,
    );

    await _storage.write(key: _kUserId, value: _userId);
    await _storage.write(key: _kAccessToken, value: _accessToken ?? '');
    await _storage.write(key: _kIdToken, value: resp['id_token'] ?? '');
    await _storage.write(
        key: _kRefreshToken, value: resp['refresh_token'] ?? '');
    await _storage.write(key: _kPhone, value: _phone ?? '');
    await _storage.write(key: _kSessionId, value: _sessionId ?? '');
    if (email != null) await _storage.write(key: _kEmail, value: email);
    if (displayName != null) {
      await _storage.write(key: _kDisplayName, value: displayName);
    }
    if (photoUrl != null) {
      await _storage.write(key: _kPhotoUrl, value: photoUrl);
    }
    await _storage.write(key: _kAuthProvider, value: authProvider);

    await _syncNativeEmergencyAuth();
    Logger.info(
        'AwsAuthService: session persisted for user=$_userId ($authProvider)');
    _updateAuthStatus(AuthStatus.authenticated);
    _authStateController.add(_currentUser);
  }
}
