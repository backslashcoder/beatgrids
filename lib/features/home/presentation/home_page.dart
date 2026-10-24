import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/widgets/bg_button.dart';
import '../../../core/widgets/page_container.dart';
import '../../community/data/community_repository.dart';
import '../../community/presentation/cubit/beat_list_cubit.dart';
import '../../community/presentation/widgets/beat_list_view.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return PageContainer(
      title: 'BeatGrid',
      child: LayoutBuilder(
        builder: (context, c) {
          final wide = c.maxWidth >= 860;
          final hero = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'MAKE. SHARE. REMIX.',
                style: text.labelSmall?.copyWith(color: AppColors.lime),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Build a beat in your browser.',
                style: wide ? text.displayMedium : text.headlineLarge,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'A step sequencer with real drum sounds, a community to publish to, '
                'and remixing that always credits the original creator.',
                style: text.bodyLarge?.copyWith(color: AppColors.textDim),
              ),
              const SizedBox(height: AppSpacing.lg),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  BgButton(
                    label: 'Open the studio',
                    icon: Icons.graphic_eq,
                    onPressed: () => context.go('/studio'),
                  ),
                  BgButton(
                    label: 'Explore beats',
                    variant: BgButtonVariant.secondary,
                    onPressed: () => context.go('/explore'),
                  ),
                ],
              ),
            ],
          );
          return Column(
            children: [
              const SizedBox(height: AppSpacing.lg),
              if (wide)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(flex: 5, child: hero),
                    const SizedBox(width: AppSpacing.xl),
                    const Expanded(flex: 5, child: _HeroGrid()),
                  ],
                )
              else ...[
                hero,
                const SizedBox(height: AppSpacing.xl),
                const _HeroGrid(),
              ],
              const SizedBox(height: AppSpacing.xxl),
              Flex(
                direction: wide ? Axis.horizontal : Axis.vertical,
                crossAxisAlignment: wide
                    ? CrossAxisAlignment.start
                    : CrossAxisAlignment.stretch,
                children: [
                  for (final (i, f) in const [
                    (
                      Icons.grid_view_rounded,
                      'Create',
                      'Tap steps, hear it instantly, tweak tempo and levels.',
                      AppColors.lime,
                    ),
                    (
                      Icons.public,
                      'Publish',
                      'Save private drafts, then share a link to your finished beat.',
                      AppColors.cyan,
                    ),
                    (
                      Icons.call_split,
                      'Remix',
                      'Fork any beat its creator allows, with attribution kept.',
                      AppColors.violet,
                    ),
                  ].indexed) ...[
                    if (i > 0)
                      SizedBox(width: AppSpacing.md, height: AppSpacing.md),
                    wide
                        ? Expanded(child: _Feature(f.$1, f.$2, f.$3, f.$4))
                        : _Feature(f.$1, f.$2, f.$3, f.$4),
                  ],
                ],
              ),
              const SizedBox(height: AppSpacing.xxl),
              const _LatestSection(),
              const SizedBox(height: AppSpacing.xxl),
            ],
          );
        },
      ),
    );
  }
}

class _Feature extends StatelessWidget {
  const _Feature(this.icon, this.title, this.body, this.color);

  final IconData icon;
  final String title;
  final String body;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.card,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(height: AppSpacing.md),
          Text(title, style: text.titleLarge),
          const SizedBox(height: AppSpacing.xs),
          Text(body, style: text.bodyMedium),
        ],
      ),
    );
  }
}

/// Decorative looping sequencer. It is purely visual and makes no sound.
class _HeroGrid extends StatefulWidget {
  const _HeroGrid();

  @override
  State<_HeroGrid> createState() => _HeroGridState();
}

class _HeroGridState extends State<_HeroGrid>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3200),
  );

  static const _rows = <(Color, List<int>)>[
    (AppColors.kick, [0, 7, 10]),
    (AppColors.snare, [4, 12]),
    (AppColors.closedHat, [0, 2, 4, 6, 8, 10, 12, 14]),
    (AppColors.openHat, [15]),
    (AppColors.clap, [4, 12]),
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadius.card,
          border: Border.all(color: AppColors.border),
        ),
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            final playhead = (_c.value * 16).floor() % 16;
            final animating = _c.isAnimating;
            return Column(
              children: [
                for (final (color, steps) in _rows)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        for (var i = 0; i < 16; i++) ...[
                          if (i > 0 && i % 4 == 0) const SizedBox(width: 6),
                          Expanded(
                            child: AspectRatio(
                              aspectRatio: 1,
                              child: Container(
                                margin: const EdgeInsets.all(1.5),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(
                                    math.min(6, 4),
                                  ),
                                  color: steps.contains(i)
                                      ? (animating && i == playhead
                                            ? Colors.white
                                            : color)
                                      : (animating && i == playhead
                                            ? AppColors.surfaceHigh
                                            : AppColors.surfaceRaised),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// The newest published beats, straight from the community.
class _LatestSection extends StatelessWidget {
  const _LatestSection();

  @override
  Widget build(BuildContext context) {
    return BlocProvider<BeatListCubit>(
      create: (_) =>
          ExploreCubit(context.read<CommunityRepository>())..reload(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionHeader(
            title: 'Fresh from the community',
            trailing: TextButton(
              key: const Key('home-see-all'),
              onPressed: () => context.go('/explore'),
              child: const Text('See all'),
            ),
          ),
          BeatListView(
            maxItems: 4,
            emptyIcon: Icons.library_music_outlined,
            emptyTitle: 'No beats published yet',
            emptyMessage:
                'Be the first: make a beat in the studio and publish it.',
            emptyActionLabel: 'Make a beat',
            onEmptyAction: () => context.go('/studio'),
          ),
        ],
      ),
    );
  }
}
