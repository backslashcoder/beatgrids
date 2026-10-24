/// Pure redirect rules so they can be unit-tested without a router.
///
/// Public: home, explore, published beats, profiles, auth pages and the blank
/// studio (anyone can try the sequencer; saving and publishing will require an
/// account). Protected: editing an existing beat and account settings.
abstract final class RouteGuards {
  static const _protectedExact = {
    '/settings',
    '/reset-password',
    '/my-beats',
    '/saved',
  };
  static const _protectedPrefixes = ['/studio/'];
  static const _authPages = {'/login', '/signup', '/forgot-password'};

  static bool isProtected(String path) =>
      _protectedExact.contains(path) || _protectedPrefixes.any(path.startsWith);

  /// Returns the path to redirect to, or null to allow navigation.
  static String? redirect({
    required Uri location,
    required bool signedIn,
    bool recovering = false,
  }) {
    final path = location.path;
    // Arrived via a recovery link: the only useful page is the new-password form.
    if (signedIn && recovering && path != '/reset-password')
      return '/reset-password';
    if (!signedIn && isProtected(path)) {
      return Uri(
        path: '/login',
        queryParameters: {'from': location.toString()},
      ).toString();
    }
    if (signedIn && _authPages.contains(path)) {
      final from = location.queryParameters['from'];
      return from != null && from.startsWith('/') && !from.startsWith('//')
          ? from
          : '/';
    }
    return null;
  }
}
