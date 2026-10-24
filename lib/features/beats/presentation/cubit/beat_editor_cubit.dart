import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/errors/app_failure.dart';
import '../../../studio/models/beat_pattern.dart';
import '../../../studio/presentation/cubit/studio_cubit.dart';
import '../../data/beat_repository.dart';
import '../../data/pending_draft_store.dart';
import '../../models/beat.dart';
import '../../models/beat_validator.dart';

enum EditorLoad { ready, loading, notFound, forbidden, failed }

enum EditorBusy { none, saving, publishing, unpublishing, deleting, uploading }

class EditorState extends Equatable {
  const EditorState({
    this.beatId,
    this.slug,
    this.status,
    this.title = '',
    this.description = '',
    this.genre = 'hip-hop',
    this.allowRemix = false,
    this.coverPath,
    this.coverUrl,
    this.load = EditorLoad.ready,
    this.loadError,
    this.busy = EditorBusy.none,
    this.dirty = false,
    this.error,
    this.fieldErrors = const {},
    this.deleted = false,
    this.sourceTitle,
    this.sourceCreator,
  });

  /// Null until the beat has been saved for the first time.
  final String? beatId;
  final String? slug;
  final BeatStatus? status;
  final String title;
  final String description;
  final String genre;
  final bool allowRemix;
  final String? coverPath;
  final String? coverUrl;
  final EditorLoad load;
  final String? loadError;
  final EditorBusy busy;

  /// There are changes that exist only in this browser tab.
  final bool dirty;

  /// Message from the last failed action.
  final String? error;
  final Map<BeatField, String> fieldErrors;
  final bool deleted;

  /// Attribution when this beat is a remix: the original's title and creator.
  final String? sourceTitle;
  final String? sourceCreator;

  bool get isRemix => sourceTitle != null;
  bool get isSaved => beatId != null;
  bool get isPublished => status == BeatStatus.published;
  bool get isBusy => busy != EditorBusy.none;

  EditorState copyWith({
    String? beatId,
    String? slug,
    BeatStatus? status,
    String? title,
    String? description,
    String? genre,
    bool? allowRemix,
    String? coverPath,
    bool clearCover = false,
    String? coverUrl,
    EditorLoad? load,
    String? loadError,
    EditorBusy? busy,
    bool? dirty,
    String? error,
    bool clearError = false,
    Map<BeatField, String>? fieldErrors,
    bool? deleted,
  }) => EditorState(
    beatId: beatId ?? this.beatId,
    slug: slug ?? this.slug,
    status: status ?? this.status,
    title: title ?? this.title,
    description: description ?? this.description,
    genre: genre ?? this.genre,
    allowRemix: allowRemix ?? this.allowRemix,
    coverPath: clearCover ? null : (coverPath ?? this.coverPath),
    coverUrl: clearCover ? null : (coverUrl ?? this.coverUrl),
    load: load ?? this.load,
    loadError: loadError ?? this.loadError,
    busy: busy ?? this.busy,
    dirty: dirty ?? this.dirty,
    error: clearError ? null : (error ?? this.error),
    fieldErrors: fieldErrors ?? this.fieldErrors,
    deleted: deleted ?? this.deleted,
    sourceTitle: sourceTitle,
    sourceCreator: sourceCreator,
  );

  @override
  List<Object?> get props => [
    beatId,
    slug,
    status,
    title,
    description,
    genre,
    allowRemix,
    coverPath,
    coverUrl,
    load,
    loadError,
    busy,
    dirty,
    error,
    fieldErrors,
    deleted,
    sourceTitle,
    sourceCreator,
  ];
}

/// Persistence and metadata for the beat open in the studio. The pattern and
/// tempo live in [StudioCubit]; this cubit reads them when saving and watches
/// them to know whether there is unsaved work.
class BeatEditorCubit extends Cubit<EditorState> {
  BeatEditorCubit(this._repo, this._studio, {PendingDraftStore? pending})
    : _pending = pending ?? const PendingDraftStore(),
      super(const EditorState()) {
    _savedSig = _signature();
    _lastPattern = _studio.state.pattern;
    _lastBpm = _studio.state.bpm;
    _sub = _studio.stream.listen(_onStudio);
  }

  final BeatRepository _repo;
  final StudioCubit _studio;
  final PendingDraftStore _pending;
  StreamSubscription<StudioState>? _sub;

  late String _savedSig;
  BeatPattern? _lastPattern;
  int? _lastBpm;
  bool _genreChosen = false;

  /// Cover files uploaded in this session but not yet referenced by a saved beat.
  final List<String> _unsavedCovers = [];

  // --- dirty tracking ------------------------------------------------------

  String _signature({EditorState? s}) {
    final e = s ?? state;
    return jsonEncode({
      't': e.title.trim(),
      'd': e.description.trim(),
      'g': e.genre,
      'r': e.allowRemix,
      'c': e.coverPath,
      'b': _studio.state.bpm,
      'p': _studio.state.pattern.toJson(),
    });
  }

