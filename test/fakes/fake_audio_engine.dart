import 'dart:async';

import 'package:beatgrid/features/studio/audio/audio_engine.dart';
import 'package:beatgrid/features/studio/models/beat_pattern.dart';

/// Records every command; emits playback status like the real engine does.
class FakeAudioEngine implements AudioEngine {
  final calls = <String>[];
  final patterns = <BeatPattern>[];
  final _c = StreamController<PlaybackStatus>.broadcast();
  PlaybackStatus _s = PlaybackStatus.idle;
  bool failInit = false;
  Completer<void>? initGate;
  int initCount = 0;
  bool disposed = false;

  void _set(PlaybackState st, [int step = -1]) {
    _s = PlaybackStatus(st, step);
    _c.add(_s);
  }

  /// Simulates the engine reporting a step while playing.
  void emitStep(int step) => _set(PlaybackState.playing, step);

  @override
  Stream<PlaybackStatus> get status => _c.stream;
  @override
  PlaybackStatus get currentStatus => _s;

  @override
  Future<void> init() async {
    initCount++;
    await initGate?.future;
    if (failInit)
      throw const AudioEngineException('Audio blocked by the browser.');
    calls.add('init');
    _set(PlaybackState.stopped);
  }

  @override
  void play() {
    calls.add('play');
    _set(PlaybackState.playing, 0);
  }

  @override
  void pause() {
    calls.add('pause');
    _set(PlaybackState.paused, _s.step);
  }

  @override
  void stop() {
    calls.add('stop');
    _set(PlaybackState.stopped);
  }

  @override
  void setBpm(int bpm) => calls.add('bpm:$bpm');
  @override
  void setPattern(BeatPattern pattern) {
    calls.add('pattern');
    patterns.add(pattern);
  }

  @override
  void setTrackVolume(TrackId track, double volume) =>
      calls.add('vol:${track.key}:${volume.toStringAsFixed(2)}');
  @override
  void setTrackMuted(TrackId track, bool muted) =>
      calls.add('mute:${track.key}:$muted');
  @override
  void setMasterVolume(double volume) =>
      calls.add('master:${volume.toStringAsFixed(2)}');
  @override
  void setLoop(bool loop) => calls.add('loop:$loop');
  @override
  void preview(TrackId track) => calls.add('preview:${track.key}');
  @override
  void dispose() {
    disposed = true;
    calls.add('dispose');
  }
}
