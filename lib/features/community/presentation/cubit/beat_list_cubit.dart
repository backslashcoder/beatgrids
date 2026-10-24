import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/errors/app_failure.dart';
import '../../data/community_repository.dart';
import '../../models/public_beat.dart';
import 'engagement.dart';

enum ListStatus { loading, ready, failed }

class BeatListState extends Equatable {
  const BeatListState({
    this.status = ListStatus.loading,
    this.items = const [],
    this.hasMore = false,
    this.loadingMore = false,
    this.error,
    this.message,
  });

  final ListStatus status;
  final List<BeatItem> items;
  final bool hasMore;
  final bool loadingMore;

  /// Why the list could not load.
  final String? error;

  /// Result of the last action (like/save/load more) for a toast.
  final String? message;

  BeatListState copyWith({
    ListStatus? status,
    List<BeatItem>? items,
    bool? hasMore,
    bool? loadingMore,
    String? error,
    String? message,
    bool clearMessage = false,
  }) => BeatListState(
    status: status ?? this.status,
    items: items ?? this.items,
    hasMore: hasMore ?? this.hasMore,
    loadingMore: loadingMore ?? this.loadingMore,
    error: error ?? this.error,
    message: clearMessage ? null : (message ?? this.message),
  );

  @override
  List<Object?> get props => [
    status,
    items,
    hasMore,
    loadingMore,
    error,
    message,
  ];
}

/// A paginated list of public beats. Subclasses say where the beats come from.
///
/// Every reload bumps a generation counter; responses belonging to an older
/// generation are dropped, so a slow request for "tech" can never overwrite the
/// results for "techno".
abstract class BeatListCubit extends Cubit<BeatListState> {
  BeatListCubit(this.repo)
    : engagement = Engagement(repo),
      super(const BeatListState());

  static const pageSize = 20;

  final CommunityRepository repo;
  final Engagement engagement;
  int _generation = 0;

  /// Fetches one page of beats.
  Future<List<PublicBeat>> fetch(int offset, int limit);

  Future<void> reload() async {
    final gen = ++_generation;
    emit(const BeatListState());
    try {
      final beats = await fetch(0, pageSize);
      final items = await _decorate(beats);
      if (isClosed || gen != _generation) return;
      emit(
        BeatListState(
          status: ListStatus.ready,
          items: items,
          hasMore: beats.length == pageSize,
        ),
      );
    } on AppFailure catch (f) {
      if (!isClosed && gen == _generation) {
        emit(BeatListState(status: ListStatus.failed, error: f.message));
      }
    }
  }

  Future<void> loadMore() async {
    if (state.loadingMore || !state.hasMore || state.status != ListStatus.ready)
      return;
    final gen = _generation;
    emit(state.copyWith(loadingMore: true));
    try {
      final beats = await fetch(state.items.length, pageSize);
      final items = await _decorate(beats);
      if (isClosed || gen != _generation) return;
      final known = {for (final i in state.items) i.beat.id};
      emit(
        state.copyWith(
          items: [
            ...state.items,
            for (final i in items)
              if (!known.contains(i.beat.id)) i,
          ],
          hasMore: beats.length == pageSize,
          loadingMore: false,
        ),
      );
    } on AppFailure catch (f) {
      if (!isClosed && gen == _generation) {
        emit(state.copyWith(loadingMore: false, message: f.message));
      }
    }
  }

  /// Adds the viewer's like/save flags and resolved image URLs. Decoration is
  /// best effort: a failure here must not hide the beats themselves.
  Future<List<BeatItem>> _decorate(List<PublicBeat> beats) async {
    if (beats.isEmpty) return const [];
    final ids = [for (final b in beats) b.id];
    final covers = [
      for (final b in beats)
        if (b.coverPath != null) b.coverPath!,
    ];
    final results = await Future.wait<Object>([
      repo.likedAmong(ids).catchError((_) => <String>{}),
      repo.savedAmong(ids).catchError((_) => <String>{}),
      repo.coverUrls(covers).catchError((_) => <String, String>{}),
    ]);
    final liked = results[0] as Set<String>;
    final saved = results[1] as Set<String>;
    final urls = results[2] as Map<String, String>;
    return [
      for (final b in beats)
        BeatItem(
          beat: b,
          liked: liked.contains(b.id),
          saved: saved.contains(b.id),
          coverUrl: b.coverPath == null ? null : urls[b.coverPath],
          avatarUrl: repo.avatarUrl(b.creatorAvatarPath),
        ),
    ];
  }

  void _update(String beatId, BeatItem Function(BeatItem) change) {
    if (isClosed) return;
    emit(
      state.copyWith(
        items: [
          for (final i in state.items) i.beat.id == beatId ? change(i) : i,
        ],
      ),
    );
  }

  void messageShown() => emit(state.copyWith(clearMessage: true));

  Future<void> toggleLike(BeatItem item) async {
    final error = await engagement.setLiked(
      item,
      !item.liked,
      (c) => _update(item.beat.id, c),
    );
    if (error != null && !isClosed) emit(state.copyWith(message: error));
  }

  Future<void> toggleSave(BeatItem item) async {
    final error = await engagement.setSaved(
      item,
      !item.saved,
      (c) => _update(item.beat.id, c),
    );
    if (error != null && !isClosed) emit(state.copyWith(message: error));
    // On the saved list, un-saving removes the row.
    if (error == null && removesWhenUnsaved && item.saved && !isClosed) {
      emit(
        state.copyWith(
          items: [
            for (final i in state.items)
              if (i.beat.id != item.beat.id) i,
          ],
        ),
      );
    }
  }

  /// True for the saved-beats list, where an unsaved beat disappears.
  bool get removesWhenUnsaved => false;
}

/// Latest or trending beats with genre filter and text search.
class ExploreCubit extends BeatListCubit {
  // ignore: prefer_initializing_formals
  ExploreCubit(super.repo, {FeedSort sort = FeedSort.latest}) : _sort = sort;

  FeedSort _sort;
  String? _genre;
  String _query = '';

  FeedSort get sort => _sort;
  String? get genre => _genre;
  String get query => _query;
  bool get hasFilters => _genre != null || _query.isNotEmpty;

  @override
  Future<List<PublicBeat>> fetch(int offset, int limit) => repo.feed(
    sort: _sort,
    genre: _genre,
    query: _query,
    offset: offset,
    limit: limit,
  );

  void setSort(FeedSort sort) {
    if (sort == _sort) return;
    _sort = sort;
    reload();
  }

  void setGenre(String? genre) {
    if (genre == _genre) return;
    _genre = genre;
    reload();
  }

  void setQuery(String query) {
    final cleaned = sanitizeSearch(query);
    if (cleaned == _query) return;
    _query = cleaned;
    reload();
  }

  void clearFilters() {
    if (!hasFilters) return;
    _genre = null;
    _query = '';
    reload();
  }
}

/// A creator's published beats.
class CreatorBeatsCubit extends BeatListCubit {
  CreatorBeatsCubit(super.repo, this.creatorId);

  final String creatorId;

  @override
  Future<List<PublicBeat>> fetch(int offset, int limit) =>
      repo.creatorBeats(creatorId, offset: offset, limit: limit);
}

/// The signed-in user's saved beats, most recently saved first.
class SavedBeatsCubit extends BeatListCubit {
  SavedBeatsCubit(super.repo);

  @override
  bool get removesWhenUnsaved => true;

  @override
  Future<List<PublicBeat>> fetch(int offset, int limit) =>
      repo.savedBeats(offset: offset, limit: limit);
}
