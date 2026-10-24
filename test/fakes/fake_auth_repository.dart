import 'dart:async';
import 'dart:typed_data';

import 'package:beatgrid/core/errors/app_failure.dart';
import 'package:beatgrid/features/auth/data/auth_repository.dart';
import 'package:beatgrid/features/auth/models/user_profile.dart';

UserProfile fakeProfile({
  String username = 'ada',
  String name = 'Ada',
  String? bio,
}) => UserProfile(
  id: 'u1',
  username: username,
  displayName: name,
  bio: bio,
  createdAt: DateTime(2026),
);

class FakeAuthRepository implements AuthRepository {
  // ignore: prefer_initializing_formals
  FakeAuthRepository({String? userId}) : _userId = userId;

  String? _userId;
  final _events = StreamController<AuthEvent>.broadcast();
  final calls = <String>[];

  AppFailure? failNext;
  bool needsConfirmation = false;
  Completer<void>? signInGate;
  Set<String> takenUsernames = {'taken'};
  UserProfile profile = fakeProfile();
  int profileLoadFailures = 0;
  bool configured = true;

  void emit(AuthEvent e) => _events.add(e);

  void _maybeFail() {
    final f = failNext;
    if (f != null) {
      failNext = null;
      throw f;
    }
  }

  @override
  bool get isConfigured => configured;
  @override
  String? get currentUserId => _userId;
  @override
  Stream<AuthEvent> get events => _events.stream;

  @override
  Future<SignUpResult> signUp({
    required String email,
    required String password,
    required String username,
    required String displayName,
  }) async {
    calls.add('signUp:$email:$username');
    _maybeFail();
    if (!needsConfirmation) _userId = 'u1';
    return SignUpResult(needsEmailConfirmation: needsConfirmation);
  }

  @override
  Future<void> signIn({required String email, required String password}) async {
    calls.add('signIn:$email');
    await signInGate?.future;
    _maybeFail();
    _userId = 'u1';
  }

  @override
  Future<void> signOut() async {
    calls.add('signOut');
    _userId = null;
  }

  @override
  Future<void> sendPasswordReset(String email) async {
    calls.add('reset:$email');
    _maybeFail();
  }

  @override
  Future<void> updatePassword(String newPassword) async {
    calls.add('updatePassword');
    _maybeFail();
  }

  @override
  Future<bool> isUsernameAvailable(String username) async {
    calls.add('available:$username');
    return !takenUsernames.contains(username);
  }

  @override
  Future<UserProfile> loadOwnProfile() async {
    calls.add('loadProfile');
    if (profileLoadFailures > 0) {
      profileLoadFailures--;
      throw const AppFailure('Could not reach BeatGrid.', code: 'network');
    }
    return profile;
  }

  @override
  Future<UserProfile> updateProfile({
    required String username,
    required String displayName,
    required String? bio,
  }) async {
    calls.add('updateProfile:$username');
    _maybeFail();
    profile = UserProfile(
      id: 'u1',
      username: username,
      displayName: displayName,
      bio: bio,
      createdAt: profile.createdAt,
    );
    return profile;
  }

  @override
  Future<UserProfile> uploadAvatar(
    Uint8List bytes, {
    required String extension,
  }) async {
    calls.add('avatar:$extension');
    _maybeFail();
    return profile;
  }

  @override
  String? avatarUrl(String? avatarPath) => null;
}
