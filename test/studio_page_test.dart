import 'package:beatgrid/app/theme/app_theme.dart';
import 'package:beatgrid/features/studio/models/beat_pattern.dart';
import 'package:beatgrid/features/studio/presentation/studio_page.dart';
import 'package:beatgrid/features/studio/presentation/widgets/mixer_panel.dart';
import 'package:beatgrid/features/studio/presentation/widgets/sequencer_grid.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes/fake_audio_engine.dart';

Future<void> pumpStudio(
  WidgetTester tester,
  FakeAudioEngine engine, {
  Size size = const Size(1280, 1000),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.dark,
      home: Scaffold(body: StudioPage(engine: engine)),
    ),
  );
  await tester.pump();
}

Future<void> settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

Finder step(String track, int n) => find.bySemanticsLabel('$track step $n');

void main() {
  testWidgets('renders 5 tracks of 16 steps and the transport', (tester) async {
    await pumpStudio(tester, FakeAudioEngine());
    for (final t in TrackId.values) {
      expect(step(t.label, 1), findsOneWidget);
      expect(step(t.label, 16), findsOneWidget);
    }
    expect(find.byKey(const Key('transport-play')), findsOneWidget);
    expect(find.text('Stopped'), findsOneWidget);
    expect(find.textContaining('Sound turns on'), findsOneWidget);
  });

  testWidgets('tapping a step toggles it and starts audio', (tester) async {
    final engine = FakeAudioEngine();
    await pumpStudio(tester, engine);
    await tester.tap(step('Kick', 1));
    await settle(tester);
    expect(engine.calls, contains('init'));
    expect(engine.patterns.last.isActive(TrackId.kick, 0), isTrue);
    await tester.tap(step('Kick', 1));
    await settle(tester);
    expect(engine.patterns.last.isActive(TrackId.kick, 0), isFalse);
  });

  testWidgets('play, pause and stop show distinct states', (tester) async {
    final engine = FakeAudioEngine();
    await pumpStudio(tester, engine);
    await tester.tap(find.byKey(const Key('transport-play')));
    await settle(tester);
    expect(find.text('Playing'), findsOneWidget);
    await tester.tap(find.byKey(const Key('transport-play')));
    await settle(tester);
    expect(find.text('Paused'), findsOneWidget);
    await tester.tap(find.byKey(const Key('transport-stop')));
    await settle(tester);
    expect(find.text('Stopped'), findsOneWidget);
    expect(engine.calls, containsAllInOrder(['play', 'pause', 'stop']));
  });

  testWidgets('space bar toggles playback', (tester) async {
    final engine = FakeAudioEngine();
    await pumpStudio(tester, engine);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await settle(tester);
    expect(engine.calls, contains('play'));
  });

  testWidgets('ctrl+z undoes a step', (tester) async {
    final engine = FakeAudioEngine();
    await pumpStudio(tester, engine);
    await tester.tap(step('Snare', 5));
    await settle(tester);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await settle(tester);
    expect(engine.patterns.last.isActive(TrackId.snare, 4), isFalse);
  });

  testWidgets('tempo buttons, field and bounds', (tester) async {
    final engine = FakeAudioEngine();
    await pumpStudio(tester, engine);
    await tester.tap(find.byKey(const Key('transport-play')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('bpm-up')));
    await settle(tester);
    expect(engine.calls, contains('bpm:121'));

    await tester.enterText(find.byKey(const Key('bpm-field')), '150');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await settle(tester);
    expect(engine.calls, contains('bpm:150'));

    // Invalid entry reverts to the current tempo and never reaches the engine.
    await tester.enterText(find.byKey(const Key('bpm-field')), '999');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await settle(tester);
    expect(engine.calls.where((c) => c == 'bpm:999'), isEmpty);
    expect(find.widgetWithText(TextField, '150'), findsOneWidget);
  });

  testWidgets('mute toggles the track', (tester) async {
    final engine = FakeAudioEngine();
    await pumpStudio(tester, engine);
    await tester.tap(find.byKey(const Key('transport-play')));
    await settle(tester);
    await tester.tap(find.byTooltip('Mute Kick'));
    await settle(tester);
    expect(engine.calls, contains('mute:kick:true'));
    expect(find.byTooltip('Unmute Kick'), findsOneWidget);
  });

  testWidgets('starter menu loads a real pattern and tempo', (tester) async {
    final engine = FakeAudioEngine();
    await pumpStudio(tester, engine);
    await tester.tap(find.byKey(const Key('starter-menu')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('starter-trap-starter')));
    await settle(tester);
    expect(find.text('Trap Starter'), findsOneWidget);
    expect(find.widgetWithText(TextField, '140'), findsOneWidget);
  });

  testWidgets(
    'randomize fills the grid; clear asks first and undo brings it back',
    (tester) async {
      final engine = FakeAudioEngine();
      await pumpStudio(tester, engine);
      await tester.tap(find.byKey(const Key('randomize')));
      await settle(tester);
      expect(engine.patterns.last.isEmpty, isFalse);
      final randomized = engine.patterns.last;

      await tester.tap(find.byKey(const Key('clear')));
      await settle(tester);
      expect(find.text('Clear the pattern?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await settle(tester);
      expect(engine.patterns.last, randomized);

      await tester.tap(find.byKey(const Key('clear')));
      await settle(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Clear'));
      await settle(tester);
      expect(engine.patterns.last.isEmpty, isTrue);

      await tester.tap(find.byKey(const Key('undo')));
      await settle(tester);
      expect(engine.patterns.last.toEngineJson(), randomized.toEngineJson());
    },
  );

  testWidgets('audio failure is explained and retry recovers', (tester) async {
    final engine = FakeAudioEngine()..failInit = true;
    await pumpStudio(tester, engine);
    await tester.tap(find.byKey(const Key('transport-play')));
    await settle(tester);
    expect(find.text('Audio blocked by the browser.'), findsOneWidget);
    engine.failInit = false;
    await tester.tap(find.byKey(const Key('audio-retry')));
    await settle(tester);
    expect(find.text('Audio blocked by the browser.'), findsNothing);
  });

  testWidgets('leaving the studio disposes the engine', (tester) async {
    final engine = FakeAudioEngine();
    await pumpStudio(tester, engine);
    await tester.tap(find.byKey(const Key('transport-play')));
    await settle(tester);
    await tester.pumpWidget(const SizedBox());
    expect(engine.disposed, isTrue);
  });

  testWidgets(
    'desktop layout has per-track volume, mobile moves it to a mixer',
    (tester) async {
      await pumpStudio(tester, FakeAudioEngine());
      expect(find.text('Mixer'), findsNothing);
      Finder slidersIn(Type t) =>
          find.descendant(of: find.byType(t), matching: find.byType(Slider));
      expect(slidersIn(SequencerGrid), findsNWidgets(5));
      await pumpStudio(tester, FakeAudioEngine(), size: const Size(375, 900));
      await tester.pump();
      expect(find.text('Mixer'), findsOneWidget);
      expect(slidersIn(SequencerGrid), findsNothing);
      expect(slidersIn(MixerPanel), findsNWidgets(5));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('tablet width scrolls the grid instead of overflowing', (
    tester,
  ) async {
    await pumpStudio(tester, FakeAudioEngine(), size: const Size(768, 1000));
    expect(tester.takeException(), isNull);
    expect(step('Clap', 16), findsOneWidget);
  });
}
