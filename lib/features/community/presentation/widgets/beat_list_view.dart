import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../core/widgets/bg_button.dart';
import '../../../../core/widgets/feedback.dart';
import '../../../../core/widgets/sign_in_gate.dart';
import '../../../../core/widgets/states.dart';
import '../../../beats/presentation/beat_card.dart';
import '../../models/public_beat.dart';
import '../cubit/beat_list_cubit.dart';
import '../cubit/player_cubit.dart';

/// Number of grid columns for a given content width.
int beatGridColumns(double width) => width >= 1000
    ? 4
    : width >= 720
    ? 3
    : width >= 460
    ? 2
    : 1;

/// Skeletons, empty and error states, the card grid and "Load more" for any
/// [BeatListCubit] found in the widget tree.
class BeatListView extends StatelessWidget {
  const BeatListView({
    super.key,
    required this.emptyIcon,
    required this.emptyTitle,
    required this.emptyMessage,
    this.emptyActionLabel,
    this.onEmptyAction,
    this.maxItems,
  });

  final IconData emptyIcon;
  final String emptyTitle;
  final String emptyMessage;
  final String? emptyActionLabel;
  final VoidCallback? onEmptyAction;

  /// Show only the first N items and no "Load more" (used on the home page).
  final int? maxItems;

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<BeatListCubit, BeatListState>(
      listenWhen: (a, b) => b.message != null && a.message != b.message,
      listener: (context, s) {
        showToast(context, s.message!, kind: ToastKind.error);
        context.read<BeatListCubit>().messageShown();
      },
      builder: (context, s) {
        final cubit = context.read<BeatListCubit>();
        return switch (s.status) {
          ListStatus.loading => const _Skeletons(),
          ListStatus.failed => ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 320),
            child: ErrorState(
              message: s.error ?? 'Could not load beats.',
              onRetry: cubit.reload,
            ),
          ),
          ListStatus.ready when s.items.isEmpty => ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 320),
            child: EmptyState(
              icon: emptyIcon,
              title: emptyTitle,
              message: emptyMessage,
              actionLabel: emptyActionLabel,
              onAction: onEmptyAction,
            ),
          ),
          ListStatus.ready => Column(
            children: [
              _Grid(
                items: maxItems == null
                    ? s.items
                    : s.items.take(maxItems!).toList(),
              ),
              if (maxItems == null && s.hasMore)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.lg),
                  child: BgButton(
                    key: const Key('load-more'),
                    label: 'Load more',
                    variant: BgButtonVariant.secondary,
                    loading: s.loadingMore,
                    onPressed: cubit.loadMore,
                  ),
                ),
            ],
          ),
        };
      },
    );
  }
}

class _Grid extends StatelessWidget {
  const _Grid({required this.items});

  final List<BeatItem> items;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final cols = beatGridColumns(c.maxWidth);
        const gap = AppSpacing.md;
        final w = (c.maxWidth - gap * (cols - 1)) / cols;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final item in items)
              SizedBox(
                width: w,
                child: BeatItemCard(item: item),
              ),
          ],
        );
      },
    );
  }
}

class _Skeletons extends StatelessWidget {
  const _Skeletons();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final cols = beatGridColumns(c.maxWidth);
        const gap = AppSpacing.md;
        final w = (c.maxWidth - gap * (cols - 1)) / cols;
        return Wrap(
          key: const Key('beat-skeletons'),
          spacing: gap,
          runSpacing: gap,
          children: [
            for (var i = 0; i < cols * 2; i++)
              SizedBox(width: w, child: const BeatCardSkeleton()),
          ],
        );
      },
    );
  }
}

/// A card wired to the player, likes and saves, for any list cubit.
class BeatItemCard extends StatelessWidget {
  const BeatItemCard({super.key, required this.item});

  final BeatItem item;

  @override
  Widget build(BuildContext context) {
    final list = context.read<BeatListCubit>();
    final player = context.read<PlayerCubit>();
    return BlocSelector<PlayerCubit, PlayerState, bool>(
      selector: (p) => p.isPlaying && p.isCurrent(item.beat.id),
      builder: (context, playing) => BeatCard(
        beat: BeatCardData.fromItem(item),
        playing: playing,
        liked: item.liked,
        saved: item.saved,
        onTap: () => context.go('/beat/${item.beat.slug}'),
        onPlay: () => playing ? player.pause() : player.play(item.beat),
        onLike: () async {
          if (await ensureSignedIn(
            context,
            reason: 'Create a free account or sign in to like beats.',
          )) {
            list.toggleLike(item);
          }
        },
        onSave: () async {
          if (await ensureSignedIn(
            context,
            reason: 'Create a free account or sign in to save beats for later.',
          )) {
            list.toggleSave(item);
          }
        },
      ),
    );
  }
}
