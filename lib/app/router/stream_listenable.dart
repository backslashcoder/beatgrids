import 'dart:async';

import 'package:flutter/foundation.dart';

/// Notifies GoRouter whenever [stream] emits so redirect guards re-run.
class StreamListenable extends ChangeNotifier {
  StreamListenable(Stream<dynamic> stream) {
    _sub = stream.listen((_) => notifyListeners());
  }

  late final StreamSubscription<dynamic> _sub;

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}
