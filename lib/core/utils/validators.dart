/// Form validators. Each returns an error message, or null when valid.
/// Server-side constraints (see supabase/migrations) remain authoritative.
abstract final class Validators {
  static final _email = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$');
  static final _username = RegExp(r'^[a-z0-9_]{3,20}$');

  static String? email(String? v) {
    final value = v?.trim() ?? '';
    if (value.isEmpty) return 'Enter your email.';
    if (!_email.hasMatch(value)) return 'Enter a valid email address.';
    return null;
  }

  static String? password(String? v) {
    final value = v ?? '';
    if (value.isEmpty) return 'Enter a password.';
    if (value.length < 8) return 'Use at least 8 characters.';
    return null;
  }

  static String? username(String? v) {
    final value = (v ?? '').trim();
    if (value.isEmpty) return 'Choose a username.';
    if (!_username.hasMatch(value)) {
      return '3-20 characters: lowercase letters, numbers and underscores.';
    }
    if (const {
      'admin',
      'root',
      'system',
      'support',
      'beatgrid',
      'beatgrids',
      'api',
      'null',
      'undefined',
    }.contains(value)) {
      return 'That username is reserved.';
    }
    return null;
  }

  static String? displayName(String? v) {
    final value = (v ?? '').trim();
    if (value.isEmpty) return 'Enter a display name.';
    if (value.length > 50) return 'Keep it under 50 characters.';
    return null;
  }

  static String? bio(String? v) =>
      (v ?? '').length > 280 ? 'Keep your bio under 280 characters.' : null;
}
