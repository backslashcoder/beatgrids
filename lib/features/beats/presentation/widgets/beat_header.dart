import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/widgets/bg_button.dart';
import '../../../../core/widgets/feedback.dart';
import '../../../../core/services/unsaved_changes_guard.dart';
import '../../../auth/presentation/cubit/auth_cubit.dart';
import '../../models/beat.dart';
import '../../models/beat_validator.dart';
import '../cubit/beat_editor_cubit.dart';
import 'beat_details_sheet.dart';

/// Title, status and the save/publish actions above the studio.
class BeatHeader extends StatefulWidget {
  const BeatHeader({super.key});

  @override
  State<BeatHeader> createState() => _BeatHeaderState();
}

class _BeatHeaderState extends State<BeatHeader> {
  final _title = TextEditingController();
  final _focus = FocusNode();

  @override
  void dispose() {
    _title.dispose();
    _focus.dispose();
    super.dispose();
  }

  /// Anonymous users are sent to sign in; their work is stashed so it comes back.
  Future<bool> _ensureSignedIn() async {
    if (context.read<AuthCubit>().state.isSignedIn) return true;
    final editor = context.read<BeatEditorCubit>();
    final go = await confirmDialog(
      context,
      title: 'Sign in to save',
      message:
          'Create a free account or sign in to save drafts and publish. '
          'Your beat is kept on this device and will be here when you come back.',
      confirmLabel: 'Sign in',
    );
    if (!go || !mounted) return false;
    await editor.stashForSignIn();
    if (!mounted) return false;
    // The work is stashed on this device, so leaving is safe: no prompt.
    context.read<UnsavedChangesGuard>().allowNextExit();
    context.go(
      Uri(path: '/login', queryParameters: {'from': '/studio'}).toString(),
    );
    return false;
  }

  Future<void> _save() async {
    if (!await _ensureSignedIn() || !mounted) return;
    final editor = context.read<BeatEditorCubit>();
    final ok = await editor.save();
    if (!mounted) return;
    if (ok) {
      showToast(
        context,
        editor.state.isPublished ? 'Changes saved' : 'Draft saved',
        kind: ToastKind.success,
      );
    } else {
      showToast(
        context,
        editor.state.error ?? 'Could not save',
        kind: ToastKind.error,
      );
    }
  }

  Future<void> _openDetails({required bool publish}) async {
    if (!await _ensureSignedIn() || !mounted) return;
    await showBeatDetails(
      context,
      editor: context.read<BeatEditorCubit>(),
      publishMode: publish,
    );
  }

  Future<void> _delete() async {
    final editor = context.read<BeatEditorCubit>();
    final ok = await confirmDialog(
      context,
      title: 'Delete this beat?',
      message:
          'This permanently deletes "${editor.state.title}". Remixes made from it keep their own copy. This cannot be undone.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!ok || !mounted) return;
    final deleted = await editor.delete();
    if (!mounted) return;
    if (deleted) {
      showToast(context, 'Beat deleted', kind: ToastKind.success);
    } else {
      showToast(
        context,
        editor.state.error ?? 'Could not delete',
        kind: ToastKind.error,
      );
    }
  }

  Future<void> _copyLink(String slug) async {
    await Clipboard.setData(
      ClipboardData(text: '${Uri.base.origin}/beat/$slug'),
    );
    if (mounted) showToast(context, 'Link copied', kind: ToastKind.success);
  }

  @override
  Widget build(BuildContext context) {
    final editor = context.read<BeatEditorCubit>();
    return BlocBuilder<BeatEditorCubit, EditorState>(
      builder: (context, s) {
        if (_title.text != s.title && !_focus.hasFocus) {
          _title.value = TextEditingValue(text: s.title);
        }
        final busy = s.isBusy;
        final text = Theme.of(context).textTheme;
        final actions = Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            BgButton(
              key: const Key('header-save'),
              label: s.isPublished ? 'Save changes' : 'Save draft',
              icon: Icons.save_outlined,
              variant: BgButtonVariant.secondary,
              loading: s.busy == EditorBusy.saving,
              onPressed: busy ? null : _save,
            ),
            BgButton(
              key: const Key('header-publish'),
              label: s.isPublished ? 'Details' : 'Publish',
              icon: s.isPublished ? Icons.tune : Icons.public,
              loading:
                  s.busy == EditorBusy.publishing ||
                  s.busy == EditorBusy.unpublishing,
              onPressed: busy
                  ? null
                  : () => _openDetails(publish: !s.isPublished),
            ),
            if (s.isSaved)
              PopupMenuButton<String>(
                key: const Key('header-menu'),
                tooltip: 'More',
                enabled: !busy,
                color: AppColors.surfaceRaised,
                onSelected: (v) {
                  switch (v) {
                    case 'details':
                      _openDetails(publish: false);
                    case 'link':
                      _copyLink(s.slug!);
                    case 'delete':
                      _delete();
                  }
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: 'details',
                    child: Text('Details and cover'),
                  ),
                  if (s.isPublished)
                    const PopupMenuItem(
                      value: 'link',
                      child: Text('Copy link'),
                    ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Text('Delete beat'),
                  ),
                ],
              ),
          ],
        );
        final titleField = TextField(
          key: const Key('header-title'),
          controller: _title,
          focusNode: _focus,
          enabled: !busy,
          maxLength: BeatValidator.maxTitle,
          style: text.headlineSmall,
          decoration: InputDecoration(
            hintText: kUntitledBeat,
            hintStyle: text.headlineSmall?.copyWith(color: AppColors.textFaint),
            suffixIcon: const Icon(
              Icons.edit_outlined,
              size: 16,
              color: AppColors.textFaint,
            ),
            counterText: '',
            filled: false,
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: AppColors.lime),
            ),
            errorText: s.fieldErrors[BeatField.title],
            contentPadding: const EdgeInsets.symmetric(vertical: 8),
          ),
          onChanged: editor.setTitle,
        );
        final status = _StatusChip(state: s);
        final attribution = s.isRemix
            ? Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: Text(
                  s.sourceCreator == null
                      ? 'Remix of "${s.sourceTitle}"'
                      : 'Remix of "${s.sourceTitle}" by @${s.sourceCreator}',
                  key: const Key('header-attribution'),
                  style: text.bodySmall,
                ),
              )
            : null;
        return LayoutBuilder(
          builder: (context, c) {
            if (c.maxWidth < 760) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  titleField,
                  ?attribution,
                  const SizedBox(height: AppSpacing.xs),
                  Align(alignment: Alignment.centerLeft, child: status),
                  const SizedBox(height: AppSpacing.sm),
                  actions,
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [titleField, ?attribution],
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                status,
                const SizedBox(width: AppSpacing.md),
                actions,
              ],
            );
          },
        );
      },
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.state});

  final EditorState state;

  @override
  Widget build(BuildContext context) {
    final (label, color) = state.dirty
        ? ('Unsaved changes', AppColors.amber)
        : switch (state.status) {
            BeatStatus.published => ('Published', AppColors.lime),
            BeatStatus.draft => ('Draft saved', AppColors.cyan),
            null => ('New beat', AppColors.textDim),
          };
    return Semantics(
      liveRegion: true,
      child: Container(
        key: const Key('header-status'),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelMedium
              ?.copyWith(color: color),
        ),
      ),
    );
  }
}
