import 'package:flutter/material.dart';

enum BgButtonVariant { primary, secondary, ghost }

/// Standard button. While [loading] it is disabled, which also prevents
/// duplicate form submissions.
class BgButton extends StatelessWidget {
  const BgButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.variant = BgButtonVariant.primary,
    this.loading = false,
    this.expanded = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final BgButtonVariant variant;
  final bool loading;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final VoidCallback? action = loading ? null : onPressed;
    final child = AnimatedSize(
      duration: const Duration(milliseconds: 140),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (loading)
            SizedBox.square(
              dimension: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: IconTheme.of(context).color,
              ),
            )
          else if (icon != null)
            Icon(icon, size: 18),
          if (loading || icon != null) const SizedBox(width: 8),
          Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
    final button = switch (variant) {
      BgButtonVariant.primary => FilledButton(onPressed: action, child: child),
      BgButtonVariant.secondary => OutlinedButton(
        onPressed: action,
        child: child,
      ),
      BgButtonVariant.ghost => TextButton(onPressed: action, child: child),
    };
    return expanded ? SizedBox(width: double.infinity, child: button) : button;
  }
}
