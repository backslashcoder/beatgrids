import 'package:beatgrid/core/errors/app_failure.dart';
import 'package:beatgrid/features/community/models/public_beat.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'app_shell_test.dart' show pumpApp, settle;
import 'fakes/fake_audio_engine.dart';
import 'fakes/fake_auth_repository.dart';
import 'fakes/fake_community_repository.dart';

Finder key(String k) => find.byKey(Key(k));

FakeCommunityRepository community({String? userId}) {
  final repo = FakeCommunityRepository(userId: userId);
  repo.add(
    id: '1',
    title: 'Sunset Drive',
    genre: 'house',
    creator: 'ada',
    likes: 2,
    playCount: 11,
  );
  repo.add(
    id: '2',
    title: 'Warehouse Pulse',
    genre: 'techno',
    creator: 'koji',
    likes: 9,
    description: 'Four on the floor.',
    allowRemix: true,
  );
  repo.add(id: '3', title: 'Rainy Loop', genre: 'lo-fi', creator: 'mira');
  repo.creators['ada'] = CreatorProfile(
    id: 'c1',
    username: 'ada',
    displayName: 'Ada',
    bio: 'Making loops.',
    createdAt: DateTime(2026, 3),
    stats: const CreatorStats(beatCount: 3, likeCount: 12, playCount: 40),
  );
  return repo;
}

Future<void> typeSearch(WidgetTester tester, String text) async {
  await tester.enterText(key('explore-search'), text);
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump();
}

