import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/widgets/bg_button.dart';
import '../../../core/widgets/chips_and_toggles.dart';
import '../../../core/widgets/creator_avatar.dart';
import '../../../core/widgets/feedback.dart';
import '../../../core/widgets/page_container.dart';
import '../../../core/widgets/sign_in_gate.dart';
import '../../../core/widgets/states.dart';
import '../../../core/errors/app_failure.dart';
import '../../auth/presentation/cubit/auth_cubit.dart';
import '../../beats/data/beat_repository.dart';
import '../../beats/models/genres.dart';
import '../../beats/presentation/beat_card.dart';
import '../../beats/presentation/widgets/pattern_preview.dart';
import '../data/community_repository.dart';
import '../models/public_beat.dart';
import 'cubit/beat_detail_cubit.dart';
import 'cubit/player_cubit.dart';

/// A published beat, reachable and shareable at `/beat/<slug>`.
class BeatDetailPage extends StatelessWidget {
  const BeatDetailPage({super.key, required this.slug});

  final String slug;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      // A new cubit per slug: navigating between beats never shows stale data.
      key: ValueKey(slug),
      create: (_) =>
          BeatDetailCubit(context.read<CommunityRepository>(), slug)..load(),
      child: BlocConsumer<BeatDetailCubit, BeatDetailState>(
        listenWhen: (a, b) => b.message != null && a.message != b.message,
        listener: (context, s) {
          showToast(context, s.message!, kind: ToastKind.error);
          context.read<BeatDetailCubit>().messageShown();
        },
        builder: (context, s) {
          final title = s.item?.beat.title ?? 'Beat';
          return PageContainer(
            title: title,
            maxWidth: 960,
            child: switch (s.status) {
              DetailStatus.loading => const _DetailSkeleton(),
              DetailStatus.notFound => ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 420),
                child: EmptyState(
                  icon: Icons.search_off,
                  title: 'Beat not found',
                  message: 'It may have been unpublished or deleted, or the link is wrong.',
                  actionLabel: 'Explore beats',
                  onAction: () => context.go('/explore'),
                ),
              ),
              DetailStatus.failed => ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 420),
                child: ErrorState(
                  message: s.error ?? 'Could not load this beat.',
                  onRetry: () => context.read<BeatDetailCubit>().load(),
                ),
              ),
              DetailStatus.ready => _DetailBody(item: s.item!, state: s),
            },
          );
        },
      ),
    );
  }
}

class _DetailSkeleton extends StatelessWidget {
  const _DetailSkeleton();

  @override
  Widget build(BuildContext context) => const Column(
    key: Key('detail-skeleton'),
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      AspectRatio(
        aspectRatio: 2.4,
        child: Skeleton(height: double.infinity, radius: AppRadius.lg),
      ),
      SizedBox(height: AppSpacing.lg),
      Skeleton(width: 280, height: 30),
      SizedBox(height: AppSpacing.sm),
      Skeleton(width: 180, height: 16),
    ],
  );
}

class _DetailBody extends StatelessWidget {
  const _DetailBody({required this.item, required this.state});

  final BeatItem item;
  final BeatDetailState state;

