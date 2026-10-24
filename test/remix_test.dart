import 'dart:async';

import 'package:beatgrid/core/errors/app_failure.dart';
import 'package:beatgrid/features/beats/models/beat.dart';
import 'package:beatgrid/features/community/models/public_beat.dart';
import 'package:beatgrid/features/studio/models/beat_pattern.dart';
import 'package:beatgrid/features/studio/models/starter_patterns.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_shell_test.dart' show pumpApp, settle;
import 'fakes/fake_audio_engine.dart';
import 'fakes/fake_auth_repository.dart';
import 'fakes/fake_beat_repository.dart';
import 'fakes/fake_community_repository.dart';

Finder key(String k) => find.byKey(Key(k));

BeatPattern originalPattern() => starterById('techno-pulse')!.toPattern();

({FakeCommunityRepository community, FakeBeatRepository beats}) world() {
  final community = FakeCommunityRepository(userId: 'u1');
  community.add(
    id: '1',
    title: 'Original Groove',
    genre: 'techno',
    bpm: 132,
    creator: 'koji',
    allowRemix: true,
  );
  community.add(
    id: '2',
    title: 'Locked Beat',
    creator: 'koji',
    allowRemix: false,
  );
  community.add(
    id: '3',
    title: 'My Own Beat',
    creatorId: 'u1',
    creator: 'ada',
    allowRemix: true,
  );
  final beats = FakeBeatRepository();
  beats.remixSources['1'] = RemixSource(
    title: 'Original Groove',
    creator: 'koji',
    pattern: originalPattern(),
  );
  beats.remixSources['2'] = RemixSource(
    title: 'Locked Beat',
    creator: 'koji',
    pattern: originalPattern(),
    allowRemix: false,
  );
  return (community: community, beats: beats);
}

