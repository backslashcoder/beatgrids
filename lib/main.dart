import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/app.dart';
import 'app/config/app_config.dart';
import 'features/auth/data/auth_repository.dart';
import 'features/auth/data/supabase_auth_repository.dart';
import 'features/auth/presentation/cubit/auth_cubit.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  usePathUrlStrategy(); // readable URLs like /beat/abc instead of /#/beat/abc

  final AuthRepository auth;
  if (AppConfig.isSupabaseConfigured) {
    // Restores a saved session and handles email-link redirects before the UI starts.
    await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      publishableKey: AppConfig.supabaseAnonKey,
    );
    auth = SupabaseAuthRepository(
      Supabase.instance.client,
      redirectOrigin: Uri.base.origin,
    );
  } else {
    auth = const UnconfiguredAuthRepository();
  }
  runApp(BeatGridApp(authCubit: AuthCubit(auth)));
}
