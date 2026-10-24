import 'package:flutter/material.dart';

/// Colour tokens. Use these (or the theme's ColorScheme) instead of literals.
abstract final class AppColors {
  // Surfaces, darkest to lightest.
  static const background = Color(0xFF0A0A0C);
  static const surface = Color(0xFF121216);
  static const surfaceRaised = Color(0xFF1A1A20);
  static const surfaceHigh = Color(0xFF23232B);
  static const border = Color(0xFF2B2B35);

  // Text.
  static const text = Color(0xFFF4F4F6);
  static const textDim = Color(0xFF9D9DAA);
  static const textFaint = Color(0xFF6B6B78);

  // Accents.
  static const lime = Color(0xFFC6FF3D);
  static const onLime = Color(0xFF10140A);
  static const violet = Color(0xFF9B6BFF);
  static const cyan = Color(0xFF27D9F0);
  static const coral = Color(0xFFFF6B5E);
  static const amber = Color(0xFFFFB84D);

  /// One coordinated colour per drum track.
  static const kick = lime;
  static const snare = coral;
  static const closedHat = cyan;
  static const openHat = violet;
  static const clap = amber;
}
