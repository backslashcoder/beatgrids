import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/cubit/auth_cubit.dart';
import 'feedback.dart';

/// Returns true when the user is signed in. Otherwise explains why an account
/// is needed and offers to go to the sign-in page, returning to the current
/// page afterwards.
Future<bool> ensureSignedIn(
  BuildContext context, {
  required String reason,
}) async {
  if (context.read<AuthCubit>().state.isSignedIn) return true;
  final here = GoRouterState.of(context).uri.toString();
  final go = await confirmDialog(
    context,
    title: 'Sign in to continue',
    message: reason,
    confirmLabel: 'Sign in',
  );
  if (go && context.mounted) {
    context.go(Uri(path: '/login', queryParameters: {'from': here}).toString());
  }
  return false;
}
