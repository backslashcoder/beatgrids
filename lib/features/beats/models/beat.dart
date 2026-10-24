import 'package:equatable/equatable.dart';

import '../../studio/models/beat_pattern.dart';

enum BeatStatus {
  draft,
  published;

  static BeatStatus parse(String value) =>
      value == 'published' ? BeatStatus.published : BeatStatus.draft;
}

/// A beat as stored in Supabase. [pattern] has been validated on the way in.
class Beat extends Equatable {
  const Beat({
    required this.id,
    required this.creatorId,
    required this.title,
    required this.slug,
    required this.genre,
    required this.bpm,
    required this.pattern,
    required this.status,
    required this.allowRemix,
    required this.createdAt,
    required this.updatedAt,
    this.description,
    this.coverPath,
    this.sourceBeatId,
    this.sourceTitle,
    this.sourceCreatorUsername,
    this.publishedAt,
  });

  final String id;
  final String creatorId;
  final String title;
  final String slug;
  final String? description;
  final String genre;
  final int bpm;
  final BeatPattern pattern;
  final String? coverPath;
  final BeatStatus status;
  final bool allowRemix;
  final String? sourceBeatId;

  /// Who this beat was remixed from (snapshot; kept if the original disappears).
  final String? sourceTitle;
  final String? sourceCreatorUsername;
  final DateTime? publishedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isPublished => status == BeatStatus.published;
  bool get isRemix => sourceTitle != null || sourceBeatId != null;

  /// Parses a database row. Throws [PatternFormatException] if the stored
  /// pattern is not valid; database content is never trusted blindly.
  factory Beat.fromJson(Map<String, dynamic> json) => Beat(
    id: json['id'] as String,
    creatorId: json['creator_id'] as String,
    title: json['title'] as String,
    slug: json['slug'] as String,
    description: json['description'] as String?,
    genre: json['genre'] as String,
    bpm: clampBpm(json['bpm'] as num),
    pattern: BeatPattern.fromJson(json['pattern_data']),
    coverPath: json['cover_path'] as String?,
    status: BeatStatus.parse(json['status'] as String),
    allowRemix: json['allow_remix'] as bool? ?? false,
    sourceBeatId: json['source_beat_id'] as String?,
    sourceTitle: json['source_title'] as String?,
    sourceCreatorUsername: json['source_creator_username'] as String?,
    publishedAt: json['published_at'] == null
        ? null
        : DateTime.parse(json['published_at'] as String),
    createdAt: DateTime.parse(json['created_at'] as String),
    updatedAt: DateTime.parse(json['updated_at'] as String),
  );

  @override
  List<Object?> get props => [
    id,
    creatorId,
    title,
    slug,
    description,
    genre,
    bpm,
    pattern,
    coverPath,
    status,
    allowRemix,
    sourceBeatId,
    sourceTitle,
    sourceCreatorUsername,
    publishedAt,
    createdAt,
    updatedAt,
  ];
}

/// Lightweight row for the "My beats" list (no pattern payload).
class BeatSummary extends Equatable {
  const BeatSummary({
    required this.id,
    required this.title,
    required this.slug,
    required this.genre,
    required this.bpm,
    required this.status,
    required this.allowRemix,
    required this.updatedAt,
    this.coverPath,
    this.sourceTitle,
    this.publishedAt,
  });

  final String id;
  final String title;
  final String slug;
  final String genre;
  final int bpm;
  final BeatStatus status;
  final bool allowRemix;
  final String? coverPath;

  /// Set when this beat is a remix of another.
  final String? sourceTitle;
  final DateTime? publishedAt;
  final DateTime updatedAt;

  bool get isRemix => sourceTitle != null;
  bool get isPublished => status == BeatStatus.published;

  /// Columns to request for a summary.
  static const columns =
      'id, title, slug, genre, bpm, status, allow_remix, cover_path, source_title, published_at, updated_at';

  factory BeatSummary.fromJson(Map<String, dynamic> json) => BeatSummary(
    id: json['id'] as String,
    title: json['title'] as String,
    slug: json['slug'] as String,
    genre: json['genre'] as String,
    bpm: (json['bpm'] as num).toInt(),
    status: BeatStatus.parse(json['status'] as String),
    allowRemix: json['allow_remix'] as bool? ?? false,
    coverPath: json['cover_path'] as String?,
    sourceTitle: json['source_title'] as String?,
    publishedAt: json['published_at'] == null
        ? null
        : DateTime.parse(json['published_at'] as String),
    updatedAt: DateTime.parse(json['updated_at'] as String),
  );

  @override
  List<Object?> get props => [
    id,
    title,
    slug,
    genre,
    bpm,
    status,
    allowRemix,
    coverPath,
    sourceTitle,
    publishedAt,
    updatedAt,
  ];
}

/// Everything a client may write when saving a beat.
class BeatInput extends Equatable {
  const BeatInput({
    required this.title,
    required this.genre,
    required this.bpm,
    required this.pattern,
    required this.status,
    this.description,
    this.coverPath,
    this.allowRemix = false,
  });

  final String title;
  final String? description;
  final String genre;
  final int bpm;
  final BeatPattern pattern;
  final String? coverPath;
  final bool allowRemix;
  final BeatStatus status;

  Map<String, dynamic> toRow() {
    final desc = description?.trim();
    return {
      'title': title.trim(),
      'description': (desc == null || desc.isEmpty) ? null : desc,
      'genre': genre,
      'bpm': bpm,
      'pattern_data': pattern.toJson(),
      'cover_path': coverPath,
      'allow_remix': allowRemix,
      'status': status.name,
    };
  }

  @override
  List<Object?> get props => [
    title,
    description,
    genre,
    bpm,
    pattern,
    coverPath,
    allowRemix,
    status,
  ];
}
