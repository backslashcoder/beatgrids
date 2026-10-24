import 'dart:async';

import 'package:beatgrid/core/errors/app_failure.dart';
import 'package:beatgrid/features/auth/data/auth_repository.dart';
import 'package:beatgrid/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes/fake_auth_repository.dart';

Future<void> flush() => Future<void>.delayed(Duration.zero);

void main() {
  test('starts signed out without a session', () {
    final cubit = AuthCubit(FakeAuthRepository());
    expect(cubit.state.isSignedIn, isFalse);
    expect(cubit.state.configured, isTrue);
  });

  test('restores a session and loads the profile', () async {
    final repo = FakeAuthRepository(userId: 'u1');
    final cubit = AuthCubit(repo);
    expect(cubit.state.isSignedIn, isTrue);
    expect(cubit.state.profileLoading, isTrue);
    await flush();
    expect(cubit.state.profile?.username, 'ada');
    expect(cubit.state.profileLoading, isFalse);
  });

  test('sign in success moves to signed in and loads the profile', () async {
    final cubit = AuthCubit(FakeAuthRepository());
    expect(await cubit.signIn('a@b.co', 'password1'), isTrue);
    await flush();
    expect(cubit.state.isSignedIn, isTrue);
    expect(cubit.state.profile, isNotNull);
    expect(cubit.state.busy, isFalse);
  });

  test(
    'sign in failure exposes a friendly error and stays signed out',
    () async {
      final repo = FakeAuthRepository()
        ..failNext = const AppFailure('Incorrect email or password.');
      final cubit = AuthCubit(repo);
      expect(await cubit.signIn('a@b.co', 'bad'), isFalse);
      expect(cubit.state.error, 'Incorrect email or password.');
      expect(cubit.state.isSignedIn, isFalse);
      expect(cubit.state.busy, isFalse);
      cubit.clearError();
      expect(cubit.state.error, isNull);
    },
  );

  test('a second submit while busy is ignored', () async {
    final gate = Completer<void>();
    final repo = FakeAuthRepository()..signInGate = gate;
    final cubit = AuthCubit(repo);
    final first = cubit.signIn('a@b.co', 'password1');
    await flush();
    expect(cubit.state.busy, isTrue);
    expect(await cubit.signIn('a@b.co', 'password1'), isFalse);
    gate.complete();
    expect(await first, isTrue);
    expect(repo.calls.where((c) => c.startsWith('signIn')).length, 1);
  });

  test('sign up that needs email confirmation does not sign in', () async {
    final repo = FakeAuthRepository()..needsConfirmation = true;
    final cubit = AuthCubit(repo);
    final result = await cubit.signUp(
      email: 'a@b.co',
      password: 'password1',
      username: 'ada',
      displayName: 'Ada',
    );
    expect(result?.needsEmailConfirmation, isTrue);
    expect(cubit.state.isSignedIn, isFalse);
  });

  test('sign up with confirmations off signs in immediately', () async {
    final cubit = AuthCubit(FakeAuthRepository());
    final result = await cubit.signUp(
      email: 'a@b.co',
      password: 'password1',
      username: 'ada',
      displayName: 'Ada',
    );
    expect(result?.needsEmailConfirmation, isFalse);
    expect(cubit.state.isSignedIn, isTrue);
  });

  test('profile load failure is surfaced and retry recovers', () async {
    final repo = FakeAuthRepository(userId: 'u1')..profileLoadFailures = 1;
    final cubit = AuthCubit(repo);
    await flush();
    expect(cubit.state.profileError, isNotNull);
    expect(cubit.state.profile, isNull);
    await cubit.loadProfile();
    expect(cubit.state.profile, isNotNull);
    expect(cubit.state.profileError, isNull);
  });

  test('signed-out event from another tab resets state', () async {
    final repo = FakeAuthRepository(userId: 'u1');
    final cubit = AuthCubit(repo);
    await flush();
    repo.emit(AuthEvent.signedOut);
    await flush();
    expect(cubit.state.isSignedIn, isFalse);
    expect(cubit.state.profile, isNull);
  });

  test(
    'password recovery event flags recovering until the password is updated',
    () async {
      final repo = FakeAuthRepository();
      final cubit = AuthCubit(repo);
      repo.emit(AuthEvent.passwordRecovery);
      await flush();
      expect(cubit.state.isSignedIn, isTrue);
      expect(cubit.state.recovering, isTrue);
      expect(await cubit.updatePassword('newpassword1'), isTrue);
      expect(cubit.state.recovering, isFalse);
    },
  );

  test(
    'profile update stores the result; a taken username reports an error',
    () async {
      final repo = FakeAuthRepository(userId: 'u1');
      final cubit = AuthCubit(repo);
      await flush();
      expect(
        await cubit.updateProfile(
          username: 'new_name',
          displayName: 'New',
          bio: 'hi',
        ),
        isTrue,
      );
      expect(cubit.state.profile?.username, 'new_name');
      repo.failNext = const AppFailure(
        'That username is already taken.',
        code: 'username_taken',
      );
      expect(
        await cubit.updateProfile(
          username: 'taken',
          displayName: 'New',
          bio: null,
        ),
        isFalse,
      );
      expect(cubit.state.error, 'That username is already taken.');
      expect(cubit.state.profile?.username, 'new_name');
    },
  );

  test('sign out clears the profile', () async {
    final cubit = AuthCubit(FakeAuthRepository(userId: 'u1'));
    await flush();
    await cubit.signOut();
    expect(cubit.state.isSignedIn, isFalse);
    expect(cubit.state.profile, isNull);
  });
}
