import 'dart:async';
import 'dart:typed_data';

import 'package:beatgrid/core/errors/app_failure.dart';
import 'package:beatgrid/features/beats/data/beat_repository.dart';
import 'package:beatgrid/features/beats/models/beat.dart';
import 'package:beatgrid/features/studio/models/beat_pattern.dart';

class RemixSource {
  const RemixSource({
    required this.title,
    required this.creator,
    required this.pattern,
    this.genre = 'techno',
    this.bpm = 132,
    this.allowRemix = true,
    this.published = true,
  });

  final String title;
  final String creator;
  final BeatPattern pattern;
  final String genre;
  final int bpm;
  final bool allowRemix;
  final bool published;
}

/// In-memory stand-in for the Supabase repository that mimics RLS ownership:
/// updates/deletes of other users' beats fail, drafts of others are invisible.
class FakeBeatRepository implements BeatRepository {
  FakeBeatRepository({this.userId = 'u1'});

  String? userId;
  final Map<String, Beat> beats = {};
  final calls = <String>[];
  final removedCovers = <String>[];
  final uploadedCovers = <String>[];
  AppFailure? failNext;

  /// Published beats of other creators that can be remixed, by id.
  final Map<String, RemixSource> remixSources = {};
  Completer<void>? gate;
  int _seq = 0;

  @override
  String? get currentUserId => userId;

  Future<void> _enter(String call) async {
    calls.add(call);
    await gate?.future;
    final f = failNext;
    if (f != null) {
      failNext = null;
      throw f;
    }
  }

  /// Adds a beat directly (as if it already existed on the server).
  Beat seed({
    String? id,
    String? creator,
    String title = 'Seed Beat',
    BeatStatus status = BeatStatus.draft,
    BeatInput? input,
    String? coverPath,
  }) {
    final n = ++_seq;
    final beatId = id ?? 'b$n';
    final base = input;
    final beat = Beat(
      id: beatId,
      creatorId: creator ?? userId ?? 'u1',
      title: base?.title ?? title,
      slug: '${(base?.title ?? title).toLowerCase().replaceAll(' ', '-')}-$n',
      description: base?.description,
      genre: base?.genre ?? 'house',
      bpm: base?.bpm ?? 120,
      pattern: base?.pattern ?? _emptyPattern(),
      coverPath: coverPath ?? base?.coverPath,
      status: status,
      allowRemix: base?.allowRemix ?? false,
      createdAt: DateTime(2026, 1, n),
      updatedAt: DateTime(2026, 1, n),
      publishedAt: status == BeatStatus.published ? DateTime(2026, 1, n) : null,
    );
    beats[beatId] = beat;
    return beat;
  }

  BeatPattern _emptyPattern() => BeatPattern.empty();

  Beat _fromInput(String id, String creator, BeatInput i, {Beat? old}) {
    final n = old == null ? ++_seq : 0;
    final publishedAt = i.status == BeatStatus.published
        ? (old?.publishedAt ?? DateTime(2026, 6, 1))
        : null;
    return Beat(
      id: id,
      creatorId: creator,
      title: i.title.trim(),
      slug:
          old?.slug ??
          '${i.title.trim().toLowerCase().replaceAll(' ', '-')}-$n',
      description: (i.description?.trim().isEmpty ?? true)
          ? null
          : i.description!.trim(),
      genre: i.genre,
      bpm: i.bpm,
      pattern: i.pattern,
      coverPath: i.coverPath,
      status: i.status,
      allowRemix: i.allowRemix,
      sourceBeatId: old?.sourceBeatId,
      sourceTitle: old?.sourceTitle,
      sourceCreatorUsername: old?.sourceCreatorUsername,
      publishedAt: publishedAt,
      createdAt: old?.createdAt ?? DateTime(2026, 6, 1),
      updatedAt: DateTime(2026, 6, 2),
    );
  }

  @override
  Future<Beat> create(BeatInput input) async {
    await _enter('create');
    final id = 'b${++_seq}';
    return beats[id] = _fromInput(id, userId!, input);
  }

