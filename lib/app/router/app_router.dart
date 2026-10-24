import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/widgets/states.dart';
import '../../features/community/presentation/explore_page.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/pages/password_pages.dart';
import '../../features/auth/presentation/pages/signup_page.dart';
import '../../features/dev/component_gallery_page.dart';
import '../../features/settings/presentation/settings_page.dart';
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
  /// [signedIn] and [recovering] come from the auth state; with neither given,
  /// protected routes redirect to /login. [refreshListenable] re-runs the
  /// guards when the auth state changes.
  static GoRouter create({
    bool Function()? signedIn,
    bool Function()? recovering,
    Listenable? refreshListenable,
    String initialLocation = '/',
  }) {
    return GoRouter(
      initialLocation: initialLocation,
      refreshListenable: refreshListenable,
      redirect: (context, state) => RouteGuards.redirect(
        location: state.uri,
        signedIn: signedIn?.call() ?? false,
        recovering: recovering?.call() ?? false,
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
              pageBuilder: (c, s) => _page(s, const SettingsPage()),
            ),
            GoRoute(
              path: '/login',
              pageBuilder: (c, s) => _page(s, const LoginPage()),
            ),
            GoRoute(
              path: '/signup',
              pageBuilder: (c, s) => _page(s, const SignupPage()),
            ),
            GoRoute(
              path: '/forgot-password',
              pageBuilder: (c, s) => _page(s, const ForgotPasswordPage()),
            ),
            GoRoute(
              path: '/reset-password',
              pageBuilder: (c, s) => _page(s, const ResetPasswordPage()),
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
