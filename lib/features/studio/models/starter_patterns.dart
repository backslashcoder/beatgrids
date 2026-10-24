import 'beat_pattern.dart';

/// A curated, loadable pattern with its default tempo and genre.
class StarterPattern {
  const StarterPattern({
    required this.id,
    required this.name,
    required this.genre,
    required this.bpm,
    required this.description,
    required this.steps,
    this.volumes = const {},
  });

  final String id;
  final String name;

  /// One of the database genre ids (hip-hop, boom-bap, trap, house, ...).
  final String genre;
  final int bpm;
  final String description;

  /// Active step indices (0-15) per track.
  final Map<TrackId, List<int>> steps;
  final Map<TrackId, double> volumes;

  BeatPattern toPattern() => BeatPattern(
    tracks: {
      for (final t in TrackId.values)
        t: List<bool>.generate(
          kStepsPerBar,
          (i) => (steps[t] ?? const []).contains(i),
        ),
    },
    trackVolumes: volumes.isEmpty ? null : volumes,
  );
}

const starterPatterns = <StarterPattern>[
  StarterPattern(
    id: 'classic-hip-hop',
    name: 'Classic Hip-Hop',
    genre: 'hip-hop',
    bpm: 92,
    description:
        'Steady backbeat, eighth-note hats, one open hat to turn it around.',
    steps: {
      TrackId.kick: [0, 5, 8, 13],
      TrackId.snare: [4, 12],
      TrackId.closedHat: [0, 2, 4, 6, 8, 10, 12, 14],
      TrackId.openHat: [15],
    },
  ),
  StarterPattern(
    id: 'boom-bap',
    name: 'Boom Bap',
    genre: 'boom-bap',
    bpm: 88,
    description: 'Syncopated kicks under a hard snare, with offbeat hats.',
    steps: {
      TrackId.kick: [0, 2, 8, 11],
      TrackId.snare: [4, 12],
      TrackId.closedHat: [2, 6, 10, 14],
      TrackId.openHat: [7],
      TrackId.clap: [12],
    },
  ),
  StarterPattern(
    id: 'trap-starter',
    name: 'Trap Starter',
    genre: 'trap',
    bpm: 140,
    description: 'Half-time snare with a rolling hi-hat and bouncy kicks.',
    steps: {
      TrackId.kick: [0, 6, 10, 13],
      TrackId.snare: [8],
      TrackId.closedHat: [0, 2, 4, 6, 8, 10, 12, 13, 14, 15],
      TrackId.openHat: [11],
      TrackId.clap: [8],
    },
  ),
  StarterPattern(
    id: 'house-groove',
    name: 'House Groove',
    genre: 'house',
    bpm: 124,
    description:
        'Four on the floor, claps on 2 and 4, open hats on the offbeat.',
    steps: {
      TrackId.kick: [0, 4, 8, 12],
      TrackId.closedHat: [0, 3, 8, 11],
      TrackId.openHat: [2, 6, 10, 14],
      TrackId.clap: [4, 12],
    },
  ),
  StarterPattern(
    id: 'techno-pulse',
    name: 'Techno Pulse',
    genre: 'techno',
    bpm: 132,
    description: 'Driving kick, sixteenth offbeat hats and a late clap.',
    steps: {
      TrackId.kick: [0, 4, 8, 12],
      TrackId.closedHat: [1, 3, 5, 7, 9, 11, 13, 15],
      TrackId.openHat: [6, 14],
      TrackId.clap: [4, 12],
    },
  ),
  StarterPattern(
    id: 'lo-fi-groove',
    name: 'Lo-fi Groove',
    genre: 'lo-fi',
    bpm: 78,
    description: 'Laid-back and quiet: soft hats, relaxed kick, single clap.',
    steps: {
      TrackId.kick: [0, 7, 10],
      TrackId.snare: [4, 12],
      TrackId.closedHat: [0, 2, 4, 6, 8, 10, 12, 14],
      TrackId.clap: [12],
    },
    volumes: {
      TrackId.kick: 0.7,
      TrackId.snare: 0.6,
      TrackId.closedHat: 0.35,
      TrackId.openHat: 0.3,
      TrackId.clap: 0.4,
    },
  ),
  StarterPattern(
    id: 'minimal-beat',
    name: 'Minimal Beat',
    genre: 'minimal',
    bpm: 120,
    description: 'As little as possible: two kicks, a snare, sparse hats.',
    steps: {
      TrackId.kick: [0, 8],
      TrackId.snare: [12],
      TrackId.closedHat: [2, 6, 10, 14],
    },
  ),
];

StarterPattern? starterById(String id) {
  for (final p in starterPatterns) {
    if (p.id == id) return p;
  }
  return null;
}
