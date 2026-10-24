import 'audio_engine.dart';
import '../models/beat_pattern.dart';

AudioEngine createAudioEngine() => const _UnavailableAudioEngine();

/// Used on platforms without the browser audio engine (VM tests, desktop).
class _UnavailableAudioEngine implements AudioEngine {
  const _UnavailableAudioEngine();

  static const _error = AudioEngineException(
    'Audio is only available in the browser.',
  );

  @override
  Stream<PlaybackStatus> get status => const Stream.empty();

  @override
  PlaybackStatus get currentStatus => PlaybackStatus.idle;

  @override
  Future<void> init() => Future.error(_error);

  @override
  void play() => throw _error;
  @override
  void pause() => throw _error;
  @override
  void stop() => throw _error;
  @override
  void setBpm(int bpm) => throw _error;
  @override
  void setPattern(BeatPattern pattern) => throw _error;
  @override
  void setTrackVolume(TrackId track, double volume) => throw _error;
  @override
  void setTrackMuted(TrackId track, bool muted) => throw _error;
  @override
  void setMasterVolume(double volume) => throw _error;
  @override
  void setLoop(bool loop) => throw _error;
  @override
  void preview(TrackId track) => throw _error;
  @override
  void dispose() {}
}
