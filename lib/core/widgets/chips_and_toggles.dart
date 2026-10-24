import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';

class GenreChip extends StatelessWidget {
  const GenreChip({
    super.key,
    required this.label,
    this.selected = false,
    this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final dur = Motion.of(context, Motion.fast);
    return Semantics(
      button: onTap != null,
      selected: selected,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: AnimatedContainer(
          duration: dur,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? AppColors.lime : AppColors.surfaceRaised,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(
              color: selected ? AppColors.lime : AppColors.border,
            ),
          ),
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelMedium
                ?.copyWith(color: selected ? AppColors.onLime : AppColors.text),
          ),
        ),
      ),
    );
  }
}

/// Icon toggle with a small bounce, used for like and save.
class BounceToggle extends StatelessWidget {
  const BounceToggle({
    super.key,
    required this.active,
    required this.icon,
    required this.activeIcon,
    required this.onPressed,
    required this.tooltip,
    this.activeColor = AppColors.coral,
    this.count,
  });

  final bool active;
  final IconData icon;
  final IconData activeIcon;
  final VoidCallback? onPressed;
  final String tooltip;
  final Color activeColor;
  final int? count;

  @override
  Widget build(BuildContext context) {
    final dur = Motion.of(context, const Duration(milliseconds: 220));
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        borderRadius: AppRadius.control,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedScale(
                scale: active ? 1.0 : 0.92,
                duration: dur,
                curve: Curves.elasticOut,
                child: AnimatedSwitcher(
                  duration: dur,
                  transitionBuilder: (c, a) =>
                      ScaleTransition(scale: a, child: c),
                  child: Icon(
                    active ? activeIcon : icon,
                    key: ValueKey(active),
                    size: 20,
                    color: active ? activeColor : AppColors.textDim,
                  ),
                ),
              ),
              if (count != null) ...[
                const SizedBox(width: 6),
                Text('$count', style: Theme.of(context).textTheme.labelMedium),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
