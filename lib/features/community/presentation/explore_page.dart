import 'package:flutter/material.dart';

import '../../../core/widgets/coming_soon_page.dart';

/// Placeholder until the Supabase-backed feed lands in Phase 6.
class ExplorePage extends StatelessWidget {
  const ExplorePage({super.key});

  @override
  Widget build(BuildContext context) => const ComingSoonPage(
    title: 'Explore',
    icon: Icons.explore_outlined,
    phase: 6,
    description:
        'Latest and trending beats from the community will appear here.',
  );
}
