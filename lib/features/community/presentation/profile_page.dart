import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/widgets/bg_button.dart';
import '../../../core/widgets/creator_avatar.dart';
import '../../../core/widgets/page_container.dart';
import '../../../core/widgets/states.dart';
import '../../auth/presentation/cubit/auth_cubit.dart';
import '../data/community_repository.dart';
import '../models/public_beat.dart';
import 'cubit/beat_list_cubit.dart';
import 'cubit/creator_profile_cubit.dart';
import 'widgets/beat_list_view.dart';

/// Public creator profile at `/profile/<username>`.
class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key, required this.username});

  final String username;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      key: ValueKey(username),
      create: (_) =>
          CreatorProfileCubit(context.read<CommunityRepository>(), username)
            ..load(),
      child: BlocBuilder<CreatorProfileCubit, CreatorProfileState>(
        builder: (context, s) => PageContainer(
          title: s.profile != null
              ? '${s.profile!.displayName} (@${s.profile!.username})'
              : '@$username',
          child: switch (s.status) {
            ProfileStatus.loading => const _ProfileSkeleton(),
            ProfileStatus.notFound => ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 420),
              child: EmptyState(
                icon: Icons.person_off_outlined,
                title: 'Creator not found',
                message: 'There is no one called @$username.',
                actionLabel: 'Explore beats',
                onAction: () => context.go('/explore'),
              ),
            ),
            ProfileStatus.failed => ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 420),
              child: ErrorState(
                message: s.error ?? 'Could not load this profile.',
                onRetry: () => context.read<CreatorProfileCubit>().load(),
              ),
            ),
            ProfileStatus.ready => _ProfileBody(
              profile: s.profile!,
              avatarUrl: s.avatarUrl,
            ),
          },
        ),
      ),
    );
  }
}

class _ProfileSkeleton extends StatelessWidget {
  const _ProfileSkeleton();

  @override
  Widget build(BuildContext context) => const Row(
    key: Key('profile-skeleton'),
    children: [
      Skeleton(width: 96, height: 96, radius: 48),
      SizedBox(width: AppSpacing.lg),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Skeleton(width: 220, height: 28),
            SizedBox(height: AppSpacing.sm),
            Skeleton(width: 120, height: 16),
          ],
        ),
      ),
    ],
  );
}

class _ProfileBody extends StatelessWidget {
  const _ProfileBody({required this.profile, required this.avatarUrl});

  final CreatorProfile profile;
  final String? avatarUrl;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final isMe = context.select<AuthCubit, bool>(
      (c) => c.state.profile?.id == profile.id,
    );
    final stats = profile.stats;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: AppSpacing.lg,
          runSpacing: AppSpacing.md,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            CreatorAvatar(
              name: profile.displayName,
              imageUrl: avatarUrl,
              size: 96,
            ),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(profile.displayName, style: text.headlineLarge),
                  Text('@${profile.username}', style: text.bodyMedium),
                  if (profile.bio != null && profile.bio!.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Text(profile.bio!, style: text.bodyLarge),
                  ],
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Joined ${DateFormat.yMMMM().format(profile.createdAt)}',
                    style: text.bodySmall,
                  ),
                ],
              ),
            ),
            if (isMe)
              BgButton(
                key: const Key('profile-edit'),
                label: 'Edit profile',
                icon: Icons.edit_outlined,
                variant: BgButtonVariant.secondary,
                onPressed: () => context.go('/settings'),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.md,
          children: [
            _StatTile(
              key: const Key('stat-beats'),
              value: stats.beatCount,
              label: 'Beats',
            ),
            _StatTile(
              key: const Key('stat-likes'),
              value: stats.likeCount,
              label: 'Likes',
            ),
            _StatTile(
              key: const Key('stat-plays'),
              value: stats.playCount,
              label: 'Plays',
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),
        Text('Beats', style: text.headlineSmall),
        const SizedBox(height: AppSpacing.md),
        BlocProvider<BeatListCubit>(
          create: (ctx) =>
              CreatorBeatsCubit(ctx.read<CommunityRepository>(), profile.id)
                ..reload(),
          child: BeatListView(
            emptyIcon: Icons.library_music_outlined,
            emptyTitle: 'No published beats yet',
            emptyMessage: isMe
                ? 'Publish a beat from the studio and it will show up here.'
                : '${profile.displayName} has not published anything yet.',
            emptyActionLabel: isMe ? 'Open the studio' : null,
            onEmptyAction: isMe ? () => context.go('/studio') : null,
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({super.key, required this.value, required this.label});

  final int value;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    width: 130,
    padding: const EdgeInsets.all(AppSpacing.md),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: AppRadius.card,
      border: Border.all(color: AppColors.border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          NumberFormat.compact().format(value),
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    ),
  );
}
