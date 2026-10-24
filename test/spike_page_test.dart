import 'dart:async';

import 'package:beatgrid/features/studio/audio/audio_engine.dart';
import 'package:beatgrid/features/studio/models/beat_pattern.dart';
import 'package:beatgrid/features/studio/presentation/spike_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeEngine implements AudioEngine {
  final calls = <String>[];
  final _c = StreamController<PlaybackStatus>.broadcast();
  PlaybackStatus _s = PlaybackStatus.idle;
  bool failInit = false;

  void _set(PlaybackState st) {
    _s = PlaybackStatus(st, st == PlaybackState.stopped ? -1 : 0);
    _c.add(_s);
  }

  @override
  Stream<PlaybackStatus> get status => _c.stream;
  @override
  PlaybackStatus get currentStatus => _s;
  @override
  Future<void> init() async {
    if (failInit) throw const AudioEngineException('blocked');
    calls.add('init');
    _set(PlaybackState.stopped);
  }

  @override
  void play() {
    calls.add('play');
    _set(PlaybackState.playing);
  }

  @override
  void pause() {
    calls.add('pause');
    _set(PlaybackState.paused);
  }

  @override
  void stop() {
    calls.add('stop');
    _set(PlaybackState.stopped);
  }

  @override
  void setBpm(int bpm) => calls.add('bpm:$bpm');
  @override
  void setPattern(BeatPattern pattern) => calls.add('pattern');
  @override
  void setTrackVolume(TrackId track, double volume) {}
  @override
  void setTrackMuted(TrackId track, bool muted) {}
  @override
  void setMasterVolume(double volume) {}
  @override
  void setLoop(bool loop) => calls.add('loop:$loop');
  @override
  void preview(TrackId track) => calls.add('preview:${track.key}');
  @override
  void dispose() => calls.add('dispose');
}

void main() {
  testWidgets('init, toggle, play, stop, dispose', (tester) async {
    final engine = FakeEngine();
    await tester.pumpWidget(MaterialApp(home: SpikePage(engine: engine)));
    await tester.tap(find.text('Start audio engine'));
    await tester.pumpAndSettle();
    expect(engine.calls, contains('init'));

    await tester.tap(find.byKey(const Key('step-clap-3')));
    await tester.pump();
    expect(engine.calls, containsAllInOrder(['pattern', 'preview:clap']));

    await tester.tap(find.byKey(const Key('play')));
    await tester.pump();
    expect(find.text('State: playing'), findsOneWidget);

    await tester.tap(find.byKey(const Key('bpm-up')));
    await tester.pump();
    expect(engine.calls, contains('bpm:91'));

    await tester.tap(find.byKey(const Key('stop')));
    await tester.pump();
    expect(find.text('State: stopped'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    expect(engine.calls.last, 'dispose');
  });

  testWidgets('shows an error when audio cannot start', (tester) async {
    final engine = FakeEngine()..failInit = true;
    await tester.pumpWidget(MaterialApp(home: SpikePage(engine: engine)));
    await tester.tap(find.text('Start audio engine'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('audio-error')), findsOneWidget);
    expect(find.text('Start audio engine'), findsOneWidget);
  });
}
