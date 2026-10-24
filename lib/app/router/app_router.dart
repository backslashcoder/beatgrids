import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/services/unsaved_changes_guard.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/states.dart';
import '../../features/beats/presentation/my_beats_page.dart';
import '../../features/community/presentation/beat_detail_page.dart';
import '../../features/community/presentation/explore_page.dart';
import '../../features/community/presentation/profile_page.dart';
import '../../features/community/presentation/saved_page.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/pages/password_pages.dart';
import '../../features/auth/presentation/pages/signup_page.dart';
import '../../features/dev/component_gallery_page.dart';
import '../../features/settings/presentation/settings_page.dart';
import '../../features/home/presentation/home_page.dart';
import '../../features/studio/audio/audio_engine.dart';
import '../../features/studio/presentation/studio_page.dart';
import '../shell/app_shell.dart';
import '../theme/app_spacing.dart';
import 'route_guards.dart';

CustomTransitionPage<void> _page(
  GoRouterState state,
  Widget child, {
  LocalKey? key,
}) {
  return CustomTransitionPage<void>(
    key: key ?? state.pageKey,
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

const _studioPageKey = ValueKey('studio-page');

abstract final class AppRouter {
  /// [signedIn] and [recovering] come from the auth state; with neither given,
  /// protected routes redirect to /login. [refreshListenable] re-runs the
  /// guards when the auth state changes.
  static GoRouter create({
    bool Function()? signedIn,
    bool Function()? recovering,
    Listenable? refreshListenable,
    String initialLocation = '/',
    UnsavedChangesGuard? unsavedGuard,
    AudioEngine Function()? engineFactory,
  }) {
    // Asked when leaving a studio route; blocks navigation if the user cancels.
    Future<bool> leaveStudio(BuildContext context, GoRouterState state) async {
      if (unsavedGuard == null) return true;
      if (unsavedGuard.consumeSkip() || !unsavedGuard.hasUnsaved) return true;
      return confirmDialog(
        context,
        title: 'Leave without saving?',
        message: 'You have unsaved changes to this beat. If you leave now they will be lost.',
        confirmLabel: 'Leave',
        destructive: true,
      );
    }

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
            // Both studio routes share one page key so saving a new beat can move
            // the URL to /studio/<id> without rebuilding the studio or its audio.
            GoRoute(
              path: '/studio',
              onExit: leaveStudio,
              pageBuilder: (c, s) => _page(
                s,
                StudioPage(engine: engineFactory?.call()),
                key: _studioPageKey,
              ),
            ),
            GoRoute(
              path: '/studio/:id',
              onExit: leaveStudio,
              pageBuilder: (c, s) => _page(
                s,
                StudioPage(
                  beatId: s.pathParameters['id'],
                  engine: engineFactory?.call(),
                ),
                key: _studioPageKey,
              ),
            ),
            GoRoute(
              path: '/my-beats',
              pageBuilder: (c, s) => _page(s, const MyBeatsPage()),
            ),
            GoRoute(
              path: '/beat/:id',
              pageBuilder: (c, s) =>
                  _page(s, BeatDetailPage(slug: s.pathParameters['id']!)),
            ),
            GoRoute(
              path: '/profile/:username',
              pageBuilder: (c, s) => _page(
                s,
                ProfilePage(username: s.pathParameters['username']!),
              ),
            ),
            GoRoute(
              path: '/saved',
              pageBuilder: (c, s) => _page(s, const SavedPage()),
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
