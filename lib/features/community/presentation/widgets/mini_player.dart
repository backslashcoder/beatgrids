import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../cubit/player_cubit.dart';

/// Persistent preview player shown above the bottom navigation on every page
/// except the studio (which owns the audio engine while it is open).
class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PlayerCubit, PlayerState>(
      builder: (context, p) {
        final beat = p.beat;
        return AnimatedSize(
          duration: Motion.of(context, Motion.medium),
          curve: Curves.easeOutCubic,
          alignment: Alignment.bottomCenter,
          child: beat == null
              ? const SizedBox(width: double.infinity)
              : _Bar(player: p),
        );
      },
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.player});

  final PlayerState player;

  @override
  Widget build(BuildContext context) {
    final beat = player.beat!;
    final cubit = context.read<PlayerCubit>();
    final text = Theme.of(context).textTheme;
    final loading = player.status == PlayerStatus.loading;
    final failed = player.status == PlayerStatus.error;
    return Semantics(
      container: true,
      label: 'Now playing ${beat.title} by ${beat.creatorDisplayName}',
      child: Container(
        key: const Key('mini-player'),
        decoration: const BoxDecoration(
          color: AppColors.surfaceRaised,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.gutter(MediaQuery.sizeOf(context).width),
          vertical: AppSpacing.sm,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: Breakpoints.maxContent),
            child: Row(
              children: [
                if (loading)
                  const SizedBox.square(
                    dimension: 40,
                    child: Padding(
                      padding: EdgeInsets.all(10),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                else
                  IconButton.filled(
                    key: const Key('mini-player-toggle'),
                    tooltip: player.isPlaying ? 'Pause' : 'Play',
                    onPressed: failed ? null : cubit.toggle,
                    icon: Icon(
                      player.isPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                    ),
                  ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: InkWell(
                    key: const Key('mini-player-open'),
                    borderRadius: AppRadius.control,
                    onTap: () => context.go('/beat/${beat.slug}'),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            beat.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: text.titleSmall,
                          ),
                          Text(
                            failed
                                ? (player.error ?? 'Could not play this beat')
                                : '${beat.creatorDisplayName} · ${beat.bpm} BPM',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: text.bodySmall?.copyWith(
                              color: failed ? AppColors.coral : null,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (MediaQuery.sizeOf(context).width >= Breakpoints.mobile)
                  _StepDots(step: player.isPlaying ? player.step : -1),
                IconButton(
                  key: const Key('mini-player-close'),
                  tooltip: 'Close player',
                  onPressed: cubit.dismiss,
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 16 small bars; the current step lights up.
class _StepDots extends StatelessWidget {
  const _StepDots({required this.step});

  final int step;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < 16; i++)
          Container(
            width: 5,
            height: i % 4 == 0 ? 16 : 10,
            margin: EdgeInsets.only(left: i % 4 == 0 && i > 0 ? 7 : 3),
            decoration: BoxDecoration(
              color: i == step ? AppColors.lime : AppColors.surfaceHigh,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
      ],
    ),
  );
}
