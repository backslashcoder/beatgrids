import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../models/beat_pattern.dart';

extension TrackStyle on TrackId {
  Color get color => switch (this) {
    TrackId.kick => AppColors.kick,
    TrackId.snare => AppColors.snare,
    TrackId.closedHat => AppColors.closedHat,
    TrackId.openHat => AppColors.openHat,
    TrackId.clap => AppColors.clap,
  };

  IconData get icon => switch (this) {
    TrackId.kick => Icons.radio_button_checked,
    TrackId.snare => Icons.flash_on,
    TrackId.closedHat => Icons.more_horiz,
    TrackId.openHat => Icons.blur_on,
    TrackId.clap => Icons.back_hand_outlined,
  };
}

/// Horizontal geometry of the 16-step grid: four groups of four with a wider
/// gap between groups. Shared by cells, rows and the playhead overlay.
class StepMetrics {
  const StepMetrics(this.cellWidth);

  static const stepGap = 4.0;
  static const groupGap = 12.0;
  static const minCellWidth = 34.0;

  final double cellWidth;

  static double totalFor(double cell) =>
      cell * kStepsPerBar + stepGap * 12 + groupGap * 3;

  /// Cell width that exactly fills [available] pixels.
  static double cellFor(double available) =>
      (available - stepGap * 12 - groupGap * 3) / kStepsPerBar;

  double get total => totalFor(cellWidth);

  double left(int step) =>
      step * cellWidth + (step - step ~/ 4) * stepGap + (step ~/ 4) * groupGap;

  /// Step under horizontal offset [dx], clamped to the grid.
  int indexAt(double dx) {
    for (var i = 0; i < kStepsPerBar; i++) {
      final edge = left(i) + cellWidth + (i % 4 == 3 ? groupGap : stepGap) / 2;
      if (dx < edge) return i;
    }
    return kStepsPerBar - 1;
  }
}
