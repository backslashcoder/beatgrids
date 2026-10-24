import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../studio/models/beat_pattern.dart';
import '../../../studio/presentation/widgets/track_style.dart';

/// Read-only view of a pattern: five rows of 16 steps in the track colours,
/// with an optional playhead column. Purely visual.
class PatternPreview extends StatelessWidget {
  const PatternPreview({super.key, required this.pattern, this.step = -1});

  final BeatPattern pattern;
  final int step;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: LayoutBuilder(
        builder: (context, c) {
          final metrics = StepMetrics(
            StepMetrics.cellFor(c.maxWidth).clamp(6.0, 60.0),
          );
          const rowH = 22.0, gap = 5.0;
          final height = TrackId.values.length * (rowH + gap) - gap;
          return SizedBox(
            width: metrics.total,
            height: height,
            child: Stack(
              children: [
                for (var r = 0; r < TrackId.values.length; r++)
                  for (var i = 0; i < kStepsPerBar; i++)
                    Positioned(
                      left: metrics.left(i),
                      top: r * (rowH + gap),
                      width: metrics.cellWidth,
                      height: rowH,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(5),
                          color: _color(TrackId.values[r], i),
                        ),
                      ),
                    ),
                if (step >= 0)
                  Positioned(
                    left: metrics.left(step) - 2,
                    width: metrics.cellWidth + 4,
                    top: -2,
                    height: height + 4,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(7),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.85),
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Color _color(TrackId track, int i) {
    if (pattern.isActive(track, i)) {
      return pattern.mutedTracks.contains(track)
          ? track.color.withValues(alpha: 0.3)
          : track.color;
    }
    return i % 4 == 0 ? AppColors.surfaceHigh : AppColors.surfaceRaised;
  }
}
