import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/errors/error_mapper.dart';
import '../../studio/models/beat_pattern.dart';
import '../models/public_beat.dart';
import 'community_repository.dart';

class SupabaseCommunityRepository implements CommunityRepository {
  SupabaseCommunityRepository(this._client);

  final SupabaseClient _client;

  @override
  String? get currentUserId => _client.auth.currentUser?.id;

  String _requireUser() {
    final id = currentUserId;
    if (id == null) {
      throw const AppFailure(
        'Please sign in to do that.',
        code: 'session_expired',
      );
    }
    return id;
  }

  Future<T> _guard<T>(Future<T> Function() body) async {
    try {
      return await body();
    } on PatternFormatException catch (e) {
      if (kDebugMode) debugPrint('invalid stored pattern: $e');
      throw const AppFailure(
        'This beat\'s data is damaged and cannot be played.',
        code: 'invalid_pattern',
      );
    } catch (e, s) {
      throw mapError(e, s);
    }
  }

  List<PublicBeat> _beats(List<Map<String, dynamic>> rows) => [
    for (final r in rows) PublicBeat.fromJson(r),
  ];

  @override
  Future<List<PublicBeat>> feed({
    required FeedSort sort,
    String? genre,
    String? query,
    required int offset,
    required int limit,
  }) => _guard(() async {
    var q = _client.from('public_beats').select();
    if (genre != null && genre.isNotEmpty) q = q.eq('genre', genre);
    final term = sanitizeSearch(query);
    if (term.isNotEmpty) {
      q = q.or(
        'title.ilike.%$term%,creator_username.ilike.%$term%,genre.ilike.%$term%',
      );
    }
    final ordered = sort == FeedSort.trending
        ? q
              .order('trending_score', ascending: false)
              .order('published_at', ascending: false)
        : q.order('published_at', ascending: false);
    final rows = await ordered.order('id').range(offset, offset + limit - 1);
    return _beats(rows);
  });

  @override
  Future<PublicBeatDetail?> detailBySlug(String slug) => _guard(() async {
    final row = await _client
        .from('public_beats')
        .select()
        .eq('slug', slug)
        .maybeSingle();
    if (row == null) return null;
    final beat = PublicBeat.fromJson(row);
    final pattern = await _client
        .from('beats')
        .select('pattern_data')
        .eq('id', beat.id)
        .maybeSingle();
    if (pattern == null) return null;
    return PublicBeatDetail(
      beat: beat,
      pattern: BeatPattern.fromJson(pattern['pattern_data']),
    );
  });

  @override
  Future<PublicBeat?> publicBeatById(String id) => _guard(() async {
    final row = await _client
        .from('public_beats')
        .select()
        .eq('id', id)
        .maybeSingle();
    return row == null ? null : PublicBeat.fromJson(row);
  });

