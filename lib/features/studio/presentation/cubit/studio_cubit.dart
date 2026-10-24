import 'dart:async';
import 'dart:math';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/services/audio_coordinator.dart';
import '../../audio/audio_engine.dart';
import '../../models/beat_pattern.dart';
import '../../models/pattern_history.dart';
import '../../models/pattern_randomizer.dart';
import '../../models/starter_patterns.dart';

enum AudioStatus { idle, initializing, ready, failed }

class StudioState extends Equatable {
  StudioState({
    BeatPattern? pattern,
    this.bpm = 120,
    this.loop = true,
    this.genre = 'hip-hop',
    this.starterId,
    this.audio = AudioStatus.idle,
    this.audioError,
    this.playback = PlaybackState.stopped,
    this.step = -1,
    this.canUndo = false,
    this.canRedo = false,
  }) : pattern = pattern ?? BeatPattern.empty();

  final BeatPattern pattern;
  final int bpm;
  final bool loop;

  /// Style used by Randomize; follows the last loaded starter.
  final String genre;

  /// Id of the starter pattern last loaded, if any.
  final String? starterId;
  final AudioStatus audio;
  final String? audioError;
  final PlaybackState playback;

  /// Current step while playing/paused, otherwise -1. Changes ~8-16 times a second.
  final int step;
  final bool canUndo;
  final bool canRedo;

  bool get isPlaying => playback == PlaybackState.playing;

  StudioState copyWith({
    BeatPattern? pattern,
    int? bpm,
    bool? loop,
    String? genre,
    String? starterId,
    bool clearStarter = false,
    AudioStatus? audio,
    String? audioError,
    bool clearAudioError = false,
    PlaybackState? playback,
    int? step,
    bool? canUndo,
    bool? canRedo,
  }) => StudioState(
    pattern: pattern ?? this.pattern,
    bpm: bpm ?? this.bpm,
    loop: loop ?? this.loop,
    genre: genre ?? this.genre,
    starterId: clearStarter ? null : (starterId ?? this.starterId),
    audio: audio ?? this.audio,
    audioError: clearAudioError ? null : (audioError ?? this.audioError),
    playback: playback ?? this.playback,
    step: step ?? this.step,
    canUndo: canUndo ?? this.canUndo,
    canRedo: canRedo ?? this.canRedo,
  );

  @override
  List<Object?> get props => [
    pattern,
    bpm,
    loop,
    genre,
    starterId,
    audio,
    audioError,
    playback,
    step,
    canUndo,
    canRedo,
  ];
}

/// Owns the studio's editable state and the [AudioEngine] lifecycle. Audio
/// scheduling itself happens in the JavaScript engine, never here.
class StudioCubit extends Cubit<StudioState> {
  StudioCubit(this._engine, {Random? random, AudioCoordinator? coordinator})
    : _random = random ?? Random(),
      // ignore: prefer_initializing_formals
      _coordinator = coordinator,
      _history = UndoHistory(BeatPattern.empty()),
      super(StudioState()) {
    _sub = _engine.status.listen(_onPlayback);
  }

  final AudioEngine _engine;
  final AudioCoordinator? _coordinator;
  final Random _random;
  final UndoHistory<BeatPattern> _history;
  StreamSubscription<PlaybackStatus>? _sub;
  Future<void>? _initFuture;

  /// History compares step grids only, so volume/mute tweaks never create entries.
  BeatPattern _gridOf(BeatPattern p) => BeatPattern(tracks: p.tracks);

  void _onPlayback(PlaybackStatus s) {
    if (isClosed) return;
    if (s.state == PlaybackState.uninitialized) return;
    emit(state.copyWith(playback: s.state, step: s.step));
  }

  // --- audio lifecycle -----------------------------------------------------

  /// Starts the audio engine. Must be triggered from a user gesture. Safe to
  /// call repeatedly; concurrent calls share one initialization.
  Future<void> ensureAudio() {
    if (state.audio == AudioStatus.ready) return Future.value();
    return _initFuture ??= _initAudio();
  }

  Future<void> _initAudio() async {
    emit(
      state.copyWith(audio: AudioStatus.initializing, clearAudioError: true),
    );
    try {
      // Takes the engine from the community player if it is playing.
      _coordinator?.claim(this, onRevoked: _onRevoked);
      await _engine.init();
      if (isClosed) return;
      _pushAllToEngine();
      emit(state.copyWith(audio: AudioStatus.ready));
    } on AudioEngineException catch (e) {
      if (!isClosed) {
        emit(state.copyWith(audio: AudioStatus.failed, audioError: e.message));
      }
    } finally {
      _initFuture = null; // allow retry after failure
    }
  }

  void _pushAllToEngine() {
    final p = state.pattern;
    _engine
      ..setPattern(p)
      ..setBpm(state.bpm)
      ..setLoop(state.loop)
      ..setMasterVolume(p.masterVolume);
    for (final t in TrackId.values) {
      _engine
        ..setTrackVolume(t, p.trackVolumes[t]!)
        ..setTrackMuted(t, p.mutedTracks.contains(t));
    }
  }

  /// Another owner (the community player) took the engine: stop and let go;
  /// the next Play re-initializes it.
  void _onRevoked() {
    if (isClosed) return;
    try {
      _engine.stop();
    } on AudioEngineException {
      // Already released.
    }
    _engine.dispose();
    _initFuture = null;
    emit(
      state.copyWith(
        audio: AudioStatus.idle,
        playback: PlaybackState.stopped,
        step: -1,
        clearAudioError: true,
      ),
    );
  }

  bool get _ready => state.audio == AudioStatus.ready;