  @override
  Widget build(BuildContext context) {
    final beat = item.beat;
    final text = Theme.of(context).textTheme;
    final cubit = context.read<BeatDetailCubit>();
    final player = context.read<PlayerCubit>();
    final myId = context.select<AuthCubit, String?>((c) => c.state.profile?.id);
    final isMine = myId != null && myId == beat.creatorId;

    final cover = ClipRRect(
      borderRadius: AppRadius.card,
      child: AspectRatio(
        aspectRatio: 2.4,
        child: item.coverUrl == null
            ? DefaultCover(seed: beat.title)
            : Image.network(
                item.coverUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => DefaultCover(seed: beat.title),
              ),
      ),
    );

    final playButton = BlocBuilder<PlayerCubit, PlayerState>(
      buildWhen: (a, b) => a.status != b.status || a.beat?.id != b.beat?.id,
      builder: (context, p) {
        final current = p.isCurrent(beat.id);
        final playing = current && p.isPlaying;
        final loading = current && p.status == PlayerStatus.loading;
        return BgButton(
          key: const Key('detail-play'),
          label: playing ? 'Pause' : 'Play',
          icon: playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
          loading: loading,
          onPressed: () => playing
              ? player.pause()
              : player.play(beat, pattern: state.pattern),
        );
      },
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        cover,
        const SizedBox(height: AppSpacing.lg),
        Text(beat.title, style: text.headlineLarge),
        const SizedBox(height: AppSpacing.sm),
        InkWell(
          key: const Key('detail-creator'),
          borderRadius: AppRadius.control,
          onTap: () => context.go('/profile/${beat.creatorUsername}'),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CreatorAvatar(
                  name: beat.creatorDisplayName,
                  imageUrl: item.avatarUrl,
                  size: 28,
                ),
                const SizedBox(width: 10),
                Text(beat.creatorDisplayName, style: text.titleSmall),
                const SizedBox(width: 6),
                Text('@${beat.creatorUsername}', style: text.bodySmall),
              ],
            ),
          ),
        ),
        if (beat.isRemix) _Attribution(beat: beat),
        const SizedBox(height: AppSpacing.md),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            GenreChip(label: genreLabel(beat.genre)),
            _Stat(icon: Icons.speed, label: '${beat.bpm} BPM'),
            _Stat(icon: Icons.play_arrow, label: '${beat.playCount} plays'),
            _Stat(icon: Icons.favorite, label: '${beat.likeCount} likes'),
            if (beat.allowRemix)
              const _Stat(icon: Icons.call_split, label: 'Remixable'),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            playButton,
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.border),
                borderRadius: AppRadius.control,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  BounceToggle(
                    key: const Key('detail-like'),
                    active: item.liked,
                    icon: Icons.favorite_border,
                    activeIcon: Icons.favorite,
                    count: beat.likeCount,
                    tooltip: item.liked ? 'Unlike' : 'Like',
                    onPressed: () async {
                      if (await ensureSignedIn(
                        context,
                        reason:
                            'Create a free account or sign in to like beats.',
                      )) {
                        cubit.toggleLike();
                      }
                    },
                  ),
                  BounceToggle(
                    key: const Key('detail-save'),
                    active: item.saved,
                    icon: Icons.bookmark_border,
                    activeIcon: Icons.bookmark,
                    activeColor: AppColors.amber,
                    tooltip: item.saved ? 'Remove from saved' : 'Save',
                    onPressed: () async {
                      if (await ensureSignedIn(
                        context,
                        reason: 'Create a free account or sign in to save beats for later.',
                      )) {
                        cubit.toggleSave();
                      }
                    },
                  ),
                ],
              ),
            ),
            BgButton(
              key: const Key('detail-share'),
              label: 'Copy link',
              icon: Icons.link,
              variant: BgButtonVariant.secondary,
              onPressed: () async {
                await Clipboard.setData(
                  ClipboardData(text: '${Uri.base.origin}/beat/${beat.slug}'),
                );
                if (context.mounted)
                  showToast(context, 'Link copied', kind: ToastKind.success);
              },
            ),
            if (beat.allowRemix && !isMine) _RemixButton(beat: beat),
            if (isMine)
              BgButton(
                key: const Key('detail-edit'),
                label: 'Edit',
                icon: Icons.edit_outlined,
                variant: BgButtonVariant.ghost,
                onPressed: () => context.go('/studio/${beat.id}'),
              ),
          ],
        ),
        if (beat.description != null && beat.description!.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          Text(beat.description!, style: text.bodyLarge),
        ],
        const SizedBox(height: AppSpacing.xl),
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppRadius.card,
            border: Border.all(color: AppColors.border),
          ),
          child: BlocSelector<PlayerCubit, PlayerState, int>(
            selector: (p) => p.isPlaying && p.isCurrent(beat.id) ? p.step : -1,
            builder: (context, step) => Align(
              alignment: Alignment.centerLeft,
              child: PatternPreview(pattern: state.pattern!, step: step),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
      ],
    );
  }
}

/// "Remix of X by @y". Links to the original while it is still public;
/// otherwise says it is gone but keeps the credit.
class _Attribution extends StatelessWidget {
  const _Attribution({required this.beat});

  final PublicBeat beat;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final title = beat.sourceTitle ?? 'another beat';
    final by = beat.sourceCreatorUsername == null
        ? ''
        : ' by @${beat.sourceCreatorUsername}';
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xs),
      child: beat.sourceAvailable
          ? InkWell(
              key: const Key('detail-attribution'),
              borderRadius: AppRadius.control,
              onTap: () => context.go('/beat/${beat.sourceSlug}'),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.call_split,
                      size: 16,
                      color: AppColors.violet,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'Remix of "$title"$by',
                        style: text.bodyMedium?.copyWith(
                          color: AppColors.violet,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : Row(
              key: const Key('detail-attribution'),
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.call_split,
                  size: 16,
                  color: AppColors.textDim,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    'Remix of "$title"$by (original no longer available)',
                    style: text.bodyMedium,
                  ),
                ),
              ],
            ),
    );
  }
}

/// Copies the beat into the user's own studio as a private draft.
class _RemixButton extends StatefulWidget {
  const _RemixButton({required this.beat});

  final PublicBeat beat;

  @override
  State<_RemixButton> createState() => _RemixButtonState();
}

class _RemixButtonState extends State<_RemixButton> {
  bool _busy = false;

  Future<void> _remix() async {
    if (_busy) return;
    final repo = context.read<BeatRepository>();
    if (!await ensureSignedIn(
          context,
          reason: 'Create a free account or sign in to remix beats.',
        ) ||
        !mounted) {
      return;
    }
    setState(() => _busy = true);
    try {
      final remix = await repo.createRemix(widget.beat.id);
      if (!mounted) return;
      showToast(
        context,
        'Remix created. It stays private until you publish it.',
        kind: ToastKind.success,
      );
      context.go('/studio/${remix.id}');
    } on AppFailure catch (f) {
      if (mounted) showToast(context, f.message, kind: ToastKind.error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => BgButton(
    key: const Key('detail-remix'),
    label: 'Remix',
    icon: Icons.call_split,
    variant: BgButtonVariant.secondary,
    loading: _busy,
    onPressed: _remix,
  );
}

class _Stat extends StatelessWidget {
  const _Stat({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 16, color: AppColors.textDim),
      const SizedBox(width: 4),
      Text(label, style: Theme.of(context).textTheme.bodyMedium),
    ],
  );
}
