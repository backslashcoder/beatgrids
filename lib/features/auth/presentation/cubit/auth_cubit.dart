import 'dart:async';
import 'dart:typed_data';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/errors/app_failure.dart';
import '../../data/auth_repository.dart';
import '../../models/user_profile.dart';

enum AuthStatus { signedOut, signedIn }

class AuthState extends Equatable {
  const AuthState({
    this.status = AuthStatus.signedOut,
    this.profile,
    this.profileError,
    this.busy = false,
    this.error,
    this.recovering = false,
    this.configured = true,
  });

  final AuthStatus status;

  /// Null while loading after sign-in, or when [profileError] is set.
  final UserProfile? profile;
  final String? profileError;

  /// A form action (sign in, save...) is in flight; used to block double submits.
  final bool busy;

  /// Last action's user-facing error, shown by the form that triggered it.
  final String? error;

  /// The user arrived from a password-recovery link and must choose a new password.
  final bool recovering;

  /// False when the build has no Supabase settings.
  final bool configured;

  bool get isSignedIn => status == AuthStatus.signedIn;
  bool get profileLoading =>
      isSignedIn && profile == null && profileError == null;

  AuthState copyWith({
    AuthStatus? status,
    UserProfile? profile,
    bool clearProfile = false,
    String? profileError,
    bool clearProfileError = false,
    bool? busy,
    String? error,
    bool clearError = false,
    bool? recovering,
  }) => AuthState(
    status: status ?? this.status,
    profile: clearProfile ? null : (profile ?? this.profile),
    profileError: clearProfileError
        ? null
        : (profileError ?? this.profileError),
    busy: busy ?? this.busy,
    error: clearError ? null : (error ?? this.error),
    recovering: recovering ?? this.recovering,
    configured: configured,
  );

  @override
  List<Object?> get props => [
    status,
    profile,
    profileError,
    busy,
    error,
    recovering,
    configured,
  ];
}

class AuthCubit extends Cubit<AuthState> {
  AuthCubit(this._repo)
    : super(
        AuthState(
          status: _repo.currentUserId != null
              ? AuthStatus.signedIn
              : AuthStatus.signedOut,
          configured: _repo.isConfigured,
        ),
      ) {
    _sub = _repo.events.listen(_onEvent);
    if (state.isSignedIn) loadProfile();
  }

  final AuthRepository _repo;
  StreamSubscription<AuthEvent>? _sub;

  String? avatarUrl(UserProfile? p) => _repo.avatarUrl(p?.avatarPath);

  void _onEvent(AuthEvent event) {
    switch (event) {
      case AuthEvent.signedIn:
        if (!state.isSignedIn)
          emit(state.copyWith(status: AuthStatus.signedIn, clearError: true));
        if (state.profile == null && state.profileError == null) loadProfile();
      case AuthEvent.signedOut:
        emit(AuthState(configured: state.configured));
      case AuthEvent.passwordRecovery:
        emit(state.copyWith(status: AuthStatus.signedIn, recovering: true));
        if (state.profile == null) loadProfile();
    }
  }

  /// Loads (and if needed creates) the signed-in user's profile.
  Future<void> loadProfile() async {
    emit(state.copyWith(clearProfileError: true));
    try {
      final profile = await _repo.loadOwnProfile();
      if (!isClosed && state.isSignedIn) emit(state.copyWith(profile: profile));
    } on AppFailure catch (f) {
      if (!isClosed) emit(state.copyWith(profileError: f.message));
    }
  }

  void clearError() {
    if (state.error != null) emit(state.copyWith(clearError: true));
  }

  /// Runs a form action: blocks re-entry, records the error message on failure.
  Future<T?> _run<T>(Future<T> Function() action) async {
    if (state.busy) return null;
    emit(state.copyWith(busy: true, clearError: true));
    try {
      final result = await action();
      if (!isClosed) emit(state.copyWith(busy: false));
      return result;
    } on AppFailure catch (f) {
      if (!isClosed) emit(state.copyWith(busy: false, error: f.message));
      return null;
    }
  }

  Future<bool> signIn(String email, String password) async {
    final ok = await _run(() async {
      await _repo.signIn(email: email, password: password);
      return true;
    });
    if (ok == true && !state.isSignedIn) {
      emit(state.copyWith(status: AuthStatus.signedIn));
      loadProfile();
    }
    return ok == true;
  }

  /// Returns null on failure (see [AuthState.error]).
  Future<SignUpResult?> signUp({
    required String email,
    required String password,
    required String username,
    required String displayName,
  }) async {
    final result = await _run(
      () => _repo.signUp(
        email: email,
        password: password,
        username: username,
        displayName: displayName,
      ),
    );
    if (result != null && !result.needsEmailConfirmation && !state.isSignedIn) {
      emit(state.copyWith(status: AuthStatus.signedIn));
      loadProfile();
    }
    return result;
  }

  Future<bool> sendPasswordReset(String email) async =>
      await _run(() async {
        await _repo.sendPasswordReset(email);
        return true;
      }) ==
      true;

  Future<bool> updatePassword(String password) async {
    final ok = await _run(() async {
      await _repo.updatePassword(password);
      return true;
    });
    if (ok == true) emit(state.copyWith(recovering: false));
    return ok == true;
  }

  Future<bool> updateProfile({
    required String username,
    required String displayName,
    required String? bio,
  }) async {
    final profile = await _run(
      () => _repo.updateProfile(
        username: username,
        displayName: displayName,
        bio: bio,
      ),
    );
    if (profile != null) emit(state.copyWith(profile: profile));
    return profile != null;
  }

  Future<bool> uploadAvatar(Uint8List bytes, String extension) async {
    final profile = await _run(
      () => _repo.uploadAvatar(bytes, extension: extension),
    );
    if (profile != null) emit(state.copyWith(profile: profile));
    return profile != null;
  }

  Future<bool> isUsernameAvailable(String username) async {
    try {
      return await _repo.isUsernameAvailable(username);
    } on AppFailure {
      return true; // do not block the form; the server still enforces uniqueness
    }
  }

  Future<void> signOut() async {
    await _run(() async {
      await _repo.signOut();
      return true;
    });
    if (!isClosed) emit(AuthState(configured: state.configured));
  }

  @override
  Future<void> close() {
    _sub?.cancel();
    return super.close();
  }
}