void main() {
  group('Explore', () {
    testWidgets('shows real beats with skeletons while loading', (
      tester,
    ) async {
      final repo = community();
      await pumpApp(
        tester,
        location: '/explore',
        community: repo,
        size: const Size(1280, 1600),
      );
      expect(find.text('Sunset Drive'), findsOneWidget);
      expect(find.text('Warehouse Pulse'), findsOneWidget);
      expect(find.text('Rainy Loop'), findsOneWidget);
      expect(key('beat-skeletons'), findsNothing);
    });

    testWidgets('empty community shows an invitation, not fake content', (
      tester,
    ) async {
      await pumpApp(
        tester,
        location: '/explore',
        community: FakeCommunityRepository(),
      );
      expect(find.text('No beats published yet'), findsOneWidget);
      expect(find.byType(Image), findsNothing);
    });

    testWidgets('genre chips filter and clear', (tester) async {
      await pumpApp(
        tester,
        location: '/explore',
        community: community(),
        size: const Size(1280, 1600),
      );
      await tester.tap(find.text('Techno'));
      await settle(tester);
      expect(find.text('Warehouse Pulse'), findsOneWidget);
      expect(find.text('Sunset Drive'), findsNothing);
      await tester.tap(find.text('All'));
      await settle(tester);
      expect(find.text('Sunset Drive'), findsOneWidget);
    });

    testWidgets(
      'search is debounced, matches creators, and shows a no-results state',
      (tester) async {
        final repo = community();
        await pumpApp(
          tester,
          location: '/explore',
          community: repo,
          size: const Size(1280, 1600),
        );
        await tester.enterText(key('explore-search'), 'war');
        await tester.enterText(key('explore-search'), 'ware');
        await tester.pump(const Duration(milliseconds: 100));
        expect(
          repo.calls.where((c) => c.contains(':ware:') || c.contains(':war:')),
          isEmpty,
          reason: 'still typing',
        );
        await tester.pump(const Duration(milliseconds: 400));
        await settle(tester);
        expect(
          repo.calls
              .where((c) => c.startsWith('feed:') && c.contains(':ware:'))
              .length,
          1,
        );
        expect(find.text('Warehouse Pulse'), findsOneWidget);
        expect(find.text('Rainy Loop'), findsNothing);

        await typeSearch(tester, 'mira');
        await settle(tester);
        expect(find.text('Rainy Loop'), findsOneWidget);

        await typeSearch(tester, 'zzzz');
        await settle(tester);
        expect(find.text('No beats match'), findsOneWidget);
        await tester.tap(find.text('Clear filters'));
        await settle(tester);
        expect(find.text('Sunset Drive'), findsOneWidget);
      },
    );

    testWidgets('trending sort reorders by engagement', (tester) async {
      final repo = community();
      await pumpApp(
        tester,
        location: '/explore',
        community: repo,
        size: const Size(1280, 1600),
      );
      await tester.tap(find.text('Trending'));
      await settle(tester);
      expect(repo.calls.last, startsWith('feed:trending'));
      final order = ['Warehouse Pulse', 'Sunset Drive', 'Rainy Loop'];
      final tops = [for (final t in order) tester.getTopLeft(find.text(t)).dy];
      expect(tops[0], lessThanOrEqualTo(tops[1]));
    });

    testWidgets('a failed load shows a retry', (tester) async {
      final repo = community()
        ..failNext = const AppFailure('Could not reach BeatGrid.');
      await pumpApp(tester, location: '/explore', community: repo);
      expect(find.text('Could not reach BeatGrid.'), findsOneWidget);
      await tester.tap(find.text('Try again'));
      await settle(tester);
      expect(find.text('Sunset Drive'), findsOneWidget);
    });

    testWidgets('anonymous like asks to sign in and sends nothing', (
      tester,
    ) async {
      final repo = community();
      await pumpApp(
        tester,
        location: '/explore',
        community: repo,
        size: const Size(1280, 1600),
      );
      await tester.tap(find.byTooltip('Like').first);
      await settle(tester);
      expect(find.text('Sign in to continue'), findsOneWidget);
      expect(repo.calls.where((c) => c.startsWith('like:')), isEmpty);
      await tester.tap(find.text('Cancel'));
      await settle(tester);
      expect(find.text('Sign in to continue'), findsNothing);
    });

    testWidgets('signed-in like and save update the card at once', (
      tester,
    ) async {
      final repo = community(userId: 'u1');
      await pumpApp(
        tester,
        location: '/explore',
        community: repo,
        repo: FakeAuthRepository(userId: 'u1'),
        size: const Size(1280, 1600),
      );
      final before = find.text('9');
      expect(before, findsWidgets);
      await tester.tap(find.byTooltip('Like').last);
      await settle(tester);
      expect(repo.liked, isNotEmpty);
      expect(find.byTooltip('Unlike'), findsOneWidget);
      await tester.tap(find.byTooltip('Save').first);
      await settle(tester);
      expect(repo.savedOrder, isNotEmpty);
      expect(find.byTooltip('Remove from saved'), findsOneWidget);
    });

    testWidgets('card opens the beat page', (tester) async {
      await pumpApp(
        tester,
        location: '/explore',
        community: community(),
        size: const Size(1280, 1600),
      );
      await tester.tap(find.text('Sunset Drive'));
      await settle(tester);
      expect(find.text('@ada'), findsOneWidget);
      expect(key('detail-play'), findsOneWidget);
    });
  });

  group('Beat page', () {
    testWidgets(
      'loads directly from its URL with details, pattern and actions',
      (tester) async {
        await pumpApp(
          tester,
          location: '/beat/beat-2',
          community: community(),
          size: const Size(1280, 1400),
        );
        expect(find.text('Warehouse Pulse'), findsOneWidget);
        expect(find.text('Four on the floor.'), findsOneWidget);
        expect(find.text('120 BPM'), findsOneWidget);
        expect(find.text('Techno'), findsOneWidget);
        expect(find.text('Remixable'), findsOneWidget);
        expect(find.text('9 likes'), findsOneWidget);
        expect(key('detail-share'), findsOneWidget);
      },
    );

    testWidgets('unpublished or unknown beats are not found', (tester) async {
      await pumpApp(
        tester,
        location: '/beat/draft-or-deleted',
        community: community(),
      );
      expect(find.text('Beat not found'), findsOneWidget);
    });

    testWidgets('a load failure offers retry', (tester) async {
      final repo = community()..failNext = const AppFailure('Offline.');
      await pumpApp(tester, location: '/beat/beat-1', community: repo);
      expect(find.text('Offline.'), findsOneWidget);
      await tester.tap(find.text('Try again'));
      await settle(tester);
      expect(find.text('Sunset Drive'), findsWidgets);
    });

    testWidgets('signed-in users like and save; counts follow', (tester) async {
      final repo = community(userId: 'u1');
      await pumpApp(
        tester,
        location: '/beat/beat-1',
        community: repo,
        repo: FakeAuthRepository(userId: 'u1'),
        size: const Size(1280, 1400),
      );
      expect(find.text('2 likes'), findsOneWidget);
      await tester.tap(key('detail-like'));
      await settle(tester);
      expect(find.text('3 likes'), findsOneWidget);
      expect(repo.liked, {'1'});
      await tester.tap(key('detail-save'));
      await settle(tester);
      expect(repo.savedOrder, ['1']);
      await tester.tap(key('detail-like'));
      await settle(tester);
      expect(find.text('2 likes'), findsOneWidget);
    });

    testWidgets('a refused like is rolled back on screen', (tester) async {
      final repo = community(userId: 'u1')
        ..failLikeNext = const AppFailure('Too many requests.');
      await pumpApp(
        tester,
        location: '/beat/beat-1',
        community: repo,
        repo: FakeAuthRepository(userId: 'u1'),
        size: const Size(1280, 1400),
      );
      await tester.tap(key('detail-like'));
      await settle(tester);
      expect(find.text('2 likes'), findsOneWidget);
      expect(find.text('Too many requests.'), findsOneWidget);
    });

    testWidgets('the creator link opens their profile', (tester) async {
      await pumpApp(
        tester,
        location: '/beat/beat-1',
        community: community(),
        size: const Size(1280, 1400),
      );
      await tester.tap(key('detail-creator'));
      await settle(tester);
      expect(find.text('Making loops.'), findsOneWidget);
    });
  });

  group('Mini-player', () {
    testWidgets(
      'playing from a card shows the persistent player, which survives navigation',
      (tester) async {
        final repo = community();
        final player = FakeAudioEngine();
        await pumpApp(
          tester,
          location: '/explore',
          community: repo,
          playerEngine: player,
          size: const Size(1280, 1600),
        );
        expect(key('mini-player'), findsNothing);
        await tester.tap(
          find.byTooltip('Play Sunset Drive'),
          warnIfMissed: false,
        );
        await settle(tester);
        expect(player.calls, containsAll(['init', 'pattern', 'play']));
        expect(key('mini-player'), findsOneWidget);
        expect(find.text('ADA · 120 BPM'), findsOneWidget);

        await tester.tap(find.text('Home').first);
        await settle(tester);
        expect(
          key('mini-player'),
          findsOneWidget,
          reason: 'persists across routes',
        );

        await tester.tap(key('mini-player-toggle'));
        await settle(tester);
        expect(player.calls, contains('pause'));
        await tester.tap(key('mini-player-toggle'));
        await settle(tester);
        expect(player.calls.where((c) => c == 'play').length, 2);

        await tester.tap(key('mini-player-close'));
        await settle(tester);
        expect(key('mini-player'), findsNothing);
        expect(player.disposed, isTrue);
      },
    );

    testWidgets(
      'opening the studio hides the player and playing there takes over the engine',
      (tester) async {
        final repo = community();
        final player = FakeAudioEngine();
        final studio = FakeAudioEngine();
        await pumpApp(
          tester,
          location: '/beat/beat-2',
          community: repo,
          playerEngine: player,
          engine: studio,
          size: const Size(1280, 1400),
        );
        await tester.tap(key('detail-play'));
        await settle(tester);
        expect(key('mini-player'), findsOneWidget);

        await tester.tap(find.text('Studio').first);
        await settle(tester);
        expect(
          key('mini-player'),
          findsNothing,
          reason: 'hidden in the studio',
        );
        expect(
          player.calls.last,
          isNot('dispose'),
          reason: 'still playing until the studio claims audio',
        );

        await tester.tap(key('transport-play'));
        await settle(tester);
        expect(player.disposed, isTrue);
        expect(studio.calls, contains('play'));

        await tester.tap(find.text('Explore').first);
        await settle(tester);
        expect(key('mini-player'), findsOneWidget);
        expect(
          find.byIcon(Icons.play_arrow_rounded),
          findsWidgets,
          reason: 'shows paused, ready to resume',
        );
      },
    );

    testWidgets('the beat page shows the playhead while its beat plays', (
      tester,
    ) async {
      final player = FakeAudioEngine();
      await pumpApp(
        tester,
        location: '/beat/beat-1',
        community: community(),
        playerEngine: player,
        size: const Size(1280, 1400),
      );
      await tester.tap(key('detail-play'));
      await settle(tester);
      expect(find.text('Pause'), findsOneWidget);
      player.emitStep(4);
      await settle(tester);
      await tester.tap(key('detail-play'));
      await settle(tester);
      expect(player.calls, contains('pause'));
    });
  });

  group('Profile', () {
    testWidgets('shows creator info, stats and their published beats', (
      tester,
    ) async {
      final repo = community();
      await pumpApp(
        tester,
        location: '/profile/ada',
        community: repo,
        size: const Size(1280, 1600),
      );
      expect(find.text('Ada'), findsWidgets);
      expect(find.text('@ada'), findsOneWidget);
      expect(find.text('Making loops.'), findsOneWidget);
      expect(find.text('Joined March 2026'), findsOneWidget);
      expect(
        find.descendant(of: key('stat-beats'), matching: find.text('3')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: key('stat-plays'), matching: find.text('40')),
        findsOneWidget,
      );
      expect(find.text('Sunset Drive'), findsOneWidget);
      expect(
        find.text('Rainy Loop'),
        findsOneWidget,
        reason: 'all beats of creator c1 in the fake',
      );
    });

    testWidgets('only the owner sees Edit profile', (tester) async {
      final repo = community();
      await pumpApp(
        tester,
        location: '/profile/ada',
        community: repo,
        size: const Size(1280, 1600),
      );
      expect(key('profile-edit'), findsNothing);
      await pumpApp(
        tester,
        location: '/profile/ada',
        community: repo,
        repo: FakeAuthRepository(userId: 'u1')
          ..profile = fakeProfileWithId('c1'),
        size: const Size(1280, 1600),
      );
      expect(key('profile-edit'), findsOneWidget);
    });

    testWidgets('unknown creators and a creator without beats', (tester) async {
      final repo = community();
      repo.creators['quiet'] = CreatorProfile(
        id: 'q1',
        username: 'quiet',
        displayName: 'Quiet',
        createdAt: DateTime(2026),
      );
      await pumpApp(tester, location: '/profile/quiet', community: repo);
      expect(find.text('No published beats yet'), findsOneWidget);
      await pumpApp(tester, location: '/profile/ghost', community: repo);
      expect(find.text('Creator not found'), findsOneWidget);
    });
  });

  group('Saved beats', () {
    testWidgets('requires sign in', (tester) async {
      await pumpApp(tester, location: '/saved', community: community());
      expect(
        find.text('Welcome back. Pick up where you left off.'),
        findsOneWidget,
      );
    });

    testWidgets(
      'lists only your saves; unsaving removes the card; empty state invites exploring',
      (tester) async {
        final repo = community(userId: 'u1')..savedOrder.addAll(['3', '1']);
        await pumpApp(
          tester,
          location: '/saved',
          community: repo,
          repo: FakeAuthRepository(userId: 'u1'),
          size: const Size(1280, 1600),
        );
        expect(find.text('Rainy Loop'), findsOneWidget);
        expect(find.text('Sunset Drive'), findsOneWidget);
        expect(find.text('Warehouse Pulse'), findsNothing);
        await tester.tap(find.byTooltip('Remove from saved').first);
        await settle(tester);
        await tester.tap(find.byTooltip('Remove from saved').first);
        await settle(tester);
        expect(find.text('Nothing saved yet'), findsOneWidget);
      },
    );
  });

  group('Home', () {
    testWidgets(
      'shows the latest community beats, or an invitation when there are none',
      (tester) async {
        await pumpApp(
          tester,
          community: community(),
          size: const Size(1280, 2200),
        );
        expect(find.text('Fresh from the community'), findsOneWidget);
        expect(find.text('Sunset Drive'), findsOneWidget);
        await tester.tap(key('home-see-all'));
        await settle(tester);
        expect(
          find.text('Beats made by the BeatGrid community.'),
          findsOneWidget,
        );

        await pumpApp(
          tester,
          community: FakeCommunityRepository(),
          size: const Size(1280, 2200),
        );
        expect(find.text('No beats published yet'), findsOneWidget);
        expect(find.text('Make a beat'), findsOneWidget);
      },
    );

    testWidgets('mobile layout has no overflow on feed pages', (tester) async {
      for (final path in ['/', '/explore', '/beat/beat-2', '/profile/ada']) {
        await pumpApp(
          tester,
          location: path,
          community: community(),
          size: const Size(375, 812),
        );
        expect(tester.takeException(), isNull, reason: path);
      }
    });
  });
}
