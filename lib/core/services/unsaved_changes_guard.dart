import 'before_unload_stub.dart'
    if (dart.library.js_interop) 'before_unload_web.dart'
    as browser;

/// Lets a page declare "I have unsaved work" so the router (in-app navigation)
/// and the browser (closing/refreshing the tab) can warn before it is lost.
class UnsavedChangesGuard {
  bool Function()? _check;

  bool _skipNext = false;

  bool get hasUnsaved => _check?.call() ?? false;

  /// The next route exit is intentional and the work is safe elsewhere (e.g. stashed
  /// before sign-in), so do not ask.
  void allowNextExit() => _skipNext = true;

  /// Consumed by the router when leaving a guarded route.
  bool consumeSkip() {
    final skip = _skipNext;
    _skipNext = false;
    return skip;
  }

  /// Registers [isDirty]. Only one page owns the guard at a time.
  void register(bool Function() isDirty) {
    _check = isDirty;
    browser.setBeforeUnloadGuard(() => hasUnsaved);
  }

  void unregister(bool Function() isDirty) {
    if (_check == isDirty) {
      _check = null;
      browser.clearBeforeUnloadGuard();
    }
  }
}
