import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/services/audio_coordinator.dart';
import '../../../core/services/unsaved_changes_guard.dart';
import '../../../core/widgets/feedback.dart';
import '../../../core/widgets/page_container.dart';
import '../../../core/widgets/states.dart';
import '../../beats/data/beat_repository.dart';
import '../../beats/presentation/cubit/beat_editor_cubit.dart';
import '../../beats/presentation/widgets/beat_header.dart';
import '../audio/audio_engine.dart';
import '../models/beat_pattern.dart';
import 'cubit/studio_cubit.dart';
import 'widgets/audio_banner.dart';
import 'widgets/mixer_panel.dart';
import 'widgets/sequencer_grid.dart';
import 'widgets/studio_toolbar.dart';
import 'widgets/transport_bar.dart';

/// The beat-making studio. Owns a [StudioCubit] (and through it the audio
/// engine) and a [BeatEditorCubit] for as long as the page is mounted, so
/// leaving the studio releases all audio resources and returning never starts
/// a second engine.
///
/// `/studio` and `/studio/:id` share one page instance (same page key), so the
/// first save can move the URL to `/studio/<id>` without rebuilding the studio
/// or interrupting playback.
class StudioPage extends StatefulWidget {
  const StudioPage({super.key, this.beatId, this.engine});

  /// Beat being edited; null for a new beat.
  final String? beatId;

  /// Injectable for tests; defaults to the browser audio engine.
  final AudioEngine? engine;

  @override
  State<StudioPage> createState() => _StudioPageState();
}

class _StudioPageState extends State<StudioPage> {
  late final StudioCubit _studio;
  late final BeatEditorCubit _editor;
  UnsavedChangesGuard? _guard;
  bool _isDirty() => _editor.state.dirty && !_editor.state.deleted;

  @override
  void initState() {
    super.initState();
    _studio = StudioCubit(
      widget.engine ?? AudioEngine(),
      coordinator: context.read<AudioCoordinator>(),
    );
    _editor = BeatEditorCubit(context.read<BeatRepository>(), _studio);
    _guard = context.read<UnsavedChangesGuard>()..register(_isDirty);
    if (widget.beatId != null) {
      _editor.load(widget.beatId!);
    } else {
      _restorePending();
    }
  }

  Future<void> _restorePending() async {
    final restored = await _editor.restorePending();
    if (restored && mounted) {
      showToast(context, 'Restored your unsaved beat', kind: ToastKind.info);
    }
  }

  @override
  void didUpdateWidget(StudioPage old) {
    super.didUpdateWidget(old);
    final id = widget.beatId;
    if (id == old.beatId) return;
    if (id != null) {
      // Our own first save moves the URL here; anything else is a different beat.
      if (id != _editor.state.beatId) _editor.load(id);
    } else if (_editor.state.isSaved) {
      // Navigated from a saved beat to a blank studio.
      _studio.loadBeat(
        pattern: BeatPattern.empty(),
        bpm: 120,
        genre: 'hip-hop',
      );
      _editor.startNew();
    }
  }

  @override
  void dispose() {
    _guard?.unregister(_isDirty);
    _editor.close();
    _studio.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: _studio),
        BlocProvider.value(value: _editor),
      ],
      child: MultiBlocListener(
        listeners: [
          // First save of a new beat: reflect the id in the URL.
          BlocListener<BeatEditorCubit, EditorState>(
            listenWhen: (a, b) => a.beatId != b.beatId && b.beatId != null,
            listener: (context, s) {
              if (widget.beatId != s.beatId) context.go('/studio/${s.beatId}');
            },
          ),
          BlocListener<BeatEditorCubit, EditorState>(
            listenWhen: (a, b) => !a.deleted && b.deleted,
            listener: (context, s) => context.go('/my-beats'),
          ),
        ],
        child: const PageContainer(title: 'Studio', child: _StudioView()),
      ),
    );
  }
}

class _StudioView extends StatelessWidget {
  const _StudioView();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<BeatEditorCubit, EditorState>(
      buildWhen: (a, b) => a.load != b.load || a.loadError != b.loadError,
      builder: (context, e) => switch (e.load) {
        EditorLoad.ready => const _StudioBody(),
        EditorLoad.loading => const _LoadingStudio(),
        EditorLoad.notFound => ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 420),
          child: EmptyState(
            icon: Icons.search_off,
            title: 'Beat not found',
            message: 'It may have been deleted, or it is a private draft that is not yours.',
            actionLabel: 'Start a new beat',
            onAction: () => context.go('/studio'),
          ),
        ),
        EditorLoad.forbidden => ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 420),
          child: EmptyState(
            icon: Icons.lock_outline,
            title: 'This beat is not yours',
            message: 'Only its creator can edit it.',
            actionLabel: 'Start a new beat',
            onAction: () => context.go('/studio'),
          ),
        ),
        EditorLoad.failed => ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 420),
          child: ErrorState(
            title: 'Could not open this beat',
            message: e.loadError ?? 'Check your connection and try again.',
            onRetry: () => context.read<BeatEditorCubit>().retryLoad(),
          ),
        ),
      },
    );
  }
}

class _LoadingStudio extends StatelessWidget {
  const _LoadingStudio();

  @override
  Widget build(BuildContext context) => const Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Skeleton(width: 260, height: 32),
      SizedBox(height: AppSpacing.md),
      Skeleton(height: 56, radius: AppRadius.md),
      SizedBox(height: AppSpacing.md),
      Skeleton(height: 280, radius: AppRadius.lg),
    ],
  );
}

class _StudioBody extends StatelessWidget {
  const _StudioBody();

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<StudioCubit>();
    final narrow = MediaQuery.sizeOf(context).width < 900;
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
              // Space belongs to the text field while typing (title, tempo...).
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
              const BeatHeader(),
              const SizedBox(height: AppSpacing.sm),
              const StudioToolbar(),
              const SizedBox(height: AppSpacing.md),
              const AudioBanner(),
              // On phones the grid comes first so it is visible without scrolling.
              if (narrow) ...[
                _Panel(child: const SequencerGrid()),
                const SizedBox(height: AppSpacing.md),
                _Panel(child: const TransportBar()),
                const SizedBox(height: AppSpacing.md),
                _Panel(title: 'Mixer', child: const MixerPanel()),
              ] else ...[
                _Panel(child: const TransportBar()),
                const SizedBox(height: AppSpacing.md),
                _Panel(child: const SequencerGrid()),
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
