import 'package:flutter/material.dart';

import '../../app/theme/app_spacing.dart';
import '../../core/widgets/bg_button.dart';
import '../../core/widgets/chips_and_toggles.dart';
import '../../core/widgets/creator_avatar.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/page_container.dart';
import '../../core/widgets/states.dart';
import '../beats/presentation/beat_card.dart';

/// Debug-only catalogue of shared components (route /dev/components).
/// Sample beats here are design fixtures and never appear in release builds.
class ComponentGalleryPage extends StatefulWidget {
  const ComponentGalleryPage({super.key});

  @override
  State<ComponentGalleryPage> createState() => _ComponentGalleryPageState();
}

class _ComponentGalleryPageState extends State<ComponentGalleryPage> {
  bool _liked = false;
  bool _saved = false;
  String _genre = 'Hip-Hop';

  static const _samples = [
    BeatCardData(
      id: '1',
      title: 'Midnight Boom Bap',
      creatorName: 'ada',
      genre: 'Hip-Hop',
      bpm: 90,
      plays: 1204,
      likes: 88,
    ),
    BeatCardData(
      id: '2',
      title: 'Warehouse Pulse',
      creatorName: 'koji',
      genre: 'Techno',
      bpm: 132,
      plays: 640,
      likes: 41,
    ),
    BeatCardData(
      id: '3',
      title: 'Rainy Lo-fi Loop',
      creatorName: 'mira',
      genre: 'Lo-fi',
      bpm: 78,
      plays: 310,
      likes: 29,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return PageContainer(
      title: 'Components',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'Buttons'),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              BgButton(
                label: 'Primary',
                icon: Icons.add,
                onPressed: () =>
                    showToast(context, 'Saved draft', kind: ToastKind.success),
              ),
              BgButton(
                label: 'Secondary',
                variant: BgButtonVariant.secondary,
                onPressed: () => showToast(context, 'Heads up'),
              ),
              BgButton(
                label: 'Ghost',
                variant: BgButtonVariant.ghost,
                onPressed: () => showToast(
                  context,
                  'Could not publish',
                  kind: ToastKind.error,
                ),
              ),
              const BgButton(label: 'Loading', loading: true, onPressed: null),
              const BgButton(label: 'Disabled', onPressed: null),
              BgButton(
                label: 'Confirm dialog',
                variant: BgButtonVariant.secondary,
                onPressed: () async {
                  final ok = await confirmDialog(
                    context,
                    title: 'Delete beat?',
                    message: 'This cannot be undone.',
                    confirmLabel: 'Delete',
                    destructive: true,
                  );
                  if (context.mounted)
                    showToast(context, ok ? 'Deleted' : 'Cancelled');
                },
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          const SectionHeader(title: 'Inputs'),
          const Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              SizedBox(
                width: 280,
                child: TextField(
                  decoration: InputDecoration(
                    labelText: 'Title',
                    hintText: 'Name your beat',
                  ),
                ),
              ),
              SizedBox(
                width: 280,
                child: TextField(
                  decoration: InputDecoration(
                    labelText: 'With error',
                    errorText: 'Title is required',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          const SectionHeader(title: 'Chips, toggles, avatars'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (final g in ['Hip-Hop', 'House', 'Techno', 'Lo-fi'])
                GenreChip(
                  label: g,
                  selected: _genre == g,
                  onTap: () => setState(() => _genre = g),
                ),
              BounceToggle(
                active: _liked,
                icon: Icons.favorite_border,
                activeIcon: Icons.favorite,
                count: _liked ? 89 : 88,
                tooltip: 'Like',
                onPressed: () => setState(() => _liked = !_liked),
              ),
              BounceToggle(
                active: _saved,
                icon: Icons.bookmark_border,
                activeIcon: Icons.bookmark,
                activeColor: Colors.amber,
                tooltip: 'Save',
                onPressed: () => setState(() => _saved = !_saved),
              ),
              const CreatorAvatar(name: 'ada', size: 40),
              const CreatorAvatar(name: 'koji', size: 40),
              const CreatorAvatar(name: 'mira', size: 40),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          const SectionHeader(title: 'Beat cards'),
          _Grid(
            children: [
              for (final b in _samples)
                BeatCard(beat: b, onTap: () {}, onPlay: () {}),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          const SectionHeader(title: 'Loading'),
          const _Grid(
            children: [
              BeatCardSkeleton(),
              BeatCardSkeleton(),
              BeatCardSkeleton(),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          const SectionHeader(title: 'Empty and error'),
          const Wrap(
            children: [
              SizedBox(
                width: 420,
                child: EmptyState(
                  icon: Icons.library_music_outlined,
                  title: 'No beats yet',
                  message: 'Publish a beat to see it here.',
                ),
              ),
              SizedBox(
                width: 420,
                child: ErrorState(
                  message: 'We could not load the feed. Check your connection.',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Grid extends StatelessWidget {
  const _Grid({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      final cols = c.maxWidth >= 900
          ? 3
          : c.maxWidth >= 560
          ? 2
          : 1;
      const gap = AppSpacing.md;
      final w = (c.maxWidth - gap * (cols - 1)) / cols;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [
          for (final child in children) SizedBox(width: w, child: child),
        ],
      );
    },
  );
}
