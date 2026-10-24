import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/errors/app_failure.dart';
import '../../../../core/services/audio_coordinator.dart';
import '../../../studio/audio/audio_engine.dart';
import '../../../studio/models/beat_pattern.dart';
import '../../data/community_repository.dart';
import '../../models/public_beat.dart';

enum PlayerStatus { idle, loading, playing, paused, error }

class PlayerState extends Equatable {
  const PlayerState({
    this.beat,
    this.status = PlayerStatus.idle,
    this.step = -1,
    this.error,
  });

  final PublicBeat? beat;
  final PlayerStatus status;

  /// Current step (0-15) while playing, otherwise -1.
  final int step;
  final String? error;

  bool get isPlaying => status == PlayerStatus.playing;
  bool isCurrent(String beatId) => beat?.id == beatId;

  @override
  List<Object?> get props => [beat, status, step, error];
}

/// The app-wide preview player behind the mini-player. It owns its own
/// [AudioEngine] wrapper only while it is playing, and gives the browser engine
/// up when the studio (or anything else) claims it through [AudioCoordinator].
class PlayerCubit extends Cubit<PlayerState> {
  PlayerCubit(
    this._repo,
    this._coordinator, {
    AudioEngine Function()? engineFactory,
    this.countAfter = const Duration(seconds: 5),
  }) : _engineFactory = engineFactory ?? AudioEngine.new,
       super(const PlayerState());

  final CommunityRepository _repo;
  final AudioCoordinator _coordinator;
  final AudioEngine Function() _engineFactory;

  /// How long a beat must keep playing before the server is asked to count it.
  final Duration countAfter;

  AudioEngine? _engine;
  StreamSubscription<PlaybackStatus>? _sub;
  BeatPattern? _pattern;
  Timer? _countTimer;
  String? _countedBeatId;
  int _request = 0;

  /// Plays [beat]. Pass [pattern] when it is already known (beat page);
  /// otherwise it is fetched. Must run from a user gesture the first time.
  Future<void> play(PublicBeat beat, {BeatPattern? pattern}) async {
    if (state.beat?.id == beat.id) {
      if (state.status == PlayerStatus.playing) return;
      if (state.status == PlayerStatus.paused && _engine != null)
        return resume();
    }
    final request = ++_request;
    _countTimer?.cancel();
    emit(PlayerState(beat: beat, status: PlayerStatus.loading));
    try {
      final resolved =
          pattern ?? (await _repo.detailBySlug(beat.slug))?.pattern;
      if (isClosed || request != _request) return;
      if (resolved == null) {
        emit(
          PlayerState(
            beat: beat,
            status: PlayerStatus.error,
            error: 'This beat is no longer available.',
          ),
        );
        return;
      }
      _pattern = resolved;
      _coordinator.claim(this, onRevoked: _onRevoked);
      final engine = _engine ??= _engineFactory();
      _sub ??= engine.status.listen(_onStatus);
      await engine.init();
      if (isClosed || request != _request) return;
      engine
        ..setPattern(resolved)
        ..setBpm(beat.bpm)
        ..setLoop(true)
        ..setMasterVolume(resolved.masterVolume);
      for (final t in TrackId.values) {
        engine
          ..setTrackVolume(t, resolved.trackVolumes[t]!)
          ..setTrackMuted(t, resolved.mutedTracks.contains(t));
      }
      engine.stop(); // always start from the top
      engine.play();
      _scheduleCount(beat);
    } on AudioEngineException catch (e) {
      if (!isClosed && request == _request) {
        emit(
          PlayerState(beat: beat, status: PlayerStatus.error, error: e.message),
        );
      }
    } on AppFailure catch (f) {
      if (!isClosed && request == _request) {
        emit(
          PlayerState(beat: beat, status: PlayerStatus.error, error: f.message),
        );
      }
    }
  }

  void _onStatus(PlaybackStatus s) {
    if (isClosed || state.beat == null) return;
    switch (s.state) {
      case PlaybackState.playing:
        emit(
          PlayerState(
            beat: state.beat,
            status: PlayerStatus.playing,
            step: s.step,
          ),
        );
      case PlaybackState.paused:
        emit(
          PlayerState(
            beat: state.beat,
            status: PlayerStatus.paused,
            step: s.step,
          ),
        );
      case PlaybackState.stopped:
        // A stop we did not ask for (end of a non-looping bar) leaves it resumable.
        if (state.status == PlayerStatus.playing) {
          emit(PlayerState(beat: state.beat, status: PlayerStatus.paused));
        }
      case PlaybackState.uninitialized:
        break;
    }
  }

  void _scheduleCount(PublicBeat beat) {
    _countTimer?.cancel();
    if (_countedBeatId == beat.id) return;
    _countTimer = Timer(countAfter, () async {
      if (isClosed || !state.isPlaying || state.beat?.id != beat.id) return;
      _countedBeatId = beat.id;
      try {
        await _repo.recordPlay(beat.id);
      } on AppFailure {
        // Play counts are best effort; never interrupt listening over one.
      }
    });
  }

  void pause() {
    if (!state.isPlaying) return;
    try {
      _engine?.pause();
    } on AudioEngineException {
      // The engine was released under us; reflect that.
      emit(PlayerState(beat: state.beat, status: PlayerStatus.paused));
    }
  }

  void resume() {
    final beat = state.beat;
    if (beat == null || state.status != PlayerStatus.paused) return;
    final engine = _engine;
    if (engine == null) {
      // The studio took the engine while we were paused: start the beat again.
      play(beat, pattern: _pattern);
      return;
    }
    _coordinator.claim(this, onRevoked: _onRevoked);
    try {
      engine.play();
      _scheduleCount(beat);
    } on AudioEngineException {
      _releaseEngine(clearBeat: false);
      play(beat, pattern: _pattern);
    }
  }

  void toggle() => state.isPlaying ? pause() : resume();

  /// Stops and hides the mini-player, releasing the audio engine.
  void dismiss() => _releaseEngine(clearBeat: true);

  void _onRevoked() {
    // Someone else (the studio) now owns the engine; step aside quietly.
    _countTimer?.cancel();
    _releaseEngine(clearBeat: false);
    if (!isClosed && state.beat != null) {
      emit(PlayerState(beat: state.beat, status: PlayerStatus.paused));
    }
  }

  void _releaseEngine({required bool clearBeat}) {
    _request++;
    _countTimer?.cancel();
    _sub?.cancel();
    _sub = null;
    final engine = _engine;
    _engine = null;
    if (engine != null) {
      try {
        engine.stop();
      } on AudioEngineException {
        // Already released.
      }
      engine.dispose();
    }
    _coordinator.release(this);
    if (clearBeat && !isClosed) emit(const PlayerState());
  }

  @override
  Future<void> close() {
    _releaseEngine(clearBeat: false);
    return super.close();
  }
}
