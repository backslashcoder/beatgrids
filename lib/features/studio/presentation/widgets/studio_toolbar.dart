import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/widgets/bg_button.dart';
import '../../../../core/widgets/feedback.dart';
import '../../models/starter_patterns.dart';
import '../cubit/studio_cubit.dart';

/// Starter patterns, randomize, clear and undo/redo.
class StudioToolbar extends StatelessWidget {
  const StudioToolbar({super.key});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<StudioCubit>();
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        BlocSelector<StudioCubit, StudioState, String?>(
          selector: (s) => s.starterId,
          builder: (context, selected) => MenuAnchor(
            style: const MenuStyle(
              backgroundColor: WidgetStatePropertyAll(AppColors.surfaceRaised),
            ),
            menuChildren: [
              for (final p in starterPatterns)
                MenuItemButton(
                  key: Key('starter-${p.id}'),
                  leadingIcon: Icon(
                    p.id == selected ? Icons.check : Icons.queue_music,
                    size: 18,
                    color: p.id == selected
                        ? AppColors.lime
                        : AppColors.textDim,
                  ),
                  trailingIcon: Text(
                    '${p.bpm} BPM',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  onPressed: () => cubit.loadStarter(p),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text(p.name),
                  ),
                ),
            ],
            builder: (context, controller, _) => BgButton(
              key: const Key('starter-menu'),
              label: selected == null
                  ? 'Starter patterns'
                  : starterById(selected)!.name,
              icon: Icons.library_music_outlined,
              variant: BgButtonVariant.secondary,
              onPressed: () =>
                  controller.isOpen ? controller.close() : controller.open(),
            ),
          ),
        ),
        BgButton(
          key: const Key('randomize'),
          label: 'Randomize',
          icon: Icons.casino_outlined,
          variant: BgButtonVariant.secondary,
          onPressed: cubit.randomize,
        ),
        BlocSelector<StudioCubit, StudioState, bool>(
          selector: (s) => !s.pattern.isEmpty,
          builder: (context, hasSteps) => BgButton(
            key: const Key('clear'),
            label: 'Clear',
            icon: Icons.delete_sweep_outlined,
            variant: BgButtonVariant.ghost,
            onPressed: hasSteps
                ? () async {
                    final ok = await confirmDialog(
                      context,
                      title: 'Clear the pattern?',
                      message: 'All steps will be removed. You can undo this.',
                      confirmLabel: 'Clear',
                      destructive: true,
                    );
                    if (ok) cubit.clearPattern();
                  }
                : null,
          ),
        ),
        BlocBuilder<StudioCubit, StudioState>(
          buildWhen: (a, b) => a.canUndo != b.canUndo || a.canRedo != b.canRedo,
          builder: (context, s) => Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                key: const Key('undo'),
                tooltip: 'Undo (Ctrl+Z)',
                onPressed: s.canUndo ? cubit.undo : null,
                icon: const Icon(Icons.undo),
              ),
              IconButton(
                key: const Key('redo'),
                tooltip: 'Redo (Ctrl+Shift+Z)',
                onPressed: s.canRedo ? cubit.redo : null,
                icon: const Icon(Icons.redo),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
