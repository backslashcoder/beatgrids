import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_failure.dart';

/// Turns library exceptions into [AppFailure]s with messages safe to display.
/// The original error is logged in debug builds only.
AppFailure mapError(Object error, [StackTrace? stack]) {
  if (error is AppFailure) return error;
  if (kDebugMode) debugPrint('mapError: $error\n${stack ?? ''}');

  if (error is AuthException) return _auth(error);
  if (error is PostgrestException) return _postgrest(error);
  if (error is StorageException) {
    final status = error.statusCode;
    if (status == '413')
      return const AppFailure(
        'That file is too large.',
        code: 'file_too_large',
      );
    if (status == '415')
      return const AppFailure(
        'That file type is not allowed.',
        code: 'file_type',
      );
    if (status == '403' || status == '401') {
      return const AppFailure(
        'You do not have permission to upload that file.',
        code: 'forbidden',
      );
    }
    return const AppFailure(
      'The file could not be uploaded. Please try again.',
      code: 'storage',
    );
  }

  final text = error.toString();
  if (text.contains('XMLHttpRequest') ||
      text.contains('ClientException') ||
      text.contains('SocketException') ||
      text.contains('Failed host lookup') ||
      text.contains('TimeoutException')) {
    return const AppFailure(
      'Could not reach BeatGrid. Check your connection and try again.',
      code: 'network',
    );
  }
  return const AppFailure(
    'Something went wrong. Please try again.',
    code: 'unknown',
  );
}

AppFailure _auth(AuthException e) {
  final code = e.code ?? '';
  final msg = e.message.toLowerCase();
  if (code == 'invalid_credentials' ||
      msg.contains('invalid login credentials')) {
    return const AppFailure(
      'Incorrect email or password.',
      code: 'invalid_credentials',
    );
  }
  if (code == 'email_not_confirmed' || msg.contains('email not confirmed')) {
    return const AppFailure(
      'Confirm your email first. Check your inbox for the link.',
      code: 'email_not_confirmed',
    );
  }
  if (code == 'user_already_exists' || msg.contains('already registered')) {
    return const AppFailure(
      'An account with this email already exists. Try signing in.',
      code: 'email_taken',
    );
  }
  if (code == 'weak_password' || msg.contains('password should')) {
    return const AppFailure(
      'That password is too weak. Use at least 8 characters.',
      code: 'weak_password',
    );
  }
  if (code == 'same_password') {
    return const AppFailure(
      'Choose a password different from your current one.',
      code: 'same_password',
    );
  }
  if (code.contains('rate_limit') ||
      msg.contains('rate limit') ||
      e.statusCode == '429') {
    return const AppFailure(
      'Too many attempts. Wait a minute and try again.',
      code: 'rate_limited',
    );
  }
  if (code == 'signup_disabled') {
    return const AppFailure(
      'Sign-ups are currently disabled.',
      code: 'signup_disabled',
    );
  }
  if (code == 'session_not_found' ||
      code == 'refresh_token_not_found' ||
      msg.contains('jwt expired')) {
    return const AppFailure(
      'Your session has expired. Please sign in again.',
      code: 'session_expired',
    );
  }
  if (msg.contains('fetch') || msg.contains('network')) {
    return const AppFailure(
      'Could not reach BeatGrid. Check your connection and try again.',
      code: 'network',
    );
  }
  return const AppFailure(
    'Authentication failed. Please try again.',
    code: 'auth',
  );
}

AppFailure _postgrest(PostgrestException e) {
  switch (e.code) {
    case '23505':
      if ((e.message + (e.details?.toString() ?? '')).contains('username')) {
        return const AppFailure(
          'That username is already taken.',
          code: 'username_taken',
        );
      }
      return const AppFailure('That already exists.', code: 'conflict');
    case '23514':
      return const AppFailure(
        'Some values are not allowed. Check your input.',
        code: 'invalid_input',
      );
    case '42501':
      return const AppFailure(
        'You do not have permission to do that.',
        code: 'forbidden',
      );
    case 'PGRST301':
    case '28000':
      return const AppFailure(
        'Your session has expired. Please sign in again.',
        code: 'session_expired',
      );
    case 'P0001':
      if (e.message == 'remix_not_allowed') {
        return const AppFailure(
          'The creator has not allowed remixes of this beat.',
          code: 'remix_not_allowed',
        );
      }
      if (e.message == 'remix_source_unavailable') {
        return const AppFailure(
          'The original beat is no longer available to remix.',
          code: 'remix_source_unavailable',
        );
      }
  }
  return const AppFailure(
    'Something went wrong. Please try again.',
    code: 'database',
  );
}
