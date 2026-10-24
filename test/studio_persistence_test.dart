import 'package:beatgrid/core/errors/app_failure.dart';
import 'package:beatgrid/core/services/unsaved_changes_guard.dart';
import 'package:beatgrid/features/beats/models/beat.dart';
import 'package:beatgrid/features/studio/models/beat_pattern.dart';
import 'package:beatgrid/features/studio/models/starter_patterns.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_shell_test.dart' show pumpApp, settle;
import 'fakes/fake_audio_engine.dart';
import 'fakes/fake_auth_repository.dart';
import 'fakes/fake_beat_repository.dart';

Finder step(String track, int n) => find.bySemanticsLabel('$track step $n');
Finder key(String k) => find.byKey(Key(k));

BeatInput savedInput({
  String title = 'Night Drive',
  BeatStatus status = BeatStatus.draft,
}) => BeatInput(
  title: title,
  genre: 'house',
  bpm: 124,
  pattern: starterById('house-groove')!.toPattern(),
  status: status,
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
    'saving a new beat creates a draft and moves the URL without disturbing audio',
    (tester) async {
      final beats = FakeBeatRepository();
      final engine = FakeAudioEngine();
      await pumpApp(
        tester,
        location: '/studio',
        repo: FakeAuthRepository(userId: 'u1'),
        beats: beats,
        engine: engine,
      );
      await tester.tap(step('Kick', 1));
      await settle(tester);
      expect(find.text('Unsaved changes'), findsOneWidget);

      await tester.tap(key('header-save'));
      await settle(tester);
      expect(beats.beats.length, 1);
      expect(beats.beats.values.single.status, BeatStatus.draft);
      expect(
        beats.beats.values.single.pattern.isActive(TrackId.kick, 0),
        isTrue,
      );
      expect(find.text('Draft saved'), findsWidgets);
      expect(find.text('Unsaved changes'), findsNothing);
      expect(
        engine.disposed,
        isFalse,
        reason: 'URL change must not rebuild the studio',
      );
      expect(
        find.byKey(const Key('header-menu')),
        findsOneWidget,
        reason: 'saved beats get the menu',
      );
    },
  );

  testWidgets(
    'publishing validates, then makes the beat public with an explicit confirmation of state',
    (tester) async {
      final beats = FakeBeatRepository();
      await pumpApp(
        tester,
        location: '/studio',
        repo: FakeAuthRepository(userId: 'u1'),
        beats: beats,
        engine: FakeAudioEngine(),
      );
      await tester.tap(key('header-publish'));
      await settle(tester);
      expect(find.text('Publish your beat'), findsOneWidget);

      await tester.tap(key('details-publish'));
      await settle(tester);
      expect(find.text('Name your beat before publishing.'), findsWidgets);
      expect(find.text('Add some steps before publishing.'), findsOneWidget);
      expect(beats.calls, isEmpty);

      await tester.enterText(key('details-title'), 'Night Drive');
      await tester.tap(find.text('Close'));
      await settle(tester);
      expect(find.text('Publish your beat'), findsNothing);
      await tester.tap(step('Kick', 1));
      await tester.tap(step('Snare', 5));
      await settle(tester);
      await tester.tap(key('header-publish'));
      await settle(tester);
      await tester.tap(key('details-publish'));
      await settle(tester);

      final stored = beats.beats.values.single;
      expect(stored.isPublished, isTrue);
      expect(stored.title, 'Night Drive');
      expect(find.text('Published'), findsWidgets);
      expect(
        find.text('Publish your beat'),
        findsNothing,
        reason: 'dialog closes on success',
      );
    },
  );

  testWidgets('a failed publish keeps the dialog open with the reason', (
    tester,
  ) async {
    final beats = FakeBeatRepository();
    await pumpApp(
      tester,
      location: '/studio',
      repo: FakeAuthRepository(userId: 'u1'),
      beats: beats,
      engine: FakeAudioEngine(),
    );
    await tester.tap(step('Kick', 1));
    await settle(tester);
    await tester.tap(key('header-title'));
    await tester.enterText(key('header-title'), 'Night Drive');
    await tester.tap(key('header-publish'));
    await settle(tester);
    beats.failNext = const AppFailure('Could not reach BeatGrid.');
    await tester.tap(key('details-publish'));
    await settle(tester);
    expect(find.text('Could not reach BeatGrid.'), findsOneWidget);
    expect(find.text('Publish your beat'), findsOneWidget);
    expect(beats.beats, isEmpty);
  });

  testWidgets('anonymous save: stash, sign in, and the beat comes back', (
    tester,
  ) async {
    final auth = FakeAuthRepository();
    final beats = FakeBeatRepository();
    await pumpApp(
      tester,
      location: '/studio',
      repo: auth,
      beats: beats,
      engine: FakeAudioEngine(),
    );
    await tester.tap(step('Kick', 1));
    await tester.tap(step('Clap', 9));
    await settle(tester);

    await tester.tap(key('header-save'));
    await settle(tester);
    expect(find.text('Sign in to save'), findsOneWidget);
    expect(beats.calls, isEmpty);
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await settle(tester);
    expect(
      find.text('Welcome back. Pick up where you left off.'),
      findsOneWidget,
    );

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Email'),
      'ada@example.com',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Password'),
      'password1',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await settle(tester);
    await settle(tester);

    expect(find.text('Restored your unsaved beat'), findsOneWidget);
    expect(find.text('Unsaved changes'), findsOneWidget);
    expect(
      beats.calls,
      isEmpty,
      reason: 'nothing is saved until the user saves',
    );
    await tester.tap(key('header-save'));
    await settle(tester);
    expect(beats.beats.values.single.pattern.isActive(TrackId.clap, 8), isTrue);
  });

  group('leaving with unsaved changes', () {
    testWidgets('asks first; cancel stays, leave goes', (tester) async {
      final guard = UnsavedChangesGuard();
      await pumpApp(
        tester,
        location: '/studio',
        repo: FakeAuthRepository(userId: 'u1'),
        engine: FakeAudioEngine(),
        guard: guard,
      );
      await tester.tap(step('Kick', 1));
      await settle(tester);
      expect(guard.hasUnsaved, isTrue);

      await tester.tap(find.text('Explore').first);
      await settle(tester);
      expect(find.text('Leave without saving?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await settle(tester);
      expect(
        find.byKey(const Key('header-title')),
        findsOneWidget,
        reason: 'still in the studio',
      );
      expect(guard.hasUnsaved, isTrue);

      await tester.tap(find.text('Explore').first);
      await settle(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Leave'));
      await settle(tester);
      expect(find.byKey(const Key('header-title')), findsNothing);
      expect(
        guard.hasUnsaved,
        isFalse,
        reason: 'guard is released with the page',
      );
    });

    testWidgets('no prompt when everything is saved or nothing was changed', (
      tester,
    ) async {
      final beats = FakeBeatRepository();
      final guard = UnsavedChangesGuard();
      await pumpApp(
        tester,
        location: '/studio',
        repo: FakeAuthRepository(userId: 'u1'),
        beats: beats,
        engine: FakeAudioEngine(),
        guard: guard,
      );
      await tester.tap(find.text('Explore').first);
      await settle(tester);
      expect(find.text('Leave without saving?'), findsNothing);

      await pumpApp(
        tester,
        location: '/studio',
        repo: FakeAuthRepository(userId: 'u1'),
        beats: beats,
        engine: FakeAudioEngine(),
        guard: guard,
      );
      await tester.tap(step('Kick', 1));
      await settle(tester);
      await tester.tap(key('header-save'));
      await settle(tester);
      expect(guard.hasUnsaved, isFalse);
      await tester.tap(find.text('Explore').first);
      await settle(tester);
      expect(find.text('Leave without saving?'), findsNothing);
    });
  });

  group('opening /studio/:id', () {
    testWidgets('loads your own beat into the studio', (tester) async {
      final beats = FakeBeatRepository();
      final saved = beats.seed(input: savedInput());
      final engine = FakeAudioEngine();
      await pumpApp(
        tester,
        location: '/studio/${saved.id}',
        repo: FakeAuthRepository(userId: 'u1'),
        beats: beats,
        engine: engine,
      );
      expect(
        tester.widget<TextField>(key('header-title')).controller!.text,
        'Night Drive',
      );
      expect(find.widgetWithText(TextField, '124'), findsOneWidget);
      expect(find.text('Draft saved'), findsWidgets);
      expect(find.text('Unsaved changes'), findsNothing);
    });

    testWidgets(
      'someone else\'s draft is not found; their public beat is not editable',
      (tester) async {
        final beats = FakeBeatRepository();
        final draft = beats.seed(creator: 'u2', input: savedInput());
        await pumpApp(
          tester,
          location: '/studio/${draft.id}',
          repo: FakeAuthRepository(userId: 'u1'),
          beats: beats,
          engine: FakeAudioEngine(),
        );
        expect(find.text('Beat not found'), findsOneWidget);

        final pub = beats.seed(
          creator: 'u2',
          status: BeatStatus.published,
          input: savedInput(title: 'Public'),
        );
        await pumpApp(
          tester,
          location: '/studio/${pub.id}',
          repo: FakeAuthRepository(userId: 'u1'),
          beats: beats,
          engine: FakeAudioEngine(),
        );
        expect(find.text('This beat is not yours'), findsOneWidget);
      },
    );

    testWidgets('anonymous visitors are sent to sign in', (tester) async {
      final beats = FakeBeatRepository();
      final saved = beats.seed(input: savedInput());
      await pumpApp(
        tester,
        location: '/studio/${saved.id}',
        beats: beats,
        engine: FakeAudioEngine(),
      );
      expect(
        find.text('Welcome back. Pick up where you left off.'),
        findsOneWidget,
      );
    });

    testWidgets('a load failure shows retry', (tester) async {
      final beats = FakeBeatRepository();
      final saved = beats.seed(input: savedInput());
      beats.failNext = const AppFailure('Check your connection.');
      await pumpApp(
        tester,
        location: '/studio/${saved.id}',
        repo: FakeAuthRepository(userId: 'u1'),
        beats: beats,
        engine: FakeAudioEngine(),
      );
      expect(find.text('Could not open this beat'), findsOneWidget);
      await tester.tap(find.text('Try again'));
      await settle(tester);
      expect(find.byKey(const Key('header-title')), findsOneWidget);
    });

    testWidgets('unpublish from the details dialog moves it back to drafts', (
      tester,
    ) async {
      final beats = FakeBeatRepository();
      final saved = beats.seed(
        status: BeatStatus.published,
        input: savedInput(status: BeatStatus.published),
      );
      await pumpApp(
        tester,
        location: '/studio/${saved.id}',
        repo: FakeAuthRepository(userId: 'u1'),
        beats: beats,
        engine: FakeAudioEngine(),
      );
      expect(find.text('Published'), findsWidgets);
      await tester.tap(key('header-publish')); // "Details" for published beats
      await settle(tester);
      await tester.tap(key('details-unpublish'));
      await settle(tester);
      expect(beats.beats[saved.id]!.status, BeatStatus.draft);
      expect(find.text('Draft saved'), findsWidgets);
    });

    testWidgets('delete asks first, then returns to My beats', (tester) async {
      final beats = FakeBeatRepository();
      final saved = beats.seed(input: savedInput());
      await pumpApp(
        tester,
        location: '/studio/${saved.id}',
        repo: FakeAuthRepository(userId: 'u1'),
        beats: beats,
        engine: FakeAudioEngine(),
      );
      await tester.tap(key('header-menu'));
      await settle(tester);
      await tester.tap(find.text('Delete beat'));
      await settle(tester);
      expect(find.text('Delete this beat?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await settle(tester);
      expect(beats.beats, isNotEmpty);

      await tester.tap(key('header-menu'));
      await settle(tester);
      await tester.tap(find.text('Delete beat'));
      await settle(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await settle(tester);
      await settle(tester);
      expect(beats.beats, isEmpty);
      expect(find.text('My beats'), findsWidgets);
    });
  });
}
