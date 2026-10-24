import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/widgets/page_container.dart';
import '../cubit/auth_cubit.dart';

/// Centred card used by every auth form. Shows a banner when the build has no
/// backend configured, and the last action error from [AuthCubit].
class AuthFormShell extends StatelessWidget {
  const AuthFormShell({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
    this.footer,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return PageContainer(
      title: title,
      maxWidth: 480,
      child: Padding(
        padding: const EdgeInsets.only(top: AppSpacing.lg),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppRadius.card,
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title, style: text.headlineMedium),
              const SizedBox(height: AppSpacing.xs),
              Text(subtitle, style: text.bodyMedium),
              const SizedBox(height: AppSpacing.lg),
              BlocBuilder<AuthCubit, AuthState>(
                buildWhen: (a, b) =>
                    a.configured != b.configured || a.error != b.error,
                builder: (context, state) => Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (!state.configured)
                      const _Banner(
                        icon: Icons.cloud_off,
                        color: AppColors.amber,
                        message:
                            'This build is not connected to Supabase, so accounts are unavailable. '
                            'See the README to add your project settings.',
                      ),
                    if (state.error != null)
                      _Banner(
                        icon: Icons.error_outline,
                        color: AppColors.coral,
                        message: state.error!,
                      ),
                  ],
                ),
              ),
              child,
              if (footer != null) ...[
                const SizedBox(height: AppSpacing.md),
                Center(child: footer),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({
    required this.icon,
    required this.color,
    required this.message,
  });

  final IconData icon;
  final Color color;
  final String message;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: AppRadius.control,
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: AppColors.text),
            ),
          ),
        ],
      ),
    ),
  );
}
