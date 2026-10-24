import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/widgets/creator_avatar.dart';

/// What a card needs to render; mapped from repository results in Phase 6.
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
  const BeatCard({super.key, required this.beat, this.onTap, this.onPlay});

  final BeatCardData beat;
  final VoidCallback? onTap;
  final VoidCallback? onPlay;

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
          button: true,
          label:
              '${beat.title} by ${beat.creatorName}, ${beat.genre}, ${beat.bpm} BPM',
          child: Material(
            color: AppColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: AppRadius.card,
              side: BorderSide(
                color: _hover
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
                            opacity: _hover ? 1 : 0.0,
                            duration: dur,
                            child: IconButton.filled(
                              tooltip: 'Play ${beat.title}',
                              onPressed: widget.onPlay,
                              icon: const Icon(Icons.play_arrow_rounded),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          beat.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: text.titleMedium,
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
                        const SizedBox(height: AppSpacing.sm),
                        Row(
                          children: [
                            Text(
                              '${beat.genre} · ${beat.bpm} BPM',
                              style: text.labelMedium,
                            ),
                            const Spacer(),
                            const Icon(
                              Icons.play_arrow,
                              size: 14,
                              color: AppColors.textDim,
                            ),
                            Text(' ${beat.plays}  ', style: text.bodySmall),
                            const Icon(
                              Icons.favorite,
                              size: 13,
                              color: AppColors.textDim,
                            ),
                            Text(' ${beat.likes}', style: text.bodySmall),
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