  @override
  Future<List<PublicBeat>> savedBeats({
    required int offset,
    required int limit,
  }) => _guard(() async {
    final uid = _requireUser();
    final saves = await _client
        .from('beat_saves')
        .select('beat_id')
        .eq('user_id', uid)
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);
    final ids = [for (final r in saves) r['beat_id'] as String];
    if (ids.isEmpty) return <PublicBeat>[];
    final rows = await _client
        .from('public_beats')
        .select()
        .inFilter('id', ids);
    final byId = {for (final b in _beats(rows)) b.id: b};
    // Keep "most recently saved first"; beats unpublished since saving drop out.
    return [
      for (final id in ids)
        if (byId[id] != null) byId[id]!,
    ];
  });

  @override
  Future<CreatorProfile?> creatorByUsername(String username) =>
      _guard(() async {
        final profile = await _client
            .from('profiles')
            .select('id, username, display_name, bio, avatar_path, created_at')
            .eq('username', username.toLowerCase())
            .maybeSingle();
        if (profile == null) return null;
        final stats = await _client
            .from('creator_stats')
            .select()
            .eq('creator_id', profile['id'] as String)
            .maybeSingle();
        return CreatorProfile(
          id: profile['id'] as String,
          username: profile['username'] as String,
          displayName: profile['display_name'] as String,
          bio: profile['bio'] as String?,
          avatarPath: profile['avatar_path'] as String?,
          createdAt: DateTime.parse(profile['created_at'] as String),
          stats: stats == null
              ? const CreatorStats()
              : CreatorStats(
                  beatCount: (stats['beat_count'] as num).toInt(),
                  likeCount: (stats['like_count'] as num).toInt(),
                  playCount: (stats['play_count'] as num).toInt(),
                ),
        );
      });

  @override
  Future<List<PublicBeat>> creatorBeats(
    String creatorId, {
    required int offset,
    required int limit,
  }) => _guard(() async {
    final rows = await _client
        .from('public_beats')
        .select()
        .eq('creator_id', creatorId)
        .order('published_at', ascending: false)
        .order('id')
        .range(offset, offset + limit - 1);
    return _beats(rows);
  });

  @override
  Future<Set<String>> likedAmong(List<String> ids) => _guard(() async {
    if (ids.isEmpty || currentUserId == null) return <String>{};
    final rows = await _client
        .from('beat_likes')
        .select('beat_id')
        .inFilter('beat_id', ids);
    return {for (final r in rows) r['beat_id'] as String};
  });

  @override
  Future<Set<String>> savedAmong(List<String> ids) => _guard(() async {
    if (ids.isEmpty || currentUserId == null) return <String>{};
    final rows = await _client
        .from('beat_saves')
        .select('beat_id')
        .inFilter('beat_id', ids);
    return {for (final r in rows) r['beat_id'] as String};
  });

  Future<void> _setRelation(String table, String beatId, bool on) async {
    final uid = _requireUser();
    if (on) {
      try {
        await _client.from(table).insert({'beat_id': beatId, 'user_id': uid});
      } on PostgrestException catch (e) {
        if (e.code != '23505')
          rethrow; // already there: the desired state holds
      }
    } else {
      await _client
          .from(table)
          .delete()
          .eq('beat_id', beatId)
          .eq('user_id', uid);
    }
  }

  @override
  Future<void> setLiked(String beatId, bool liked) =>
      _guard(() => _setRelation('beat_likes', beatId, liked));

  @override
  Future<void> setSaved(String beatId, bool saved) =>
      _guard(() => _setRelation('beat_saves', beatId, saved));

  @override
  Future<bool> recordPlay(String beatId) => _guard(() async {
    final res = await _client.rpc('record_play', params: {'p_beat_id': beatId});
    return res == true;
  });

  @override
  Future<Map<String, String>> coverUrls(List<String> paths) async {
    final unique = paths.toSet().toList();
    if (unique.isEmpty) return {};
    try {
      final results = await _client.storage
          .from('covers')
          .createSignedUrlsResult(unique, 3600);
      return {
        for (final r in results)
          if (r is SignedUrlSuccess) r.path: r.signedUrl,
      };
    } catch (e) {
      // Covers are decoration; the generated artwork is the fallback.
      if (kDebugMode) debugPrint('coverUrls failed: $e');
      return {};
    }
  }

  @override
  String? avatarUrl(String? avatarPath) => avatarPath == null
      ? null
      : _client.storage.from('avatars').getPublicUrl(avatarPath);
}

class UnconfiguredCommunityRepository implements CommunityRepository {
  const UnconfiguredCommunityRepository();

  Never _fail() => throw AppFailure.notConfigured;

  @override
  String? get currentUserId => null;
  @override
  Future<List<PublicBeat>> feed({
    required FeedSort sort,
    String? genre,
    String? query,
    required int offset,
    required int limit,
  }) async => _fail();
  @override
  Future<PublicBeatDetail?> detailBySlug(String slug) async => _fail();
  @override
  Future<PublicBeat?> publicBeatById(String id) async => _fail();
  @override
  Future<List<PublicBeat>> savedBeats({
    required int offset,
    required int limit,
  }) async => _fail();
  @override
  Future<CreatorProfile?> creatorByUsername(String username) async => _fail();
  @override
  Future<List<PublicBeat>> creatorBeats(
    String creatorId, {
    required int offset,
    required int limit,
  }) async => _fail();
  @override
  Future<Set<String>> likedAmong(List<String> ids) async => {};
  @override
  Future<Set<String>> savedAmong(List<String> ids) async => {};
  @override
  Future<void> setLiked(String beatId, bool liked) async => _fail();
  @override
  Future<void> setSaved(String beatId, bool saved) async => _fail();
  @override
  Future<bool> recordPlay(String beatId) async => false;
  @override
  Future<Map<String, String>> coverUrls(List<String> paths) async => {};
  @override
  String? avatarUrl(String? avatarPath) => null;
}
