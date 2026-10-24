import 'dart:convert';

import 'package:beatgrid/features/beats/models/beat.dart';
import 'package:beatgrid/features/beats/models/beat_validator.dart';
import 'package:beatgrid/features/beats/models/genres.dart';
import 'package:beatgrid/features/studio/models/beat_pattern.dart';
import 'package:beatgrid/features/studio/models/starter_patterns.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> row({
  Object? pattern,
  String status = 'draft',
  Object? bpm = 120,
}) => {
  'id': 'b1',
  'creator_id': 'u1',
  'title': 'My Beat',
  'slug': 'my-beat-abc123',
  'description': null,
  'genre': 'house',
  'bpm': bpm,
  'pattern_data': pattern ?? starterById('house-groove')!.toPattern().toJson(),
  'cover_path': null,
  'status': status,
  'allow_remix': true,
  'source_beat_id': null,
  'published_at': status == 'published' ? '2026-01-02T00:00:00Z' : null,
  'created_at': '2026-01-01T00:00:00Z',
  'updated_at': '2026-01-01T00:00:00Z',
};

BeatInput input({
  String title = 'My Beat',
  String? description,
  String genre = 'house',
  int bpm = 120,
  BeatPattern? pattern,
  BeatStatus status = BeatStatus.draft,
}) => BeatInput(
  title: title,
  description: description,
  genre: genre,
  bpm: bpm,
  pattern: pattern ?? starterById('house-groove')!.toPattern(),
  status: status,
);

void main() {
  group('Beat.fromJson', () {
    test('parses a database row', () {
      final beat = Beat.fromJson(row(status: 'published'));
      expect(beat.title, 'My Beat');
      expect(beat.isPublished, isTrue);
      expect(beat.allowRemix, isTrue);
      expect(beat.publishedAt, isNotNull);
      expect(beat.pattern.isActive(TrackId.kick, 0), isTrue);
    });

    test('rejects damaged pattern data instead of trusting the database', () {
      final bad = starterById('house-groove')!.toPattern().toJson();
      (bad['tracks'] as Map)['kick'] = [true];
      expect(
        () => Beat.fromJson(row(pattern: bad)),
        throwsA(isA<PatternFormatException>()),
      );
      expect(
        () => Beat.fromJson(row(pattern: 'garbage')),
        throwsA(isA<PatternFormatException>()),
      );
    });

    test('clamps an out-of-range stored tempo', () {
      expect(Beat.fromJson(row(bpm: 500)).bpm, kMaxBpm);
    });

    test('summary rows parse without a pattern', () {
      final s = BeatSummary.fromJson(row()..remove('pattern_data'));
      expect(s.slug, 'my-beat-abc123');
      expect(s.status, BeatStatus.draft);
    });
  });

  group('BeatInput.toRow', () {
    test('trims, nulls an empty description and serializes the pattern', () {
      final r = input(title: '  Hello  ', description: '   ').toRow();
      expect(r['title'], 'Hello');
      expect(r['description'], isNull);
      expect(r['status'], 'draft');
      expect(jsonEncode(r['pattern_data']), contains('"stepsPerBar":16'));
      expect(
        r.containsKey('creator_id'),
        isFalse,
        reason: 'ownership is added by the repository',
      );
      expect(
        r.containsKey('slug'),
        isFalse,
        reason: 'slug is server-generated',
      );
    });
  });

  group('BeatValidator', () {
    Map<BeatField, String> check(BeatInput i, {bool publish = false}) =>
        BeatValidator.validate(i, forPublish: publish);

    test('a normal beat is valid for saving and publishing', () {
      expect(check(input()), isEmpty);
      expect(check(input(), publish: true), isEmpty);
    });

    test('title rules', () {
      expect(check(input(title: '  ')).keys, contains(BeatField.title));
      expect(check(input(title: 'x' * 81)).keys, contains(BeatField.title));
      expect(check(input(title: 'x' * 80)), isEmpty);
      expect(
        check(input(title: kUntitledBeat)),
        isEmpty,
        reason: 'drafts may stay untitled',
      );
      expect(
        check(input(title: kUntitledBeat), publish: true).keys,
        contains(BeatField.title),
      );
    });

    test('description, genre and tempo limits', () {
      expect(
        check(input(description: 'x' * 501)).keys,
        contains(BeatField.description),
      );
      expect(check(input(description: 'x' * 500)), isEmpty);
      expect(check(input(genre: 'polka')).keys, contains(BeatField.genre));
      expect(check(input(bpm: 59)).keys, contains(BeatField.bpm));
      expect(check(input(bpm: 181)).keys, contains(BeatField.bpm));
    });

    test('an empty pattern can be saved but not published', () {
      final empty = input(pattern: BeatPattern.empty());
      expect(check(empty), isEmpty);
      expect(check(empty, publish: true).keys, contains(BeatField.pattern));
    });

    test('every genre the app offers is known to the validator', () {
      for (final g in genres) {
        expect(check(input(genre: g.id)), isEmpty, reason: g.id);
      }
      expect(genreLabel('lo-fi'), 'Lo-fi');
      expect(genreLabel('mystery'), 'mystery');
    });
  });
}
