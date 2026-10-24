import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/theme/app_colors.dart';
import '../../models/beat_pattern.dart';
import '../cubit/studio_cubit.dart';
import 'track_style.dart';

/// Volume sliders for narrow layouts, where the grid's track headers only have
/// room for the mute button.
class MixerPanel extends StatelessWidget {
  const MixerPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<StudioCubit>();
    return Column(
      children: [
        for (final t in TrackId.values)
          BlocSelector<StudioCubit, StudioState, (bool, double)>(
            selector: (s) =>
                (s.pattern.mutedTracks.contains(t), s.pattern.trackVolumes[t]!),
            builder: (context, v) {
              final (muted, volume) = v;
              return Row(
                children: [
                  SizedBox(
                    width: 96,
                    child: Text(
                      t.label,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: muted ? AppColors.textFaint : AppColors.text,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Semantics(
                      label: '${t.label} volume',
                      child: Slider(
                        value: volume,
                        onChanged: (v) => cubit.setTrackVolume(t, v),
                        activeColor: muted ? AppColors.textFaint : t.color,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
      ],
    );
  }
}
