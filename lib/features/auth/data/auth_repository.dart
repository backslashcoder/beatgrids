import 'dart:typed_data';

import '../models/user_profile.dart';

enum AuthEvent { signedIn, signedOut, passwordRecovery }

class SignUpResult {
  const SignUpResult({required this.needsEmailConfirmation});

  /// True when the project requires verifying the email before sign-in.
  final bool needsEmailConfirmation;
}

/// All authentication and own-profile access. Implementations throw
/// `AppFailure` with user-safe messages.
abstract class AuthRepository {
  bool get isConfigured;

  /// Id of the restored or current session user, null when signed out.
  String? get currentUserId;

  Stream<AuthEvent> get events;

  Future<SignUpResult> signUp({
    required String email,
    required String password,
    required String username,
    required String displayName,
  });

  Future<void> signIn({required String email, required String password});
  Future<void> signOut();
  Future<void> sendPasswordReset(String email);
  Future<void> updatePassword(String newPassword);
  Future<bool> isUsernameAvailable(String username);

  /// Loads the signed-in user's profile, creating it if it is missing.
  Future<UserProfile> loadOwnProfile();

  Future<UserProfile> updateProfile({
    required String username,
    required String displayName,
    required String? bio,
  });

  /// Uploads [bytes] as the avatar and returns the updated profile.
  Future<UserProfile> uploadAvatar(
    Uint8List bytes, {
    required String extension,
  });

  /// Public URL for a profile's avatar, or null for the default avatar.
  String? avatarUrl(String? avatarPath);
}
