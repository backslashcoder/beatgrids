import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/widgets/chips_and_toggles.dart';
import '../../../core/widgets/creator_avatar.dart';
import '../../community/models/public_beat.dart';
import '../models/genres.dart';

/// What a card needs to render.
class BeatCardData {
  const BeatCardData({
    required this.id,
    required this.title,
    required this.creatorName,
    required this.genre,
    required this.bpm,
    this.coverUrl,
    this.creatorAvatarUrl,
    this.plays = 0,
    this.likes = 0,
  });

  factory BeatCardData.fromItem(BeatItem item) => BeatCardData(
    id: item.beat.id,
    title: item.beat.title,
    creatorName: item.beat.creatorDisplayName,
    genre: genreLabel(item.beat.genre),
    bpm: item.beat.bpm,
    coverUrl: item.coverUrl,
    creatorAvatarUrl: item.avatarUrl,
    plays: item.beat.playCount,
    likes: item.beat.likeCount,
  );

  final String id;
  final String title;
  final String creatorName;
  final String genre;
  final int bpm;
  final String? coverUrl;
  final String? creatorAvatarUrl;
  final int plays;
  final int likes;
}

class BeatCard extends StatefulWidget {
  const BeatCard({
    super.key,
    required this.beat,
    this.onTap,
    this.onPlay,
    this.playing = false,
    this.liked = false,
    this.saved = false,
    this.onLike,
    this.onSave,
  });

  final BeatCardData beat;
  final VoidCallback? onTap;
  final VoidCallback? onPlay;

  /// This beat is the one currently playing in the mini-player.
  final bool playing;
  final bool liked;
  final bool saved;
  final VoidCallback? onLike;
  final VoidCallback? onSave;

  @override
  State<BeatCard> createState() => _BeatCardState();
}

class _BeatCardState extends State<BeatCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final beat = widget.beat;
    final text = Theme.of(context).textTheme;
    final dur = Motion.of(context, Motion.medium);
    // Touch screens have no hover, so the play button stays visible there and
    // while the beat is playing.
    final showPlay = _hover || widget.playing;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: widget.onTap == null
          ? MouseCursor.defer
          : SystemMouseCursors.click,
      child: AnimatedScale(
        scale: _hover ? 1.02 : 1,
        duration: dur,
        curve: Curves.easeOutCubic,
        child: Semantics(
          container: true,
          label:
              '${beat.title} by ${beat.creatorName}, ${beat.genre}, ${beat.bpm} BPM',
          child: Material(
            color: AppColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: AppRadius.card,
              side: BorderSide(
                color: widget.playing
                    ? AppColors.lime
                    : _hover
                    ? AppColors.lime.withValues(alpha: 0.6)
                    : AppColors.border,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: widget.onTap,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AspectRatio(
                    aspectRatio: 1.5,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        beat.coverUrl == null
                            ? DefaultCover(seed: beat.title)
                            : Image.network(
                                beat.coverUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) =>
                                    DefaultCover(seed: beat.title),
                              ),
                        Positioned(
                          right: 10,
                          bottom: 10,
                          child: AnimatedOpacity(
                            opacity: widget.onPlay == null
                                ? 0
                                : (showPlay ? 1 : 0.0),
                            duration: dur,
                            child: IconButton.filled(
                              tooltip: widget.playing
                                  ? 'Pause ${beat.title}'
                                  : 'Play ${beat.title}',
                              onPressed: widget.onPlay,
                              icon: Icon(
                                widget.playing
                                    ? Icons.pause_rounded
                                    : Icons.play_arrow_rounded,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.md,
                      AppSpacing.md,
                      AppSpacing.sm,
                      AppSpacing.sm,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(right: AppSpacing.sm),
                          child: Text(
                            beat.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: text.titleMedium,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            CreatorAvatar(
                              name: beat.creatorName,
                              imageUrl: beat.creatorAvatarUrl,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                beat.creatorName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: text.bodySmall,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${beat.genre} · ${beat.bpm} BPM',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: text.labelMedium,
                              ),
                            ),
                            const Icon(
                              Icons.play_arrow,
                              size: 14,
                              color: AppColors.textDim,
                            ),
                            Text(' ${beat.plays}', style: text.bodySmall),
                            if (widget.onLike == null) ...[
                              const SizedBox(width: 8),
                              const Icon(
                                Icons.favorite,
                                size: 13,
                                color: AppColors.textDim,
                              ),
                              Text(' ${beat.likes}', style: text.bodySmall),
                            ],
                            if (widget.onLike != null)
                              BounceToggle(
                                active: widget.liked,
                                icon: Icons.favorite_border,
                                activeIcon: Icons.favorite,
                                count: beat.likes,
                                tooltip: widget.liked ? 'Unlike' : 'Like',
                                onPressed: widget.onLike,
                              ),
                            if (widget.onSave != null)
                              BounceToggle(
                                active: widget.saved,
                                icon: Icons.bookmark_border,
                                activeIcon: Icons.bookmark,
                                activeColor: AppColors.amber,
                                tooltip: widget.saved
                                    ? 'Remove from saved'
                                    : 'Save',
                                onPressed: widget.onSave,
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Generative cover: a mini step grid seeded by the title, so every beat has
/// a stable, distinctive default artwork.
class DefaultCover extends StatelessWidget {
  const DefaultCover({super.key, required this.seed});

  final String seed;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(painter: _CoverPainter(seed.hashCode));
}

class _CoverPainter extends CustomPainter {
  _CoverPainter(this.seed);

  final int seed;

  static const _colors = [
    AppColors.kick,
    AppColors.snare,
    AppColors.closedHat,
    AppColors.openHat,
    AppColors.clap,
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final rnd = math.Random(seed);
    final base = _colors[seed.abs() % _colors.length];
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [base.withValues(alpha: 0.28), AppColors.surfaceRaised],
        ).createShader(Offset.zero & size),
    );
    const rows = 5, cols = 16;
    final pad = size.width * 0.08;
    final cell = math.min(
      (size.width - pad * 2) / cols,
      (size.height - pad * 2) / rows,
    );
    final gridW = cell * cols, gridH = cell * rows;
    final origin = Offset((size.width - gridW) / 2, (size.height - gridH) / 2);
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        final on =
            rnd.nextDouble() <
            (r == 0
                ? 0.28
                : r == 2
                ? 0.5
                : 0.18);
        final rect = RRect.fromRectAndRadius(
          Rect.fromLTWH(
            origin.dx + c * cell + 1,
            origin.dy + r * cell + 1,
            cell - 2,
            cell - 2,
          ),
          Radius.circular(cell * 0.2),
        );
        canvas.drawRRect(
          rect,
          Paint()
            ..color = on
                ? _colors[r].withValues(alpha: 0.95)
                : Colors.white.withValues(alpha: 0.05),
        );
      }
    }
  }

  @override
  bool shouldRepaint(_CoverPainter old) => old.seed != seed;
}
