import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'page_container.dart';
import 'states.dart';

/// Honest stand-in for a route whose feature is not built yet.
class ComingSoonPage extends StatelessWidget {
  const ComingSoonPage({
    super.key,
    required this.title,
    required this.icon,
    required this.phase,
    required this.description,
  });

  final String title;
  final IconData icon;
  final int phase;
  final String description;

  @override
  Widget build(BuildContext context) {
    return PageContainer(
      title: title,
      scroll: false,
      child: EmptyState(
        icon: icon,
        title: title,
        message: '$description\n(Planned for phase $phase.)',
        actionLabel: 'Back home',
        onAction: () => context.go('/'),
      ),
    );
  }
}
