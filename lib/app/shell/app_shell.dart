import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

class _Destination {
  const _Destination(this.label, this.path, this.icon, this.selectedIcon);
  final String label;
  final String path;
  final IconData icon;
  final IconData selectedIcon;
}

const _destinations = [
  _Destination('Home', '/', Icons.home_outlined, Icons.home_rounded),
  _Destination('Explore', '/explore', Icons.explore_outlined, Icons.explore),
  _Destination(
    'Studio',
    '/studio',
    Icons.grid_view_outlined,
    Icons.grid_view_rounded,
  ),
];

int _selectedIndex(String path) {
  if (path == '/') return 0;
  if (path.startsWith('/explore') ||
      path.startsWith('/beat/') ||
      path.startsWith('/profile/')) {
    return 1;
  }
  if (path.startsWith('/studio')) return 2;
  return -1; // auth, settings etc. highlight nothing
}

/// Responsive frame: top bar with nav on tablet/desktop, bottom bar on mobile.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.path, required this.child});

  final String path;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final mobile = Breakpoints.isMobile(width);
    final selected = _selectedIndex(path);
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(64),
        child: _TopBar(selected: selected, mobile: mobile, width: width),
      ),
      body: child,
      bottomNavigationBar: mobile && selected >= 0
          ? NavigationBar(
              selectedIndex: selected,
              onDestinationSelected: (i) => context.go(_destinations[i].path),
              destinations: [
                for (final d in _destinations)
                  NavigationDestination(
                    icon: Icon(d.icon),
                    selectedIcon: Icon(d.selectedIcon),
                    label: d.label,
                  ),
              ],
            )
          : null,
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.selected,
    required this.mobile,
    required this.width,
  });

  final int selected;
  final bool mobile;
  final double width;

  @override
  Widget build(BuildContext context) {
    final gutter = AppSpacing.gutter(width);
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.background,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: Breakpoints.maxContent),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: gutter),
              child: Row(
                children: [
                  const _Logo(),
                  if (!mobile) ...[
                    const SizedBox(width: AppSpacing.xl),
                    for (var i = 0; i < _destinations.length; i++)
                      _NavLink(
                        destination: _destinations[i],
                        selected: i == selected,
                      ),
                  ],
                  const Spacer(),
                  if (mobile)
                    IconButton(
                      tooltip: 'Sign in',
                      onPressed: () => context.go('/login'),
                      icon: const Icon(Icons.account_circle_outlined),
                    )
                  else ...[
                    TextButton(
                      onPressed: () => context.go('/login'),
                      child: const Text('Sign in'),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    FilledButton(
                      onPressed: () => context.go('/signup'),
                      child: const Text('Sign up'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Logo extends StatelessWidget {
  const _Logo();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'BeatGrid home',
      child: InkWell(
        borderRadius: AppRadius.control,
        onTap: () => context.go('/'),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const _LogoMark(),
              const SizedBox(width: 10),
              Text('BeatGrid', style: Theme.of(context).textTheme.titleLarge),
            ],
          ),
        ),
      ),
    );
  }
}

/// Tiny 2x2 step-grid glyph.
class _LogoMark extends StatelessWidget {
  const _LogoMark();

  @override
  Widget build(BuildContext context) {
    Widget cell(bool on) => Container(
      width: 9,
      height: 9,
      decoration: BoxDecoration(
        color: on ? AppColors.lime : AppColors.surfaceHigh,
        borderRadius: BorderRadius.circular(2.5),
      ),
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [cell(true), const SizedBox(width: 3), cell(false)],
        ),
        const SizedBox(height: 3),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [cell(false), const SizedBox(width: 3), cell(true)],
        ),
      ],
    );
  }
}

class _NavLink extends StatelessWidget {
  const _NavLink({required this.destination, required this.selected});

  final _Destination destination;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      child: TextButton.icon(
        onPressed: () => context.go(destination.path),
        icon: Icon(
          selected ? destination.selectedIcon : destination.icon,
          size: 20,
          color: selected ? AppColors.lime : AppColors.textDim,
        ),
        label: Text(
          destination.label,
          style: TextStyle(
            color: selected ? AppColors.text : AppColors.textDim,
          ),
        ),
      ),
    );
  }
}
