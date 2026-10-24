import 'package:beatgrid/app/router/route_guards.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  String? run(String url, {required bool signedIn}) =>
      RouteGuards.redirect(location: Uri.parse(url), signedIn: signedIn);

  test('anonymous users are sent to login from protected routes', () {
    expect(run('/settings', signedIn: false), '/login?from=%2Fsettings');
    expect(run('/studio/abc', signedIn: false), startsWith('/login?from='));
  });

  test('public routes stay open', () {
    for (final p in [
      '/',
      '/explore',
      '/studio',
      '/beat/x',
      '/profile/ada',
      '/login',
    ]) {
      expect(run(p, signedIn: false), isNull, reason: p);
    }
  });

  test(
    'signed-in users skip auth pages and return to where they came from',
    () {
      expect(run('/login', signedIn: true), '/');
      expect(run('/login?from=/studio/abc', signedIn: true), '/studio/abc');
      expect(run('/signup', signedIn: true), '/');
    },
  );

  test('reset-password needs a session; recovery forces the reset page', () {
    expect(run('/reset-password', signedIn: false), startsWith('/login'));
    expect(run('/reset-password', signedIn: true), isNull);
    expect(
      RouteGuards.redirect(
        location: Uri.parse('/explore'),
        signedIn: true,
        recovering: true,
      ),
      '/reset-password',
    );
    expect(
      RouteGuards.redirect(
        location: Uri.parse('/reset-password'),
        signedIn: true,
        recovering: true,
      ),
      isNull,
    );
  });

  test('open redirects are ignored', () {
    expect(run('/login?from=//evil.example', signedIn: true), '/');
    expect(run('/login?from=https://evil.example', signedIn: true), '/');
  });

  test('signed-in users can open protected routes', () {
    expect(run('/settings', signedIn: true), isNull);
  });
}