  /// Runs an engine command if audio is ready; surfaces failures in state.
  void _engineDo(void Function() command) {
    if (!_ready) return;
    try {
      command();
    } on AudioEngineException catch (e) {
      emit(state.copyWith(audioError: e.message));
    }
  }

  // --- transport -----------------------------------------------------------

  Future<void> togglePlay() async {
    if (state.isPlaying) return pause();
    await play();
  }

  Future<void> play() async {
    await ensureAudio();
    _engineDo(_engine.play);
  }

  void pause() => _engineDo(_engine.pause);

  void stop() => _engineDo(_engine.stop);

  void setLoop(bool loop) {
    emit(state.copyWith(loop: loop));
    _engineDo(() => _engine.setLoop(loop));
  }

  void setBpm(num bpm) {
    final value = clampBpm(bpm);
    if (value == state.bpm) return;
    emit(state.copyWith(bpm: value));
    _engineDo(() => _engine.setBpm(value));
  }

  // --- pattern editing -----------------------------------------------------

  void _applyPattern(
    BeatPattern next, {
    bool record = true,
    bool clearStarter = true,
  }) {
    if (record) _history.push(_gridOf(next));
    emit(
      state.copyWith(
        pattern: next,
        clearStarter: clearStarter,
        canUndo: _history.canUndo,
        canRedo: _history.canRedo,
      ),
    );
    _engineDo(() => _engine.setPattern(next));
  }

  void toggleStep(TrackId track, int step) {
    if (step < 0 || step >= kStepsPerBar) return;
    final next = state.pattern.toggleStep(track, step);
    _applyPattern(next);
    // First interaction doubles as the browser's required user gesture.
    if (!_ready) {
      unawaited(ensureAudio());
    } else if (next.isActive(track, step) && !state.isPlaying) {
      _engineDo(() => _engine.preview(track));
    }
  }

  /// Sets a step to [on] without recording history; used while painting by
  /// dragging. Call [commitPaint] when the stroke ends.
  void paintStep(TrackId track, int step, bool on) {
    if (step < 0 ||
        step >= kStepsPerBar ||
        state.pattern.isActive(track, step) == on) {
      return;
    }
    final next = state.pattern.toggleStep(track, step);
    emit(state.copyWith(pattern: next, clearStarter: true));
    _engineDo(() => _engine.setPattern(next));
  }

  void commitPaint() {
    _history.push(_gridOf(state.pattern));
    emit(state.copyWith(canUndo: _history.canUndo, canRedo: _history.canRedo));
  }

  void clearPattern() {
    final cleared = state.pattern.copyWith(tracks: BeatPattern.empty().tracks);
    _applyPattern(cleared);
  }

  void loadStarter(StarterPattern starter) {
    final loaded = starter.toPattern();
    // Keep master volume and mutes; a starter brings its own track mix.
    final next = loaded.copyWith(
      masterVolume: state.pattern.masterVolume,
      mutedTracks: state.pattern.mutedTracks,
    );
    _history.push(_gridOf(next));
    emit(
      state.copyWith(
        pattern: next,
        bpm: starter.bpm,
        genre: starter.genre,
        starterId: starter.id,
        canUndo: _history.canUndo,
        canRedo: _history.canRedo,
      ),
    );
    _engineDo(() {
      _engine.setPattern(next);
      _engine.setBpm(starter.bpm);
      for (final t in TrackId.values) {
        _engine.setTrackVolume(t, next.trackVolumes[t]!);
      }
    });
  }

  void randomize() {
    final next = PatternRandomizer.generate(
      genre: state.genre,
      current: state.pattern,
      random: _random,
    );
    _applyPattern(next);
    if (!_ready) unawaited(ensureAudio());
  }

  /// Replaces everything, e.g. when opening a saved beat. Clears history.
  void loadBeat({
    required BeatPattern pattern,
    required int bpm,
    String? genre,
  }) {
    _history.reset(_gridOf(pattern));
    emit(
      state.copyWith(
        pattern: pattern,
        bpm: clampBpm(bpm),
        genre: genre,
        clearStarter: true,
        canUndo: false,
        canRedo: false,
      ),
    );
    _engineDo(_pushAllToEngine);
  }

  void undo() {
    final grid = _history.undo();
    if (grid == null) return;
    _restoreGrid(grid);
  }

  void redo() {
    final grid = _history.redo();
    if (grid == null) return;
    _restoreGrid(grid);
  }

  void _restoreGrid(BeatPattern grid) {
    final next = state.pattern.copyWith(tracks: grid.tracks);
    _applyPattern(next, record: false);
  }

  // --- mixer ---------------------------------------------------------------

  void setTrackVolume(TrackId track, double volume) {
    final v = volume.clamp(0.0, 1.0).toDouble();
    final next = state.pattern.copyWith(
      trackVolumes: {...state.pattern.trackVolumes, track: v},
    );
    emit(state.copyWith(pattern: next));
    _engineDo(() => _engine.setTrackVolume(track, v));
  }

  void toggleMute(TrackId track) {
    final muted = {...state.pattern.mutedTracks};
    final nowMuted = muted.add(track);
    if (!nowMuted) muted.remove(track);
    emit(state.copyWith(pattern: state.pattern.copyWith(mutedTracks: muted)));
    _engineDo(() => _engine.setTrackMuted(track, nowMuted));
  }

  void setMasterVolume(double volume) {
    final v = volume.clamp(0.0, 1.0).toDouble();
    emit(state.copyWith(pattern: state.pattern.copyWith(masterVolume: v)));
    _engineDo(() => _engine.setMasterVolume(v));
  }

  @override
  Future<void> close() {
    _sub?.cancel();
    _coordinator?.release(this);
    _engine.dispose(); // releases Tone.js nodes and the transport
    return super.close();
  }
}
