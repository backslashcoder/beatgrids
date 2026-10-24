import 'package:flutter/material.dart';

import '../../../core/widgets/page_container.dart';
import 'spike_page.dart';

/// Hosts the studio. Currently the Phase 1 audio spike; replaced in Phase 4.
class StudioPage extends StatelessWidget {
  const StudioPage({super.key, this.beatId});

  /// Beat being edited; null for a new beat. Loading it arrives in Phase 5.
  final String? beatId;

  @override
  Widget build(BuildContext context) =>
      PageContainer(title: 'Studio', scroll: false, child: const SpikePage());
}
