import 'dart:convert';

import 'package:beatgrid/features/studio/models/beat_pattern.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> validJson() =>
    jsonDecode(jsonEncode(BeatPattern.empty().toJson()))
        as Map<String, dynamic>;

void main() {
  test('round-trips through JSON', () {
    final p = BeatPattern.empty()
        .toggleStep(TrackId.kick, 0)
        .toggleStep(TrackId.clap, 12);
    final restored = BeatPattern.fromJson(p.toJson());
    expect(restored, p);
    expect(restored.isActive(TrackId.kick, 0), isTrue);
    expect(restored.isActive(TrackId.clap, 12), isTrue);
  });

  test('toggleStep does not mutate the original', () {
    final a = BeatPattern.empty();
    final b = a.toggleStep(TrackId.snare, 4);
    expect(a.isActive(TrackId.snare, 4), isFalse);
    expect(b.isActive(TrackId.snare, 4), isTrue);
  });

  test('rejects wrong step count', () {
    final json = validJson();
    (json['tracks'] as Map)['kick'] = List.filled(8, false);
    expect(
      () => BeatPattern.fromJson(json),
      throwsA(isA<PatternFormatException>()),
    );
  });

  test('rejects unknown tracks, bad versions and non-boolean steps', () {
    var json = validJson();
    (json['tracks'] as Map)['cowbell'] = List.filled(16, false);
    expect(
      () => BeatPattern.fromJson(json),
      throwsA(isA<PatternFormatException>()),
    );

    json = validJson()..['version'] = 99;
    expect(
      () => BeatPattern.fromJson(json),
      throwsA(isA<PatternFormatException>()),
    );

    json = validJson();
    (json['tracks'] as Map)['kick'] = List.filled(16, 1);
    expect(
      () => BeatPattern.fromJson(json),
      throwsA(isA<PatternFormatException>()),
    );
  });

  test('rejects out-of-range volumes', () {
    final json = validJson();
    (json['trackVolumes'] as Map)['kick'] = 1.5;
    expect(
      () => BeatPattern.fromJson(json),
      throwsA(isA<PatternFormatException>()),
    );
    expect(
      () => BeatPattern.fromJson(validJson()..['masterVolume'] = -1),
      throwsA(isA<PatternFormatException>()),
    );
  });

  test('rejects non-object input', () {
    expect(
      () => BeatPattern.fromJson('nope'),
      throwsA(isA<PatternFormatException>()),
    );
  });

  test('clampBpm keeps values in range', () {
    expect(clampBpm(10), kMinBpm);
    expect(clampBpm(999), kMaxBpm);
    expect(clampBpm(120.4), 120);
  });

  test('engine JSON contains only step rows', () {
    expect(BeatPattern.empty().toEngineJson(), contains('"closed_hat"'));
    expect(BeatPattern.empty().toEngineJson(), isNot(contains('version')));
  });
}
