import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/widgets/bg_button.dart';
import '../../../../core/widgets/feedback.dart';
import '../../models/beat_validator.dart';
import '../../models/genres.dart';
import '../cubit/beat_editor_cubit.dart';

/// Opens the beat details form as a dialog on wide screens and a bottom sheet
/// on narrow ones. [publishMode] makes Publish the primary action.
Future<void> showBeatDetails(
  BuildContext context, {
  required BeatEditorCubit editor,
  bool publishMode = false,
}) {
  final body = BlocProvider.value(
    value: editor,
    child: BeatDetailsForm(publishMode: publishMode),
  );
  if (MediaQuery.sizeOf(context).width < 700) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => body,
    );
  }
  return showDialog<void>(
    context: context,
    builder: (_) => Dialog(
      insetPadding: const EdgeInsets.all(AppSpacing.lg),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: body,
      ),
    ),
  );
}

class BeatDetailsForm extends StatefulWidget {
  const BeatDetailsForm({super.key, required this.publishMode});

  final bool publishMode;

  @override
  State<BeatDetailsForm> createState() => _BeatDetailsFormState();
}

class _BeatDetailsFormState extends State<BeatDetailsForm> {
  late final TextEditingController _title;
  late final TextEditingController _description;

  @override
  void initState() {
    super.initState();
    final s = context.read<BeatEditorCubit>().state;
    _title = TextEditingController(text: s.title);
    _description = TextEditingController(text: s.description);
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _pickCover() async {
    final editor = context.read<BeatEditorCubit>();
    final picked = await FilePicker.pickFiles(type: FileType.image);
    if (picked.isEmpty) return;
    final file = picked.single;
    final bytes = await file.readAsBytes();
    final ok = await editor.setCover(bytes, file.extension ?? '');
    if (!mounted || ok) return;
    showToast(
      context,
      editor.state.error ?? 'Upload failed',
      kind: ToastKind.error,
    );
  }

  Future<void> _run(Future<bool> Function() action, String success) async {
    final ok = await action();
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop();
      showToast(context, success, kind: ToastKind.success);
    }
    // On failure the form stays open showing field errors / the banner.
  }

  @override
  Widget build(BuildContext context) {
    final editor = context.read<BeatEditorCubit>();
    final text = Theme.of(context).textTheme;
    return BlocBuilder<BeatEditorCubit, EditorState>(
      builder: (context, s) {
        final busy = s.isBusy;
        final published = s.isPublished;
        final err = s.fieldErrors;
        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.lg + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.publishMode && !published
                    ? 'Publish your beat'
                    : 'Beat details',
                style: text.headlineSmall,
              ),
              const SizedBox(height: 4),
              Text(
                widget.publishMode && !published
                    ? 'Published beats are public and can be played, liked and shared by anyone.'
                    : 'Drafts stay private until you publish them.',
                style: text.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.lg),
              if (s.error != null)
                Container(
                  margin: const EdgeInsets.only(bottom: AppSpacing.md),
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.coral.withValues(alpha: 0.1),
                    borderRadius: AppRadius.control,
                    border: Border.all(
                      color: AppColors.coral.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Text(s.error!, key: const Key('details-error')),
                ),
              TextField(
                key: const Key('details-title'),
                controller: _title,
                enabled: !busy,
                maxLength: BeatValidator.maxTitle,
                decoration: InputDecoration(
                  labelText: 'Title',
                  errorText: err[BeatField.title],
                ),
                onChanged: editor.setTitle,
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                key: const Key('details-description'),
                controller: _description,
                enabled: !busy,
                maxLines: 3,
                maxLength: BeatValidator.maxDescription,
                decoration: InputDecoration(
                  labelText: 'Description (optional)',
                  errorText: err[BeatField.description],
                ),
                onChanged: editor.setDescription,
              ),
              const SizedBox(height: AppSpacing.sm),
              DropdownButtonFormField<String>(
                key: const Key('details-genre'),
                initialValue: s.genre,
                decoration: InputDecoration(
                  labelText: 'Genre',
                  errorText: err[BeatField.genre],
                ),
                dropdownColor: AppColors.surfaceRaised,
                items: [
                  for (final g in genres)
                    DropdownMenuItem(value: g.id, child: Text(g.label)),
                ],
                onChanged: busy
                    ? null
                    : (v) => v == null ? null : editor.setGenre(v),
              ),
              const SizedBox(height: AppSpacing.sm),
              SwitchListTile(
                key: const Key('details-remix'),
                contentPadding: EdgeInsets.zero,
                value: s.allowRemix,
                onChanged: busy ? null : editor.setAllowRemix,
                title: const Text('Allow remixes'),
                subtitle: const Text(
                  'Others can copy this beat into their own studio. You are always credited.',
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              _CoverPicker(
                state: s,
                onPick: busy ? null : _pickCover,
                onRemove: busy ? null : editor.removeCover,
              ),
              if (err[BeatField.pattern] != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  err[BeatField.pattern]!,
                  style: text.bodyMedium?.copyWith(color: AppColors.coral),
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  BgButton(
                    label: 'Close',
                    variant: BgButtonVariant.ghost,
                    onPressed: busy ? null : () => Navigator.of(context).pop(),
                  ),
                  if (published)
                    BgButton(
                      key: const Key('details-unpublish'),
                      label: 'Unpublish',
                      variant: BgButtonVariant.secondary,
                      loading: s.busy == EditorBusy.unpublishing,
                      onPressed: busy
                          ? null
                          : () =>
                                _run(editor.unpublish, 'Moved back to drafts'),
                    ),
                  if (!published)
                    BgButton(
                      key: const Key('details-save'),
                      label: 'Save draft',
                      variant: BgButtonVariant.secondary,
                      loading: s.busy == EditorBusy.saving,
                      onPressed: busy
                          ? null
                          : () => _run(editor.save, 'Draft saved'),
                    ),
                  BgButton(
                    key: const Key('details-publish'),
                    label: published ? 'Update' : 'Publish',
                    icon: published ? Icons.check : Icons.public,
                    loading: s.busy == EditorBusy.publishing,
                    onPressed: busy
                        ? null
                        : () => _run(
                            editor.publish,
                            published ? 'Beat updated' : 'Beat published',
                          ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _CoverPicker extends StatelessWidget {
  const _CoverPicker({
    required this.state,
    required this.onPick,
    required this.onRemove,
  });

  final EditorState state;
  final VoidCallback? onPick;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final has = state.coverPath != null;
    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          child: Container(
            width: 72,
            height: 72,
            color: AppColors.surfaceHigh,
            child: state.coverUrl != null
                ? Image.network(
                    state.coverUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) =>
                        const Icon(Icons.broken_image_outlined),
                  )
                : Icon(
                    has ? Icons.image : Icons.image_outlined,
                    color: AppColors.textDim,
                  ),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              BgButton(
                key: const Key('details-cover'),
                label: has ? 'Replace cover' : 'Add cover art',
                icon: Icons.upload,
                variant: BgButtonVariant.secondary,
                loading: state.busy == EditorBusy.uploading,
                onPressed: onPick,
              ),
              if (has)
                BgButton(
                  label: 'Remove',
                  variant: BgButtonVariant.ghost,
                  onPressed: onRemove,
                ),
              Text(
                'PNG, JPG or WebP, up to 5 MB. Optional.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
