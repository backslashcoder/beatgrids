import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/widgets/bg_button.dart';
import '../../../core/widgets/feedback.dart';
import '../../../core/widgets/page_container.dart';
import '../../../core/widgets/states.dart';
import '../data/beat_repository.dart';
import '../models/beat.dart';
import '../models/genres.dart';
import 'beat_card.dart';
import 'cubit/my_beats_cubit.dart';

/// The signed-in user's drafts and published beats, with edit, publish,
/// unpublish, link and delete actions.
class MyBeatsPage extends StatelessWidget {
  const MyBeatsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => MyBeatsCubit(context.read<BeatRepository>())..load(),
      child: PageContainer(
        title: 'My beats',
        maxWidth: 900,
        child: BlocConsumer<MyBeatsCubit, MyBeatsState>(
          listenWhen: (a, b) => b.message != null && a.message != b.message,
          listener: (context, s) {
            showToast(context, s.message!);
            context.read<MyBeatsCubit>().messageShown();
          },
          builder: (context, s) {
            final text = Theme.of(context).textTheme;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text('My beats', style: text.headlineMedium),
                    ),
                    BgButton(
                      label: 'New beat',
                      icon: Icons.add,
                      onPressed: () => context.go('/studio'),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                switch (s.status) {
                  MyBeatsStatus.loading => const _Loading(),
                  MyBeatsStatus.failed => ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 360),
                    child: ErrorState(
                      message: s.error ?? 'Could not load your beats.',
                      onRetry: () => context.read<MyBeatsCubit>().load(),
                    ),
                  ),
                  MyBeatsStatus.ready when s.beats.isEmpty => ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 360),
                    child: EmptyState(
                      icon: Icons.library_music_outlined,
                      title: 'No beats yet',
                      message: 'Make something in the studio and save it. Drafts show up here.',
                      actionLabel: 'Open the studio',
                      onAction: () => context.go('/studio'),
                    ),
                  ),
                  MyBeatsStatus.ready => Column(
                    children: [
                      for (final beat in s.beats)
                        _BeatRow(beat: beat, busy: s.busyIds.contains(beat.id)),
                      if (s.hasMore)
                        Padding(
                          padding: const EdgeInsets.only(top: AppSpacing.md),
                          child: BgButton(
                            label: 'Load more',
                            variant: BgButtonVariant.secondary,
                            loading: s.loadingMore,
                            onPressed: () =>
                                context.read<MyBeatsCubit>().loadMore(),
                          ),
                        ),
                    ],
                  ),
                },
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (var i = 0; i < 3; i++) ...const [
        Skeleton(height: 92, radius: AppRadius.lg),
        SizedBox(height: AppSpacing.sm),
      ],
    ],
  );
}

class _BeatRow extends StatelessWidget {
  const _BeatRow({required this.beat, required this.busy});

  final BeatSummary beat;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<MyBeatsCubit>();
    final text = Theme.of(context).textTheme;
    final statusColor = beat.isPublished ? AppColors.lime : AppColors.cyan;
    return Container(
      key: Key('beat-row-${beat.id}'),
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.card,
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            child: SizedBox(
              width: 72,
              height: 56,
              child: DefaultCover(seed: beat.title),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  beat.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.titleMedium,
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: AppSpacing.sm,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                      child: Text(
                        beat.isPublished ? 'Published' : 'Draft',
                        style: text.labelSmall?.copyWith(color: statusColor),
                      ),
                    ),
                    Text(
                      '${genreLabel(beat.genre)} · ${beat.bpm} BPM',
                      style: text.bodySmall,
                    ),
                    if (beat.allowRemix)
                      Text('Remixable', style: text.bodySmall),
                    if (beat.isRemix)
                      Text(
                        'Remix of ${beat.sourceTitle}',
                        key: Key('remix-tag-${beat.id}'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.bodySmall,
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          if (busy)
            const SizedBox.square(
              dimension: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            Wrap(
              spacing: 4,
              children: [
                IconButton(
                  key: Key('edit-${beat.id}'),
                  tooltip: 'Edit in studio',
                  onPressed: () => context.go('/studio/${beat.id}'),
                  icon: const Icon(Icons.edit_outlined),
                ),
                PopupMenuButton<String>(
                  key: Key('menu-${beat.id}'),
                  tooltip: 'More actions',
                  color: AppColors.surfaceRaised,
                  onSelected: (v) async {
                    switch (v) {
                      case 'publish':
                        // Publishing is reviewed in the studio, where title, pattern and
                        // genre are validated before anything goes public.
                        context.go('/studio/${beat.id}');
                      case 'unpublish':
                        cubit.setPublished(beat, false);
                      case 'link':
                        await Clipboard.setData(
                          ClipboardData(
                            text: '${Uri.base.origin}/beat/${beat.slug}',
                          ),
                        );
                        if (context.mounted)
                          showToast(
                            context,
                            'Link copied',
                            kind: ToastKind.success,
                          );
                      case 'delete':
                        final ok = await confirmDialog(
                          context,
                          title: 'Delete "${beat.title}"?',
                          message: 'This permanently deletes the beat. This cannot be undone.',
                          confirmLabel: 'Delete',
                          destructive: true,
                        );
                        if (ok) cubit.delete(beat);
                    }
                  },
                  itemBuilder: (_) => [
                    if (beat.isPublished) ...[
                      const PopupMenuItem(
                        value: 'link',
                        child: Text('Copy link'),
                      ),
                      const PopupMenuItem(
                        value: 'unpublish',
                        child: Text('Unpublish'),
                      ),
                    ] else
                      const PopupMenuItem(
                        value: 'publish',
                        child: Text('Review and publish'),
                      ),
                    const PopupMenuItem(value: 'delete', child: Text('Delete')),
                  ],
                ),
              ],
            ),
        ],
      ),
    );
  }
}