  void _recomputeDirty([EditorState? s]) {
    final dirty = _signature(s: s) != _savedSig;
    if (dirty != (s ?? state).dirty) emit((s ?? state).copyWith(dirty: dirty));
  }

  void _onStudio(StudioState s) {
    if (isClosed) return;
    // Playback emits ~10 events a second; only react to real edits.
    if (identical(s.pattern, _lastPattern) && s.bpm == _lastBpm) return;
    _lastPattern = s.pattern;
    _lastBpm = s.bpm;
    if (!_genreChosen && !state.isSaved && s.genre != state.genre) {
      emit(state.copyWith(genre: s.genre));
    }
    _recomputeDirty();
  }

  // --- metadata edits ------------------------------------------------------

  void setTitle(String v) {
    final next = state.copyWith(
      title: v,
      fieldErrors: _without(BeatField.title),
    );
    emit(next);
    _recomputeDirty();
  }

  void setDescription(String v) {
    emit(
      state.copyWith(
        description: v,
        fieldErrors: _without(BeatField.description),
      ),
    );
    _recomputeDirty();
  }

  void setGenre(String v) {
    _genreChosen = true;
    emit(state.copyWith(genre: v, fieldErrors: _without(BeatField.genre)));
    _recomputeDirty();
  }

  void setAllowRemix(bool v) {
    emit(state.copyWith(allowRemix: v));
    _recomputeDirty();
  }

  Map<BeatField, String> _without(BeatField f) =>
      {...state.fieldErrors}..remove(f);

  void clearError() {
    if (state.error != null) emit(state.copyWith(clearError: true));
  }

  // --- cover art -----------------------------------------------------------

  Future<bool> setCover(Uint8List bytes, String extension) async {
    if (state.isBusy) return false;
    emit(state.copyWith(busy: EditorBusy.uploading, clearError: true));
    try {
      final path = await _repo.uploadCover(bytes, extension: extension);
      final url = await _repo.coverUrl(path);
      // A previous upload that was never saved is now unused.
      final previous = state.coverPath;
      if (previous != null && _unsavedCovers.remove(previous)) {
        unawaited(_repo.removeCover(previous));
      }
      _unsavedCovers.add(path);
      if (isClosed) return true;
      emit(
        state.copyWith(busy: EditorBusy.none, coverPath: path, coverUrl: url),
      );
      _recomputeDirty();
      return true;
    } on AppFailure catch (f) {
      if (!isClosed)
        emit(state.copyWith(busy: EditorBusy.none, error: f.message));
      return false;
    }
  }

  void removeCover() {
    final previous = state.coverPath;
    if (previous != null && _unsavedCovers.remove(previous)) {
      unawaited(_repo.removeCover(previous));
    }
    emit(state.copyWith(clearCover: true));
    _recomputeDirty();
  }

  // --- loading -------------------------------------------------------------

  String? _requestedId;

  Future<void> retryLoad() =>
      _requestedId == null ? Future.value() : load(_requestedId!);

  Future<void> load(String id) async {
    _requestedId = id;
    emit(state.copyWith(load: EditorLoad.loading, clearError: true));
    try {
      final beat = await _repo.getById(id);
      if (isClosed) return;
      if (beat == null) {
        emit(state.copyWith(load: EditorLoad.notFound));
        return;
      }
      if (beat.creatorId != _repo.currentUserId) {
        emit(state.copyWith(load: EditorLoad.forbidden));
        return;
      }
      _genreChosen = true;
      _studio.loadBeat(pattern: beat.pattern, bpm: beat.bpm, genre: beat.genre);
      _lastPattern = _studio.state.pattern;
      _lastBpm = _studio.state.bpm;
      _savedCoverPath = beat.coverPath;
      final url = await _repo.coverUrl(beat.coverPath);
      if (isClosed) return;
      final loaded = _stateFrom(beat, coverUrl: url);
      _savedSig = _signature(s: loaded);
      emit(loaded);
    } on AppFailure catch (f) {
      if (!isClosed)
        emit(state.copyWith(load: EditorLoad.failed, loadError: f.message));
    }
  }

  EditorState _stateFrom(Beat beat, {String? coverUrl}) => EditorState(
    beatId: beat.id,
    slug: beat.slug,
    status: beat.status,
    title: beat.title,
    description: beat.description ?? '',
    genre: beat.genre,
    allowRemix: beat.allowRemix,
    coverPath: beat.coverPath,
    coverUrl: coverUrl,
    sourceTitle: beat.sourceTitle,
    sourceCreator: beat.sourceCreatorUsername,
  );