Future<void> openBeat(
  WidgetTester tester,
  String slug, {
  required FakeCommunityRepository community,
  required FakeBeatRepository beats,
  bool signedIn = true,
  FakeAudioEngine? engine,
}) => pumpApp(
  tester,
  location: '/beat/$slug',
  community: community,
  beats: beats,
  engine: engine ?? FakeAudioEngine(),
  repo: signedIn
      ? (FakeAuthRepository(userId: 'u1')..profile = fakeProfileWithId('u1'))
      : FakeAuthRepository(),
  size: const Size(1280, 1500),
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('models', () {
    Map<String, dynamic> row({Map<String, dynamic>? extra}) => {
      'id': 'b1',
      'slug': 'x-1',
      'title': 'X',
      'description': null,
      'genre': 'house',
      'bpm': 120,
      'cover_path': null,
      'allow_remix': false,
      'source_beat_id': null,
      'published_at': '2026-01-01T00:00:00Z',
      'creator_id': 'c1',
      'creator_username': 'ada',
      'creator_display_name': 'Ada',
      'creator_avatar_path': null,
      'like_count': 0,
      'play_count': 0,
      ...?extra,
    };

    test('a plain beat is not a remix', () {
      final b = PublicBeat.fromJson(row());
      expect(b.isRemix, isFalse);
      expect(b.sourceAvailable, isFalse);
    });

    test(
      'attribution survives when the original is unpublished or deleted',
      () {
        final live = PublicBeat.fromJson(
          row(
            extra: {
              'source_beat_id': 's1',
              'source_title': 'Orig',
              'source_creator_username': 'koji',
              'source_slug': 'orig-1',
            },
          ),
        );
        expect(live.isRemix && live.sourceAvailable, isTrue);
        final unpublished = PublicBeat.fromJson(
          row(
            extra: {
              'source_beat_id': 's1',
              'source_title': 'Orig',
              'source_creator_username': 'koji',
            },
          ),
        );
        expect(unpublished.isRemix, isTrue);
        expect(unpublished.sourceAvailable, isFalse);
        final deleted = PublicBeat.fromJson(
          row(
            extra: {
              'source_beat_id': null,
              'source_title': 'Orig',
              'source_creator_username': 'koji',
            },
          ),
        );
        expect(
          deleted.isRemix,
          isTrue,
          reason: 'the snapshot is enough to know it was a remix',
        );
        expect(deleted.sourceAvailable, isFalse);
      },
    );

    test('copyWith keeps attribution', () {
      final b = PublicBeat.fromJson(
        row(extra: {'source_title': 'Orig', 'source_slug': 'o'}),
      );
      expect(b.copyWith(likeCount: 5).sourceTitle, 'Orig');
      expect(b.copyWith(likeCount: 5).sourceSlug, 'o');
    });

    test('Beat and BeatSummary expose the snapshot', () {
      final beat = Beat.fromJson({
        'id': 'b1',
        'creator_id': 'u1',
        'title': 'T (remix)',
        'slug': 's',
        'description': null,
        'genre': 'house',
        'bpm': 120,
        'pattern_data': originalPattern().toJson(),
        'cover_path': null,
        'status': 'draft',
        'allow_remix': false,
        'source_beat_id': null,
        'source_title': 'T',
        'source_creator_username': 'koji',
        'published_at': null,
        'created_at': '2026-01-01T00:00:00Z',
        'updated_at': '2026-01-01T00:00:00Z',
      });
      expect(beat.isRemix, isTrue);
      expect(beat.sourceCreatorUsername, 'koji');
      final s = BeatSummary.fromJson({
        'id': 'b1',
        'title': 'T (remix)',
        'slug': 's',
        'genre': 'house',
        'bpm': 120,
        'status': 'draft',
        'allow_remix': false,
        'source_title': 'T',
        'updated_at': '2026-01-01T00:00:00Z',
      });
      expect(s.isRemix, isTrue);
      expect(BeatSummary.columns, contains('source_title'));
    });
  });

  group('Remix button', () {
    testWidgets('appears only on remixable beats that are not yours', (
      tester,
    ) async {
      final w = world();
      await openBeat(tester, 'beat-1', community: w.community, beats: w.beats);
      expect(key('detail-remix'), findsOneWidget);
      expect(find.text('Remixable'), findsOneWidget);

      await openBeat(tester, 'beat-2', community: w.community, beats: w.beats);
      expect(
        key('detail-remix'),
        findsNothing,
        reason: 'creator has not allowed remixes',
      );

      await openBeat(tester, 'beat-3', community: w.community, beats: w.beats);
      expect(
        key('detail-remix'),
        findsNothing,
        reason: 'your own beat offers Edit instead',
      );
      expect(key('detail-edit'), findsOneWidget);
    });

    testWidgets(
      'signed-out visitors are asked to sign in and nothing is created',
      (tester) async {
        final w = world();
        await openBeat(
          tester,
          'beat-1',
          community: w.community,
          beats: w.beats,
          signedIn: false,
        );
        await tester.tap(key('detail-remix'));
        await settle(tester);
        expect(find.text('Sign in to continue'), findsOneWidget);
        expect(find.textContaining('remix beats'), findsOneWidget);
        expect(w.beats.calls.where((c) => c.startsWith('remix')), isEmpty);
      },
    );

    testWidgets(
      'creates a private copy and opens it in the studio with its attribution',
      (tester) async {
        final w = world();
        await openBeat(
          tester,
          'beat-1',
          community: w.community,
          beats: w.beats,
        );
        await tester.tap(key('detail-remix'));
        await settle(tester);
        await settle(tester);

        expect(w.beats.calls.where((c) => c == 'remix:1').length, 1);
        final created = w.beats.beats.values.single;
        expect(created.creatorId, 'u1');
        expect(
          created.status,
          BeatStatus.draft,
          reason: 'stays private until published',
        );
        expect(created.sourceBeatId, '1');
        expect(created.allowRemix, isFalse);

        // The studio shows the copy, with the remix title, tempo and credit.
        expect(
          tester.widget<TextField>(key('header-title')).controller!.text,
          'Original Groove (remix)',
        );
        expect(find.widgetWithText(TextField, '132'), findsOneWidget);
        expect(
          find.text('Remix of "Original Groove" by @koji'),
          findsOneWidget,
        );
        expect(find.text('Draft saved'), findsWidgets);
        expect(find.text('Unsaved changes'), findsNothing);
      },
    );

    testWidgets('a refused remix explains why and can be retried', (
      tester,
    ) async {
      final w = world();
      await openBeat(tester, 'beat-1', community: w.community, beats: w.beats);
      w.beats.remixSources['1'] = RemixSource(
        title: 'Original Groove',
        creator: 'koji',
        pattern: originalPattern(),
        allowRemix: false,
      );
      await tester.tap(key('detail-remix'));
      await settle(tester);
      expect(
        find.text('The creator has not allowed remixes of this beat.'),
        findsOneWidget,
      );
      expect(w.beats.beats, isEmpty);
      expect(
        key('detail-remix'),
        findsOneWidget,
        reason: 'still on the beat page',
      );

      w.beats.remixSources['1'] = RemixSource(
        title: 'Original Groove',
        creator: 'koji',
        pattern: originalPattern(),
        published: false,
      );
      await tester.tap(key('detail-remix'));
      await settle(tester);
      expect(
        find.text('The original beat is no longer available to remix.'),
        findsOneWidget,
      );

      w.beats.remixSources['1'] = RemixSource(
        title: 'Original Groove',
        creator: 'koji',
        pattern: originalPattern(),
      );
      await tester.tap(key('detail-remix'));
      await settle(tester);
      await settle(tester);
      expect(w.beats.beats.length, 1);
    });

    testWidgets('double taps create only one remix', (tester) async {
      final w = world();
      await openBeat(tester, 'beat-1', community: w.community, beats: w.beats);
      final gate = Completer<void>();
      w.beats.gate = gate;
      await tester.tap(key('detail-remix'));
      await tester.pump();
      await tester.tap(key('detail-remix'), warnIfMissed: false);
      await tester.pump();
      gate.complete();
      await settle(tester);
      await settle(tester);
      expect(w.beats.calls.where((c) => c == 'remix:1').length, 1);
      expect(w.beats.beats.length, 1);
    });

    testWidgets('network failure leaves the page usable', (tester) async {
      final w = world();
      await openBeat(tester, 'beat-1', community: w.community, beats: w.beats);
      w.beats.failNext = const AppFailure(
        'Could not reach BeatGrid.',
        code: 'network',
      );
      await tester.tap(key('detail-remix'));
      await settle(tester);
      expect(find.text('Could not reach BeatGrid.'), findsOneWidget);
      expect(w.beats.beats, isEmpty);
    });
  });

  group('after remixing', () {
    Future<FakeBeatRepository> remixed(WidgetTester tester) async {
      final w = world();
      await openBeat(tester, 'beat-1', community: w.community, beats: w.beats);
      await tester.tap(key('detail-remix'));
      await settle(tester);
      await settle(tester);
      return w.beats;
    }

    testWidgets(
      'editing and saving updates the remix, never the original, and keeps the credit',
      (tester) async {
        final beats = await remixed(tester);
        final id = beats.beats.keys.single;
        await tester.tap(find.bySemanticsLabel('Clap step 3'));
        await settle(tester);
        expect(find.text('Unsaved changes'), findsOneWidget);
        await tester.tap(key('header-save'));
        await settle(tester);
        expect(
          beats.calls.where((c) => c == 'create'),
          isEmpty,
          reason: 'updates the existing copy',
        );
        expect(beats.beats[id]!.pattern.isActive(TrackId.clap, 2), isTrue);
        expect(beats.beats[id]!.sourceTitle, 'Original Groove');
        expect(
          beats.remixSources['1']!.pattern.isActive(TrackId.clap, 2),
          isFalse,
          reason: 'the original is untouched',
        );
        expect(
          find.text('Remix of "Original Groove" by @koji'),
          findsOneWidget,
        );
      },
    );

    testWidgets('the remix only becomes public when published', (tester) async {
      final beats = await remixed(tester);
      final id = beats.beats.keys.single;
      await tester.tap(key('header-publish'));
      await settle(tester);
      expect(beats.beats[id]!.isPublished, isFalse);
      await tester.tap(key('details-publish'));
      await settle(tester);
      expect(beats.beats[id]!.isPublished, isTrue);
      expect(beats.beats[id]!.sourceBeatId, '1');
    });

    testWidgets('My beats marks remixes with their original', (tester) async {
      final beats = await remixed(tester);
      final id = beats.beats.keys.single;
      // Give the fake's listing the snapshot, as the database view does.
      await pumpApp(
        tester,
        location: '/my-beats',
        beats: beats,
        repo: FakeAuthRepository(userId: 'u1'),
        engine: FakeAudioEngine(),
      );
      expect(find.byKey(Key('beat-row-$id')), findsOneWidget);
      expect(find.byKey(Key('remix-tag-$id')), findsOneWidget);
      expect(find.text('Remix of Original Groove'), findsOneWidget);
    });
  });

  group('attribution on a published remix', () {
    testWidgets('links to the original while it is public', (tester) async {
      final community = FakeCommunityRepository();
      community.add(id: '1', title: 'Original Groove', creator: 'koji');
      community.add(
        id: '9',
        title: 'Night Version',
        creator: 'ada',
        sourceTitle: 'Original Groove',
        sourceCreator: 'koji',
        sourceSlug: 'beat-1',
      );
      await pumpApp(
        tester,
        location: '/beat/beat-9',
        community: community,
        size: const Size(1280, 1500),
      );
      expect(find.text('Remix of "Original Groove" by @koji'), findsOneWidget);
      await tester.tap(key('detail-attribution'));
      await settle(tester);
      expect(find.text('Original Groove'), findsWidgets);
      expect(
        key('detail-attribution'),
        findsNothing,
        reason: 'the original is not itself a remix',
      );
    });

    testWidgets('keeps the credit and says so when the original is gone', (
      tester,
    ) async {
      final community = FakeCommunityRepository();
      community.add(
        id: '9',
        title: 'Night Version',
        creator: 'ada',
        sourceTitle: 'Original Groove',
        sourceCreator: 'koji',
      );
      await pumpApp(
        tester,
        location: '/beat/beat-9',
        community: community,
        size: const Size(1280, 1500),
      );
      expect(
        find.text(
          'Remix of "Original Groove" by @koji (original no longer available)',
        ),
        findsOneWidget,
      );
      expect(find.text('Night Version'), findsWidgets);
      expect(
        find
            .byType(InkWell)
            .evaluate()
            .where((e) => e.widget.key == const Key('detail-attribution')),
        isEmpty,
        reason: 'nothing to link to',
      );
    });

    testWidgets('a plain beat shows no attribution', (tester) async {
      final community = FakeCommunityRepository();
      community.add(id: '1', title: 'Plain');
      await pumpApp(
        tester,
        location: '/beat/beat-1',
        community: community,
        size: const Size(1280, 1500),
      );
      expect(key('detail-attribution'), findsNothing);
    });
  });

  testWidgets('a brand new beat shows no remix credit in the studio', (
    tester,
  ) async {
    await pumpApp(
      tester,
      location: '/studio',
      repo: FakeAuthRepository(userId: 'u1'),
      engine: FakeAudioEngine(),
    );
    expect(key('header-attribution'), findsNothing);
  });
}
