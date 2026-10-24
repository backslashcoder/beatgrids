import 'dart:async';

import 'package:flutter/material.dart';

import '../audio/audio_engine.dart';
import '../models/beat_pattern.dart';

/// Phase 1 technical spike: a real 16-step grid wired to the Tone.js engine.
/// Replaced by the full studio (Cubit-driven) in Phase 4.
class SpikePage extends StatefulWidget {
  const SpikePage({super.key, this.engine});

  /// Injectable for tests; defaults to the browser engine.
  final AudioEngine? engine;

  @override
  State<SpikePage> createState() => _SpikePageState();
}

class _SpikePageState extends State<SpikePage> {
  late final AudioEngine _engine = widget.engine ?? AudioEngine();
  StreamSubscription<PlaybackStatus>? _sub;
  PlaybackStatus _status = PlaybackStatus.idle;
  BeatPattern _pattern = _boomBap();
  int _bpm = 90;
  bool _loop = true;
  bool _starting = false;
  String? _error;

  static BeatPattern _boomBap() {
    List<bool> row(List<int> on) => List.generate(16, on.contains);
    return BeatPattern(
      tracks: {
        TrackId.kick: row([0, 7, 10]),
        TrackId.snare: row([4, 12]),
        TrackId.closedHat: row([0, 2, 4, 6, 8, 10, 12, 14]),
        TrackId.openHat: row([15]),
        TrackId.clap: row([]),
      },
    );
  }

  @override
  void initState() {
    super.initState();
    _sub = _engine.status.listen((s) {
      if (mounted) setState(() => _status = s);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _engine.dispose();
    super.dispose();
  }

  void _run(void Function() command) {
    try {
      command();
      if (_error != null) setState(() => _error = null);
    } on AudioEngineException catch (e) {
      setState(() => _error = e.message);
    }
  }

  Future<void> _start() async {
    setState(() {
      _starting = true;
      _error = null;
    });
    try {
      await _engine.init();
      _engine
        ..setPattern(_pattern)
        ..setBpm(_bpm)
        ..setLoop(_loop);
      for (final t in TrackId.values) {
        _engine.setTrackVolume(t, _pattern.trackVolumes[t]!);
      }
      if (mounted) setState(() => _status = _engine.currentStatus);
    } on AudioEngineException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  void _toggle(TrackId track, int step) {
    setState(() => _pattern = _pattern.toggleStep(track, step));
    if (_status.state == PlaybackState.uninitialized) return;
    _run(() {
      _engine.setPattern(_pattern);
      if (_pattern.isActive(track, step) &&
          _status.state != PlaybackState.playing) {
        _engine.preview(track);
      }
    });
  }

  void _setBpm(int bpm) {
    final value = clampBpm(bpm);
    setState(() => _bpm = value);
    if (_status.state != PlaybackState.uninitialized)
      _run(() => _engine.setBpm(value));
  }

  @override
  Widget build(BuildContext context) {
    final ready = _status.state != PlaybackState.uninitialized;
    final playing = _status.state == PlaybackState.playing;
    return Material(
      type: MaterialType.transparency,
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!ready)
                  FilledButton.icon(
                    onPressed: _starting ? null : _start,
                    icon: const Icon(Icons.volume_up),
                    label: Text(
                      _starting ? 'Starting audio...' : 'Start audio engine',
                    ),
                  ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      _error!,
                      key: const Key('audio-error'),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                // Rows keep a usable tap size on narrow screens by scrolling sideways.
                LayoutBuilder(
                  builder: (context, c) {
                    final rows = Column(
                      children: [
                        for (final track in TrackId.values)
                          _TrackRow(
                            track: track,
                            pattern: _pattern,
                            currentStep: _status.step,
                            onToggle: (step) => _toggle(track, step),
                          ),
                      ],
                    );
                    if (c.maxWidth >= 640) return rows;
                    return SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SizedBox(width: 640, child: rows),
                    );
                  },
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    IconButton.filled(
                      key: const Key('play'),
                      tooltip: playing ? 'Pause' : 'Play',
                      onPressed: ready
                          ? () => _run(playing ? _engine.pause : _engine.play)
                          : null,
                      icon: Icon(playing ? Icons.pause : Icons.play_arrow),
                    ),
                    IconButton.outlined(
                      key: const Key('stop'),
                      tooltip: 'Stop',
                      onPressed: ready ? () => _run(_engine.stop) : null,
                      icon: const Icon(Icons.stop),
                    ),
                    FilterChip(
                      label: const Text('Loop'),
                      selected: _loop,
                      onSelected: (v) {
                        setState(() => _loop = v);
                        if (ready) _run(() => _engine.setLoop(v));
                      },
                    ),
                    Text(
                      'State: ${_status.state.name}',
                      key: const Key('state'),
                    ),
                    const SizedBox(width: 16),
                    IconButton(
                      key: const Key('bpm-down'),
                      onPressed: () => _setBpm(_bpm - 1),
                      icon: const Icon(Icons.remove),
                    ),
                    Text('$_bpm BPM', key: const Key('bpm')),
                    IconButton(
                      key: const Key('bpm-up'),
                      onPressed: () => _setBpm(_bpm + 1),
                      icon: const Icon(Icons.add),
                    ),
                    SizedBox(
                      width: 220,
                      child: Slider(
                        min: kMinBpm.toDouble(),
                        max: kMaxBpm.toDouble(),
                        value: _bpm.toDouble(),
                        onChanged: (v) => _setBpm(v.round()),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TrackRow extends StatelessWidget {
  const _TrackRow({
    required this.track,
    required this.pattern,
    required this.currentStep,
    required this.onToggle,
  });

  final TrackId track;
  final BeatPattern pattern;
  final int currentStep;
  final ValueChanged<int> onToggle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(width: 90, child: Text(track.label)),
          for (var i = 0; i < kStepsPerBar; i++) ...[
            if (i > 0 && i % 4 == 0) const SizedBox(width: 8),
            Expanded(
              child: GestureDetector(
                key: Key('step-${track.key}-$i'),
                onTap: () => onToggle(i),
                child: Container(
                  height: 36,
                  margin: const EdgeInsets.all(1.5),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(5),
                    color: pattern.isActive(track, i)
                        ? scheme.primary
                        : scheme.surfaceContainerHighest,
                    border: Border.all(
                      width: 2,
                      color: i == currentStep
                          ? scheme.tertiary
                          : Colors.transparent,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
