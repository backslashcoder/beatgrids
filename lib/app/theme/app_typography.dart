import 'package:flutter/material.dart';

import 'app_colors.dart';

abstract final class AppTypography {
  static const _fallback = [
    'Inter',
    'Segoe UI',
    'Roboto',
    'Helvetica Neue',
    'Arial',
  ];

  static TextStyle _s(
    double size,
    FontWeight w, {
    double? height,
    double? spacing,
    Color? color,
  }) => TextStyle(
    fontFamilyFallback: _fallback,
    fontSize: size,
    fontWeight: w,
    height: height,
    letterSpacing: spacing,
    color: color ?? AppColors.text,
  );

  static TextTheme get textTheme => TextTheme(
    displayLarge: _s(56, FontWeight.w800, height: 1.05, spacing: -1.5),
    displayMedium: _s(44, FontWeight.w800, height: 1.08, spacing: -1.0),
    headlineLarge: _s(32, FontWeight.w800, height: 1.15, spacing: -0.6),
    headlineMedium: _s(26, FontWeight.w700, height: 1.2, spacing: -0.4),
    headlineSmall: _s(21, FontWeight.w700, height: 1.25, spacing: -0.2),
    titleLarge: _s(18, FontWeight.w700, height: 1.3),
    titleMedium: _s(16, FontWeight.w600, height: 1.3),
    titleSmall: _s(14, FontWeight.w600, height: 1.3),
    bodyLarge: _s(16, FontWeight.w400, height: 1.5),
    bodyMedium: _s(14, FontWeight.w400, height: 1.5, color: AppColors.textDim),
    bodySmall: _s(12, FontWeight.w400, height: 1.4, color: AppColors.textDim),
    labelLarge: _s(14, FontWeight.w700, spacing: 0.2),
    labelMedium: _s(12, FontWeight.w600, spacing: 0.3),
    labelSmall: _s(11, FontWeight.w700, spacing: 0.8, color: AppColors.textDim),
  );
}
