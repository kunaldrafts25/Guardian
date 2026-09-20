import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:guardian/core/services/aws_auth_service.dart';

final authServiceProvider = Provider<AwsAuthService>((ref) {
  return AwsAuthService.instance;
});

final authStateProvider = StreamProvider<AwsAuthUser?>((ref) async* {
  final service = ref.watch(authServiceProvider);
  yield service.currentUser;
  yield* service.authStateChanges;
});

final currentUserProvider = Provider<AwsAuthUser?>((ref) {
  return ref.watch(authStateProvider).valueOrNull;
});

enum PhoneVerificationState { idle, codeSent, verifying, verified, error }

final phoneVerificationProvider =
    StateNotifierProvider<PhoneVerificationNotifier, PhoneVerificationState>(
        (ref) {
  return PhoneVerificationNotifier(ref.watch(authServiceProvider));
});

class PhoneVerificationNotifier extends StateNotifier<PhoneVerificationState> {
  final AwsAuthService _authService;
  String? _phoneNumber;
  String? _errorMessage;

  PhoneVerificationNotifier(this._authService)
      : super(PhoneVerificationState.idle);

  String? get errorMessage => _errorMessage;

  Future<bool> sendOtp(String phoneNumber) async {
    state = PhoneVerificationState.verifying;
    _errorMessage = null;
    try {
      await _authService.sendOtp(phoneNumber);
      _phoneNumber = phoneNumber;
      state = PhoneVerificationState.codeSent;
      return true;
    } catch (error) {
      _errorMessage = _message(error);
      state = PhoneVerificationState.error;
      return false;
    }
  }

  Future<bool> verifyOtp(String otp) async {
    if (_phoneNumber == null) {
      _errorMessage = 'Request a new verification code.';
      state = PhoneVerificationState.error;
      return false;
    }
    state = PhoneVerificationState.verifying;
    _errorMessage = null;
    try {
      await _authService.verifyOtp(otp);
      state = PhoneVerificationState.verified;
      return true;
    } catch (error) {
      _errorMessage = _message(error);
      state = PhoneVerificationState.error;
      return false;
    }
  }

  Future<bool> resendOtp(String phoneNumber) => sendOtp(phoneNumber);

  void reset() {
    _phoneNumber = null;
    _errorMessage = null;
    state = PhoneVerificationState.idle;
  }

  String _message(Object error) =>
      error.toString().replaceFirst('Exception: ', '');
}

final signOutProvider = Provider<Future<void> Function()>((ref) {
  return () => ref.read(authServiceProvider).signOut();
});

final authenticatedSessionsProvider =
    FutureProvider.autoDispose<List<AuthenticatedSession>>((ref) {
  return ref.watch(authServiceProvider).listSessions();
});
