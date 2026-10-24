import '../../../../core/errors/app_failure.dart';
import '../../data/community_repository.dart';
import '../../models/public_beat.dart';

/// Applies [update] to the item for one beat, wherever the owner keeps it.
typedef ItemUpdater = void Function(BeatItem Function(BeatItem current) update);

/// Optimistic like/save with server reconciliation, shared by every screen that
/// shows beats. The UI changes immediately; if the server refuses, the change is
/// rolled back and the failure message is returned; on success the public counts
/// are refreshed from the server so they never drift.
class Engagement {
  Engagement(this._repo);

  final CommunityRepository _repo;
  final Set<String> _inFlight = {};

  bool isBusy(String beatId) => _inFlight.contains(beatId);

  /// Returns an error message, or null on success (or when ignored as a repeat tap).
  Future<String?> setLiked(
    BeatItem before,
    bool value,
    ItemUpdater apply,
  ) async {
    final id = before.beat.id;
    if (before.liked == value || !_inFlight.add(id)) return null;
    apply((i) => i.withLiked(value));
    try {
      await _repo.setLiked(id, value);
    } on AppFailure catch (f) {
      apply((i) => i.liked == value ? i.withLiked(!value) : i);
      _inFlight.remove(id);
      return f.message;
    }
    await _reconcile(id, apply);
    _inFlight.remove(id);
    return null;
  }

  Future<String?> setSaved(
    BeatItem before,
    bool value,
    ItemUpdater apply,
  ) async {
    final id = before.beat.id;
    if (before.saved == value || !_inFlight.add('save:$id')) return null;
    apply((i) => i.copyWith(saved: value));
    try {
      await _repo.setSaved(id, value);
    } on AppFailure catch (f) {
      apply((i) => i.saved == value ? i.copyWith(saved: !value) : i);
      _inFlight.remove('save:$id');
      return f.message;
    }
    _inFlight.remove('save:$id');
    return null;
  }

  Future<void> _reconcile(String id, ItemUpdater apply) async {
    try {
      final fresh = await _repo.publicBeatById(id);
      if (fresh == null) return;
      apply(
        (i) => i.copyWith(
          beat: i.beat.copyWith(
            likeCount: fresh.likeCount,
            playCount: fresh.playCount,
          ),
        ),
      );
    } on AppFailure {
      // The optimistic value stays; the next load corrects it.
    }
  }
}