  /// Brings back an unsaved beat stashed before sign-in. Returns true if one was restored.
  Future<bool> restorePending() async {
    final draft = await _pending.load();
    if (draft == null || isClosed || state.isSaved) return false;
    await _pending.clear();
    _studio.loadBeat(
      pattern: draft.pattern,
      bpm: draft.bpm,
      genre: draft.genre,
    );
    _lastPattern = _studio.state.pattern;
    _lastBpm = _studio.state.bpm;
    _genreChosen = true;
    emit(
      state.copyWith(
        title: draft.title,
        description: draft.description,
        genre: draft.genre,
        allowRemix: draft.allowRemix,
      ),
    );
    _recomputeDirty();
    return true;
  }

  /// Stashes the current work on this device (used before sending the user to sign in).
  Future<void> stashForSignIn() => _pending.save(
    PendingDraft(
      pattern: _studio.state.pattern,
      bpm: _studio.state.bpm,
      title: state.title,
      description: state.description,
      genre: state.genre,
      allowRemix: state.allowRemix,
    ),
  );

  /// Discards the open beat and starts a blank one (the studio resets separately).
  void startNew() {
    _genreChosen = false;
    _savedCoverPath = null;
    for (final path in _unsavedCovers) {
      unawaited(_repo.removeCover(path));
    }
    _unsavedCovers.clear();
    _lastPattern = _studio.state.pattern;
    _lastBpm = _studio.state.bpm;
    emit(const EditorState());
    _savedSig = _signature();
  }

  // --- saving --------------------------------------------------------------

  BeatInput _input(BeatStatus status) => BeatInput(
    title: state.title.trim().isEmpty ? kUntitledBeat : state.title.trim(),
    description: state.description,
    genre: state.genre,
    bpm: _studio.state.bpm,
    pattern: _studio.state.pattern,
    coverPath: state.coverPath,
    allowRemix: state.allowRemix,
    status: status,
  );

  /// Saves without changing publication state (new beats start as drafts).
  Future<bool> save() => _persist(
    status: state.status ?? BeatStatus.draft,
    busy: EditorBusy.saving,
    forPublish: false,
  );

  /// Validates, then saves and publishes in one write.
  Future<bool> publish() => _persist(
    status: BeatStatus.published,
    busy: EditorBusy.publishing,
    forPublish: true,
  );

  Future<bool> unpublish() async {
    final id = state.beatId;
    if (id == null || state.isBusy) return false;
    // Save pending edits and flip to draft in one update.
    return _persist(
      status: BeatStatus.draft,
      busy: EditorBusy.unpublishing,
      forPublish: false,
    );
  }

  Future<bool> _persist({
    required BeatStatus status,
    required EditorBusy busy,
    required bool forPublish,
  }) async {
    if (state.isBusy) return false; // ignore double submits
    final input = _input(status);
    final errors = BeatValidator.validate(input, forPublish: forPublish);
    if (errors.isNotEmpty) {
      emit(state.copyWith(fieldErrors: errors, error: errors.values.first));
      return false;
    }
    final sentSig = _signature(s: state.copyWith(title: input.title));
    final previousCover = state.isSaved ? _savedCoverPath : null;
    emit(state.copyWith(busy: busy, clearError: true, fieldErrors: const {}));
    try {
      final saved = state.beatId == null
          ? await _repo.create(input)
          : await _repo.update(state.beatId!, input);
      if (isClosed) return true;
      _savedSig = sentSig;
      _savedCoverPath = saved.coverPath;
      _unsavedCovers.remove(saved.coverPath);
      if (previousCover != null && previousCover != saved.coverPath) {
        unawaited(_repo.removeCover(previousCover));
      }
      emit(
        state.copyWith(
          busy: EditorBusy.none,
          beatId: saved.id,
          slug: saved.slug,
          status: saved.status,
          title: saved.title,
        ),
      );
      _recomputeDirty();
      return true;
    } on AppFailure catch (f) {
      if (!isClosed)
        emit(state.copyWith(busy: EditorBusy.none, error: f.message));
      return false;
    }
  }

  String? _savedCoverPath;

  Future<bool> delete() async {
    final id = state.beatId;
    if (id == null || state.isBusy) return false;
    emit(state.copyWith(busy: EditorBusy.deleting, clearError: true));
    try {
      await _repo.delete(id, coverPath: _savedCoverPath);
      if (isClosed) return true;
      _savedSig = _signature(); // nothing left to lose
      emit(state.copyWith(busy: EditorBusy.none, deleted: true, dirty: false));
      return true;
    } on AppFailure catch (f) {
      if (!isClosed)
        emit(state.copyWith(busy: EditorBusy.none, error: f.message));
      return false;
    }
  }

  @override
  Future<void> close() {
    _sub?.cancel();
    // Files uploaded but never attached to a saved beat are just clutter.
    for (final path in _unsavedCovers) {
      unawaited(_repo.removeCover(path));
    }
    return super.close();
  }
}
