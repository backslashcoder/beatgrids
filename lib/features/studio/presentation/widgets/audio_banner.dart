import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/widgets/bg_button.dart';
import '../cubit/studio_cubit.dart';

/// Explains the audio state: not started yet, loading, or failed (with retry).
class AudioBanner extends StatelessWidget {
  const AudioBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<StudioCubit, StudioState>(
      buildWhen: (a, b) => a.audio != b.audio || a.audioError != b.audioError,
      builder: (context, s) {
        if (s.audio == AudioStatus.ready && s.audioError == null)
          return const SizedBox.shrink();
        final (icon, color, text) = switch (s.audio) {
          AudioStatus.failed => (
            Icons.volume_off,
            AppColors.coral,
            s.audioError ?? 'Audio failed to start.',
          ),
          AudioStatus.initializing => (
            Icons.hourglass_top,
            AppColors.cyan,
            'Starting the sound engine...',
          ),
          AudioStatus.ready => (
            Icons.warning_amber,
            AppColors.amber,
            s.audioError!,
          ),
          AudioStatus.idle => (
            Icons.volume_up_outlined,
            AppColors.textDim,
            'Sound turns on when you press Play or tap a step.',
          ),
        };
        return Semantics(
          liveRegion: true,
          child: Container(
            margin: const EdgeInsets.only(bottom: AppSpacing.md),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              borderRadius: AppRadius.control,
              border: Border.all(color: color.withValues(alpha: 0.35)),
            ),
            child: Row(
              children: [
                if (s.audio == AudioStatus.initializing)
                  const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  Icon(icon, color: color, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    text,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                if (s.audio == AudioStatus.failed)
                  BgButton(
                    key: const Key('audio-retry'),
                    label: 'Retry',
                    variant: BgButtonVariant.secondary,
                    onPressed: () => context.read<StudioCubit>().ensureAudio(),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
