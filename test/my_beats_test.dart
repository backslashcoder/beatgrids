import 'dart:async';

import 'package:beatgrid/core/errors/app_failure.dart';
import 'package:beatgrid/features/beats/models/beat.dart';
import 'package:beatgrid/features/beats/presentation/cubit/my_beats_cubit.dart';
import 'package:beatgrid/features/studio/models/starter_patterns.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'app_shell_test.dart' show pumpApp, settle;
import 'fakes/fake_audio_engine.dart';
import 'fakes/fake_auth_repository.dart';
import 'fakes/fake_beat_repository.dart';

BeatInput inputFor(String title, {BeatStatus status = BeatStatus.draft}) =>
    BeatInput(
      title: title,
      genre: 'house',
      bpm: 120,
      pattern: starterById('house-groove')!.toPattern(),
      status: status,
    );

Future<void> flush() => Future<void>.delayed(Duration.zero);

void main() {
  group('MyBeatsCubit', () {
    test('loads only the signed-in user\'s beats, newest first', () async {
      final repo = FakeBeatRepository();
      repo.seed(title: 'Mine A', input: inputFor('Mine A'));
      repo.seed(title: 'Mine B', input: inputFor('Mine B'));
      repo.seed(creator: 'u2', input: inputFor('Theirs'));
      final cubit = MyBeatsCubit(repo);
      await cubit.load();
      expect(cubit.state.status, MyBeatsStatus.ready);
      expect(cubit.state.beats.map((b) => b.title), ['Mine B', 'Mine A']);
      expect(cubit.state.hasMore, isFalse);
    });

    test('paginates', () async {
      final repo = FakeBeatRepository();
      for (var i = 0; i < 25; i++) {
        repo.seed(title: 'Beat $i', input: inputFor('Beat $i'));
      }
      final cubit = MyBeatsCubit(repo);
      await cubit.load();
      expect(cubit.state.beats.length, 20);
      expect(cubit.state.hasMore, isTrue);
      await cubit.loadMore();
      expect(cubit.state.beats.length, 25);
      expect(cubit.state.hasMore, isFalse);
      expect(cubit.state.beats.map((b) => b.id).toSet().length, 25);
    });

    test('load failure is reported and can be retried', () async {
      final repo = FakeBeatRepository()
        ..failNext = const AppFailure('Could not reach BeatGrid.');
      final cubit = MyBeatsCubit(repo);
      await cubit.load();
      expect(cubit.state.status, MyBeatsStatus.failed);
      expect(cubit.state.error, 'Could not reach BeatGrid.');
      await cubit.load();
      expect(cubit.state.status, MyBeatsStatus.ready);
    });

    test('unpublish updates the row; double taps do not send twice', () async {
      final repo = FakeBeatRepository();
      repo.seed(
        status: BeatStatus.published,
        input: inputFor('Live', status: BeatStatus.published),
      );
      final cubit = MyBeatsCubit(repo);
      await cubit.load();
      final gate = Completer<void>();
      repo.gate = gate;
      final first = cubit.setPublished(cubit.state.beats.single, false);
      await flush();
      expect(cubit.state.busyIds, isNotEmpty);
      await cubit.setPublished(cubit.state.beats.single, false);
      gate.complete();
      await first;
      expect(repo.calls.where((c) => c.startsWith('setStatus')).length, 1);
      expect(cubit.state.beats.single.status, BeatStatus.draft);
      expect(cubit.state.busyIds, isEmpty);
      expect(cubit.state.message, contains('moved to drafts'));
    });

    test('delete removes the row and its cover', () async {
      final repo = FakeBeatRepository();
      repo.seed(input: inputFor('Gone'), coverPath: 'u1/c.png');
      final cubit = MyBeatsCubit(repo);
      await cubit.load();
      await cubit.delete(cubit.state.beats.single);
      expect(cubit.state.beats, isEmpty);
      expect(repo.removedCovers, ['u1/c.png']);
    });

    test('a failed action keeps the row and reports why', () async {
      final repo = FakeBeatRepository();
      repo.seed(input: inputFor('Stays'));
      final cubit = MyBeatsCubit(repo);
      await cubit.load();
      repo.failNext = const AppFailure('That beat could not be found.');
      await cubit.delete(cubit.state.beats.single);
      expect(cubit.state.beats.length, 1);
      expect(cubit.state.message, 'That beat could not be found.');
      expect(cubit.state.busyIds, isEmpty);
    });
  });

  group('My beats page', () {
    testWidgets('anonymous visitors are sent to sign in', (tester) async {
      await pumpApp(tester, location: '/my-beats');
      expect(
        find.text('Welcome back. Pick up where you left off.'),
        findsOneWidget,
      );
    });

    testWidgets('empty state invites you to the studio', (tester) async {
      await pumpApp(
        tester,
        location: '/my-beats',
        repo: FakeAuthRepository(userId: 'u1'),
        engine: FakeAudioEngine(),
      );
      expect(find.text('No beats yet'), findsOneWidget);
      await tester.tap(find.text('Open the studio'));
      await settle(tester);
      expect(find.byKey(const Key('header-title')), findsOneWidget);
    });

    testWidgets('lists drafts and published beats; edit opens the studio', (
      tester,
    ) async {
      final beats = FakeBeatRepository();
      final draft = beats.seed(input: inputFor('Quiet Draft'));
      beats.seed(
        status: BeatStatus.published,
        input: inputFor('Loud Hit', status: BeatStatus.published),
      );
      await pumpApp(
        tester,
        location: '/my-beats',
        repo: FakeAuthRepository(userId: 'u1'),
        beats: beats,
        engine: FakeAudioEngine(),
      );
      expect(find.text('Quiet Draft'), findsOneWidget);
      expect(find.text('Loud Hit'), findsOneWidget);
      expect(find.text('Draft'), findsOneWidget);
      expect(find.text('Published'), findsOneWidget);

      await tester.tap(find.byKey(Key('edit-${draft.id}')));
      await settle(tester);
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('header-title')))
            .controller!
            .text,
        'Quiet Draft',
      );
    });

    testWidgets('unpublish and delete (with confirmation) from the row menu', (
      tester,
    ) async {
      final beats = FakeBeatRepository();
      final live = beats.seed(
        status: BeatStatus.published,
        input: inputFor('Loud Hit', status: BeatStatus.published),
      );
      await pumpApp(
        tester,
        location: '/my-beats',
        repo: FakeAuthRepository(userId: 'u1'),
        beats: beats,
        engine: FakeAudioEngine(),
      );

      await tester.tap(find.byKey(Key('menu-${live.id}')));
      await settle(tester);
      await tester.tap(find.text('Unpublish'));
      await settle(tester);
      expect(beats.beats[live.id]!.status, BeatStatus.draft);
      expect(find.text('Draft'), findsOneWidget);

      await tester.tap(find.byKey(Key('menu-${live.id}')));
      await settle(tester);
      await tester.tap(find.text('Delete'));
      await settle(tester);
      await tester.tap(find.text('Cancel'));
      await settle(tester);
      expect(beats.beats, isNotEmpty);

      await tester.tap(find.byKey(Key('menu-${live.id}')));
      await settle(tester);
      await tester.tap(find.text('Delete'));
      await settle(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await settle(tester);
      expect(beats.beats, isEmpty);
      expect(find.text('No beats yet'), findsOneWidget);
    });

    testWidgets(
      'a drafts "Review and publish" goes through the studio validation',
      (tester) async {
        final beats = FakeBeatRepository();
        final draft = beats.seed(input: inputFor('Quiet Draft'));
        await pumpApp(
          tester,
          location: '/my-beats',
          repo: FakeAuthRepository(userId: 'u1'),
          beats: beats,
          engine: FakeAudioEngine(),
        );
        await tester.tap(find.byKey(Key('menu-${draft.id}')));
        await settle(tester);
        await tester.tap(find.text('Review and publish'));
        await settle(tester);
        expect(find.byKey(const Key('header-publish')), findsOneWidget);
        expect(beats.calls.where((c) => c.startsWith('setStatus')), isEmpty);
      },
    );

    testWidgets('load failure offers retry', (tester) async {
      final beats = FakeBeatRepository()
        ..failNext = const AppFailure('Check your connection.');
      await pumpApp(
        tester,
        location: '/my-beats',
        repo: FakeAuthRepository(userId: 'u1'),
        beats: beats,
        engine: FakeAudioEngine(),
      );
      expect(find.text('Check your connection.'), findsOneWidget);
      await tester.tap(find.text('Try again'));
      await settle(tester);
      expect(find.text('No beats yet'), findsOneWidget);
    });
  });
}
