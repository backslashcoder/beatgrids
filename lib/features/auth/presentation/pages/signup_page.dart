import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/bg_button.dart';
import '../../../../core/widgets/states.dart';
import '../cubit/auth_cubit.dart';
import '../widgets/auth_form_shell.dart';

enum _UsernameCheck { idle, checking, available, taken }

class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _username = TextEditingController();
  final _displayName = TextEditingController();
  final _password = TextEditingController();
  Timer? _debounce;
  int _checkToken = 0;
  _UsernameCheck _check = _UsernameCheck.idle;
  String? _confirmEmail;

  @override
  void initState() {
    super.initState();
    context.read<AuthCubit>().clearError();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _email.dispose();
    _username.dispose();
    _displayName.dispose();
    _password.dispose();
    super.dispose();
  }

  void _onUsernameChanged(String value) {
    _debounce?.cancel();
    final name = value.trim();
    if (Validators.username(name) != null) {
      setState(() => _check = _UsernameCheck.idle);
      return;
    }
    setState(() => _check = _UsernameCheck.checking);
    final token = ++_checkToken;
    _debounce = Timer(const Duration(milliseconds: 400), () async {
      final free = await context.read<AuthCubit>().isUsernameAvailable(name);
      // Ignore results for names the user has already typed past.
      if (!mounted || token != _checkToken) return;
      setState(
        () => _check = free ? _UsernameCheck.available : _UsernameCheck.taken,
      );
    });
  }

  String? _validateUsername(String? v) {
    final basic = Validators.username(v);
    if (basic != null) return basic;
    if (_check == _UsernameCheck.taken)
      return 'That username is already taken.';
    return null;
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    final result = await context.read<AuthCubit>().signUp(
      email: _email.text,
      password: _password.text,
      username: _username.text,
      displayName: _displayName.text,
    );
    if (result != null && result.needsEmailConfirmation && mounted) {
      setState(() => _confirmEmail = _email.text.trim());
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_confirmEmail != null) {
      return AuthFormShell(
        title: 'Check your email',
        subtitle: 'One more step.',
        footer: TextButton(
          onPressed: () => context.go('/login'),
          child: const Text('Back to sign in'),
        ),
        child: EmptyState(
          icon: Icons.mark_email_unread_outlined,
          title: 'Confirm your address',
          message:
              'We sent a link to $_confirmEmail. Open it to activate your account, then sign in.',
        ),
      );
    }
    return AuthFormShell(
      title: 'Create account',
      subtitle: 'Make beats, publish them, remix others.',
      footer: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          const Text('Already have an account?'),
          TextButton(
            onPressed: () => context.go('/login'),
            child: const Text('Sign in'),
          ),
        ],
      ),
      child: BlocBuilder<AuthCubit, AuthState>(
        builder: (context, state) => AutofillGroup(
          child: Form(
            key: _form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _email,
                  decoration: const InputDecoration(labelText: 'Email'),
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.email],
                  validator: Validators.email,
                  inputFormatters: [
                    FilteringTextInputFormatter.deny(RegExp(r'\s')),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _username,
                  decoration: InputDecoration(
                    labelText: 'Username',
                    prefixText: '@',
                    helperText: switch (_check) {
                      _UsernameCheck.checking => 'Checking...',
                      _UsernameCheck.available => 'Available',
                      _ => 'Lowercase letters, numbers, underscores',
                    },
                    helperStyle: TextStyle(
                      color: _check == _UsernameCheck.available
                          ? AppColors.lime
                          : AppColors.textDim,
                    ),
                  ),
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.newUsername],
                  validator: _validateUsername,
                  onChanged: _onUsernameChanged,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9_]')),
                    TextInputFormatter.withFunction(
                      (o, n) => n.copyWith(text: n.text.toLowerCase()),
                    ),
                    LengthLimitingTextInputFormatter(20),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _displayName,
                  decoration: const InputDecoration(labelText: 'Display name'),
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.nickname],
                  validator: Validators.displayName,
                  inputFormatters: [LengthLimitingTextInputFormatter(50)],
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _password,
                  decoration: const InputDecoration(
                    labelText: 'Password',
                    helperText: 'At least 8 characters',
                  ),
                  obscureText: true,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.newPassword],
                  validator: Validators.password,
                  onFieldSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: AppSpacing.lg),
                BgButton(
                  label: 'Create account',
                  loading: state.busy,
                  onPressed: state.configured ? _submit : null,
                  expanded: true,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
