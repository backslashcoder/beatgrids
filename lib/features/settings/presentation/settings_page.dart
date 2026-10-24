import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/bg_button.dart';
import '../../../core/widgets/creator_avatar.dart';
import '../../../core/widgets/feedback.dart';
import '../../../core/widgets/page_container.dart';
import '../../../core/widgets/states.dart';
import '../../auth/models/user_profile.dart';
import '../../auth/presentation/cubit/auth_cubit.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return PageContainer(
      title: 'Settings',
      maxWidth: 720,
      child: BlocBuilder<AuthCubit, AuthState>(
        buildWhen: (a, b) =>
            a.profile != b.profile ||
            a.profileError != b.profileError ||
            a.status != b.status,
        builder: (context, state) {
          if (state.profileError != null) {
            return SizedBox(
              height: 360,
              child: ErrorState(
                title: 'Could not load your profile',
                message: state.profileError!,
                onRetry: () => context.read<AuthCubit>().loadProfile(),
              ),
            );
          }
          final profile = state.profile;
          if (profile == null) {
            return const Padding(
              padding: EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Skeleton(width: 220, height: 28),
                  SizedBox(height: AppSpacing.lg),
                  Skeleton(height: 56),
                  SizedBox(height: AppSpacing.md),
                  Skeleton(height: 56),
                ],
              ),
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Settings',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: AppSpacing.lg),
              _ProfileCard(profile: profile),
              const SizedBox(height: AppSpacing.lg),
              const _PasswordCard(),
              const SizedBox(height: AppSpacing.lg),
              Align(
                alignment: Alignment.centerLeft,
                child: BgButton(
                  label: 'Sign out',
                  icon: Icons.logout,
                  variant: BgButtonVariant.secondary,
                  onPressed: () => context.read<AuthCubit>().signOut(),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(AppSpacing.lg),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: AppRadius.card,
      border: Border.all(color: AppColors.border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: AppSpacing.md),
        child,
      ],
    ),
  );
}

class _ProfileCard extends StatefulWidget {
  const _ProfileCard({required this.profile});

  final UserProfile profile;

  @override
  State<_ProfileCard> createState() => _ProfileCardState();
}

class _ProfileCardState extends State<_ProfileCard> {
  final _form = GlobalKey<FormState>();
  late final _username = TextEditingController(text: widget.profile.username);
  late final _displayName = TextEditingController(
    text: widget.profile.displayName,
  );
  late final _bio = TextEditingController(text: widget.profile.bio ?? '');

  @override
  void dispose() {
    _username.dispose();
    _displayName.dispose();
    _bio.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final cubit = context.read<AuthCubit>();
    final ok = await cubit.updateProfile(
      username: _username.text,
      displayName: _displayName.text,
      bio: _bio.text,
    );
    if (!mounted) return;
    showToast(
      context,
      ok ? 'Profile saved' : (cubit.state.error ?? 'Could not save'),
      kind: ok ? ToastKind.success : ToastKind.error,
    );
  }

  Future<void> _pickAvatar() async {
    final cubit = context.read<AuthCubit>();
    final picked = await FilePicker.pickFiles(type: FileType.image);
    if (picked.isEmpty) return;
    final file = picked.single;
    final bytes = await file.readAsBytes();
    final ok = await cubit.uploadAvatar(bytes, file.extension ?? '');
    if (!mounted) return;
    showToast(
      context,
      ok ? 'Avatar updated' : (cubit.state.error ?? 'Upload failed'),
      kind: ok ? ToastKind.success : ToastKind.error,
    );
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<AuthCubit>();
    final profile = widget.profile;
    return _Card(
      title: 'Profile',
      child: BlocBuilder<AuthCubit, AuthState>(
        buildWhen: (a, b) => a.busy != b.busy,
        builder: (context, state) => Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  CreatorAvatar(
                    name: profile.displayName,
                    imageUrl: cubit.avatarUrl(profile),
                    size: 64,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  BgButton(
                    label: 'Change avatar',
                    icon: Icons.upload,
                    variant: BgButtonVariant.secondary,
                    onPressed: state.busy ? null : _pickAvatar,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              TextFormField(
                controller: _displayName,
                decoration: const InputDecoration(labelText: 'Display name'),
                validator: Validators.displayName,
                inputFormatters: [LengthLimitingTextInputFormatter(50)],
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _username,
                decoration: const InputDecoration(
                  labelText: 'Username',
                  prefixText: '@',
                ),
                validator: Validators.username,
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
                controller: _bio,
                decoration: const InputDecoration(labelText: 'Bio (optional)'),
                maxLines: 3,
                maxLength: 280,
                validator: Validators.bio,
              ),
              const SizedBox(height: AppSpacing.md),
              Align(
                alignment: Alignment.centerLeft,
                child: BgButton(
                  label: 'Save profile',
                  loading: state.busy,
                  onPressed: _save,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PasswordCard extends StatefulWidget {
  const _PasswordCard();

  @override
  State<_PasswordCard> createState() => _PasswordCardState();
}

class _PasswordCardState extends State<_PasswordCard> {
  final _form = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final cubit = context.read<AuthCubit>();
    final ok = await cubit.updatePassword(_password.text);
    if (!mounted) return;
    if (ok) {
      _password.clear();
      _confirm.clear();
    }
    showToast(
      context,
      ok ? 'Password updated' : (cubit.state.error ?? 'Could not update'),
      kind: ok ? ToastKind.success : ToastKind.error,
    );
  }

  @override
  Widget build(BuildContext context) {
    return _Card(
      title: 'Password',
      child: BlocBuilder<AuthCubit, AuthState>(
        buildWhen: (a, b) => a.busy != b.busy,
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
              ),
              const SizedBox(height: AppSpacing.md),
              Align(
                alignment: Alignment.centerLeft,
                child: BgButton(
                  label: 'Update password',
                  loading: state.busy,
                  onPressed: _save,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
