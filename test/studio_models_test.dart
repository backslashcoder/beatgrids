import 'dart:math';

import 'package:beatgrid/features/studio/models/beat_pattern.dart';
import 'package:beatgrid/features/studio/models/pattern_history.dart';
import 'package:beatgrid/features/studio/models/pattern_randomizer.dart';
import 'package:beatgrid/features/studio/models/starter_patterns.dart';
import 'package:flutter_test/flutter_test.dart';

int hits(BeatPattern p, TrackId t) => p.tracks[t]!.where((v) => v).length;

void main() {
  group('starter patterns', () {
    test('are distinct, valid and real', () {
      expect(starterPatterns.length, 7);
      expect({for (final p in starterPatterns) p.id}.length, 7);
      expect({for (final p in starterPatterns) p.name}.length, 7);
      const dbGenres = {
        'hip-hop',
        'boom-bap',
        'trap',
        'house',
        'techno',
        'lo-fi',
        'minimal',
        'other',
      };
      final seen = <String>{};
      for (final s in starterPatterns) {
        final pattern = s.toPattern();
        expect(s.bpm, inInclusiveRange(kMinBpm, kMaxBpm), reason: s.name);
        expect(dbGenres, contains(s.genre), reason: s.name);
        expect(pattern.isEmpty, isFalse, reason: s.name);
        expect(hits(pattern, TrackId.kick), greaterThan(0), reason: s.name);
        // Survives the same validation the database applies.
        expect(BeatPattern.fromJson(pattern.toJson()), pattern);
        expect(
          seen.add(pattern.toEngineJson()),
          isTrue,
          reason: '${s.name} duplicates another pattern',
        );
      }
    });

    test('names match the brief', () {
      expect(
        starterPatterns.map((p) => p.name),
        containsAll([
          'Classic Hip-Hop',
          'Boom Bap',
          'Trap Starter',
          'House Groove',
          'Techno Pulse',
          'Lo-fi Groove',
          'Minimal Beat',
        ]),
      );
    });

    test('house and techno are four on the floor', () {
      for (final id in ['house-groove', 'techno-pulse']) {
        expect(starterById(id)!.steps[TrackId.kick], [0, 4, 8, 12]);
      }
    });

    test('lo-fi ships a quieter mix', () {
      final p = starterById('lo-fi-groove')!.toPattern();
      expect(
        p.trackVolumes[TrackId.closedHat]!,
        lessThan(BeatPattern.defaultVolumes[TrackId.closedHat]!),
      );
    });
  });

  group('PatternRandomizer', () {
    test('respects musical invariants for every style', () {
      for (final genre in PatternRandomizer.genres) {
        for (var seed = 0; seed < 300; seed++) {
          final p = PatternRandomizer.generate(
            genre: genre,
            current: BeatPattern.empty(),
            random: Random(seed),
          );
          final ctx = '$genre seed $seed';
          expect(hits(p, TrackId.kick), inInclusiveRange(2, 7), reason: ctx);
          expect(hits(p, TrackId.snare), lessThanOrEqualTo(4), reason: ctx);
          expect(hits(p, TrackId.clap), lessThanOrEqualTo(4), reason: ctx);
          expect(hits(p, TrackId.openHat), lessThanOrEqualTo(4), reason: ctx);
          expect(
            hits(p, TrackId.closedHat),
            lessThanOrEqualTo(14),
            reason: ctx,
          );
          expect(
            hits(p, TrackId.snare) + hits(p, TrackId.clap),
            greaterThan(0),
            reason: '$ctx has no backbeat',
          );
          for (var i = 0; i < kStepsPerBar; i++) {
            expect(
              p.isActive(TrackId.openHat, i) &&
                  p.isActive(TrackId.closedHat, i),
              isFalse,
              reason: '$ctx step $i',
            );
          }
          // Never a wall of hits.
          final total = TrackId.values.fold<int>(0, (a, t) => a + hits(p, t));
          expect(total, lessThan(48), reason: ctx);
        }
      }
    });

    test('house and techno keep a four-on-the-floor kick', () {
      for (final genre in ['house', 'techno']) {
        for (var seed = 0; seed < 100; seed++) {
          final p = PatternRandomizer.generate(
            genre: genre,
            current: BeatPattern.empty(),
            random: Random(seed),
          );
          for (final step in [0, 4, 8, 12]) {
            expect(
              p.isActive(TrackId.kick, step),
              isTrue,
              reason: '$genre seed $seed step $step',
            );
          }
        }
      }
    });

    test('trap uses a half-time backbeat, not 2 and 4', () {
      var halfTime = 0;
      for (var seed = 0; seed < 100; seed++) {
        final p = PatternRandomizer.generate(
          genre: 'trap',
          current: BeatPattern.empty(),
          random: Random(seed),
        );
        if (p.isActive(TrackId.snare, 8)) halfTime++;
        expect(p.isActive(TrackId.snare, 4), isFalse);
        expect(p.isActive(TrackId.snare, 12), isFalse);
      }
      expect(halfTime, greaterThan(80));
    });

    test('is deterministic for a seed and varies across seeds', () {
      PatternRandomizer.generate(
        genre: 'hip-hop',
        current: BeatPattern.empty(),
        random: Random(7),
      );
      final a = PatternRandomizer.generate(
        genre: 'hip-hop',
        current: BeatPattern.empty(),
        random: Random(7),
      );
      final b = PatternRandomizer.generate(
        genre: 'hip-hop',
        current: BeatPattern.empty(),
        random: Random(7),
      );
      expect(a, b);
      final distinct = {
        for (var s = 0; s < 40; s++)
          PatternRandomizer.generate(
            genre: 'hip-hop',
            current: BeatPattern.empty(),
            random: Random(s),
          ).toEngineJson(),
      };
      expect(distinct.length, greaterThan(30));
    });

    test(
      'returns a different pattern from the current one and keeps the mix',
      () {
        final current = starterById('classic-hip-hop')!.toPattern().copyWith(
          trackVolumes: {TrackId.kick: 0.3},
          mutedTracks: {TrackId.clap},
          masterVolume: 0.5,
        );
        for (var seed = 0; seed < 50; seed++) {
          final next = PatternRandomizer.generate(
            genre: 'hip-hop',
            current: current,
            random: Random(seed),
          );
          expect(next.toEngineJson(), isNot(current.toEngineJson()));
          expect(next.trackVolumes, current.trackVolumes);
          expect(next.mutedTracks, current.mutedTracks);
          expect(next.masterVolume, 0.5);
        }
      },
    );

    test('unknown genre falls back gracefully and normal use is varied', () {
      final p = PatternRandomizer.generate(
        genre: 'polka',
        current: BeatPattern.empty(),
      );
      expect(p.isEmpty, isFalse);
    });
  });

  group('UndoHistory', () {
    test('undo and redo walk through states', () {
      final h = UndoHistory<int>(0)
        ..push(1)
        ..push(2);
      expect(h.undo(), 1);
      expect(h.undo(), 0);
      expect(h.undo(), isNull);
      expect(h.redo(), 1);
      expect(h.redo(), 2);
      expect(h.redo(), isNull);
    });

    test('a new push clears redo and duplicates are ignored', () {
      final h = UndoHistory<int>(0)
        ..push(1)
        ..push(2);
      h.undo();
      expect(h.canRedo, isTrue);
      expect(h.push(1), isFalse);
      expect(h.canRedo, isTrue);
      expect(h.push(5), isTrue);
      expect(h.canRedo, isFalse);
    });

    test('is bounded', () {
      final h = UndoHistory<int>(0, limit: 3);
      for (var i = 1; i <= 10; i++) {
        h.push(i);
      }
      var undone = 0;
      while (h.undo() != null) {
        undone++;
      }
      expect(undone, 3);
      expect(h.present, 7);
    });

    test('reset drops history', () {
      final h = UndoHistory<int>(0)..push(1);
      h.reset(9);
      expect(h.canUndo, isFalse);
      expect(h.present, 9);
    });
  });
}
