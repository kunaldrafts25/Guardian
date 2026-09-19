import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:guardian/core/models/user_model.dart';
import 'package:guardian/core/providers/auth_provider.dart';
import 'package:guardian/core/services/aws_auth_service.dart';

UserModel _profileFromApi(
  Map<String, dynamic> data,
  AwsAuthUser session,
) {
  final rawContacts = data['emergency_contacts'] as List<dynamic>? ?? const [];
  final contacts = rawContacts
      .whereType<Map>()
      .map((item) => EmergencyContact.fromJson(
            Map<String, dynamic>.from(item),
          ))
      .toList();
  final now = DateTime.now();
  DateTime parseDate(Object? value) =>
      value is String ? DateTime.tryParse(value) ?? now : now;
  final score = (data['trust_score'] as num?)?.toInt() ?? 0;

  return UserModel(
    uid: session.uid,
    phoneNumber: data['phone'] as String? ?? session.phoneNumber ?? '',
    displayName: data['display_name'] as String? ?? session.displayName,
    photoUrl: data['photo_url'] as String? ?? session.photoURL,
    trustScore: score,
    trustRank: UserModel.calculateRank(score),
    locationMode: LocationMode.values.firstWhere(
      (mode) => mode.name == data['location_mode'],
      orElse: () => LocationMode.smart,
    ),
    emergencyContacts: contacts,
    helpedCount: (data['helped_count'] as num?)?.toInt() ?? 0,
    sosUsedCount: (data['sos_used_count'] as num?)?.toInt() ?? 0,
    walkSessionsCount: (data['walk_sessions_count'] as num?)?.toInt() ?? 0,
    isPhoneVerified: true,
    isIdVerified: data['is_id_verified'] as bool? ?? false,
    createdAt: parseDate(data['created_at']),
    updatedAt: parseDate(data['updated_at']),
  );
}

final userProfileStreamProvider = StreamProvider<UserModel?>((ref) async* {
  final session = ref.watch(currentUserProvider);
  if (session == null) {
    yield null;
    return;
  }
  final data = await ref.watch(authServiceProvider).getUserProfile();
  yield data == null ? null : _profileFromApi(data, session);
});

final userProfileProvider = FutureProvider<UserModel?>((ref) async {
  final session = ref.watch(currentUserProvider);
  if (session == null) return null;
  final data = await ref.watch(authServiceProvider).getUserProfile();
  return data == null ? null : _profileFromApi(data, session);
});

final ensureUserProfileProvider =
    FutureProvider.family<UserModel, void>((ref, _) async {
  final session = ref.watch(currentUserProvider);
  if (session == null) throw StateError('No authenticated user');
  final data = await ref.watch(authServiceProvider).getUserProfile();
  if (data == null) throw StateError('User profile is unavailable');
  return _profileFromApi(data, session);
});

class ProfileUpdateNotifier extends StateNotifier<AsyncValue<void>> {
  final Ref _ref;
  final AwsAuthService _service;

  ProfileUpdateNotifier(this._ref, this._service)
      : super(const AsyncValue.data(null));

  Future<void> _update(Map<String, dynamic> values) async {
    state = const AsyncValue.loading();
    try {
      final success = await _service.updateProfile(values);
      if (!success) throw StateError('Profile update failed');
      _ref.invalidate(userProfileProvider);
      _ref.invalidate(userProfileStreamProvider);
      state = const AsyncValue.data(null);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  Future<void> updateDisplayName(String name) =>
      _update({'display_name': name});

  Future<void> updatePhotoUrl(String url) => _update({'photo_url': url});

  Future<void> updateLocationMode(LocationMode mode) => _update({
        'settings': {'location_mode': mode.name}
      });

  Future<void> addEmergencyContact(EmergencyContact contact) async {
    final current = await _ref.read(userProfileProvider.future);
    final contacts = [...?current?.emergencyContacts, contact];
    await _saveContacts(contacts);
  }

  Future<void> removeEmergencyContact(String contactId) async {
    final current = await _ref.read(userProfileProvider.future);
    final contacts = [...?current?.emergencyContacts]
      ..removeWhere((contact) => contact.id == contactId);
    await _saveContacts(contacts);
  }

  Future<void> _saveContacts(List<EmergencyContact> contacts) async {
    state = const AsyncValue.loading();
    try {
      final success = await _service.saveEmergencyContacts(
        contacts.map((contact) => contact.toJson()).toList(),
      );
      if (!success) throw StateError('Contact update failed');
      _ref.invalidate(userProfileProvider);
      _ref.invalidate(userProfileStreamProvider);
      state = const AsyncValue.data(null);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }
}

final profileUpdateProvider =
    StateNotifierProvider<ProfileUpdateNotifier, AsyncValue<void>>((ref) {
  return ProfileUpdateNotifier(ref, ref.watch(authServiceProvider));
});

final trustScoreProvider = Provider<int>(
    (ref) => ref.watch(userProfileStreamProvider).valueOrNull?.trustScore ?? 0);

final trustRankProvider = Provider<TrustRank>((ref) =>
    ref.watch(userProfileStreamProvider).valueOrNull?.trustRank ??
    TrustRank.watcher);

final emergencyContactsProvider = Provider<List<EmergencyContact>>((ref) =>
    ref.watch(userProfileStreamProvider).valueOrNull?.emergencyContacts ??
    const []);
