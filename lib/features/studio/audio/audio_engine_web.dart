import 'dart:async';
import 'dart:js_interop';

import '../models/beat_pattern.dart';
import 'audio_engine.dart';

/// Typed view of `window.BeatGridAudio` (web/audio/beatgrid_audio_engine.js).
@JS('BeatGridAudio')
extension type _JsEngine._(JSObject _) implements JSObject {
  external JSPromise<JSAny?> init();
  external void play();
  external void pause();
  external void stop();
  external void setBpm(JSNumber bpm);
  external void setPattern(JSString json);
  external void setTrackVolume(JSString track, JSNumber volume);
  external void setTrackMuted(JSString track, JSBoolean muted);
  external void setMasterVolume(JSNumber volume);
  external void setLoop(JSBoolean loop);
  external void preview(JSString track);
  external void setStatusListener(JSFunction? listener);
  external void dispose();
}

@JS('BeatGridAudio')
external _JsEngine? get _globalEngine;

AudioEngine createAudioEngine() => _WebAudioEngine();

class _WebAudioEngine implements AudioEngine {
  final _controller = StreamController<PlaybackStatus>.broadcast();
  PlaybackStatus _status = PlaybackStatus.idle;
  Future<void>? _initFuture;
  bool _disposed = false;

  _JsEngine _engine() {
    final engine = _globalEngine;
    if (engine == null) {
      throw const AudioEngineException('The audio engine script did not load.');
    }
    return engine;
  }

  _JsEngine _ready() {
    if (_status.state == PlaybackState.uninitialized) {
      throw const AudioEngineException('Audio has not been started yet.');
    }
    return _engine();
  }

  T _guard<T>(T Function() body) {
    try {
      return body();
    } on AudioEngineException {
      rethrow;
    } catch (e) {
      throw AudioEngineException('$e');
    }
  }

  @override
  Stream<PlaybackStatus> get status => _controller.stream;

  @override
  PlaybackStatus get currentStatus => _status;

  @override
  Future<void> init() {
    if (_disposed) _disposed = false;
    return _initFuture ??= _initImpl().catchError((Object e) {
      _initFuture = null; // allow retry
      throw e is AudioEngineException ? e : AudioEngineException('$e');
    });
  }

  Future<void> _initImpl() async {
    final engine = _engine();
    await engine.init().toDart;
    // Single listener: the JS side replaces any previous one.
    engine.setStatusListener(
      ((JSString state, JSNumber step) {
        _emit(_parseState(state.toDart), step.toDartInt);
      }).toJS,
    );
    _emit(PlaybackState.stopped, -1);
  }

  PlaybackState _parseState(String s) => switch (s) {
    'playing' => PlaybackState.playing,
    'paused' => PlaybackState.paused,
    'stopped' => PlaybackState.stopped,
    _ => PlaybackState.uninitialized,
  };

  void _emit(PlaybackState state, int step) {
    if (_disposed || _controller.isClosed) return;
    _status = PlaybackStatus(state, step);
    _controller.add(_status);
  }

  @override
  void play() => _guard(() => _ready().play());

  @override
  void pause() => _guard(() => _ready().pause());

  @override
  void stop() => _guard(() => _ready().stop());

  @override
  void setBpm(int bpm) {
    if (bpm < kMinBpm || bpm > kMaxBpm) {
      throw AudioEngineException('BPM must be between $kMinBpm and $kMaxBpm.');
    }
    _guard(() => _ready().setBpm(bpm.toJS));
  }

  @override
  void setPattern(BeatPattern pattern) =>
      _guard(() => _ready().setPattern(pattern.toEngineJson().toJS));

  @override
  void setTrackVolume(TrackId track, double volume) => _guard(
    () => _ready().setTrackVolume(track.key.toJS, volume.clamp(0.0, 1.0).toJS),
  );

  @override
  void setTrackMuted(TrackId track, bool muted) =>
      _guard(() => _ready().setTrackMuted(track.key.toJS, muted.toJS));

  @override
  void setMasterVolume(double volume) =>
      _guard(() => _ready().setMasterVolume(volume.clamp(0.0, 1.0).toJS));

  @override
  void setLoop(bool loop) => _guard(() => _ready().setLoop(loop.toJS));

  @override
  void preview(TrackId track) => _guard(() => _ready().preview(track.key.toJS));

  @override
  void dispose() {
    if (_disposed) return;
    final engine = _globalEngine;
    if (engine != null && _status.state != PlaybackState.uninitialized) {
      try {
        engine.setStatusListener(null);
        engine.dispose();
      } catch (_) {
        // Disposal must never throw into widget teardown.
      }
    }
    _disposed = true;
    _initFuture = null;
    _status = PlaybackStatus.idle;
    if (!_controller.isClosed) _controller.add(_status);
  }
}
