import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../core/widgets/chips_and_toggles.dart';
import '../../../core/widgets/page_container.dart';
import '../../beats/models/genres.dart';
import '../data/community_repository.dart';
import '../models/public_beat.dart';
import 'cubit/beat_list_cubit.dart';
import 'widgets/beat_list_view.dart';

/// Community discovery: latest or trending beats, genre filter and search.
class ExplorePage extends StatelessWidget {
  const ExplorePage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<BeatListCubit>(
      create: (_) =>
          ExploreCubit(context.read<CommunityRepository>())..reload(),
      child: const PageContainer(title: 'Explore', child: _ExploreBody()),
    );
  }
}

class _ExploreBody extends StatefulWidget {
  const _ExploreBody();

  @override
  State<_ExploreBody> createState() => _ExploreBodyState();
}

class _ExploreBodyState extends State<_ExploreBody> {
  final _search = TextEditingController();
  Timer? _debounce;

  ExploreCubit get _cubit => context.read<BeatListCubit>() as ExploreCubit;

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    // Wait for a pause in typing so each keystroke is not a database query.
    _debounce = Timer(
      const Duration(milliseconds: 350),
      () => _cubit.setQuery(value),
    );
    setState(() {});
  }

  void _clearFilters() {
    _debounce?.cancel();
    _search.clear();
    _cubit.clearFilters();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return BlocBuilder<BeatListCubit, BeatListState>(
      buildWhen: (a, b) =>
          false, // filter widgets read the cubit directly below
      builder: (context, _) {
        final cubit = _cubit;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Explore', style: text.headlineMedium),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Beats made by the BeatGrid community.',
              style: text.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.lg),
            LayoutBuilder(
              builder: (context, c) {
                final field = TextField(
                  key: const Key('explore-search'),
                  controller: _search,
                  onChanged: _onQueryChanged,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (v) {
                    _debounce?.cancel();
                    cubit.setQuery(v);
                  },
                  decoration: InputDecoration(
                    hintText: 'Search titles, creators or genres',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _search.text.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Clear search',
                            icon: const Icon(Icons.close),
                            onPressed: () {
                              _search.clear();
                              _debounce?.cancel();
                              cubit.setQuery('');
                              setState(() {});
                            },
                          ),
                  ),
                );
                final sort = _SortToggle(cubit: cubit);
                if (c.maxWidth < 640) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      field,
                      const SizedBox(height: AppSpacing.sm),
                      Align(alignment: Alignment.centerLeft, child: sort),
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: field),
                    const SizedBox(width: AppSpacing.md),
                    sort,
                  ],
                );
              },
            ),
            const SizedBox(height: AppSpacing.md),
            _GenreChips(cubit: cubit),
            const SizedBox(height: AppSpacing.lg),
            BlocBuilder<BeatListCubit, BeatListState>(
              buildWhen: (a, b) =>
                  a.status != b.status || a.items.isEmpty != b.items.isEmpty,
              builder: (context, _) => BeatListView(
                emptyIcon: cubit.hasFilters
                    ? Icons.search_off
                    : Icons.library_music_outlined,
                emptyTitle: cubit.hasFilters
                    ? 'No beats match'
                    : 'No beats published yet',
                emptyMessage: cubit.hasFilters
                    ? 'Try a different search or genre.'
                    : 'Be the first: make a beat in the studio and publish it.',
                emptyActionLabel: cubit.hasFilters ? 'Clear filters' : null,
                onEmptyAction: cubit.hasFilters ? _clearFilters : null,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
          ],
        );
      },
    );
  }
}

class _SortToggle extends StatelessWidget {
  const _SortToggle({required this.cubit});

  final ExploreCubit cubit;

  @override
  Widget build(BuildContext context) {
    return StatefulBuilder(
      builder: (context, setState) => SegmentedButton<FeedSort>(
        key: const Key('explore-sort'),
        showSelectedIcon: false,
        segments: const [
          ButtonSegment(
            value: FeedSort.latest,
            label: Text('Latest'),
            icon: Icon(Icons.schedule, size: 18),
          ),
          ButtonSegment(
            value: FeedSort.trending,
            label: Text('Trending'),
            icon: Icon(Icons.local_fire_department_outlined, size: 18),
          ),
        ],
        selected: {cubit.sort},
        onSelectionChanged: (s) {
          cubit.setSort(s.first);
          setState(() {});
        },
      ),
    );
  }
}

class _GenreChips extends StatelessWidget {
  const _GenreChips({required this.cubit});

  final ExploreCubit cubit;

  @override
  Widget build(BuildContext context) {
    return StatefulBuilder(
      builder: (context, setState) => Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: [
          GenreChip(
            label: 'All',
            selected: cubit.genre == null,
            onTap: () {
              cubit.setGenre(null);
              setState(() {});
            },
          ),
          for (final g in genres)
            GenreChip(
              label: g.label,
              selected: cubit.genre == g.id,
              onTap: () {
                cubit.setGenre(cubit.genre == g.id ? null : g.id);
                setState(() {});
              },
            ),
        ],
      ),
    );
  }
}
