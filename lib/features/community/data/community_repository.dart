import '../models/public_beat.dart';

/// Read access to the public community plus the signed-in user's likes and
/// saves. Implementations throw `AppFailure` with user-safe messages.
abstract class CommunityRepository {
  String? get currentUserId;

  Future<List<PublicBeat>> feed({
    required FeedSort sort,
    String? genre,
    String? query,
    required int offset,
    required int limit,
  });

  /// A published beat with its pattern, by slug. Null when it does not exist
  /// or is not published.
  Future<PublicBeatDetail?> detailBySlug(String slug);

  /// Fresh public counts for one beat (used to reconcile optimistic updates).
  Future<PublicBeat?> publicBeatById(String id);

  Future<List<PublicBeat>> savedBeats({
    required int offset,
    required int limit,
  });

  Future<CreatorProfile?> creatorByUsername(String username);

  Future<List<PublicBeat>> creatorBeats(
    String creatorId, {
    required int offset,
    required int limit,
  });

  /// Which of [ids] the signed-in user has liked / saved (empty when signed out).
  Future<Set<String>> likedAmong(List<String> ids);
  Future<Set<String>> savedAmong(List<String> ids);

  Future<void> setLiked(String beatId, bool liked);
  Future<void> setSaved(String beatId, bool saved);

  /// Asks the server to count a play. Returns whether it was counted.
  Future<bool> recordPlay(String beatId);

  /// Signed URLs for cover art, keyed by storage path. Missing files are omitted.
  Future<Map<String, String>> coverUrls(List<String> paths);

  String? avatarUrl(String? avatarPath);
}