  @override
  Future<Beat> update(String id, BeatInput input) async {
    await _enter('update');
    final old = beats[id];
    if (old == null || old.creatorId != userId) {
      throw const AppFailure(
        'That beat could not be found, or it is not yours to change.',
        code: 'not_found',
      );
    }
    return beats[id] = _fromInput(id, userId!, input, old: old);
  }

  @override
  Future<Beat> createRemix(String sourceId) async {
    await _enter('remix:$sourceId');
    final src = remixSources[sourceId];
    if (src == null || !src.published) {
      throw const AppFailure(
        'The original beat is no longer available to remix.',
        code: 'remix_source_unavailable',
      );
    }
    if (!src.allowRemix) {
      throw const AppFailure(
        'The creator has not allowed remixes of this beat.',
        code: 'remix_not_allowed',
      );
    }
    final id = 'b${++_seq}';
    final title =
        '${src.title.length > 71 ? src.title.substring(0, 71) : src.title} (remix)';
    return beats[id] = Beat(
      id: id,
      creatorId: userId!,
      title: title,
      slug: 'remix-$id',
      genre: src.genre,
      bpm: src.bpm,
      pattern: src.pattern,
      status: BeatStatus.draft,
      allowRemix: false,
      sourceBeatId: sourceId,
      sourceTitle: src.title,
      sourceCreatorUsername: src.creator,
      createdAt: DateTime(2026, 6, 1),
      updatedAt: DateTime(2026, 6, 1),
    );
  }

  @override
  Future<Beat> setStatus(String id, BeatStatus status) async {
    await _enter('setStatus:${status.name}');
    final old = beats[id];
    if (old == null || old.creatorId != userId) {
      throw const AppFailure(
        'That beat could not be found, or it is not yours to change.',
        code: 'not_found',
      );
    }
    return beats[id] = Beat(
      id: old.id,
      creatorId: old.creatorId,
      title: old.title,
      slug: old.slug,
      description: old.description,
      genre: old.genre,
      bpm: old.bpm,
      pattern: old.pattern,
      coverPath: old.coverPath,
      status: status,
      allowRemix: old.allowRemix,
      sourceBeatId: old.sourceBeatId,
      sourceTitle: old.sourceTitle,
      sourceCreatorUsername: old.sourceCreatorUsername,
      publishedAt: status == BeatStatus.published ? DateTime(2026, 6, 1) : null,
      createdAt: old.createdAt,
      updatedAt: DateTime(2026, 6, 3),
    );
  }

  @override
  Future<Beat?> getById(String id) async {
    await _enter('get:$id');
    final b = beats[id];
    if (b == null) return null;
    if (b.creatorId != userId && !b.isPublished)
      return null; // RLS hides others' drafts
    return b;
  }

  @override
  Future<List<BeatSummary>> listMine({
    required int offset,
    required int limit,
  }) async {
    await _enter('list:$offset');
    final mine = beats.values.where((b) => b.creatorId == userId).toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return [
      for (final b in mine.skip(offset).take(limit))
        BeatSummary(
          id: b.id,
          title: b.title,
          slug: b.slug,
          genre: b.genre,
          bpm: b.bpm,
          status: b.status,
          allowRemix: b.allowRemix,
          coverPath: b.coverPath,
          sourceTitle: b.sourceTitle,
          publishedAt: b.publishedAt,
          updatedAt: b.updatedAt,
        ),
    ];
  }

  @override
  Future<void> delete(String id, {String? coverPath}) async {
    await _enter('delete:$id');
    final b = beats[id];
    if (b == null || b.creatorId != userId) {
      throw const AppFailure(
        'That beat could not be found.',
        code: 'not_found',
      );
    }
    beats.remove(id);
    if (coverPath != null) removedCovers.add(coverPath);
  }

  @override
  Future<String> uploadCover(
    Uint8List bytes, {
    required String extension,
  }) async {
    await _enter('upload');
    final path = '$userId/cover-${uploadedCovers.length}.$extension';
    uploadedCovers.add(path);
    return path;
  }

  @override
  Future<void> removeCover(String path) async => removedCovers.add(path);

  @override
  Future<String?> coverUrl(String? path) async =>
      path == null ? null : 'https://example.test/$path';
}
