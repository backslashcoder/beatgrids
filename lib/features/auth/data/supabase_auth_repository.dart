import 'dart:async';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/errors/error_mapper.dart';
import '../models/user_profile.dart';
import 'auth_repository.dart';

class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository(this._client, {required this.redirectOrigin});

  final SupabaseClient _client;

  /// Where email links (confirmation, recovery) return to, e.g. https://beatgrid.app.
  /// Must be listed under Authentication > URL Configuration in Supabase.
  final String redirectOrigin;

  GoTrueClient get _auth => _client.auth;

  @override
  bool get isConfigured => true;

  @override
  String? get currentUserId => _auth.currentUser?.id;

  @override
  Stream<AuthEvent> get events => _auth.onAuthStateChange.expand((state) {
    switch (state.event) {
      case AuthChangeEvent.signedIn:
      case AuthChangeEvent.initialSession:
        return state.session == null
            ? const <AuthEvent>[]
            : [AuthEvent.signedIn];
      case AuthChangeEvent.signedOut:
        return [AuthEvent.signedOut];
      case AuthChangeEvent.passwordRecovery:
        return [AuthEvent.passwordRecovery];
      default:
        return const <AuthEvent>[];
    }
  });

  Future<T> _guard<T>(Future<T> Function() body) async {
    try {
      return await body();
    } catch (e, s) {
      throw mapError(e, s);
    }
  }

  @override
  Future<SignUpResult> signUp({
    required String email,
    required String password,
    required String username,
    required String displayName,
  }) => _guard(() async {
    final res = await _auth.signUp(
      email: email.trim(),
      password: password,
      emailRedirectTo: redirectOrigin,
      data: {
        'username': username.trim().toLowerCase(),
        'display_name': displayName.trim(),
      },
    );
    return SignUpResult(needsEmailConfirmation: res.session == null);
  });

  @override
  Future<void> signIn({required String email, required String password}) =>
      _guard(
        () => _auth.signInWithPassword(email: email.trim(), password: password),
      );

  @override
  Future<void> signOut() => _guard(() => _auth.signOut());

  @override
  Future<void> sendPasswordReset(String email) => _guard(
    () => _auth.resetPasswordForEmail(
      email.trim(),
      redirectTo: '$redirectOrigin/reset-password',
    ),
  );

  @override
  Future<void> updatePassword(String newPassword) =>
      _guard(() => _auth.updateUser(UserAttributes(password: newPassword)));

  @override
  Future<bool> isUsernameAvailable(String username) => _guard(() async {
    final res = await _client.rpc(
      'is_username_available',
      params: {'name': username},
    );
    return res == true;
  });

  @override
  Future<UserProfile> loadOwnProfile() => _guard(() async {
    final row = await _client.rpc('ensure_profile');
    return UserProfile.fromJson(Map<String, dynamic>.from(row as Map));
  });

  @override
  Future<UserProfile> updateProfile({
    required String username,
    required String displayName,
    required String? bio,
  }) => _guard(() async {
    final id = currentUserId;
    if (id == null)
      throw const AppFailure('Please sign in first.', code: 'session_expired');
    final trimmedBio = bio?.trim();
    final row = await _client
        .from('profiles')
        .update({
          'username': username.trim().toLowerCase(),
          'display_name': displayName.trim(),
          'bio': (trimmedBio == null || trimmedBio.isEmpty) ? null : trimmedBio,
        })
        .eq('id', id)
        .select()
        .single();
    return UserProfile.fromJson(row);
  });

  @override
  Future<UserProfile> uploadAvatar(
    Uint8List bytes, {
    required String extension,
  }) => _guard(() async {
    final id = currentUserId;
    if (id == null)
      throw const AppFailure('Please sign in first.', code: 'session_expired');
    final ext = extension.toLowerCase().replaceAll('.', '');
    const types = {
      'png': 'image/png',
      'jpg': 'image/jpeg',
      'jpeg': 'image/jpeg',
      'webp': 'image/webp',
    };
    final contentType = types[ext];
    if (contentType == null) {
      throw const AppFailure(
        'Use a PNG, JPG or WebP image.',
        code: 'file_type',
      );
    }
    if (bytes.lengthInBytes > 2 * 1024 * 1024) {
      throw const AppFailure(
        'Avatars must be 2 MB or smaller.',
        code: 'file_too_large',
      );
    }
    // A new name per upload avoids stale CDN/browser caches.
    final path = '$id/avatar-${DateTime.now().millisecondsSinceEpoch}.$ext';
    await _client.storage
        .from('avatars')
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: contentType),
        );
    final row = await _client
        .from('profiles')
        .update({'avatar_path': path})
        .eq('id', id)
        .select()
        .single();
    return UserProfile.fromJson(row);
  });

  @override
  String? avatarUrl(String? avatarPath) => avatarPath == null
      ? null
      : _client.storage.from('avatars').getPublicUrl(avatarPath);
}

/// Used when no Supabase project is configured: the app still runs (studio,
/// home) and auth screens explain what is missing.
class UnconfiguredAuthRepository implements AuthRepository {
  const UnconfiguredAuthRepository();

  @override
  bool get isConfigured => false;
  @override
  String? get currentUserId => null;
  @override
  Stream<AuthEvent> get events => const Stream.empty();

  Never _fail() => throw AppFailure.notConfigured;

  @override
  Future<SignUpResult> signUp({
    required String email,
    required String password,
    required String username,
    required String displayName,
  }) async => _fail();
  @override
  Future<void> signIn({
    required String email,
    required String password,
  }) async => _fail();
  @override
  Future<void> signOut() async {}
  @override
  Future<void> sendPasswordReset(String email) async => _fail();
  @override
  Future<void> updatePassword(String newPassword) async => _fail();
  @override
  Future<bool> isUsernameAvailable(String username) async => _fail();
  @override
  Future<UserProfile> loadOwnProfile() async => _fail();
  @override
  Future<UserProfile> updateProfile({
    required String username,
    required String displayName,
    required String? bio,
  }) async => _fail();
  @override
  Future<UserProfile> uploadAvatar(
    Uint8List bytes, {
    required String extension,
  }) async => _fail();
  @override
  String? avatarUrl(String? avatarPath) => null;
}
