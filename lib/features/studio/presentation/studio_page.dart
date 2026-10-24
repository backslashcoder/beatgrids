import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/widgets/page_container.dart';
import '../audio/audio_engine.dart';
import 'cubit/studio_cubit.dart';
import 'widgets/audio_banner.dart';
import 'widgets/mixer_panel.dart';
import 'widgets/sequencer_grid.dart';
import 'widgets/studio_toolbar.dart';
import 'widgets/transport_bar.dart';

/// The beat-making studio. Owns a [StudioCubit] (and through it the audio
/// engine) for as long as the page is mounted, so leaving the studio releases
/// all audio resources and returning never starts a second engine.
class StudioPage extends StatelessWidget {
  const StudioPage({super.key, this.beatId, this.engine});

  /// Beat being edited; null for a new beat. Loading it arrives in Phase 5.
  final String? beatId;

  /// Injectable for tests; defaults to the browser audio engine.
  final AudioEngine? engine;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => StudioCubit(engine ?? AudioEngine()),
      child: const PageContainer(title: 'Studio', child: _StudioView()),
    );
  }
}

class _StudioView extends StatelessWidget {
  const _StudioView();

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<StudioCubit>();
    final text = Theme.of(context).textTheme;
    return Shortcuts(
      shortcuts: {
        const SingleActivator(LogicalKeyboardKey.space): const _PlayIntent(),
        const SingleActivator(LogicalKeyboardKey.keyZ, control: true):
            const _UndoIntent(),
        const SingleActivator(LogicalKeyboardKey.keyZ, meta: true):
            const _UndoIntent(),
        const SingleActivator(
          LogicalKeyboardKey.keyZ,
          control: true,
          shift: true,
        ): const _RedoIntent(),
        const SingleActivator(LogicalKeyboardKey.keyZ, meta: true, shift: true):
            const _RedoIntent(),
        const SingleActivator(LogicalKeyboardKey.keyY, control: true):
            const _RedoIntent(),
      },
      child: Actions(
        actions: {
          _PlayIntent: CallbackAction<_PlayIntent>(
            onInvoke: (_) {
              // Space belongs to the text field while typing (e.g. the tempo box).
              final typing = FocusManager.instance.primaryFocus?.context
                  ?.findAncestorWidgetOfExactType<EditableText>();
              if (typing == null) cubit.togglePlay();
              return null;
            },
          ),
          _UndoIntent: CallbackAction<_UndoIntent>(
            onInvoke: (_) => cubit.undo(),
          ),
          _RedoIntent: CallbackAction<_RedoIntent>(
            onInvoke: (_) => cubit.redo(),
          ),
        },
        child: Focus(
          autofocus: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Studio', style: text.headlineMedium),
              const SizedBox(height: AppSpacing.md),
              const StudioToolbar(),
              const SizedBox(height: AppSpacing.md),
              const AudioBanner(),
              _Panel(child: const TransportBar()),
              const SizedBox(height: AppSpacing.md),
              _Panel(child: const SequencerGrid()),
              if (MediaQuery.sizeOf(context).width < 900) ...[
                const SizedBox(height: AppSpacing.md),
                _Panel(title: 'Mixer', child: const MixerPanel()),
              ],
              const SizedBox(height: AppSpacing.xl),
            ],
          ),
        ),
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child, this.title});

  final Widget child;
  final String? title;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(AppSpacing.md),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: AppRadius.card,
      border: Border.all(color: AppColors.border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (title != null) ...[
          Text(title!, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
        ],
        child,
      ],
    ),
  );
}

class _PlayIntent extends Intent {
  const _PlayIntent();
}

class _UndoIntent extends Intent {
  const _UndoIntent();
}

class _RedoIntent extends Intent {
  const _RedoIntent();
}
