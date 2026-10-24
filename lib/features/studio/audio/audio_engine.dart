import 'dart:async';

import '../models/beat_pattern.dart';
import 'audio_engine_stub.dart'
    if (dart.library.js_interop) 'audio_engine_web.dart'
    as impl;

enum PlaybackState { uninitialized, stopped, playing, paused }

class PlaybackStatus {
  const PlaybackStatus(this.state, this.step);

  static const idle = PlaybackStatus(PlaybackState.uninitialized, -1);

  final PlaybackState state;

  /// Current step (0-15), or -1 when not playing.
  final int step;
}

class AudioEngineException implements Exception {
  const AudioEngineException(this.message);
  final String message;

  @override
  String toString() => 'AudioEngineException: $message';
}

/// The only way the Dart app talks to the browser audio engine.
///
/// All commands validate their input and throw [AudioEngineException] on
/// failure. See docs/AUDIO_ENGINE.md.
abstract class AudioEngine {
  /// The real Tone.js-backed engine on web, an unavailable stub elsewhere.
  factory AudioEngine() => impl.createAudioEngine();

  Stream<PlaybackStatus> get status;
  PlaybackStatus get currentStatus;

  /// Starts the audio context and builds the sounds. Call from a user gesture.
  Future<void> init();

  void play();
  void pause();
  void stop();
  void setBpm(int bpm);
  void setPattern(BeatPattern pattern);
  void setTrackVolume(TrackId track, double volume);
  void setTrackMuted(TrackId track, bool muted);
  void setMasterVolume(double volume);
  void setLoop(bool loop);

  /// Plays one hit of [track] right now (audition when editing).
  void preview(TrackId track);

  /// Releases audio resources and listeners. [init] may be called again.
  void dispose();
}
