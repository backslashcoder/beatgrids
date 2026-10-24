import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../models/beat_pattern.dart';
import '../cubit/studio_cubit.dart';
import 'track_style.dart';

const double _rowHeight = 46;
const double _rowGap = 6;
const double _rulerHeight = 22;

/// The 16-step grid. Cells rebuild only when their row changes; the moving
/// playhead is a separate overlay so a step change does not rebuild the grid.
class SequencerGrid extends StatelessWidget {
  const SequencerGrid({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final wide = c.maxWidth >= 900;
        final headerWidth = wide ? 230.0 : 52.0;
        final available = c.maxWidth - headerWidth - AppSpacing.sm;
        final needsScroll =
            available < StepMetrics.totalFor(StepMetrics.minCellWidth);
        final metrics = StepMetrics(
          needsScroll
              ? StepMetrics.minCellWidth
              : StepMetrics.cellFor(available),
        );
        const rows = TrackId.values;
        final gridHeight = rows.length * (_rowHeight + _rowGap);

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: headerWidth,
              child: Column(
                children: [
                  const SizedBox(height: _rulerHeight),
                  for (final t in rows)
                    Padding(
                      padding: const EdgeInsets.only(bottom: _rowGap),
                      child: SizedBox(
                        height: _rowHeight,
                        child: _TrackHeader(track: t, compact: !wide),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: needsScroll
                    ? null
                    : const NeverScrollableScrollPhysics(),
                child: SizedBox(
                  width: metrics.total,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Ruler(metrics: metrics),
                      Stack(
                        children: [
                          Column(
                            children: [
                              for (final t in rows)
                                Padding(
                                  padding: const EdgeInsets.only(
                                    bottom: _rowGap,
                                  ),
                                  child: _TrackStepsRow(
                                    track: t,
                                    metrics: metrics,
                                    paintable: !needsScroll,
                                  ),
                                ),
                            ],
                          ),
                          _Playhead(
                            metrics: metrics,
                            height: gridHeight - _rowGap,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Ruler extends StatelessWidget {
  const _Ruler({required this.metrics});

  final StepMetrics metrics;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelSmall;
    return ExcludeSemantics(
      child: SizedBox(
        height: _rulerHeight,
        child: Stack(
          children: [
            for (var i = 0; i < kStepsPerBar; i += 4)
              Positioned(
                left: metrics.left(i) + 2,
                top: 2,
                child: Text('${i ~/ 4 + 1}', style: style),
              ),
          ],
        ),
      ),
    );
  }
}

class _TrackHeader extends StatelessWidget {
  const _TrackHeader({required this.track, required this.compact});

  final TrackId track;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<StudioCubit>();
    return BlocSelector<StudioCubit, StudioState, (bool, double)>(
      selector: (s) => (
        s.pattern.mutedTracks.contains(track),
        s.pattern.trackVolumes[track]!,
      ),
      builder: (context, v) {
        final (muted, volume) = v;
        final color = muted ? AppColors.textFaint : track.color;
        final muteButton = Semantics(
          toggled: muted,
          label: 'Mute ${track.label}',
          child: IconButton(
            tooltip: muted ? 'Unmute ${track.label}' : 'Mute ${track.label}',
            onPressed: () => cubit.toggleMute(track),
            icon: AnimatedSwitcher(
              duration: Motion.of(context, Motion.fast),
              child: Icon(
                muted ? Icons.volume_off : track.icon,
                key: ValueKey(muted),
                color: color,
              ),
            ),
          ),
        );
        if (compact) return Center(child: muteButton);
        return Row(
          children: [
            muteButton,
            SizedBox(
              width: 82,
              child: Text(
                track.label,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: muted ? AppColors.textFaint : AppColors.text,
                ),
              ),
            ),
            Expanded(
              child: Semantics(
                label: '${track.label} volume',
                child: Slider(
                  value: volume,
                  onChanged: (v) => cubit.setTrackVolume(track, v),
                  activeColor: color,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _TrackStepsRow extends StatelessWidget {
  const _TrackStepsRow({
    required this.track,
    required this.metrics,
    required this.paintable,
  });

  final TrackId track;
  final StepMetrics metrics;
  final bool paintable;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<StudioCubit>();
    return BlocSelector<StudioCubit, StudioState, (String, bool)>(
      selector: (s) => (
        s.pattern.tracks[track]!.map((on) => on ? '1' : '0').join(),
        s.pattern.mutedTracks.contains(track),
      ),
      builder: (context, v) {
        final (bits, muted) = v;
        final row = SizedBox(
          height: _rowHeight,
          child: Stack(
            children: [
              for (var i = 0; i < kStepsPerBar; i++)
                Positioned(
                  left: metrics.left(i),
                  width: metrics.cellWidth,
                  top: 0,
                  bottom: 0,
                  child: _StepCell(
                    track: track,
                    step: i,
                    active: bits[i] == '1',
                    muted: muted,
                    onToggle: () => cubit.toggleStep(track, i),
                  ),
                ),
            ],
          ),
        );
        if (!paintable) return row;
        return _PaintRegion(
          track: track,
          metrics: metrics,
          bits: bits,
          child: row,
        );
      },
    );
  }
}

/// Dragging across a row paints steps on or off (mouse layouts only, so it never
/// fights horizontal scrolling on small screens). The stroke state lives here
/// because the row rebuilds on every painted step.
class _PaintRegion extends StatefulWidget {
  const _PaintRegion({
    required this.track,
    required this.metrics,
    required this.bits,
    required this.child,
  });

  final TrackId track;
  final StepMetrics metrics;
  final String bits;
  final Widget child;

  @override
  State<_PaintRegion> createState() => _PaintRegionState();
}

class _PaintRegionState extends State<_PaintRegion> {
  bool? _paintValue;

  void _paint(double dx) {
    final value = _paintValue;
    if (value == null) return;
    context.read<StudioCubit>().paintStep(
      widget.track,
      widget.metrics.indexAt(dx),
      value,
    );
  }

  void _end() {
    if (_paintValue != null) context.read<StudioCubit>().commitPaint();
    _paintValue = null;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragStart: (d) {
        final i = widget.metrics.indexAt(d.localPosition.dx);
        _paintValue = widget.bits[i] != '1';
        _paint(d.localPosition.dx);
      },
      onHorizontalDragUpdate: (d) => _paint(d.localPosition.dx),
      onHorizontalDragEnd: (_) => _end(),
      onHorizontalDragCancel: _end,
      child: widget.child,
    );
  }
}

class _StepCell extends StatefulWidget {
  const _StepCell({
    required this.track,
    required this.step,
    required this.active,
    required this.muted,
    required this.onToggle,
  });

  final TrackId track;
  final int step;
  final bool active;
  final bool muted;
  final VoidCallback onToggle;

  @override
  State<_StepCell> createState() => _StepCellState();
}

class _StepCellState extends State<_StepCell> {
  bool _hover = false;
  bool _focus = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final beatStart = widget.step % 4 == 0;
    final base = beatStart ? AppColors.surfaceHigh : AppColors.surfaceRaised;
    final color = widget.active
        ? (widget.muted
              ? widget.track.color.withValues(alpha: 0.28)
              : widget.track.color)
        : (_hover ? Color.lerp(base, Colors.white, 0.08)! : base);
    final dur = Motion.of(context, Motion.fast);
    return Semantics(
      button: true,
      toggled: widget.active,
      label: '${widget.track.label} step ${widget.step + 1}',
      child: FocusableActionDetector(
        mouseCursor: SystemMouseCursors.click,
        onShowHoverHighlight: (v) => setState(() => _hover = v),
        onShowFocusHighlight: (v) => setState(() => _focus = v),
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              widget.onToggle();
              return null;
            },
          ),
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) => setState(() => _pressed = true),
          onTapCancel: () => setState(() => _pressed = false),
          onTap: () {
            setState(() => _pressed = false);
            widget.onToggle();
          },
          child: AnimatedScale(
            scale: _pressed ? 0.9 : 1,
            duration: dur,
            child: AnimatedContainer(
              duration: dur,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  width: _focus ? 2 : 1,
                  color: _focus
                      ? Colors.white
                      : widget.active
                      ? Colors.transparent
                      : AppColors.border.withValues(alpha: beatStart ? 1 : 0.5),
                ),
                boxShadow: widget.active && !widget.muted
                    ? [
                        BoxShadow(
                          color: widget.track.color.withValues(alpha: 0.35),
                          blurRadius: 10,
                        ),
                      ]
                    : null,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Column highlight following the current step. Listens to the step only, so the
/// rest of the grid is untouched by playback.
class _Playhead extends StatelessWidget {
  const _Playhead({required this.metrics, required this.height});

  final StepMetrics metrics;
  final double height;

  @override
  Widget build(BuildContext context) {
    return BlocSelector<StudioCubit, StudioState, int>(
      selector: (s) => s.step,
      builder: (context, step) {
        if (step < 0) return const SizedBox.shrink();
        return Positioned(
          left: metrics.left(step) - 3,
          width: metrics.cellWidth + 6,
          top: -3,
          height: height + 6,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(11),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.85),
                  width: 1.5,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
