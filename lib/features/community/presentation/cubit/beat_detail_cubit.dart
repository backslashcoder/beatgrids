import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/errors/app_failure.dart';
import '../../../studio/models/beat_pattern.dart';
import '../../data/community_repository.dart';
import '../../models/public_beat.dart';
import 'engagement.dart';

enum DetailStatus { loading, ready, notFound, failed }

class BeatDetailState extends Equatable {
  const BeatDetailState({
    this.status = DetailStatus.loading,
    this.item,
    this.pattern,
    this.error,
    this.message,
  });

  final DetailStatus status;
  final BeatItem? item;
  final BeatPattern? pattern;
  final String? error;
  final String? message;

  BeatDetailState copyWith({
    DetailStatus? status,
    BeatItem? item,
    BeatPattern? pattern,
    String? error,
    String? message,
    bool clearMessage = false,
  }) => BeatDetailState(
    status: status ?? this.status,
    item: item ?? this.item,
    pattern: pattern ?? this.pattern,
    error: error ?? this.error,
    message: clearMessage ? null : (message ?? this.message),
  );

  @override
  List<Object?> get props => [status, item, pattern, error, message];
}

/// A single published beat page, loaded by slug.
class BeatDetailCubit extends Cubit<BeatDetailState> {
  BeatDetailCubit(this._repo, this.slug)
    : engagement = Engagement(_repo),
      super(const BeatDetailState());

  final CommunityRepository _repo;
  final String slug;
  final Engagement engagement;

  Future<void> load() async {
    emit(const BeatDetailState());
    try {
      final detail = await _repo.detailBySlug(slug);
      if (isClosed) return;
      if (detail == null) {
        emit(const BeatDetailState(status: DetailStatus.notFound));
        return;
      }
      final b = detail.beat;
      final results = await Future.wait<Object>([
        _repo.likedAmong([b.id]).catchError((_) => <String>{}),
        _repo.savedAmong([b.id]).catchError((_) => <String>{}),
        if (b.coverPath != null)
          _repo.coverUrls([b.coverPath!]).catchError((_) => <String, String>{}),
      ]);
      if (isClosed) return;
      final covers = results.length > 2
          ? results[2] as Map<String, String>
          : const <String, String>{};
      emit(
        BeatDetailState(
          status: DetailStatus.ready,
          pattern: detail.pattern,
          item: BeatItem(
            beat: b,
            liked: (results[0] as Set<String>).contains(b.id),
            saved: (results[1] as Set<String>).contains(b.id),
            coverUrl: b.coverPath == null ? null : covers[b.coverPath],
            avatarUrl: _repo.avatarUrl(b.creatorAvatarPath),
          ),
        ),
      );
    } on AppFailure catch (f) {
      if (!isClosed)
        emit(BeatDetailState(status: DetailStatus.failed, error: f.message));
    }
  }

  void _update(BeatItem Function(BeatItem) change) {
    final item = state.item;
    if (isClosed || item == null) return;
    emit(state.copyWith(item: change(item)));
  }

  void messageShown() => emit(state.copyWith(clearMessage: true));

  Future<void> toggleLike() async {
    final item = state.item;
    if (item == null) return;
    final error = await engagement.setLiked(item, !item.liked, _update);
    if (error != null && !isClosed) emit(state.copyWith(message: error));
  }

  Future<void> toggleSave() async {
    final item = state.item;
    if (item == null) return;
    final error = await engagement.setSaved(item, !item.saved, _update);
    if (error != null && !isClosed) emit(state.copyWith(message: error));
  }
}
