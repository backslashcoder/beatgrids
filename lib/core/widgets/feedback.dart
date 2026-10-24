import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import 'bg_button.dart';

enum ToastKind { info, success, error }

void showToast(
  BuildContext context,
  String message, {
  ToastKind kind = ToastKind.info,
}) {
  final (icon, color) = switch (kind) {
    ToastKind.success => (Icons.check_circle, AppColors.lime),
    ToastKind.error => (Icons.error, AppColors.coral),
    ToastKind.info => (Icons.info, AppColors.cyan),
  };
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
}

/// Returns true only if the user explicitly confirms.
Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirm',
  bool destructive = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        BgButton(
          label: 'Cancel',
          variant: BgButtonVariant.ghost,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        FilledButton(
          style: destructive
              ? FilledButton.styleFrom(
                  backgroundColor: AppColors.coral,
                  foregroundColor: Colors.black,
                )
              : null,
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}
