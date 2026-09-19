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
import 'package:http/http.dart' as http;
import 'package:guardian/core/utils/logger.dart';

/// Storage keys
const _kUserId = 'aws_user_id';
const _kAccessToken = 'aws_access_token';
const _kIdToken = 'aws_id_token';
const _kRefreshToken = 'aws_refresh_token';
const _kPhone = 'aws_user_phone';

class AwsAuthUser {
  final String uid;
  final String? phoneNumber;
  final String? displayName;
  final String? photoURL;

  const AwsAuthUser({
    required this.uid,
    this.phoneNumber,
    this.displayName,
    this.photoURL,
  });

  AwsAuthUser copyWith({String? displayName, String? photoURL}) => AwsAuthUser(
        uid: uid,
        phoneNumber: phoneNumber,
        displayName: displayName ?? this.displayName,
        photoURL: photoURL ?? this.photoURL,
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
    defaultValue: '',
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
    return 'http://192.168.0.103:8000';
  }

  // ─── Cached state ───────────────────────────────────────────────────────
  String? _userId;
  String? _accessToken;
  String? _phone;
  String? _pendingSession; // Cognito auth session for OTP verification
  AwsAuthUser? _currentUser;
  Future<bool>? _refreshInFlight;
  final StreamController<AwsAuthUser?> _authStateController =
      StreamController<AwsAuthUser?>.broadcast();

  String? get currentUserId => _userId;
  String? get currentPhone => _phone;
  String? get accessToken => _accessToken;
  bool get isSignedIn => _userId != null;
  AwsAuthUser? get currentUser => _currentUser;
  Stream<AwsAuthUser?> get authStateChanges => _authStateController.stream;

  // ─── Initialization ─────────────────────────────────────────────────────

  /// Call this at app startup to restore cached session.
  Future<void> initialize() async {
    try {
      _userId = await _storage.read(key: _kUserId);
      _accessToken = await _storage.read(key: _kAccessToken);
      _phone = await _storage.read(key: _kPhone);
      if (_userId != null &&
          _userId!.isNotEmpty &&
          _accessToken != null &&
          _accessToken!.isNotEmpty) {
        if (_isJwtExpired(_accessToken!)) {
          final refreshed = await refreshSession();
          if (!refreshed) {
            await _clearLocalSession();
            _authStateController.add(null);
            return;
          }
        }
        _currentUser = AwsAuthUser(uid: _userId!, phoneNumber: _phone);
      }
      _authStateController.add(_currentUser);
      Logger.info('AwsAuthService: restored user=$_userId');
    } catch (e) {
      Logger.warning('AwsAuthService: could not restore session: $e');
    }
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
    final operation = _refreshSessionInternal();
    _refreshInFlight = operation;
    return operation.whenComplete(() {
      if (identical(_refreshInFlight, operation)) _refreshInFlight = null;
    });
  }

  Future<bool> _refreshSessionInternal() async {
    final refreshToken = await _storage.read(key: _kRefreshToken);
    if (refreshToken == null || _userId == null) return false;

    try {
      final resp = await _post(
          '/auth/refresh',
          {
            'refresh_token': refreshToken,
          },
          retryUnauthorized: false);
      if (resp['access_token'] != null) {
        _accessToken = resp['access_token'] as String;
        await _storage.write(key: _kAccessToken, value: _accessToken);
        await _storage.write(key: _kIdToken, value: resp['id_token'] ?? '');
        Logger.info('AwsAuthService: tokens refreshed');
        return true;
      }
    } catch (e) {
      Logger.warning('AwsAuthService: token refresh failed: $e');
    }
    return false;
  }

  /// Sign out — revokes tokens and clears local storage.
  Future<void> signOut() async {
    if (_accessToken != null) {
      try {
        await _post('/auth/sign-out', {'access_token': _accessToken!});
      } catch (e) {
        Logger.warning('AwsAuthService: sign-out API error: $e');
      }
    }
    await _clearLocalSession();
    _authStateController.add(null);
    Logger.info('AwsAuthService: signed out');
  }

  bool _isJwtExpired(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return true;
      final payload = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
      ) as Map<String, dynamic>;
      final expiry = (payload['exp'] as num?)?.toInt();
      if (expiry == null) return true;
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      return expiry <= now + 60;
    } catch (_) {
      return true;
    }
  }

  Future<void> _clearLocalSession() async {
    _userId = null;
    _accessToken = null;
    _phone = null;
    _pendingSession = null;
    _currentUser = null;
    for (final key in [
      _kUserId,
      _kAccessToken,
      _kIdToken,
      _kRefreshToken,
      _kPhone,
    ]) {
      await _storage.delete(key: key);
    }
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
      };

  Future<Map<String, dynamic>> post(String path, Map<String, dynamic> body) =>
      _post(path, body);

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
        !path.startsWith('/auth/') &&
        await refreshSession()) {
      response = await send(url).timeout(timeout);
    }
    final Object? decoded =
        response.body.isEmpty ? null : jsonDecode(response.body);
    final data = decoded is Map<String, dynamic>
        ? decoded
        : <String, dynamic>{'data': decoded};
    if (response.statusCode >= 400) {
      if (response.statusCode == 401 && !path.startsWith('/auth/')) {
        await _clearLocalSession();
        _authStateController.add(null);
      }
      throw Exception(
          data['detail'] ?? 'Request failed: ${response.statusCode}');
    }
    return data;
  }

  Future<void> _persistSession(Map<String, dynamic> resp) async {
    _userId = resp['user_id'] as String;
    _accessToken = resp['access_token'] as String?;
    _phone = resp['phone'] as String? ?? _phone;
    _currentUser = AwsAuthUser(uid: _userId!, phoneNumber: _phone);

    await _storage.write(key: _kUserId, value: _userId);
    await _storage.write(key: _kAccessToken, value: _accessToken ?? '');
    await _storage.write(key: _kIdToken, value: resp['id_token'] ?? '');
    await _storage.write(
        key: _kRefreshToken, value: resp['refresh_token'] ?? '');
    await _storage.write(key: _kPhone, value: _phone ?? '');

    Logger.info('AwsAuthService: session persisted for user=$_userId');
    _authStateController.add(_currentUser);
  }
}
