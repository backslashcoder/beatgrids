import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/bg_button.dart';
import '../../../../core/widgets/feedback.dart';
import '../../../../core/widgets/states.dart';
import '../cubit/auth_cubit.dart';
import '../widgets/auth_form_shell.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  String? _sentTo;

  @override
  void initState() {
    super.initState();
    context.read<AuthCubit>().clearError();
  }

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    final ok = await context.read<AuthCubit>().sendPasswordReset(_email.text);
    if (ok && mounted) setState(() => _sentTo = _email.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final back = TextButton(
      onPressed: () => context.go('/login'),
      child: const Text('Back to sign in'),
    );
    if (_sentTo != null) {
      return AuthFormShell(
        title: 'Reset password',
        subtitle: 'Check your inbox.',
        footer: back,
        child: EmptyState(
          icon: Icons.mark_email_read_outlined,
          title: 'Link sent',
          message:
              'If an account exists for $_sentTo, a reset link is on its way.',
        ),
      );
    }
    return AuthFormShell(
      title: 'Reset password',
      subtitle: 'We will email you a link to choose a new one.',
      footer: back,
      child: BlocBuilder<AuthCubit, AuthState>(
        builder: (context, state) => Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _email,
                decoration: const InputDecoration(labelText: 'Email'),
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                validator: Validators.email,
                inputFormatters: [
                  FilteringTextInputFormatter.deny(RegExp(r'\s')),
                ],
                onFieldSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: AppSpacing.lg),
              BgButton(
                label: 'Send reset link',
                loading: state.busy,
                onPressed: state.configured ? _submit : null,
                expanded: true,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Reached from the emailed recovery link, which signs the user in temporarily.
class ResetPasswordPage extends StatefulWidget {
  const ResetPasswordPage({super.key});

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final _form = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  @override
  void initState() {
    super.initState();
    context.read<AuthCubit>().clearError();
  }

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    final ok = await context.read<AuthCubit>().updatePassword(_password.text);
    if (ok && mounted) {
      showToast(context, 'Password updated', kind: ToastKind.success);
      context.go('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthFormShell(
      title: 'Choose a new password',
      subtitle: 'Use at least 8 characters.',
      child: BlocBuilder<AuthCubit, AuthState>(
        builder: (context, state) => Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _password,
                decoration: const InputDecoration(labelText: 'New password'),
                obscureText: true,
                autofillHints: const [AutofillHints.newPassword],
                validator: Validators.password,
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _confirm,
                decoration: const InputDecoration(
                  labelText: 'Confirm new password',
                ),
                obscureText: true,
                validator: (v) =>
                    v != _password.text ? 'Passwords do not match.' : null,
                onFieldSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: AppSpacing.lg),
              BgButton(
                label: 'Update password',
                loading: state.busy,
                onPressed: _submit,
                expanded: true,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
