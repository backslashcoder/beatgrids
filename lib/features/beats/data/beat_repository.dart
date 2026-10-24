import 'dart:typed_data';

import '../models/beat.dart';

/// Access to the signed-in user's own beats. Implementations throw `AppFailure`
/// with user-safe messages.
abstract class BeatRepository {
  /// Id of the signed-in user, or null.
  String? get currentUserId;

  /// Inserts a new beat for the current user and returns the stored row.
  Future<Beat> create(BeatInput input);

  /// Updates an existing beat (RLS limits this to its owner) and returns it.
  Future<Beat> update(String id, BeatInput input);

  /// Creates an independent private draft copy of a published, remixable beat
  /// for the current user, with attribution to the original. The database
  /// enforces that the source is published and allows remixing.
  Future<Beat> createRemix(String sourceId);

  /// Changes only the publication state.
  Future<Beat> setStatus(String id, BeatStatus status);

  /// Loads a beat the current user may read (own beats, or published ones).
  /// Returns null when it does not exist or is not visible.
  Future<Beat?> getById(String id);

  /// The current user's beats, newest first.
  Future<List<BeatSummary>> listMine({required int offset, required int limit});

  Future<void> delete(String id, {String? coverPath});

  /// Uploads cover art and returns its storage path (`<user id>/<file>`).
  Future<String> uploadCover(Uint8List bytes, {required String extension});

  /// Best-effort removal of an unused cover file.
  Future<void> removeCover(String path);

  /// Short-lived URL for displaying a cover from the private bucket.
  Future<String?> coverUrl(String? path);
}
