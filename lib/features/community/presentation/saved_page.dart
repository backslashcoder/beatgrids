import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../core/widgets/page_container.dart';
import '../data/community_repository.dart';
import 'cubit/beat_list_cubit.dart';
import 'widgets/beat_list_view.dart';

/// The signed-in user's saved beats (private to them).
class SavedPage extends StatelessWidget {
  const SavedPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<BeatListCubit>(
      create: (_) =>
          SavedBeatsCubit(context.read<CommunityRepository>())..reload(),
      child: PageContainer(
        title: 'Saved beats',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Saved beats',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Only you can see this list.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.lg),
            BeatListView(
              emptyIcon: Icons.bookmark_border,
              emptyTitle: 'Nothing saved yet',
              emptyMessage: 'Tap the bookmark on any beat to keep it here.',
              emptyActionLabel: 'Explore beats',
              onEmptyAction: () => context.go('/explore'),
            ),
            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }
}
