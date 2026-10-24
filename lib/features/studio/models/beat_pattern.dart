import 'dart:convert';

/// Drum tracks supported by pattern format version 1.
enum TrackId {
  kick('kick', 'Kick'),
  snare('snare', 'Snare'),
  closedHat('closed_hat', 'Closed Hat'),
  openHat('open_hat', 'Open Hat'),
  clap('clap', 'Clap');

  const TrackId(this.key, this.label);

  /// Identifier used in stored JSON and in the audio engine.
  final String key;
  final String label;

  static TrackId? fromKey(String key) {
    for (final t in TrackId.values) {
      if (t.key == key) return t;
    }
    return null;
  }
}

class PatternFormatException implements Exception {
  const PatternFormatException(this.message);
  final String message;

  @override
  String toString() => 'PatternFormatException: $message';
}

const int kStepsPerBar = 16;
const int kMinBpm = 60;
const int kMaxBpm = 180;

int clampBpm(num bpm) => bpm.round().clamp(kMinBpm, kMaxBpm);

/// Immutable, versioned step-sequencer pattern.
class BeatPattern {
  BeatPattern({
    required Map<TrackId, List<bool>> tracks,
    Map<TrackId, double>? trackVolumes,
    Set<TrackId> mutedTracks = const {},
    double masterVolume = 0.8,
  }) : tracks = Map.unmodifiable({
         for (final t in TrackId.values)
           t: List<bool>.unmodifiable(
             tracks[t] ?? List.filled(kStepsPerBar, false),
           ),
       }),
       trackVolumes = Map.unmodifiable({
         for (final t in TrackId.values)
           t: (trackVolumes?[t] ?? defaultVolumes[t]!)
               .clamp(0.0, 1.0)
               .toDouble(),
       }),
       mutedTracks = Set.unmodifiable(mutedTracks),
       masterVolume = masterVolume.clamp(0.0, 1.0).toDouble() {
    for (final row in this.tracks.values) {
      if (row.length != kStepsPerBar) {
        throw const PatternFormatException(
          'Each track needs exactly 16 steps.',
        );
      }
    }
  }

  factory BeatPattern.empty() => BeatPattern(tracks: const {});

  static const int version = 1;

  static const Map<TrackId, double> defaultVolumes = {
    TrackId.kick: 0.8,
    TrackId.snare: 0.8,
    TrackId.closedHat: 0.6,
    TrackId.openHat: 0.5,
    TrackId.clap: 0.7,
  };

  final Map<TrackId, List<bool>> tracks;
  final Map<TrackId, double> trackVolumes;
  final Set<TrackId> mutedTracks;
  final double masterVolume;

  bool isActive(TrackId track, int step) => tracks[track]![step];

  bool get isEmpty => tracks.values.every((row) => !row.contains(true));

  BeatPattern toggleStep(TrackId track, int step) {
    final row = List<bool>.of(tracks[track]!);
    row[step] = !row[step];
    return copyWith(tracks: {...tracks, track: row});
  }

  BeatPattern copyWith({
    Map<TrackId, List<bool>>? tracks,
    Map<TrackId, double>? trackVolumes,
    Set<TrackId>? mutedTracks,
    double? masterVolume,
  }) => BeatPattern(
    tracks: tracks ?? this.tracks,
    trackVolumes: trackVolumes ?? this.trackVolumes,
    mutedTracks: mutedTracks ?? this.mutedTracks,
    masterVolume: masterVolume ?? this.masterVolume,
  );

  /// Only the step data, as sent to the audio engine.
  String toEngineJson() =>
      jsonEncode({for (final e in tracks.entries) e.key.key: e.value});

  Map<String, dynamic> toJson() => {
    'version': version,
    'stepsPerBar': kStepsPerBar,
    'tracks': {for (final e in tracks.entries) e.key.key: e.value},
    'trackVolumes': {for (final e in trackVolumes.entries) e.key.key: e.value},
    'mutedTracks': [for (final t in mutedTracks) t.key],
    'masterVolume': masterVolume,
  };

  /// Parses untrusted JSON. Throws [PatternFormatException] if it is invalid.
  factory BeatPattern.fromJson(Object? json) {
    if (json is! Map)
      throw const PatternFormatException('Pattern must be an object.');
    final v = json['version'];
    if (v is! int || v < 1 || v > version) {
      throw PatternFormatException('Unsupported pattern version: $v.');
    }
    if (json['stepsPerBar'] != kStepsPerBar) {
      throw const PatternFormatException(
        'Only 16 steps per bar are supported.',
      );
    }

    final rawTracks = json['tracks'];
    if (rawTracks is! Map)
      throw const PatternFormatException('Missing tracks.');
    final tracks = <TrackId, List<bool>>{};
    for (final entry in rawTracks.entries) {
      final id = TrackId.fromKey('${entry.key}');
      if (id == null)
        throw PatternFormatException('Unknown track "${entry.key}".');
      final row = entry.value;
      if (row is! List ||
          row.length != kStepsPerBar ||
          row.any((s) => s is! bool)) {
        throw PatternFormatException(
          'Track "${entry.key}" must be 16 booleans.',
        );
      }
      tracks[id] = row.cast<bool>();
    }
    for (final t in TrackId.values) {
      if (!tracks.containsKey(t))
        throw PatternFormatException('Missing track "${t.key}".');
    }

    final volumes = <TrackId, double>{};
    final rawVolumes = json['trackVolumes'];
    if (rawVolumes != null) {
      if (rawVolumes is! Map)
        throw const PatternFormatException('Invalid trackVolumes.');
      for (final entry in rawVolumes.entries) {
        final id = TrackId.fromKey('${entry.key}');
        final value = entry.value;
        if (id == null || value is! num || value < 0 || value > 1) {
          throw PatternFormatException('Invalid volume for "${entry.key}".');
        }
        volumes[id] = value.toDouble();
      }
    }

    final muted = <TrackId>{};
    final rawMuted = json['mutedTracks'];
    if (rawMuted != null) {
      if (rawMuted is! List)
        throw const PatternFormatException('Invalid mutedTracks.');
      for (final key in rawMuted) {
        final id = TrackId.fromKey('$key');
        if (id == null)
          throw PatternFormatException('Unknown muted track "$key".');
        muted.add(id);
      }
    }

    final master = json['masterVolume'] ?? 0.8;
    if (master is! num || master < 0 || master > 1) {
      throw const PatternFormatException('Invalid masterVolume.');
    }

    return BeatPattern(
      tracks: tracks,
      trackVolumes: volumes,
      mutedTracks: muted,
      masterVolume: master.toDouble(),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is BeatPattern &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;
}
