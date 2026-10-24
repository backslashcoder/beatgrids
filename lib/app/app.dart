import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/presentation/cubit/auth_cubit.dart';
import 'router/app_router.dart';
import 'router/stream_listenable.dart';
import 'theme/app_theme.dart';

class BeatGridApp extends StatefulWidget {
  const BeatGridApp({super.key, required this.authCubit, this.router});

  final AuthCubit authCubit;

  /// Injectable for tests.
  final GoRouter? router;

  @override
  State<BeatGridApp> createState() => _BeatGridAppState();
}

class _BeatGridAppState extends State<BeatGridApp> {
  StreamListenable? _refresh;
  late final GoRouter _router = widget.router ?? _createRouter();

  GoRouter _createRouter() {
    final cubit = widget.authCubit;
    _refresh = StreamListenable(cubit.stream);
    return AppRouter.create(
      signedIn: () => cubit.state.isSignedIn,
      recovering: () => cubit.state.recovering,
      refreshListenable: _refresh,
    );
  }

  @override
  void dispose() {
    if (widget.router == null) _router.dispose();
    _refresh?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: widget.authCubit,
      child: MaterialApp.router(
        title: 'BeatGrid',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark,
        darkTheme: AppTheme.dark,
        themeMode: ThemeMode.dark,
        routerConfig: _router,
      ),
    );
  }
}
