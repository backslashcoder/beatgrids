import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../core/services/audio_coordinator.dart';
import '../core/services/unsaved_changes_guard.dart';
import '../features/community/data/community_repository.dart';
import '../features/community/presentation/cubit/player_cubit.dart';
import '../features/studio/audio/audio_engine.dart';
import '../features/auth/presentation/cubit/auth_cubit.dart';
import '../features/beats/data/beat_repository.dart';
import 'router/app_router.dart';
import 'router/stream_listenable.dart';
import 'theme/app_theme.dart';

class BeatGridApp extends StatefulWidget {
  const BeatGridApp({
    super.key,
    required this.authCubit,
    required this.beatRepository,
    required this.communityRepository,
    this.audioCoordinator,
    this.playerEngineFactory,
    this.unsavedGuard,
    this.router,
  });

  final AuthCubit authCubit;
  final BeatRepository beatRepository;
  final CommunityRepository communityRepository;

  /// Shared by the studio and the mini-player. Injectable for tests.
  final AudioCoordinator? audioCoordinator;

  /// Builds the mini-player's audio engine (a fake in tests).
  final AudioEngine Function()? playerEngineFactory;

  /// Shared with the router so it can warn before leaving unsaved work.
  /// Injectable for tests that build their own router.
  final UnsavedChangesGuard? unsavedGuard;

  /// Injectable for tests.
  final GoRouter? router;

  @override
  State<BeatGridApp> createState() => _BeatGridAppState();
}

class _BeatGridAppState extends State<BeatGridApp> {
  StreamListenable? _refresh;
  late final UnsavedChangesGuard _guard =
      widget.unsavedGuard ?? UnsavedChangesGuard();
  late final AudioCoordinator _coordinator =
      widget.audioCoordinator ?? AudioCoordinator();
  late final PlayerCubit _player = PlayerCubit(
    widget.communityRepository,
    _coordinator,
    engineFactory: widget.playerEngineFactory,
  );
  late final GoRouter _router = widget.router ?? _createRouter();

  GoRouter _createRouter() {
    final cubit = widget.authCubit;
    _refresh = StreamListenable(cubit.stream);
    return AppRouter.create(
      signedIn: () => cubit.state.isSignedIn,
      recovering: () => cubit.state.recovering,
      refreshListenable: _refresh,
      unsavedGuard: _guard,
    );
  }

  @override
  void dispose() {
    if (widget.router == null) _router.dispose();
    _refresh?.dispose();
    _player.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<BeatRepository>.value(value: widget.beatRepository),
        RepositoryProvider<CommunityRepository>.value(
          value: widget.communityRepository,
        ),
        RepositoryProvider<AudioCoordinator>.value(value: _coordinator),
        RepositoryProvider<UnsavedChangesGuard>.value(value: _guard),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider.value(value: widget.authCubit),
          BlocProvider.value(value: _player),
        ],
        child: MaterialApp.router(
          title: 'BeatGrid',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.dark,
          darkTheme: AppTheme.dark,
          themeMode: ThemeMode.dark,
          routerConfig: _router,
        ),
      ),
    );
  }
}
