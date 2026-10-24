import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';

/// Avatar with a deterministic coloured-initial fallback.
class CreatorAvatar extends StatelessWidget {
  const CreatorAvatar({
    super.key,
    required this.name,
    this.imageUrl,
    this.size = 32,
  });

  final String name;
  final String? imageUrl;
  final double size;

  static const _palette = [
    AppColors.lime,
    AppColors.violet,
    AppColors.cyan,
    AppColors.coral,
    AppColors.amber,
  ];

  @override
  Widget build(BuildContext context) {
    final color =
        _palette[name.runes.fold<int>(0, (a, b) => a + b) % _palette.length];
    final initial = name.trim().isEmpty
        ? '?'
        : String.fromCharCode(name.trim().runes.first).toUpperCase();
    final fallback = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      color: color.withValues(alpha: 0.18),
      child: Text(
        initial,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w800,
          fontSize: size * 0.42,
        ),
      ),
    );
    return Semantics(
      label: 'Avatar of $name',
      child: ClipOval(
        child: SizedBox.square(
          dimension: size,
          child: imageUrl == null
              ? fallback
              : Image.network(
                  imageUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => fallback,
                ),
        ),
      ),
    );
  }
}
