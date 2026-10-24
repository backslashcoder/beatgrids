import 'dart:js_interop';

import 'package:web/web.dart' as web;

JSFunction? _handler;

/// Makes the browser ask for confirmation before closing or reloading the tab
/// while [hasUnsaved] returns true.
void setBeforeUnloadGuard(bool Function() hasUnsaved) {
  clearBeforeUnloadGuard();
  final handler = ((web.Event event) {
    if (hasUnsaved()) {
      event.preventDefault();
      (event as web.BeforeUnloadEvent).returnValue = '';
    }
  }).toJS;
  _handler = handler;
  web.window.addEventListener('beforeunload', handler);
}

void clearBeforeUnloadGuard() {
  final handler = _handler;
  if (handler != null) {
    web.window.removeEventListener('beforeunload', handler);
    _handler = null;
  }
}
