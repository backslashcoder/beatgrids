import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';

import 'app/app.dart';

void main() {
  usePathUrlStrategy(); // readable URLs like /beat/abc instead of /#/beat/abc
  runApp(const BeatGridApp());
}
