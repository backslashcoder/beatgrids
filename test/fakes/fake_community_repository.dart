import 'dart:async';

import 'package:beatgrid/core/errors/app_failure.dart';
import 'package:beatgrid/features/community/data/community_repository.dart';
import 'package:beatgrid/features/community/models/public_beat.dart';
import 'package:beatgrid/features/studio/models/beat_pattern.dart';
import 'package:beatgrid/features/studio/models/starter_patterns.dart';

/// In-memory community: published beats, per-viewer likes/saves, play counting.
class FakeCommunityRepository implements CommunityRepository {
  FakeCommunityRepository({this.userId});

  String? userId;
  final List<PublicBeat> beats = [];
  final Map<String, BeatPattern> patterns = {};
  final Set<String> liked = {}; // beat ids liked by the current user
  final List<String> savedOrder = []; // most recent first
  final Map<String, int> otherLikes = {}; // likes from other users
  final Map<String, CreatorProfile> creators = {};
  final Map<String, String> covers = {};
  final calls = <String>[];
  final plays = <String>[];

  AppFailure? failNext;
  AppFailure? failLikeNext;
  Completer<void>? likeGate;

  /// Awaited at the start of every feed call with its query; lets tests delay
  /// specific responses to prove stale results are ignored.
  Future<void> Function(String? query)? feedHook;

  PublicBeat add({
    required String id,
    String? slug,
    String? title,
    String genre = 'house',
    int bpm = 120,
    String creatorId = 'c1',
    String creator = 'koji',
    String? coverPath,
    String? description,
    bool allowRemix = false,
    String? sourceTitle,
    String? sourceCreator,
    String? sourceSlug,
    int likes = 0,
    int playCount = 0,
    DateTime? publishedAt,
  }) {
    final beat = PublicBeat(
      id: id,
      slug: slug ?? 'beat-$id',
      title: title ?? 'Beat $id',
      description: description,
      genre: genre,
      bpm: bpm,
      coverPath: coverPath,
      allowRemix: allowRemix,
      sourceTitle: sourceTitle,
      sourceCreatorUsername: sourceCreator,
      sourceSlug: sourceSlug,
      publishedAt:
          publishedAt ??
          DateTime(
            2026,
            1,
            int.tryParse(id.replaceAll(RegExp(r'\D'), '')) ?? 1,
          ),
      creatorId: creatorId,
      creatorUsername: creator,
      creatorDisplayName: creator.toUpperCase(),
      likeCount: likes,
      playCount: playCount,
    );
    beats.add(beat);
    patterns[id] = starterById('house-groove')!.toPattern();
    otherLikes[id] = likes;
    return beat;
  }

  void _maybeFail() {
    final f = failNext;
    if (f != null) {
      failNext = null;
      throw f;
    }
  }

  PublicBeat _withCounts(PublicBeat b) => b.copyWith(
    likeCount: (otherLikes[b.id] ?? 0) + (liked.contains(b.id) ? 1 : 0),
  );

  @override
  String? get currentUserId => userId;

  @override
  Future<List<PublicBeat>> feed({
    required FeedSort sort,
    String? genre,
    String? query,
    required int offset,
    required int limit,
  }) async {
    calls.add('feed:${sort.name}:${genre ?? '-'}:${query ?? ''}:$offset');
    await feedHook?.call(query);
    _maybeFail();
    final q = (query ?? '').toLowerCase();
    var rows = beats
        .where((b) {
          if (genre != null && genre.isNotEmpty && b.genre != genre)
            return false;
          if (q.isEmpty) return true;
          return b.title.toLowerCase().contains(q) ||
              b.creatorUsername.toLowerCase().contains(q) ||
              b.genre.toLowerCase().contains(q);
        })
        .map(_withCounts)
        .toList();
    if (sort == FeedSort.trending) {
      rows.sort((a, b) {
        final c = (b.likeCount * 3 + b.playCount).compareTo(
          a.likeCount * 3 + a.playCount,
        );
        return c != 0 ? c : b.publishedAt.compareTo(a.publishedAt);
      });
    } else {
      rows.sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
    }
    return rows.skip(offset).take(limit).toList();
  }

  @override
  Future<PublicBeatDetail?> detailBySlug(String slug) async {
    calls.add('detail:$slug');
    _maybeFail();
    for (final b in beats) {
      if (b.slug == slug)
        return PublicBeatDetail(beat: _withCounts(b), pattern: patterns[b.id]!);
    }
    return null;
  }

  @override
  Future<PublicBeat?> publicBeatById(String id) async {
    calls.add('stats:$id');
    for (final b in beats) {
      if (b.id == id) return _withCounts(b);
    }
    return null;
  }

  @override
  Future<List<PublicBeat>> savedBeats({
    required int offset,
    required int limit,
  }) async {
    calls.add('saved:$offset');
    _maybeFail();
    if (userId == null)
      throw const AppFailure(
        'Please sign in to do that.',
        code: 'session_expired',
      );
    final byId = {for (final b in beats) b.id: _withCounts(b)};
    return [
      for (final id in savedOrder.skip(offset).take(limit))
        if (byId[id] != null) byId[id]!,
    ];
  }

  @override
  Future<CreatorProfile?> creatorByUsername(String username) async {
    calls.add('creator:$username');
    _maybeFail();
    return creators[username.toLowerCase()];
  }

  @override
  Future<List<PublicBeat>> creatorBeats(
    String creatorId, {
    required int offset,
    required int limit,
  }) async {
    calls.add('creatorBeats:$creatorId:$offset');
    _maybeFail();
    final rows =
        beats.where((b) => b.creatorId == creatorId).map(_withCounts).toList()
          ..sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
    return rows.skip(offset).take(limit).toList();
  }

  @override
  Future<Set<String>> likedAmong(List<String> ids) async => userId == null
      ? {}
      : {
          for (final id in ids)
            if (liked.contains(id)) id,
        };

  @override
  Future<Set<String>> savedAmong(List<String> ids) async => userId == null
      ? {}
      : {
          for (final id in ids)
            if (savedOrder.contains(id)) id,
        };

  @override
  Future<void> setLiked(String beatId, bool value) async {
    calls.add('like:$beatId:$value');
    await likeGate?.future;
    final f = failLikeNext;
    if (f != null) {
      failLikeNext = null;
      throw f;
    }
    if (userId == null)
      throw const AppFailure(
        'Please sign in to do that.',
        code: 'session_expired',
      );
    value ? liked.add(beatId) : liked.remove(beatId);
  }

  @override
  Future<void> setSaved(String beatId, bool value) async {
    calls.add('save:$beatId:$value');
    _maybeFail();
    if (userId == null)
      throw const AppFailure(
        'Please sign in to do that.',
        code: 'session_expired',
      );
    savedOrder.remove(beatId);
    if (value) savedOrder.insert(0, beatId);
  }

  @override
  Future<bool> recordPlay(String beatId) async {
    plays.add(beatId);
    return true;
  }

  @override
  Future<Map<String, String>> coverUrls(List<String> paths) async => {
    for (final p in paths)
      if (covers.containsKey(p)) p: covers[p]!,
  };

  @override
  String? avatarUrl(String? avatarPath) =>
      avatarPath == null ? null : 'https://example.test/avatars/$avatarPath';
}
