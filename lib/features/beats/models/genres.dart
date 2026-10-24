/// Genres accepted by the database (`beats_genre_valid`). Keep in sync with
/// supabase/migrations/20260101000100_beats.sql.
class Genre {
  const Genre(this.id, this.label);

  final String id;
  final String label;
}

const genres = <Genre>[
  Genre('hip-hop', 'Hip-Hop'),
  Genre('boom-bap', 'Boom Bap'),
  Genre('trap', 'Trap'),
  Genre('house', 'House'),
  Genre('techno', 'Techno'),
  Genre('lo-fi', 'Lo-fi'),
  Genre('minimal', 'Minimal'),
  Genre('other', 'Other'),
];

String genreLabel(String id) {
  for (final g in genres) {
    if (g.id == id) return g.label;
  }
  return id;
}

bool isKnownGenre(String id) => genres.any((g) => g.id == id);
