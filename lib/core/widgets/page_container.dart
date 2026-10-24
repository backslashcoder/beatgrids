import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';

/// Sets the browser tab title and centres content at a readable width with
/// responsive gutters. Pass [scroll] false for pages that manage their own scrolling.
class PageContainer extends StatelessWidget {
  const PageContainer({
    super.key,
    required this.title,
    required this.child,
    this.scroll = true,
    this.maxWidth = Breakpoints.maxContent,
  });

  final String title;
  final Widget child;
  final bool scroll;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Title(
      title: title == 'BeatGrid' ? title : '$title · BeatGrid',
      color: AppColors.background,
      child: LayoutBuilder(
        builder: (context, c) {
          final gutter = AppSpacing.gutter(c.maxWidth);
          final content = Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: gutter,
                  vertical: AppSpacing.lg,
                ),
                child: child,
              ),
            ),
          );
          return scroll ? SingleChildScrollView(child: content) : content;
        },
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader({super.key, required this.title, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.md),
    child: Row(
      children: [
        Expanded(
          child: Text(title, style: Theme.of(context).textTheme.headlineSmall),
        ),
        ?trailing,
      ],
    ),
  );
}
