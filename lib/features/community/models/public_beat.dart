import 'package:equatable/equatable.dart';

import '../../studio/models/beat_pattern.dart';

enum FeedSort { latest, trending }

/// One row of the `public_beats` view: a published beat with its creator and
/// public counts. Carries no pattern; see [PublicBeatDetail].
class PublicBeat extends Equatable {
  const PublicBeat({
    required this.id,
    required this.slug,
    required this.title,
    required this.genre,
    required this.bpm,
    required this.creatorId,
    required this.creatorUsername,
    required this.creatorDisplayName,
    required this.allowRemix,
    required this.publishedAt,
    this.description,
    this.coverPath,
    this.creatorAvatarPath,
    this.sourceBeatId,
    this.sourceTitle,
    this.sourceCreatorUsername,
    this.sourceSlug,
    this.likeCount = 0,
    this.playCount = 0,
  });

  final String id;
  final String slug;
  final String title;
  final String? description;
  final String genre;
  final int bpm;
  final String? coverPath;
  final bool allowRemix;
  final String? sourceBeatId;

  /// Attribution snapshot taken when the remix was made; survives the original
  /// being unpublished or deleted.
  final String? sourceTitle;
  final String? sourceCreatorUsername;

  /// Present only while the original is still published (so it can be linked).
  final String? sourceSlug;
  final DateTime publishedAt;
  final String creatorId;
  final String creatorUsername;
  final String creatorDisplayName;
  final String? creatorAvatarPath;
  final int likeCount;
  final int playCount;

  factory PublicBeat.fromJson(Map<String, dynamic> json) => PublicBeat(
    id: json['id'] as String,
    slug: json['slug'] as String,
    title: json['title'] as String,
    description: json['description'] as String?,
    genre: json['genre'] as String,
    bpm: clampBpm(json['bpm'] as num),
    coverPath: json['cover_path'] as String?,
    allowRemix: json['allow_remix'] as bool? ?? false,
    sourceBeatId: json['source_beat_id'] as String?,
    sourceTitle: json['source_title'] as String?,
    sourceCreatorUsername: json['source_creator_username'] as String?,
    sourceSlug: json['source_slug'] as String?,
    publishedAt: DateTime.parse(json['published_at'] as String),
    creatorId: json['creator_id'] as String,
    creatorUsername: json['creator_username'] as String,
    creatorDisplayName: json['creator_display_name'] as String,
    creatorAvatarPath: json['creator_avatar_path'] as String?,
    likeCount: (json['like_count'] as num?)?.toInt() ?? 0,
    playCount: (json['play_count'] as num?)?.toInt() ?? 0,
  );

  /// This beat was made by remixing another.
  bool get isRemix => sourceTitle != null || sourceBeatId != null;

  /// The original is still public, so it can be linked.
  bool get sourceAvailable => sourceSlug != null;

  PublicBeat copyWith({int? likeCount, int? playCount}) => PublicBeat(
    id: id,
    slug: slug,
    title: title,
    description: description,
    genre: genre,
    bpm: bpm,
    coverPath: coverPath,
    allowRemix: allowRemix,
    sourceBeatId: sourceBeatId,
    sourceTitle: sourceTitle,
    sourceCreatorUsername: sourceCreatorUsername,
    sourceSlug: sourceSlug,
    publishedAt: publishedAt,
    creatorId: creatorId,
    creatorUsername: creatorUsername,
    creatorDisplayName: creatorDisplayName,
    creatorAvatarPath: creatorAvatarPath,
    likeCount: likeCount ?? this.likeCount,
    playCount: playCount ?? this.playCount,
  );

  @override
  List<Object?> get props => [
    id,
    slug,
    title,
    description,
    genre,
    bpm,
    coverPath,
    allowRemix,
    sourceBeatId,
    sourceTitle,
    sourceCreatorUsername,
    sourceSlug,
    publishedAt,
    creatorId,
    creatorUsername,
    creatorDisplayName,
    creatorAvatarPath,
    likeCount,
    playCount,
  ];
}

/// A feed beat plus what only this viewer knows (liked/saved) and resolved image URLs.
class BeatItem extends Equatable {
  const BeatItem({
    required this.beat,
    this.liked = false,
    this.saved = false,
    this.coverUrl,
    this.avatarUrl,
  });

  final PublicBeat beat;
  final bool liked;
  final bool saved;
  final String? coverUrl;
  final String? avatarUrl;

  BeatItem copyWith({
    PublicBeat? beat,
    bool? liked,
    bool? saved,
    String? coverUrl,
    String? avatarUrl,
  }) => BeatItem(
    beat: beat ?? this.beat,
    liked: liked ?? this.liked,
    saved: saved ?? this.saved,
    coverUrl: coverUrl ?? this.coverUrl,
    avatarUrl: avatarUrl ?? this.avatarUrl,
  );

  /// Applies an optimistic like change, adjusting the public count to match.
  BeatItem withLiked(bool value) {
    if (value == liked) return this;
    final next = (beat.likeCount + (value ? 1 : -1)).clamp(0, 1 << 30);
    return copyWith(
      liked: value,
      beat: beat.copyWith(likeCount: next),
    );
  }

  @override
  List<Object?> get props => [beat, liked, saved, coverUrl, avatarUrl];
}

/// Everything needed to open and play a beat.
class PublicBeatDetail extends Equatable {
  const PublicBeatDetail({required this.beat, required this.pattern});

  final PublicBeat beat;
  final BeatPattern pattern;

  @override
  List<Object?> get props => [beat, pattern];
}

class CreatorStats extends Equatable {
  const CreatorStats({
    this.beatCount = 0,
    this.likeCount = 0,
    this.playCount = 0,
  });

  final int beatCount;
  final int likeCount;
  final int playCount;

  @override
  List<Object?> get props => [beatCount, likeCount, playCount];
}

class CreatorProfile extends Equatable {
  const CreatorProfile({
    required this.id,
    required this.username,
    required this.displayName,
    required this.createdAt,
    this.bio,
    this.avatarPath,
    this.stats = const CreatorStats(),
  });

  final String id;
  final String username;
  final String displayName;
  final String? bio;
  final String? avatarPath;
  final DateTime createdAt;
  final CreatorStats stats;

  @override
  List<Object?> get props => [
    id,
    username,
    displayName,
    bio,
    avatarPath,
    createdAt,
    stats,
  ];
}

/// Makes free text safe to embed in a PostgREST `or=(...)` filter and bounds its size.
String sanitizeSearch(String? input) {
  if (input == null) return '';
  final cleaned = input
      .replaceAll(RegExp(r'[,()*%\\"]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  return cleaned.length > 50 ? cleaned.substring(0, 50).trim() : cleaned;
}
