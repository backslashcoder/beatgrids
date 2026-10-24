import 'package:flutter/material.dart';

abstract final class AppSpacing {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 32.0;
  static const xxl = 48.0;

  /// Horizontal page gutter by viewport width.
  static double gutter(double width) => width < Breakpoints.mobile ? md : lg;
}

abstract final class AppRadius {
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 18.0;
  static const pill = 999.0;

  static BorderRadius get card => BorderRadius.circular(lg);
  static BorderRadius get control => BorderRadius.circular(md);
}

abstract final class Breakpoints {
  static const mobile = 640.0;
  static const tablet = 1024.0;
  static const maxContent = 1200.0;

  static bool isMobile(double width) => width < mobile;
  static bool isDesktop(double width) => width >= tablet;
}

/// Animation timing that honours the OS reduced-motion preference.
abstract final class Motion {
  static const fast = Duration(milliseconds: 140);
  static const medium = Duration(milliseconds: 240);

  static Duration of(BuildContext context, Duration d) =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false ? Duration.zero : d;
}
