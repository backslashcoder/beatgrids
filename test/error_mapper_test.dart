import 'package:beatgrid/core/errors/error_mapper.dart';
import 'package:beatgrid/core/utils/validators.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('mapError', () {
    test('auth errors become friendly messages', () {
      expect(
        mapError(
          const AuthApiException(
            'Invalid login credentials',
            code: 'invalid_credentials',
            statusCode: '400',
          ),
        ).code,
        'invalid_credentials',
      );
      expect(
        mapError(
          const AuthApiException(
            'Email not confirmed',
            code: 'email_not_confirmed',
            statusCode: '400',
          ),
        ).code,
        'email_not_confirmed',
      );
      expect(
        mapError(
          const AuthApiException(
            'User already registered',
            code: 'user_already_exists',
            statusCode: '422',
          ),
        ).code,
        'email_taken',
      );
      expect(
        mapError(
          const AuthApiException(
            'slow down',
            code: 'over_email_send_rate_limit',
            statusCode: '429',
          ),
        ).code,
        'rate_limited',
      );
      expect(
        mapError(
          const AuthApiException(
            'Password should be at least 6 characters',
            code: 'weak_password',
            statusCode: '422',
          ),
        ).code,
        'weak_password',
      );
    });

    test('database errors map by SQLSTATE and never leak details', () {
      final unique = mapError(
        const PostgrestException(
          message: 'duplicate key value violates unique constraint "profiles_username_key"',
          code: '23505',
          details: 'Key (username)=(x)',
        ),
      );
      expect(unique.code, 'username_taken');
      expect(unique.message, isNot(contains('profiles_username_key')));
      expect(
        mapError(
          const PostgrestException(
            message: 'permission denied for table beats',
            code: '42501',
          ),
        ).code,
        'forbidden',
      );
      expect(
        mapError(
          const PostgrestException(
            message: 'new row violates check constraint',
            code: '23514',
          ),
        ).code,
        'invalid_input',
      );
      expect(
        mapError(
          const PostgrestException(message: 'remix_not_allowed', code: 'P0001'),
        ).code,
        'remix_not_allowed',
      );
      expect(
        mapError(
          const PostgrestException(
            message: 'remix_source_unavailable',
            code: 'P0001',
          ),
        ).code,
        'remix_source_unavailable',
      );
      expect(
        mapError(const PostgrestException(message: 'boom', code: 'XX000')).code,
        'database',
      );
    });

    test('network and unknown errors', () {
      expect(
        mapError(Exception('ClientException: Failed to fetch')).code,
        'network',
      );
      expect(mapError(StateError('weird')).code, 'unknown');
    });
  });

  group('Validators', () {
    test('email', () {
      expect(Validators.email(''), isNotNull);
      expect(Validators.email('nope'), isNotNull);
      expect(Validators.email(' a@b.co '), isNull);
    });
    test('password needs 8 characters', () {
      expect(Validators.password('short'), isNotNull);
      expect(Validators.password('longenough'), isNull);
    });
    test('username rules mirror the database', () {
      for (final bad in [
        'ab',
        'Has_Caps',
        'with space',
        'a' * 21,
        'admin',
        '',
      ]) {
        expect(Validators.username(bad), isNotNull, reason: bad);
      }
      for (final ok in ['ada', 'dj_koji_99', 'a' * 20]) {
        expect(Validators.username(ok), isNull, reason: ok);
      }
    });
    test('display name and bio limits', () {
      expect(Validators.displayName('  '), isNotNull);
      expect(Validators.displayName('x' * 51), isNotNull);
      expect(Validators.displayName('Ada'), isNull);
      expect(Validators.bio('x' * 281), isNotNull);
      expect(Validators.bio(null), isNull);
    });
  });
}
