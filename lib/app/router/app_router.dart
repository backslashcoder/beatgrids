import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/widgets/states.dart';
import '../../features/community/presentation/explore_page.dart';
import '../../features/dev/component_gallery_page.dart';
import '../../features/home/presentation/home_page.dart';
import '../../features/studio/presentation/studio_page.dart';
import '../../core/widgets/coming_soon_page.dart';
import '../shell/app_shell.dart';
import '../theme/app_spacing.dart';
import 'route_guards.dart';

CustomTransitionPage<void> _page(GoRouterState state, Widget child) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 220),
    transitionsBuilder: (context, animation, _, child) {
      if (Motion.of(context, Motion.medium) == Duration.zero) return child;
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween(
            begin: const Offset(0, 0.015),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
  );
}

abstract final class AppRouter {
  /// [signedIn] is wired to the real session in Phase 3; until then nobody can
  /// be signed in, so protected routes redirect to /login.
  static GoRouter create({
    bool Function()? signedIn,
    Listenable? refreshListenable,
    String initialLocation = '/',
  }) {
    return GoRouter(
      initialLocation: initialLocation,
      refreshListenable: refreshListenable,
      redirect: (context, state) => RouteGuards.redirect(
        location: state.uri,
        signedIn: signedIn?.call() ?? false,
      ),
      errorBuilder: (context, state) => Scaffold(
        body: EmptyState(
          icon: Icons.search_off,
          title: 'Page not found',
          message: 'There is nothing at ${state.uri.path}.',
          actionLabel: 'Back home',
          onAction: () => context.go('/'),
        ),
      ),
      routes: [
        ShellRoute(
          builder: (context, state, child) =>
              AppShell(path: state.uri.path, child: child),
          routes: [
            GoRoute(
              path: '/',
              pageBuilder: (c, s) => _page(s, const HomePage()),
            ),
            GoRoute(
              path: '/explore',
              pageBuilder: (c, s) => _page(s, const ExplorePage()),
            ),
            GoRoute(
              path: '/studio',
              pageBuilder: (c, s) => _page(s, const StudioPage()),
            ),
            GoRoute(
              path: '/studio/:id',
              pageBuilder: (c, s) =>
                  _page(s, StudioPage(beatId: s.pathParameters['id'])),
            ),
            GoRoute(
              path: '/beat/:id',
              pageBuilder: (c, s) => _page(
                s,
                ComingSoonPage(
                  title: 'Beat',
                  icon: Icons.album_outlined,
                  phase: 6,
                  description:
                      'Published beat pages (${s.pathParameters['id']}) arrive with the community.',
                ),
              ),
            ),
            GoRoute(
              path: '/profile/:username',
              pageBuilder: (c, s) => _page(
                s,
                ComingSoonPage(
                  title: '@${s.pathParameters['username']}',
                  icon: Icons.person_outline,
                  phase: 6,
                  description: 'Creator profiles arrive with the community.',
                ),
              ),
            ),
            GoRoute(
              path: '/settings',
              pageBuilder: (c, s) => _page(
                s,
                const ComingSoonPage(
                  title: 'Settings',
                  icon: Icons.settings_outlined,
                  phase: 3,
                  description: 'Account and profile settings arrive with authentication.',
                ),
              ),
            ),
            GoRoute(
              path: '/login',
              pageBuilder: (c, s) => _page(
                s,
                const ComingSoonPage(
                  title: 'Sign in',
                  icon: Icons.login,
                  phase: 3,
                  description: 'Accounts are not connected yet. Sign-in arrives with Supabase authentication.',
                ),
              ),
            ),
            GoRoute(
              path: '/signup',
              pageBuilder: (c, s) => _page(
                s,
                const ComingSoonPage(
                  title: 'Create account',
                  icon: Icons.person_add_alt,
                  phase: 3,
                  description: 'Sign-up arrives with Supabase authentication.',
                ),
              ),
            ),
            GoRoute(
              path: '/forgot-password',
              pageBuilder: (c, s) => _page(
                s,
                const ComingSoonPage(
                  title: 'Reset password',
                  icon: Icons.lock_reset,
                  phase: 3,
                  description:
                      'Password recovery arrives with Supabase authentication.',
                ),
              ),
            ),
            if (kDebugMode)
              GoRoute(
                path: '/dev/components',
                pageBuilder: (c, s) => _page(s, const ComponentGalleryPage()),
              ),
          ],
        ),
      ],
    );
  }
}
