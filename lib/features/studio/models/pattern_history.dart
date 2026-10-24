/// Bounded undo/redo stack. Pushing a value equal to the current one is ignored,
/// so redundant updates never create history entries.
class UndoHistory<T> {
  UndoHistory(T initial, {this.limit = 50}) : _present = initial;

  final int limit;
  final List<T> _past = [];
  final List<T> _future = [];
  T _present;

  T get present => _present;
  bool get canUndo => _past.isNotEmpty;
  bool get canRedo => _future.isNotEmpty;

  /// Records [value] as the new present. Returns false if it equals the current one.
  bool push(T value) {
    if (value == _present) return false;
    _past.add(_present);
    if (_past.length > limit) _past.removeAt(0);
    _future.clear();
    _present = value;
    return true;
  }

  T? undo() {
    if (!canUndo) return null;
    _future.add(_present);
    _present = _past.removeLast();
    return _present;
  }

  T? redo() {
    if (!canRedo) return null;
    _past.add(_present);
    _present = _future.removeLast();
    return _present;
  }

  /// Replaces the present without recording history (e.g. after loading a saved beat).
  void reset(T value) {
    _past.clear();
    _future.clear();
    _present = value;
  }
}
