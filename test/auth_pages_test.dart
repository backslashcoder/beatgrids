import 'package:beatgrid/core/errors/app_failure.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'app_shell_test.dart' show pumpApp, settle;
import 'fakes/fake_auth_repository.dart';

Finder field(String label) => find.widgetWithText(TextFormField, label);

void main() {
  group('login', () {
    testWidgets('empty submit shows validation and does not call the backend', (
      tester,
    ) async {
      final repo = await pumpApp(tester, location: '/login');
      await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
      await settle(tester);
      expect(find.text('Enter your email.'), findsOneWidget);
      expect(find.text('Enter your password.'), findsOneWidget);
      expect(repo.calls, isEmpty);
    });

    testWidgets('successful sign in leaves the login page', (tester) async {
      final repo = await pumpApp(tester, location: '/login');
      await tester.enterText(field('Email'), 'ada@example.com');
      await tester.enterText(field('Password'), 'password1');
      await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
      await settle(tester);
      expect(repo.calls, contains('signIn:ada@example.com'));
      expect(
        find.text('Welcome back. Pick up where you left off.'),
        findsNothing,
      );
      expect(find.byTooltip('Account'), findsOneWidget);
    });

    testWidgets('wrong credentials show the error and stay on the page', (
      tester,
    ) async {
      final repo = FakeAuthRepository()
        ..failNext = const AppFailure('Incorrect email or password.');
      await pumpApp(tester, location: '/login', repo: repo);
      await tester.enterText(field('Email'), 'ada@example.com');
      await tester.enterText(field('Password'), 'wrongpass');
      await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
      await settle(tester);
      expect(find.text('Incorrect email or password.'), findsOneWidget);
    });

    testWidgets('unconfigured build explains itself and disables submit', (
      tester,
    ) async {
      final repo = FakeAuthRepository()..configured = false;
      await pumpApp(tester, location: '/login', repo: repo);
      // AuthCubit snapshots `configured` at construction, so rebuild via repo flag.
      expect(find.textContaining('not connected to Supabase'), findsOneWidget);
      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Sign in'),
      );
      expect(button.onPressed, isNull);
    });
  });

  group('signup', () {
    testWidgets('validates fields and username rules', (tester) async {
      final repo = await pumpApp(tester, location: '/signup');
      await tester.tap(find.widgetWithText(FilledButton, 'Create account'));
      await settle(tester);
      expect(find.text('Enter your email.'), findsOneWidget);
      expect(find.text('Choose a username.'), findsOneWidget);
      expect(find.text('Enter a display name.'), findsOneWidget);
      expect(find.text('Enter a password.'), findsOneWidget);
      expect(repo.calls, isEmpty);
    });

    testWidgets('flags a taken username after the debounce and blocks submit', (
      tester,
    ) async {
      final repo = await pumpApp(tester, location: '/signup');
      await tester.enterText(field('Username'), 'taken');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();
      expect(repo.calls, contains('available:taken'));
      await tester.enterText(field('Email'), 'a@b.co');
      await tester.enterText(field('Display name'), 'Ada');
      await tester.enterText(field('Password'), 'password1');
      await tester.tap(find.widgetWithText(FilledButton, 'Create account'));
      await settle(tester);
      expect(find.text('That username is already taken.'), findsOneWidget);
      expect(repo.calls.any((c) => c.startsWith('signUp')), isFalse);
    });

    testWidgets('email confirmation flow shows the check-your-inbox state', (
      tester,
    ) async {
      final repo = FakeAuthRepository()..needsConfirmation = true;
      await pumpApp(tester, location: '/signup', repo: repo);
      await tester.enterText(field('Email'), 'a@b.co');
      await tester.enterText(field('Username'), 'newbie');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.enterText(field('Display name'), 'Newbie');
      await tester.enterText(field('Password'), 'password1');
      await tester.tap(find.widgetWithText(FilledButton, 'Create account'));
      await settle(tester);
      expect(repo.calls, contains('signUp:a@b.co:newbie'));
      expect(find.text('Confirm your address'), findsOneWidget);
    });
  });

  testWidgets('forgot password sends the link and confirms', (tester) async {
    final repo = await pumpApp(tester, location: '/forgot-password');
    await tester.enterText(field('Email'), 'a@b.co');
    await tester.tap(find.widgetWithText(FilledButton, 'Send reset link'));
    await settle(tester);
    expect(repo.calls, contains('reset:a@b.co'));
    expect(find.text('Link sent'), findsOneWidget);
  });

  group('settings', () {
    testWidgets('anonymous users are sent to sign in', (tester) async {
      await pumpApp(tester, location: '/settings');
      expect(
        find.text('Welcome back. Pick up where you left off.'),
        findsOneWidget,
      );
    });

    testWidgets('signed-in users edit their profile', (tester) async {
      final repo = FakeAuthRepository(userId: 'u1');
      await pumpApp(
        tester,
        location: '/settings',
        repo: repo,
        size: const Size(1280, 1400),
      );
      expect(
        find.widgetWithText(TextFormField, 'Display name'),
        findsOneWidget,
      );
      await tester.enterText(field('Display name'), 'Ada L');
      await tester.tap(find.text('Save profile'));
      await settle(tester);
      expect(repo.calls, contains('updateProfile:ada'));
      expect(repo.profile.displayName, 'Ada L');
    });

    testWidgets('rejects an invalid username without calling the backend', (
      tester,
    ) async {
      final repo = FakeAuthRepository(userId: 'u1');
      await pumpApp(
        tester,
        location: '/settings',
        repo: repo,
        size: const Size(1280, 1400),
      );
      await tester.enterText(field('Username'), 'ab');
      await tester.tap(find.text('Save profile'));
      await settle(tester);
      expect(find.textContaining('3-20 characters'), findsOneWidget);
      expect(repo.calls.any((c) => c.startsWith('updateProfile')), isFalse);
    });

    testWidgets('profile load failure offers retry', (tester) async {
      final repo = FakeAuthRepository(userId: 'u1')..profileLoadFailures = 1;
      await pumpApp(tester, location: '/settings', repo: repo);
      expect(find.text('Could not load your profile'), findsOneWidget);
      await tester.tap(find.text('Try again'));
      await settle(tester);
      expect(
        find.widgetWithText(TextFormField, 'Display name'),
        findsOneWidget,
      );
    });
  });
}
