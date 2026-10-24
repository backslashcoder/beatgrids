import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../audio/audio_engine.dart';
import '../../models/beat_pattern.dart';
import '../cubit/studio_cubit.dart';

/// Play/pause, stop, loop, status, tempo and master volume.
class TransportBar extends StatelessWidget {
  const TransportBar({super.key});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<StudioCubit>();
    return Wrap(
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.sm,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        BlocBuilder<StudioCubit, StudioState>(
          buildWhen: (a, b) =>
              a.playback != b.playback ||
              a.audio != b.audio ||
              a.loop != b.loop,
          builder: (context, s) => Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton.filled(
                key: const Key('transport-play'),
                tooltip: s.isPlaying ? 'Pause (Space)' : 'Play (Space)',
                onPressed: s.audio == AudioStatus.initializing
                    ? null
                    : cubit.togglePlay,
                iconSize: 28,
                icon: Icon(
                  s.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              IconButton.outlined(
                key: const Key('transport-stop'),
                tooltip: 'Stop',
                onPressed: s.playback == PlaybackState.stopped
                    ? null
                    : cubit.stop,
                icon: const Icon(Icons.stop_rounded),
              ),
              const SizedBox(width: AppSpacing.sm),
              FilterChip(
                key: const Key('transport-loop'),
                avatar: const Icon(Icons.repeat, size: 18),
                label: const Text('Loop'),
                selected: s.loop,
                showCheckmark: false,
                onSelected: cubit.setLoop,
                selectedColor: AppColors.lime.withValues(alpha: 0.2),
                side: BorderSide(
                  color: s.loop ? AppColors.lime : AppColors.border,
                ),
              ),
            ],
          ),
        ),
        BlocBuilder<StudioCubit, StudioState>(
          buildWhen: (a, b) => a.playback != b.playback,
          builder: (context, s) => _StatusLabel(state: s),
        ),
        const _BpmControl(),
        const _MasterVolume(),
      ],
    );
  }
}

class _StatusLabel extends StatelessWidget {
  const _StatusLabel({required this.state});

  final StudioState state;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (state.playback) {
      PlaybackState.playing => ('Playing', AppColors.lime),
      PlaybackState.paused => ('Paused', AppColors.amber),
      _ => ('Stopped', AppColors.textDim),
    };
    return Semantics(
      liveRegion: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            key: const Key('transport-status'),
            style: Theme.of(context).textTheme.labelLarge,
          ),
        ],
      ),
    );
  }
}

class _BpmControl extends StatefulWidget {
  const _BpmControl();

  @override
  State<_BpmControl> createState() => _BpmControlState();
}

class _BpmControlState extends State<_BpmControl> {
  final _controller = TextEditingController();
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller.text = '${context.read<StudioCubit>().state.bpm}';
    _focus.addListener(() {
      if (!_focus.hasFocus) _commit();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  /// Applies typed text if it is a valid tempo, otherwise restores the current one.
  void _commit() {
    final cubit = context.read<StudioCubit>();
    final parsed = int.tryParse(_controller.text.trim());
    if (parsed != null && parsed >= kMinBpm && parsed <= kMaxBpm) {
      cubit.setBpm(parsed);
    }
    _controller.text = '${cubit.state.bpm}';
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<StudioCubit>();
    return BlocConsumer<StudioCubit, StudioState>(
      listenWhen: (a, b) => a.bpm != b.bpm,
      listener: (context, s) {
        if (!_focus.hasFocus) _controller.text = '${s.bpm}';
      },
      buildWhen: (a, b) => a.bpm != b.bpm,
      builder: (context, s) => Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          IconButton(
            key: const Key('bpm-down'),
            tooltip: 'Slower',
            onPressed: s.bpm > kMinBpm ? () => cubit.setBpm(s.bpm - 1) : null,
            icon: const Icon(Icons.remove),
          ),
          SizedBox(
            width: 72,
            child: TextField(
              key: const Key('bpm-field'),
              controller: _controller,
              focusNode: _focus,
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(3),
              ],
              decoration: const InputDecoration(
                isDense: true,
                suffixText: 'BPM',
                suffixStyle: TextStyle(fontSize: 10, color: AppColors.textDim),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 10,
                ),
              ),
              style: Theme.of(context).textTheme.titleMedium,
              onSubmitted: (_) => _commit(),
            ),
          ),
          IconButton(
            key: const Key('bpm-up'),
            tooltip: 'Faster',
            onPressed: s.bpm < kMaxBpm ? () => cubit.setBpm(s.bpm + 1) : null,
            icon: const Icon(Icons.add),
          ),
          SizedBox(
            width: 170,
            child: Semantics(
              label: 'Tempo',
              child: Slider(
                key: const Key('bpm-slider'),
                min: kMinBpm.toDouble(),
                max: kMaxBpm.toDouble(),
                divisions: kMaxBpm - kMinBpm,
                value: s.bpm.toDouble(),
                onChanged: (v) => cubit.setBpm(v),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MasterVolume extends StatelessWidget {
  const _MasterVolume();

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<StudioCubit>();
    return BlocSelector<StudioCubit, StudioState, double>(
      selector: (s) => s.pattern.masterVolume,
      builder: (context, volume) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            volume == 0 ? Icons.volume_off : Icons.volume_up,
            size: 20,
            color: AppColors.textDim,
          ),
          SizedBox(
            width: 130,
            child: Semantics(
              label: 'Master volume',
              child: Slider(
                key: const Key('master-volume'),
                value: volume,
                onChanged: cubit.setMasterVolume,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
