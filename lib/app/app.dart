import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'router/app_router.dart';
import 'theme/app_theme.dart';

class BeatGridApp extends StatefulWidget {
  const BeatGridApp({super.key, this.router});

  /// Injectable for tests.
  final GoRouter? router;

  @override
  State<BeatGridApp> createState() => _BeatGridAppState();
}

class _BeatGridAppState extends State<BeatGridApp> {
  late final GoRouter _router = widget.router ?? AppRouter.create();

  @override
  void dispose() {
    if (widget.router == null) _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'BeatGrid',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.dark,
      routerConfig: _router,
    );
  }
}
