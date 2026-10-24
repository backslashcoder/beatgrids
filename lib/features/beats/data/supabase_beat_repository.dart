import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/errors/error_mapper.dart';
import '../../studio/models/beat_pattern.dart';
import '../models/beat.dart';
import 'beat_repository.dart';

class SupabaseBeatRepository implements BeatRepository {
  SupabaseBeatRepository(this._client);

  final SupabaseClient _client;

  static const _table = 'beats';
  static const _coverBucket = 'covers';
  static const _maxCoverBytes = 5 * 1024 * 1024;
  static const _coverTypes = {
    'png': 'image/png',
    'jpg': 'image/jpeg',
    'jpeg': 'image/jpeg',
    'webp': 'image/webp',
  };

  @override
  String? get currentUserId => _client.auth.currentUser?.id;

  String _requireUser() {
    final id = currentUserId;
    if (id == null) {
      throw const AppFailure(
        'Please sign in to continue.',
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
        'This beat\'s data is damaged and cannot be opened.',
        code: 'invalid_pattern',
      );
    } catch (e, s) {
      throw mapError(e, s);
    }
  }

  @override
  Future<Beat> create(BeatInput input) => _guard(() async {
    final uid = _requireUser();
    final row = await _client
        .from(_table)
        .insert({...input.toRow(), 'creator_id': uid})
        .select()
        .single();
    return Beat.fromJson(row);
  });

  @override
  Future<Beat> update(String id, BeatInput input) => _guard(() async {
    _requireUser();
    // `single()` fails with PGRST116 if RLS hides or blocks the row, so a beat
    // that is not ours can never be reported as saved.
    final row = await _client
        .from(_table)
        .update(input.toRow())
        .eq('id', id)
        .select()
        .single();
    return Beat.fromJson(row);
  });

  @override
  Future<Beat> createRemix(String sourceId) => _guard(() async {
    _requireUser();
    final row = await _client.rpc(
      'create_remix',
      params: {'p_source_id': sourceId},
    );
    return Beat.fromJson(Map<String, dynamic>.from(row as Map));
  });

  @override
  Future<Beat> setStatus(String id, BeatStatus status) => _guard(() async {
    _requireUser();
    final row = await _client
        .from(_table)
        .update({'status': status.name})
        .eq('id', id)
        .select()
        .single();
    return Beat.fromJson(row);
  });

  @override
  Future<Beat?> getById(String id) => _guard(() async {
    final row = await _client.from(_table).select().eq('id', id).maybeSingle();
    return row == null ? null : Beat.fromJson(row);
  });

  @override
  Future<List<BeatSummary>> listMine({
    required int offset,
    required int limit,
  }) => _guard(() async {
    final uid = _requireUser();
    final rows = await _client
        .from(_table)
        .select(BeatSummary.columns)
        .eq('creator_id', uid)
        .order('updated_at', ascending: false)
        .range(offset, offset + limit - 1);
    return [for (final r in rows) BeatSummary.fromJson(r)];
  });

  @override
  Future<void> delete(String id, {String? coverPath}) => _guard(() async {
    _requireUser();
    final rows = await _client.from(_table).delete().eq('id', id).select('id');
    if (rows.isEmpty) {
      throw const AppFailure(
        'That beat could not be found.',
        code: 'not_found',
      );
    }
    if (coverPath != null) await removeCover(coverPath);
  });

  @override
  Future<String> uploadCover(
    Uint8List bytes, {
    required String extension,
  }) => _guard(() async {
    final uid = _requireUser();
    final ext = extension.toLowerCase().replaceAll('.', '');
    final contentType = _coverTypes[ext];
    if (contentType == null) {
      throw const AppFailure(
        'Use a PNG, JPG or WebP image.',
        code: 'file_type',
      );
    }
    if (bytes.lengthInBytes > _maxCoverBytes) {
      throw const AppFailure(
        'Cover art must be 5 MB or smaller.',
        code: 'file_too_large',
      );
    }
    final name =
        '${DateTime.now().millisecondsSinceEpoch}-${Random().nextInt(1 << 32).toRadixString(36)}';
    final path = '$uid/$name.$ext';
    await _client.storage
        .from(_coverBucket)
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: contentType),
        );
    return path;
  });

  @override
  Future<void> removeCover(String path) async {
    try {
      await _client.storage.from(_coverBucket).remove([path]);
    } catch (e) {
      // Orphaned files are harmless; never fail the user's action over cleanup.
      if (kDebugMode) debugPrint('removeCover failed: $e');
    }
  }

  @override
  Future<String?> coverUrl(String? path) async {
    if (path == null) return null;
    try {
      return await _client.storage
          .from(_coverBucket)
          .createSignedUrl(path, 3600);
    } catch (e) {
      if (kDebugMode) debugPrint('coverUrl failed: $e');
      return null;
    }
  }
}

/// Used when no Supabase project is configured.
class UnconfiguredBeatRepository implements BeatRepository {
  const UnconfiguredBeatRepository();

  Never _fail() => throw AppFailure.notConfigured;

  @override
  String? get currentUserId => null;
  @override
  Future<Beat> create(BeatInput input) async => _fail();
  @override
  Future<Beat> update(String id, BeatInput input) async => _fail();
  @override
  Future<Beat> createRemix(String sourceId) async => _fail();
  @override
  Future<Beat> setStatus(String id, BeatStatus status) async => _fail();
  @override
  Future<Beat?> getById(String id) async => _fail();
  @override
  Future<List<BeatSummary>> listMine({
    required int offset,
    required int limit,
  }) async => _fail();
  @override
  Future<void> delete(String id, {String? coverPath}) async => _fail();
  @override
  Future<String> uploadCover(
    Uint8List bytes, {
    required String extension,
  }) async => _fail();
  @override
  Future<void> removeCover(String path) async {}
  @override
  Future<String?> coverUrl(String? path) async => null;
}
