/// A failure with a message that is safe to show to users. Technical detail is
/// logged where the failure is created, never put in [message].
class AppFailure implements Exception {
  const AppFailure(this.message, {this.code});

  final String message;

  /// Stable machine-readable reason, e.g. `username_taken`, `network`.
  final String? code;

  static const notConfigured = AppFailure(
    'BeatGrid is not connected to a backend yet. Add the Supabase settings and rebuild.',
    code: 'not_configured',
  );

  @override
  String toString() => 'AppFailure($code): $message';
}
