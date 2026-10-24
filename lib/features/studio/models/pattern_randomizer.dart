import 'dart:math';

import 'beat_pattern.dart';

/// Per-genre hit probabilities. Positions are grouped by musical role:
/// downbeat (steps 0,4,8,12), eighth offbeat (2,6,10,14) and sixteenth (odd steps).
class _Style {
  const _Style({
    required this.kick,
    required this.snareBackbeat,
    required this.snareGhost,
    required this.hat,
    required this.openOffbeat,
    required this.openOther,
    required this.clapBackbeat,
    required this.clapOther,
    this.snareSteps = const [4, 12],
    this.fourOnFloor = false,
  });

  /// (downbeat, eighth offbeat, sixteenth)
  final (double, double, double) kick;
  final double snareBackbeat;
  final double snareGhost;

  /// (eighth, sixteenth)
  final (double, double) hat;
  final double openOffbeat;
  final double openOther;
  final double clapBackbeat;
  final double clapOther;
  final List<int> snareSteps;
  final bool fourOnFloor;
}

const _styles = <String, _Style>{
  'hip-hop': _Style(
    kick: (0.55, 0.2, 0.15),
    snareBackbeat: 0.95,
    snareGhost: 0.05,
    hat: (0.85, 0.12),
    openOffbeat: 0.1,
    openOther: 0.03,
    clapBackbeat: 0.2,
    clapOther: 0.0,
  ),
  'boom-bap': _Style(
    kick: (0.5, 0.35, 0.2),
    snareBackbeat: 0.97,
    snareGhost: 0.08,
    hat: (0.7, 0.08),
    openOffbeat: 0.12,
    openOther: 0.05,
    clapBackbeat: 0.25,
    clapOther: 0.0,
  ),
  'trap': _Style(
    kick: (0.45, 0.25, 0.22),
    snareBackbeat: 0.92,
    snareGhost: 0.0,
    snareSteps: [8],
    hat: (0.9, 0.55),
    openOffbeat: 0.1,
    openOther: 0.08,
    clapBackbeat: 0.5,
    clapOther: 0.04,
  ),
  'house': _Style(
    kick: (0.97, 0.0, 0.03),
    snareBackbeat: 0.05,
    snareGhost: 0.02,
    hat: (0.3, 0.2),
    openOffbeat: 0.85,
    openOther: 0.02,
    clapBackbeat: 0.9,
    clapOther: 0.03,
    fourOnFloor: true,
  ),
  'techno': _Style(
    kick: (0.97, 0.0, 0.03),
    snareBackbeat: 0.05,
    snareGhost: 0.03,
    hat: (0.3, 0.75),
    openOffbeat: 0.35,
    openOther: 0.04,
    clapBackbeat: 0.8,
    clapOther: 0.05,
    fourOnFloor: true,
  ),
  'lo-fi': _Style(
    kick: (0.5, 0.25, 0.2),
    snareBackbeat: 0.9,
    snareGhost: 0.05,
    hat: (0.75, 0.1),
    openOffbeat: 0.05,
    openOther: 0.02,
    clapBackbeat: 0.3,
    clapOther: 0.0,
  ),
  'minimal': _Style(
    kick: (0.4, 0.1, 0.05),
    snareBackbeat: 0.4,
    snareGhost: 0.0,
    hat: (0.45, 0.05),
    openOffbeat: 0.08,
    openOther: 0.0,
    clapBackbeat: 0.25,
    clapOther: 0.0,
  ),
};

const _maxHits = <TrackId, int>{
  TrackId.kick: 7,
  TrackId.snare: 4,
  TrackId.closedHat: 14,
  TrackId.openHat: 4,
  TrackId.clap: 4,
};

/// Generates musically reasonable drum grids. Pass a seeded [Random] in tests.
abstract final class PatternRandomizer {
  static const genres = [
    'hip-hop',
    'boom-bap',
    'trap',
    'house',
    'techno',
    'lo-fi',
    'minimal',
  ];

  /// Returns a new pattern (steps only; volumes and mutes are kept from
  /// [current]) that differs from [current] whenever possible.
  static BeatPattern generate({
    required String genre,
    required BeatPattern current,
    Random? random,
  }) {
    final rnd = random ?? Random();
    final style = _styles[genre] ?? _styles['hip-hop']!;
    BeatPattern next = current;
    for (var attempt = 0; attempt < 6; attempt++) {
      next = current.copyWith(tracks: _roll(style, rnd));
      if (!_sameSteps(next, current)) break;
    }
    return next;
  }

  static bool _sameSteps(BeatPattern a, BeatPattern b) =>
      TrackId.values.every((t) {
        for (var i = 0; i < kStepsPerBar; i++) {
          if (a.isActive(t, i) != b.isActive(t, i)) return false;
        }
        return true;
      });

  static Map<TrackId, List<bool>> _roll(_Style s, Random rnd) {
    bool chance(double p) => rnd.nextDouble() < p;
    final kick = List.generate(kStepsPerBar, (i) {
      final p = i % 4 == 0
          ? s.kick.$1
          : i % 4 == 2
          ? s.kick.$2
          : s.kick.$3;
      // Keep the pulse: the first downbeat almost always has a kick.
      return i == 0 ? chance(0.97) : chance(p);
    });
    final snare = List.generate(
      kStepsPerBar,
      (i) => s.snareSteps.contains(i)
          ? chance(s.snareBackbeat)
          : chance(s.snareGhost),
    );
    // Trap/hip-hop use a snare *or* a clap on the backbeat; avoid stacking both most of the time.
    final clap = List.generate(kStepsPerBar, (i) {
      final backbeat = s.snareSteps.contains(i);
      return backbeat ? chance(s.clapBackbeat) : chance(s.clapOther);
    });
    final closed = List.generate(
      kStepsPerBar,
      (i) => chance(i.isEven ? s.hat.$1 : s.hat.$2),
    );
    final open = List.generate(kStepsPerBar, (i) {
      final p = i % 4 == 2 ? s.openOffbeat : s.openOther;
      // Open hat replaces the closed hat on the same step.
      return chance(p);
    });
    for (var i = 0; i < kStepsPerBar; i++) {
      if (open[i]) closed[i] = false;
    }

    if (s.fourOnFloor) {
      for (var i = 0; i < kStepsPerBar; i += 4) {
        kick[i] = true;
      }
    }

    final tracks = {
      TrackId.kick: kick,
      TrackId.snare: snare,
      TrackId.closedHat: closed,
      TrackId.openHat: open,
      TrackId.clap: clap,
    };

    // Guarantees: a pulse, a backbeat, never a wall of hits.
    if (kick.where((v) => v).length < 2) {
      kick[0] = true;
      kick[8] = true;
    }
    if (!snare.contains(true) && !clap.contains(true)) {
      final step = s.snareSteps.first;
      (s.snareBackbeat > 0 ? snare : clap)[step] = true;
    }
    if (!closed.contains(true) && !open.contains(true)) {
      closed[2] = true;
      closed[10] = true;
    }
    for (final entry in tracks.entries) {
      _capHits(entry.value, _maxHits[entry.key]!, rnd);
    }
    return tracks;
  }

  /// Removes random hits (never step 0 of the kick) until the row is within [max].
  static void _capHits(List<bool> row, int max, Random rnd) {
    var hits = [
      for (var i = 0; i < row.length; i++)
        if (row[i]) i,
    ];
    while (hits.length > max) {
      final victim = hits[rnd.nextInt(hits.length)];
      row[victim] = false;
      hits = [
        for (var i = 0; i < row.length; i++)
          if (row[i]) i,
      ];
    }
  }
}
