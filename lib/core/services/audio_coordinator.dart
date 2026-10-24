import 'dart:ui';

/// There is one browser audio engine. This decides who may use it: whoever
/// [claim]s it last owns it, and the previous owner is told to stop and let go.
///
/// Used by the studio and the community mini-player so they never play at the
/// same time or fight over the engine's single status listener.
class AudioCoordinator {
  Object? _owner;
  VoidCallback? _onRevoked;

  Object? get owner => _owner;

  /// Takes ownership. If someone else held it, their [onRevoked] runs first
  /// (synchronously) so the engine is free before the new owner initializes it.
  void claim(Object owner, {required VoidCallback onRevoked}) {
    if (_owner != null && !identical(_owner, owner)) {
      final previous = _onRevoked;
      _owner = null;
      _onRevoked = null;
      previous?.call();
    }
    _owner = owner;
    _onRevoked = onRevoked;
  }

  /// Gives up ownership without notifying anyone (the owner is closing).
  void release(Object owner) {
    if (identical(_owner, owner)) {
      _owner = null;
      _onRevoked = null;
    }
  }
}
