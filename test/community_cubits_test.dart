import 'dart:async';

import 'package:beatgrid/core/errors/app_failure.dart';
import 'package:beatgrid/core/services/audio_coordinator.dart';
import 'package:beatgrid/features/community/models/public_beat.dart';
import 'package:beatgrid/features/community/presentation/cubit/beat_detail_cubit.dart';
import 'package:beatgrid/features/community/presentation/cubit/beat_list_cubit.dart';
import 'package:beatgrid/features/community/presentation/cubit/creator_profile_cubit.dart';
import 'package:beatgrid/features/community/presentation/cubit/player_cubit.dart';
import 'package:beatgrid/features/studio/models/beat_pattern.dart';
import 'package:beatgrid/features/studio/presentation/cubit/studio_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes/fake_audio_engine.dart';
import 'fakes/fake_community_repository.dart';

Future<void> flush([int times = 3]) async {
  for (var i = 0; i < times; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

FakeCommunityRepository seeded({String? userId}) {
  final repo = FakeCommunityRepository(userId: userId);
  repo.add(
    id: '1',
    title: 'Sunset Drive',
    genre: 'house',
    creator: 'ada',
    likes: 2,
  );
  repo.add(
    id: '2',
    title: 'Warehouse',
    genre: 'techno',
    creator: 'koji',
    likes: 9,
    playCount: 30,
  );
  repo.add(
    id: '3',
    title: 'Rainy Loop',
    genre: 'lo-fi',
    creator: 'mira',
    likes: 1,
  );
  repo.add(id: '4', title: 'Techno Tuesday', genre: 'techno', creator: 'ada');
  return repo;
}

void main() {
  group('sanitizeSearch', () {
    test(
      'removes characters that could break the filter and bounds length',
      () {
        expect(sanitizeSearch('  hello,  (world)*% '), 'hello world');
        expect(sanitizeSearch('a\\b"c'), 'a b c');
        expect(sanitizeSearch(null), '');
        expect(sanitizeSearch('x' * 80).length, 50);
        expect(
          sanitizeSearch('lo_fi'),
          'lo_fi',
          reason: 'usernames may contain underscores',
        );
      },
    );
  });

  group('ExploreCubit', () {
    test('loads the latest beats first', () async {
      final cubit = ExploreCubit(seeded());
      await cubit.reload();
      expect(cubit.state.status, ListStatus.ready);
      expect(cubit.state.items.map((i) => i.beat.id), ['4', '3', '2', '1']);
      expect(cubit.state.hasMore, isFalse);
    });

    test('trending ranks by engagement', () async {
      final cubit = ExploreCubit(seeded());
      cubit.setSort(FeedSort.trending);
      await flush();
      expect(cubit.state.items.first.beat.id, '2');
    });

    test('genre filter, search, and clearing filters', () async {
      final repo = seeded();
      final cubit = ExploreCubit(repo);
      cubit.setGenre('techno');
      await flush();
      expect(cubit.state.items.map((i) => i.beat.id), ['4', '2']);
      cubit.setQuery('ada');
      await flush();
      expect(cubit.state.items.map((i) => i.beat.id), [
        '4',
      ], reason: 'search matches creator username');
      cubit.setQuery('  Warehouse  ');
      await flush();
      expect(cubit.state.items.map((i) => i.beat.id), ['2']);
      expect(cubit.hasFilters, isTrue);
      cubit.clearFilters();
      await flush();
      expect(cubit.state.items.length, 4);
      expect(cubit.hasFilters, isFalse);
    });

    test('unsafe characters never reach the repository', () async {
      final repo = seeded();
      final cubit = ExploreCubit(repo);
      cubit.setQuery('a,b)(c*%');
      await flush();
      expect(repo.calls.last, contains(':a b c:'));
    });

    test('a slow, older response never overwrites newer results', () async {
      final repo = seeded();
      final slow = Completer<void>();
      repo.feedHook = (q) => q == 'tech' ? slow.future : Future.value();
      final cubit = ExploreCubit(repo);
      cubit.setQuery('tech'); // slow
      await flush();
      cubit.setQuery('warehouse'); // fast, issued later
      await flush();
      expect(cubit.state.items.map((i) => i.beat.title), ['Warehouse']);
      slow.complete();
      await flush();
      expect(cubit.state.items.map((i) => i.beat.title), [
        'Warehouse',
      ], reason: 'stale "tech" result dropped');
    });

    test('paginates without duplicates', () async {
      final repo = FakeCommunityRepository();
      for (var i = 1; i <= 25; i++) {
        repo.add(
          id: '$i',
          publishedAt: DateTime(2026, 1, 1).add(Duration(days: i)),
        );
      }
      final cubit = ExploreCubit(repo);
      await cubit.reload();
      expect(cubit.state.items.length, 20);
      expect(cubit.state.hasMore, isTrue);
      await cubit.loadMore();
      await cubit.loadMore(); // no more pages: ignored
      expect(cubit.state.items.length, 25);
      expect(cubit.state.hasMore, isFalse);
      expect({for (final i in cubit.state.items) i.beat.id}.length, 25);
      expect(repo.calls.where((c) => c.startsWith('feed:')).length, 2);
    });

    test('a failure is reported and reload recovers', () async {
      final repo = seeded()
        ..failNext = const AppFailure('Could not reach BeatGrid.');
      final cubit = ExploreCubit(repo);
      await cubit.reload();
      expect(cubit.state.status, ListStatus.failed);
      expect(cubit.state.error, 'Could not reach BeatGrid.');
      await cubit.reload();
      expect(cubit.state.status, ListStatus.ready);
    });

    test('a failed "load more" keeps the existing items', () async {
      final repo = FakeCommunityRepository();
      for (var i = 1; i <= 21; i++) {
        repo.add(id: '$i');
      }
      final cubit = ExploreCubit(repo);
      await cubit.reload();
      repo.failNext = const AppFailure('Offline.');
      await cubit.loadMore();
      expect(cubit.state.items.length, 20);
      expect(cubit.state.message, 'Offline.');
      expect(cubit.state.loadingMore, isFalse);
      expect(cubit.state.hasMore, isTrue, reason: 'can retry');
    });

    test(
      'decorates items with the viewer\'s likes, saves, covers and avatars',
      () async {
        final repo = seeded(userId: 'me');
        repo.liked.add('2');
        repo.savedOrder.add('3');
        repo.add(id: '5', title: 'Covered', coverPath: 'c1/cover.png');
        repo.covers['c1/cover.png'] = 'https://example.test/signed/cover.png';
        final cubit = ExploreCubit(repo);
        await cubit.reload();
        final byId = {for (final i in cubit.state.items) i.beat.id: i};
        expect(byId['2']!.liked, isTrue);
        expect(byId['1']!.liked, isFalse);
        expect(byId['3']!.saved, isTrue);
        expect(byId['5']!.coverUrl, 'https://example.test/signed/cover.png');
      },
    );

    test('anonymous visitors see no liked/saved flags', () async {
      final repo = seeded();
      repo.liked.add('2');
      final cubit = ExploreCubit(repo);
      await cubit.reload();
      expect(cubit.state.items.every((i) => !i.liked && !i.saved), isTrue);
    });
  });

  group('likes and saves (optimistic updates)', () {
    Future<(ExploreCubit, FakeCommunityRepository)> ready({
      String? userId = 'me',
    }) async {
      final repo = seeded(userId: userId);
      final cubit = ExploreCubit(repo);
      await cubit.reload();
      return (cubit, repo);
    }

    BeatItem item(ExploreCubit c, String id) =>
        c.state.items.firstWhere((i) => i.beat.id == id);

    test(
      'the UI changes immediately, then the server count is reconciled',
      () async {
        final (cubit, repo) = await ready();
        final gate = Completer<void>();
        repo.likeGate = gate;
        final future = cubit.toggleLike(item(cubit, '1'));
        await flush();
        expect(item(cubit, '1').liked, isTrue, reason: 'optimistic');
        expect(item(cubit, '1').beat.likeCount, 3);
        gate.complete();
        await future;
        expect(repo.liked, contains('1'));
        expect(item(cubit, '1').beat.likeCount, 3, reason: 'server agrees');
        expect(repo.calls, contains('stats:1'));
      },
    );

    test('reconciliation corrects drift from other viewers\' likes', () async {
      final (cubit, repo) = await ready();
      repo.otherLikes['1'] = 10; // others liked meanwhile
      await cubit.toggleLike(item(cubit, '1'));
      expect(item(cubit, '1').beat.likeCount, 11);
    });

    test('a refused like is rolled back with a message', () async {
      final (cubit, repo) = await ready();
      repo.failLikeNext = const AppFailure(
        'You do not have permission to do that.',
      );
      await cubit.toggleLike(item(cubit, '1'));
      expect(item(cubit, '1').liked, isFalse);
      expect(item(cubit, '1').beat.likeCount, 2);
      expect(cubit.state.message, 'You do not have permission to do that.');
    });

    test(
      'unlike decrements and double taps are ignored while in flight',
      () async {
        final (cubit, repo) = await ready();
        repo.liked.add('2');
        await cubit.reload();
        final gate = Completer<void>();
        repo.likeGate = gate;
        final first = cubit.toggleLike(item(cubit, '2'));
        await flush();
        await cubit.toggleLike(item(cubit, '2')); // ignored
        gate.complete();
        await first;
        expect(repo.calls.where((c) => c.startsWith('like:2')).length, 1);
        expect(item(cubit, '2').liked, isFalse);
        expect(item(cubit, '2').beat.likeCount, 9);
      },
    );

    test('saving toggles and rolls back on failure', () async {
      final (cubit, repo) = await ready();
      await cubit.toggleSave(item(cubit, '3'));
      expect(item(cubit, '3').saved, isTrue);
      expect(repo.savedOrder, ['3']);
      repo.failNext = const AppFailure('Nope.');
      await cubit.toggleSave(item(cubit, '3'));
      expect(
        item(cubit, '3').saved,
        isTrue,
        reason: 'unsave failed, state restored',
      );
      expect(cubit.state.message, 'Nope.');
    });

    test('signed-out attempts fail safely without changing anything', () async {
      final (cubit, _) = await ready(userId: null);
      await cubit.toggleLike(item(cubit, '1'));
      expect(item(cubit, '1').liked, isFalse);
      expect(item(cubit, '1').beat.likeCount, 2);
      expect(cubit.state.message, isNotNull);
    });
  });

  group('SavedBeatsCubit', () {
    test(
      'lists saved beats most recent first and drops a beat when unsaved',
      () async {
        final repo = seeded(userId: 'me');
        repo.savedOrder.addAll(['3', '1']);
        final cubit = SavedBeatsCubit(repo);
        await cubit.reload();
        expect(cubit.state.items.map((i) => i.beat.id), ['3', '1']);
        expect(cubit.state.items.every((i) => i.saved), isTrue);
        await cubit.toggleSave(cubit.state.items.first);
        expect(cubit.state.items.map((i) => i.beat.id), ['1']);
      },
    );

    test('signed-out users get a clear failure', () async {
      final cubit = SavedBeatsCubit(seeded());
      await cubit.reload();
      expect(cubit.state.status, ListStatus.failed);
    });
  });

  group('BeatDetailCubit', () {
    test('loads a beat with its pattern and viewer flags', () async {
      final repo = seeded(userId: 'me');
      repo.liked.add('2');
      final cubit = BeatDetailCubit(repo, 'beat-2');
      await cubit.load();
      expect(cubit.state.status, DetailStatus.ready);
      expect(cubit.state.item!.beat.title, 'Warehouse');
      expect(cubit.state.item!.liked, isTrue);
      expect(cubit.state.pattern!.isEmpty, isFalse);
    });

    test(
      'unknown or unpublished slugs are not found; failures are separate',
      () async {
        final repo = seeded();
        final missing = BeatDetailCubit(repo, 'nope');
        await missing.load();
        expect(missing.state.status, DetailStatus.notFound);
        repo.failNext = const AppFailure('Offline.');
        final failing = BeatDetailCubit(repo, 'beat-1');
        await failing.load();
        expect(failing.state.status, DetailStatus.failed);
        await failing.load();
        expect(failing.state.status, DetailStatus.ready);
      },
    );

    test('like and save update the page and counts', () async {
      final repo = seeded(userId: 'me');
      final cubit = BeatDetailCubit(repo, 'beat-1');
      await cubit.load();
      await cubit.toggleLike();
      expect(cubit.state.item!.liked, isTrue);
      expect(cubit.state.item!.beat.likeCount, 3);
      await cubit.toggleSave();
      expect(cubit.state.item!.saved, isTrue);
      await cubit.toggleLike();
      expect(cubit.state.item!.beat.likeCount, 2);
    });
  });

  group('CreatorProfileCubit', () {
    test('loads a profile and reports missing creators', () async {
      final repo = seeded();
      repo.creators['ada'] = CreatorProfile(
        id: 'c1',
        username: 'ada',
        displayName: 'Ada',
        createdAt: DateTime(2026),
        stats: const CreatorStats(beatCount: 2, likeCount: 3, playCount: 4),
      );
      final ok = CreatorProfileCubit(repo, 'Ada');
      await ok.load();
      expect(ok.state.status, ProfileStatus.ready);
      expect(ok.state.profile!.stats.beatCount, 2);
      final none = CreatorProfileCubit(repo, 'ghost');
      await none.load();
      expect(none.state.status, ProfileStatus.notFound);
    });

    test('creator beats list only that creator\'s beats', () async {
      final repo = seeded();
      final cubit = CreatorBeatsCubit(repo, 'c1');
      await cubit.reload();
      expect(cubit.state.items.length, 4);
      expect(
        CreatorBeatsCubit(repo, 'nobody').fetch(0, 20),
        completion(isEmpty),
      );
    });
  });

  group('PlayerCubit', () {
    late FakeCommunityRepository repo;
    late FakeAudioEngine engine;
    late AudioCoordinator coordinator;
    late PlayerCubit player;
    late PublicBeat beat;

    setUp(() {
      repo = seeded();
      engine = FakeAudioEngine();
      coordinator = AudioCoordinator();
      player = PlayerCubit(
        repo,
        coordinator,
        engineFactory: () => engine,
        countAfter: const Duration(milliseconds: 20),
      );
      beat = repo.beats.firstWhere((b) => b.id == '2');
    });

    test('plays a beat: loads its pattern, sets tempo and loops', () async {
      await player.play(beat);
      await flush();
      expect(
        engine.calls,
        containsAll(['init', 'pattern', 'bpm:120', 'loop:true', 'play']),
      );
      expect(player.state.isPlaying, isTrue);
      expect(player.state.beat!.id, '2');
      expect(engine.patterns.single.isActive(TrackId.kick, 0), isTrue);
    });

    test('pause, resume and toggle', () async {
      await player.play(beat);
      await flush();
      player.pause();
      await flush();
      expect(player.state.status, PlayerStatus.paused);
      player.toggle();
      await flush();
      expect(player.state.isPlaying, isTrue);
    });

    test(
      'counts a play once after the listening threshold, not before',
      () async {
        await player.play(beat);
        await flush();
        expect(repo.plays, isEmpty);
        await Future<void>.delayed(const Duration(milliseconds: 40));
        expect(repo.plays, ['2']);
        player.pause();
        await flush();
        player.resume();
        await Future<void>.delayed(const Duration(milliseconds: 40));
        expect(repo.plays, ['2'], reason: 'resuming does not count again');
      },
    );

    test('skipping away before the threshold counts nothing', () async {
      await player.play(beat);
      await flush();
      player.dismiss();
      await Future<void>.delayed(const Duration(milliseconds: 40));
      expect(repo.plays, isEmpty);
    });

    test('switching beats replaces the song and keeps one engine', () async {
      await player.play(beat);
      await flush();
      await player.play(repo.beats.firstWhere((b) => b.id == '1'));
      await flush();
      expect(player.state.beat!.id, '1');
      expect(
        engine.initCount,
        2,
        reason: 'init is idempotent in the real engine',
      );
      expect(engine.calls.where((c) => c == 'dispose'), isEmpty);
    });

    test(
      'a beat that disappeared reports an error instead of playing',
      () async {
        repo.beats.removeWhere((b) => b.id == '2');
        await player.play(beat);
        expect(player.state.status, PlayerStatus.error);
        expect(engine.calls, isNot(contains('play')));
      },
    );

    test('audio failure is surfaced', () async {
      engine.failInit = true;
      await player.play(beat);
      expect(player.state.status, PlayerStatus.error);
      expect(player.state.error, 'Audio blocked by the browser.');
    });

    test('dismiss stops, releases the engine and hides the player', () async {
      await player.play(beat);
      await flush();
      player.dismiss();
      expect(engine.disposed, isTrue);
      expect(player.state.beat, isNull);
      expect(coordinator.owner, isNull);
    });

    test(
      'the studio taking the engine pauses the player; resume starts it again',
      () async {
        await player.play(beat);
        await flush();
        final studioEngine = FakeAudioEngine();
        final studio = StudioCubit(studioEngine, coordinator: coordinator);
        await studio.play();
        await flush();
        expect(
          engine.disposed,
          isTrue,
          reason: 'player released the browser engine',
        );
        expect(player.state.status, PlayerStatus.paused);
        expect(studio.state.isPlaying, isTrue);

        engine.disposed = false;
        player.resume(); // user presses play on the mini-player again
        await flush(6);
        expect(player.state.isPlaying, isTrue);
        expect(
          studioEngine.disposed,
          isTrue,
          reason: 'studio was told to let go',
        );
        expect(studio.state.audio, AudioStatus.idle);
        expect(studio.state.isPlaying, isFalse);
      },
    );

    test('closing the player releases ownership', () async {
      await player.play(beat);
      await flush();
      await player.close();
      expect(coordinator.owner, isNull);
    });
  });

  group('AudioCoordinator', () {
    test('claiming notifies the previous owner once, in order', () {
      final c = AudioCoordinator();
      final log = <String>[];
      final a = Object(), b = Object();
      c.claim(a, onRevoked: () => log.add('a revoked'));
      c.claim(
        a,
        onRevoked: () => log.add('a revoked'),
      ); // same owner: no revoke
      expect(log, isEmpty);
      c.claim(b, onRevoked: () => log.add('b revoked'));
      expect(log, ['a revoked']);
      expect(c.owner, same(b));
      c.release(a); // not the owner: ignored
      expect(c.owner, same(b));
      c.release(b);
      expect(c.owner, isNull);
      c.claim(a, onRevoked: () => log.add('a revoked'));
      expect(log, ['a revoked'], reason: 'released owners are not notified');
    });
  });
}
