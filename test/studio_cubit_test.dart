import 'dart:math';

import 'package:beatgrid/features/studio/audio/audio_engine.dart';
import 'package:beatgrid/features/studio/models/beat_pattern.dart';
import 'package:beatgrid/features/studio/models/starter_patterns.dart';
import 'package:beatgrid/features/studio/presentation/cubit/studio_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes/fake_audio_engine.dart';

Future<void> flush() => Future<void>.delayed(Duration.zero);

Future<(StudioCubit, FakeAudioEngine)> readyCubit() async {
  final engine = FakeAudioEngine();
  final cubit = StudioCubit(engine, random: Random(1));
  await cubit.ensureAudio();
  await flush();
  engine.calls.clear();
  return (cubit, engine);
}

void main() {
  group('editing and history', () {
    test('toggling a step and undo/redo', () async {
      final (cubit, _) = await readyCubit();
      cubit.toggleStep(TrackId.kick, 0);
      expect(cubit.state.pattern.isActive(TrackId.kick, 0), isTrue);
      expect(cubit.state.canUndo, isTrue);
      cubit.undo();
      expect(cubit.state.pattern.isActive(TrackId.kick, 0), isFalse);
      expect(cubit.state.canRedo, isTrue);
      cubit.redo();
      expect(cubit.state.pattern.isActive(TrackId.kick, 0), isTrue);
    });

    test('undo/redo cover clear, starter load and randomize', () async {
      final (cubit, _) = await readyCubit();
      cubit.loadStarter(starterById('boom-bap')!);
      final loaded = cubit.state.pattern.toEngineJson();
      cubit.clearPattern();
      expect(cubit.state.pattern.isEmpty, isTrue);
      cubit.undo();
      expect(cubit.state.pattern.toEngineJson(), loaded);
      cubit.randomize();
      final randomized = cubit.state.pattern.toEngineJson();
      expect(randomized, isNot(loaded));
      cubit.undo();
      expect(cubit.state.pattern.toEngineJson(), loaded);
      cubit.redo();
      expect(cubit.state.pattern.toEngineJson(), randomized);
      cubit.undo();
      cubit.undo();
      cubit.undo();
      expect(cubit.state.pattern.isEmpty, isTrue);
      expect(cubit.state.canUndo, isFalse);
    });

    test('undo restores steps but not the mixer', () async {
      final (cubit, _) = await readyCubit();
      cubit.toggleStep(TrackId.snare, 4);
      cubit.setTrackVolume(TrackId.snare, 0.2);
      cubit.toggleMute(TrackId.clap);
      cubit.undo();
      expect(cubit.state.pattern.isActive(TrackId.snare, 4), isFalse);
      expect(cubit.state.pattern.trackVolumes[TrackId.snare], 0.2);
      expect(cubit.state.pattern.mutedTracks, {TrackId.clap});
    });

    test('volume, mute and tempo changes create no history entries', () async {
      final (cubit, _) = await readyCubit();
      cubit.setTrackVolume(TrackId.kick, 0.1);
      cubit.toggleMute(TrackId.kick);
      cubit.setMasterVolume(0.3);
      cubit.setBpm(100);
      cubit.setLoop(false);
      expect(cubit.state.canUndo, isFalse);
    });

    test('clearing an already empty pattern is not a history entry', () async {
      final (cubit, _) = await readyCubit();
      cubit.clearPattern();
      expect(cubit.state.canUndo, isFalse);
    });

    test('a drag-paint stroke is one undo step', () async {
      final (cubit, _) = await readyCubit();
      for (var i = 0; i < 6; i++) {
        cubit.paintStep(TrackId.closedHat, i, true);
      }
      cubit.commitPaint();
      expect(
        cubit.state.pattern.tracks[TrackId.closedHat]!.where((v) => v).length,
        6,
      );
      cubit.undo();
      expect(cubit.state.pattern.isEmpty, isTrue);
      expect(cubit.state.canUndo, isFalse);
    });

    test('history size is bounded', () async {
      final (cubit, _) = await readyCubit();
      for (var i = 0; i < 80; i++) {
        cubit.toggleStep(TrackId.kick, i % 16);
        cubit.toggleStep(TrackId.snare, (i * 3) % 16);
      }
      var undone = 0;
      while (cubit.state.canUndo) {
        cubit.undo();
        undone++;
      }
      expect(undone, lessThanOrEqualTo(50));
    });

    test('out-of-range steps are ignored', () async {
      final (cubit, _) = await readyCubit();
      cubit.toggleStep(TrackId.kick, 16);
      cubit.toggleStep(TrackId.kick, -1);
      expect(cubit.state.pattern.isEmpty, isTrue);
    });

    test('editing a starter clears the starter marker', () async {
      final (cubit, _) = await readyCubit();
      cubit.loadStarter(starterById('house-groove')!);
      expect(cubit.state.starterId, 'house-groove');
      cubit.toggleStep(TrackId.kick, 1);
      expect(cubit.state.starterId, isNull);
      expect(cubit.state.genre, 'house'); // randomize still follows the style
    });
  });

  group('starters', () {
    test(
      'loading a starter sets tempo and genre and pushes to the engine',
      () async {
        final (cubit, engine) = await readyCubit();
        cubit.setMasterVolume(0.4);
        cubit.toggleMute(TrackId.clap);
        engine.calls.clear();
        cubit.loadStarter(starterById('trap-starter')!);
        expect(cubit.state.bpm, 140);
        expect(cubit.state.genre, 'trap');
        expect(cubit.state.pattern.masterVolume, 0.4);
        expect(cubit.state.pattern.mutedTracks, {TrackId.clap});
        expect(engine.calls, containsAll(['pattern', 'bpm:140']));
      },
    );
  });

  group('transport and audio lifecycle', () {
    test('nothing touches the engine until audio is started', () async {
      final engine = FakeAudioEngine();
      final cubit = StudioCubit(engine);
      cubit.setBpm(100);
      cubit.setTrackVolume(TrackId.kick, 0.5);
      cubit.setLoop(false);
      expect(engine.calls, isEmpty);
      expect(cubit.state.audio, AudioStatus.idle);
    });

    test('play initializes once, syncs all state, then plays', () async {
      final engine = FakeAudioEngine();
      final cubit = StudioCubit(engine);
      cubit.setBpm(100);
      cubit.toggleMute(TrackId.openHat);
      await cubit.play();
      await flush();
      expect(engine.calls.first, 'init');
      expect(
        engine.calls,
        containsAll([
          'pattern',
          'bpm:100',
          'loop:true',
          'mute:open_hat:true',
          'play',
        ]),
      );
      expect(
        engine.calls.indexOf('pattern'),
        lessThan(engine.calls.indexOf('play')),
      );
      expect(cubit.state.audio, AudioStatus.ready);
      expect(cubit.state.isPlaying, isTrue);
    });

    test('concurrent starts share one initialization', () async {
      final engine = FakeAudioEngine();
      final cubit = StudioCubit(engine);
      await Future.wait([
        cubit.ensureAudio(),
        cubit.ensureAudio(),
        cubit.play(),
      ]);
      expect(engine.initCount, 1);
    });

    test('pause keeps the position, stop resets it', () async {
      final (cubit, engine) = await readyCubit();
      await cubit.play();
      engine.emitStep(5);
      await flush();
      expect(cubit.state.step, 5);
      cubit.pause();
      await flush();
      expect(cubit.state.playback, PlaybackState.paused);
      expect(cubit.state.step, 5);
      await cubit.togglePlay();
      await flush();
      expect(cubit.state.isPlaying, isTrue);
      cubit.stop();
      await flush();
      expect(cubit.state.playback, PlaybackState.stopped);
      expect(cubit.state.step, -1);
    });

    test('togglePlay pauses when playing', () async {
      final (cubit, engine) = await readyCubit();
      await cubit.togglePlay();
      await flush();
      await cubit.togglePlay();
      await flush();
      expect(engine.calls, containsAllInOrder(['play', 'pause']));
    });

    test('init failure is reported and retry works', () async {
      final engine = FakeAudioEngine()..failInit = true;
      final cubit = StudioCubit(engine);
      await cubit.play();
      expect(cubit.state.audio, AudioStatus.failed);
      expect(cubit.state.audioError, 'Audio blocked by the browser.');
      expect(engine.calls, isNot(contains('play')));
      engine.failInit = false;
      await cubit.ensureAudio();
      expect(cubit.state.audio, AudioStatus.ready);
      expect(cubit.state.audioError, isNull);
    });

    test(
      'first step tap doubles as the audio-starting gesture and previews later',
      () async {
        final engine = FakeAudioEngine();
        final cubit = StudioCubit(engine);
        cubit.toggleStep(TrackId.kick, 0);
        await flush();
        await flush();
        expect(cubit.state.audio, AudioStatus.ready);
        expect(engine.patterns.last.isActive(TrackId.kick, 0), isTrue);
        engine.calls.clear();
        cubit.toggleStep(TrackId.snare, 4);
        expect(engine.calls, contains('preview:snare'));
        cubit.toggleStep(TrackId.snare, 4); // turning off: silent
        expect(engine.calls.where((c) => c.startsWith('preview')).length, 1);
      },
    );

    test('no preview while playing', () async {
      final (cubit, engine) = await readyCubit();
      await cubit.play();
      await flush();
      engine.calls.clear();
      cubit.toggleStep(TrackId.snare, 4);
      expect(engine.calls, ['pattern']);
    });

    test('pattern edits reach the engine during playback', () async {
      final (cubit, engine) = await readyCubit();
      await cubit.play();
      engine.patterns.clear();
      cubit.toggleStep(TrackId.clap, 12);
      expect(engine.patterns.single.isActive(TrackId.clap, 12), isTrue);
    });

    test('closing the cubit disposes the engine and listeners', () async {
      final (cubit, engine) = await readyCubit();
      await cubit.close();
      expect(engine.disposed, isTrue);
    });

    test('a new studio after leaving gets its own fresh engine', () async {
      final (first, engineA) = await readyCubit();
      await first.play();
      await first.close();
      final engineB = FakeAudioEngine();
      final second = StudioCubit(engineB);
      expect(second.state.isPlaying, isFalse);
      await second.play();
      expect(engineA.calls.where((c) => c == 'play').length, 1);
      expect(engineB.calls.where((c) => c == 'play').length, 1);
    });
  });

  group('tempo and mixer', () {
    test('tempo is clamped to 60-180 before reaching the engine', () async {
      final (cubit, engine) = await readyCubit();
      cubit.setBpm(500);
      expect(cubit.state.bpm, 180);
      cubit.setBpm(3);
      expect(cubit.state.bpm, 60);
      cubit.setBpm(120.4);
      expect(cubit.state.bpm, 120);
      expect(engine.calls.where((c) => c.startsWith('bpm')), [
        'bpm:180',
        'bpm:60',
        'bpm:120',
      ]);
    });

    test('same tempo is not re-sent', () async {
      final (cubit, engine) = await readyCubit();
      cubit.setBpm(120);
      expect(engine.calls, isEmpty);
    });

    test('volumes are clamped and affect the engine', () async {
      final (cubit, engine) = await readyCubit();
      cubit.setTrackVolume(TrackId.kick, 3);
      cubit.setTrackVolume(TrackId.snare, -2);
      cubit.setMasterVolume(9);
      expect(cubit.state.pattern.trackVolumes[TrackId.kick], 1.0);
      expect(cubit.state.pattern.trackVolumes[TrackId.snare], 0.0);
      expect(cubit.state.pattern.masterVolume, 1.0);
      expect(
        engine.calls,
        containsAll(['vol:kick:1.00', 'vol:snare:0.00', 'master:1.00']),
      );
    });

    test('mute toggles and reaches the engine', () async {
      final (cubit, engine) = await readyCubit();
      cubit.toggleMute(TrackId.clap);
      expect(cubit.state.pattern.mutedTracks, {TrackId.clap});
      cubit.toggleMute(TrackId.clap);
      expect(cubit.state.pattern.mutedTracks, isEmpty);
      expect(engine.calls, ['mute:clap:true', 'mute:clap:false']);
    });

    test('loop toggles', () async {
      final (cubit, engine) = await readyCubit();
      cubit.setLoop(false);
      expect(cubit.state.loop, isFalse);
      expect(engine.calls, ['loop:false']);
    });
  });

  test('loadBeat replaces everything and clears history', () async {
    final (cubit, engine) = await readyCubit();
    cubit.toggleStep(TrackId.kick, 3);
    final saved = starterById('minimal-beat')!.toPattern();
    cubit.loadBeat(pattern: saved, bpm: 118, genre: 'minimal');
    expect(cubit.state.pattern, saved);
    expect(cubit.state.bpm, 118);
    expect(cubit.state.canUndo, isFalse);
    expect(engine.calls, containsAll(['pattern', 'bpm:118']));
  });
}
