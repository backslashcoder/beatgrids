import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/errors/app_failure.dart';
import '../../data/beat_repository.dart';
import '../../models/beat.dart';

enum MyBeatsStatus { loading, ready, failed }

class MyBeatsState extends Equatable {
  const MyBeatsState({
    this.status = MyBeatsStatus.loading,
    this.beats = const [],
    this.hasMore = false,
    this.loadingMore = false,
    this.busyIds = const {},
    this.error,
    this.message,
  });

  final MyBeatsStatus status;
  final List<BeatSummary> beats;
  final bool hasMore;
  final bool loadingMore;

  /// Beats with an action (publish/unpublish/delete) in flight.
  final Set<String> busyIds;

  /// Why the list failed to load.
  final String? error;

  /// Result of the last row action, for a toast.
  final String? message;

  MyBeatsState copyWith({
    MyBeatsStatus? status,
    List<BeatSummary>? beats,
    bool? hasMore,
    bool? loadingMore,
    Set<String>? busyIds,
    String? error,
    String? message,
    bool clearMessage = false,
  }) => MyBeatsState(
    status: status ?? this.status,
    beats: beats ?? this.beats,
    hasMore: hasMore ?? this.hasMore,
    loadingMore: loadingMore ?? this.loadingMore,
    busyIds: busyIds ?? this.busyIds,
    error: error ?? this.error,
    message: clearMessage ? null : (message ?? this.message),
  );

  @override
  List<Object?> get props => [
    status,
    beats,
    hasMore,
    loadingMore,
    busyIds,
    error,
    message,
  ];
}

class MyBeatsCubit extends Cubit<MyBeatsState> {
  MyBeatsCubit(this._repo) : super(const MyBeatsState());

  static const pageSize = 20;
  final BeatRepository _repo;

  Future<void> load() async {
    emit(const MyBeatsState());
    try {
      final rows = await _repo.listMine(offset: 0, limit: pageSize);
      if (isClosed) return;
      emit(
        MyBeatsState(
          status: MyBeatsStatus.ready,
          beats: rows,
          hasMore: rows.length == pageSize,
        ),
      );
    } on AppFailure catch (f) {
      if (!isClosed)
        emit(MyBeatsState(status: MyBeatsStatus.failed, error: f.message));
    }
  }

  Future<void> loadMore() async {
    if (state.loadingMore || !state.hasMore) return;
    emit(state.copyWith(loadingMore: true));
    try {
      final rows = await _repo.listMine(
        offset: state.beats.length,
        limit: pageSize,
      );
      if (isClosed) return;
      emit(
        state.copyWith(
          beats: [...state.beats, ...rows],
          hasMore: rows.length == pageSize,
          loadingMore: false,
        ),
      );
    } on AppFailure catch (f) {
      if (!isClosed)
        emit(state.copyWith(loadingMore: false, message: f.message));
    }
  }

  void messageShown() => emit(state.copyWith(clearMessage: true));

  Future<void> _withBusy(String id, Future<void> Function() action) async {
    if (state.busyIds.contains(id)) return; // no double submits
    emit(state.copyWith(busyIds: {...state.busyIds, id}, clearMessage: true));
    try {
      await action();
    } on AppFailure catch (f) {
      if (!isClosed) emit(state.copyWith(message: f.message));
    } finally {
      if (!isClosed)
        emit(state.copyWith(busyIds: {...state.busyIds}..remove(id)));
    }
  }

  Future<void> setPublished(BeatSummary beat, bool published) =>
      _withBusy(beat.id, () async {
        final updated = await _repo.setStatus(
          beat.id,
          published ? BeatStatus.published : BeatStatus.draft,
        );
        if (isClosed) return;
        emit(
          state.copyWith(
            beats: [
              for (final b in state.beats)
                if (b.id == beat.id)
                  BeatSummary(
                    id: b.id,
                    title: updated.title,
                    slug: updated.slug,
                    genre: updated.genre,
                    bpm: updated.bpm,
                    status: updated.status,
                    allowRemix: updated.allowRemix,
                    coverPath: updated.coverPath,
                    publishedAt: updated.publishedAt,
                    updatedAt: updated.updatedAt,
                  )
                else
                  b,
            ],
            message: published
                ? '"${updated.title}" is now public'
                : '"${updated.title}" moved to drafts',
          ),
        );
      });

  Future<void> delete(BeatSummary beat) => _withBusy(beat.id, () async {
    await _repo.delete(beat.id, coverPath: beat.coverPath);
    if (isClosed) return;
    emit(
      state.copyWith(
        beats: [
          for (final b in state.beats)
            if (b.id != beat.id) b,
        ],
        message: 'Deleted "${beat.title}"',
      ),
    );
  });
}
