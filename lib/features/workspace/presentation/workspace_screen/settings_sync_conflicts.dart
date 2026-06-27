part of '../workspace_screen.dart';

class _SyncConflictReviewDialog extends ConsumerStatefulWidget {
  const _SyncConflictReviewDialog({required this.conflicts});

  final List<SyncRecordConflict> conflicts;

  @override
  ConsumerState<_SyncConflictReviewDialog> createState() =>
      _SyncConflictReviewDialogState();
}

class _SyncConflictReviewDialogState
    extends ConsumerState<_SyncConflictReviewDialog> {
  final Map<String, Map<String, bool>> _choices = {};
  var _saving = false;

  @override
  void initState() {
    super.initState();
    for (final conflict in widget.conflicts) {
      final fieldSet = conflict.fieldSet;
      if (fieldSet == null) {
        continue;
      }
      _choices[conflict.id.value] = {
        for (final field in fieldSet.fields) field.key: false,
      };
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SerlinkDialog(
      maxWidth: _adaptiveDialogWidth(context, _dialogWidthReview),
      title: Text(l10n.syncConflictReviewDialogTitle),
      content: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 820,
          maxHeight: math.min(560, MediaQuery.sizeOf(context).height * 0.68),
        ),
        child: ListView.separated(
          shrinkWrap: true,
          itemCount: widget.conflicts.length,
          separatorBuilder: (_, _) => const SizedBox(height: SerlinkSpacing.md),
          itemBuilder: (context, index) {
            final conflict = widget.conflicts[index];
            final fieldSet = conflict.fieldSet;
            if (fieldSet == null) {
              return _SyncConflictUnsupportedCard(conflict: conflict);
            }
            if (!fieldSet.supportsFieldMerge) {
              return _SyncConflictUnsupportedCard(conflict: conflict);
            }
            return _SyncConflictFieldCard(
              conflict: conflict,
              fieldSet: fieldSet,
              useRemoteByField: _choices[conflict.id.value] ?? const {},
              onChanged: (fieldKey, useRemote) {
                setState(() {
                  _choices.putIfAbsent(conflict.id.value, () => {})[fieldKey] =
                      useRemote;
                });
              },
            );
          },
        ),
      ),
      actions: [
        SerlinkTextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: Text(l10n.cancelAction),
        ),
        SerlinkFilledButton(
          onPressed: _saving ? null : _apply,
          child: Text(
            _saving
                ? l10n.syncConflictApplying
                : l10n.syncConflictApplyMergeAction,
          ),
        ),
      ],
    );
  }

  Future<void> _apply() async {
    final l10n = context.l10n;
    if (widget.conflicts.any((conflict) {
      final fieldSet = conflict.fieldSet;
      return fieldSet == null || !fieldSet.supportsFieldMerge;
    })) {
      _showSnackBar(context, l10n.syncConflictUnsupportedBody);
      return;
    }
    final confirmed = await _confirmDialog(
      context,
      title: l10n.syncKeepLocalTitle,
      body: l10n.syncKeepLocalBody,
      confirmLabel: l10n.syncConflictApplyMergeAction,
      destructive: true,
    );
    if (!confirmed || !mounted) {
      return;
    }
    setState(() {
      _saving = true;
    });
    try {
      final merges = <SyncMergedConflict>[];
      for (final conflict in widget.conflicts) {
        final fieldSet = conflict.fieldSet!;
        final merged = ref
            .read(syncFieldMergeServiceProvider)
            .merge(
              fieldSet: fieldSet,
              useRemoteByField: _choices[conflict.id.value] ?? const {},
            );
        merges.add(SyncMergedConflict(conflict: conflict, mergedJson: merged));
      }
      if (!mounted) {
        return;
      }
      final result = await _applySyncConflictMerges(context, ref, merges);
      if (!mounted) {
        return;
      }
      if (result != null) {
        Navigator.of(context).pop(result);
      } else {
        Navigator.of(context).pop();
      }
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _saving = false;
      });
      _showSnackBar(context, _syncSettingsErrorMessage(l10n, error));
    }
  }
}

class _SyncConflictFieldCard extends StatelessWidget {
  const _SyncConflictFieldCard({
    required this.conflict,
    required this.fieldSet,
    required this.useRemoteByField,
    required this.onChanged,
  });

  final SyncRecordConflict conflict;
  final SyncConflictFieldSet fieldSet;
  final Map<String, bool> useRemoteByField;
  final void Function(String fieldKey, bool useRemote) onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final t = context.tokens;
    final titleStyle = Theme.of(context).textTheme.titleSmall?.copyWith(
      color: t.textPrimary,
      fontWeight: FontWeight.w800,
    );
    return SurfacePanel(
      borderRadius: SerlinkRadii.dialog,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: SerlinkSpacing.lg,
              vertical: SerlinkSpacing.md,
            ),
            decoration: BoxDecoration(
              color: t.surfaceOverlay,
              border: Border(bottom: BorderSide(color: t.borderSubtle)),
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: t.statusWarning.withValues(alpha: 0.13),
                    borderRadius: SerlinkRadii.control,
                    border: Border.all(
                      color: t.statusWarning.withValues(alpha: 0.28),
                    ),
                  ),
                  child: Icon(
                    Icons.compare_arrows_rounded,
                    size: 18,
                    color: t.statusWarning,
                  ),
                ),
                const SizedBox(width: SerlinkSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        conflict.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: titleStyle,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        conflict.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: t.textMuted,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: SerlinkSpacing.md),
                StatusPill(
                  label: fieldSet.fields.length.toString(),
                  color: t.statusWarning,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(SerlinkSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _ConflictColumnLabels(
                  localLabel: l10n.syncConflictLocalLabel,
                  remoteLabel: l10n.syncConflictRemoteLabel,
                ),
                const SizedBox(height: SerlinkSpacing.sm),
                for (var index = 0; index < fieldSet.fields.length; index++)
                  _ConflictFieldRow(
                    field: fieldSet.fields[index],
                    useRemote:
                        useRemoteByField[fieldSet.fields[index].key] ?? false,
                    localLabel: l10n.syncConflictLocalLabel,
                    remoteLabel: l10n.syncConflictRemoteLabel,
                    showTopDivider: index > 0,
                    onChanged: onChanged,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ConflictColumnLabels extends StatelessWidget {
  const _ConflictColumnLabels({
    required this.localLabel,
    required this.remoteLabel,
  });

  final String localLabel;
  final String remoteLabel;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final style = Theme.of(context).textTheme.labelSmall?.copyWith(
      color: t.textMuted,
      fontWeight: FontWeight.w800,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 620) {
          return const SizedBox.shrink();
        }
        return Row(
          children: [
            const SizedBox(width: 116),
            Expanded(child: Text(localLabel, style: style)),
            const SizedBox(width: SerlinkSpacing.sm),
            Expanded(child: Text(remoteLabel, style: style)),
          ],
        );
      },
    );
  }
}

class _ConflictFieldRow extends StatelessWidget {
  const _ConflictFieldRow({
    required this.field,
    required this.useRemote,
    required this.localLabel,
    required this.remoteLabel,
    required this.showTopDivider,
    required this.onChanged,
  });

  final SyncConflictFieldChoice field;
  final bool useRemote;
  final String localLabel;
  final String remoteLabel;
  final bool showTopDivider;
  final void Function(String fieldKey, bool useRemote) onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final label = Text(
      field.label,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(context).textTheme.labelMedium?.copyWith(
        color: t.textSecondary,
        fontWeight: FontWeight.w800,
      ),
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        border: showTopDivider
            ? Border(top: BorderSide(color: t.borderSubtle))
            : null,
      ),
      child: Padding(
        padding: EdgeInsets.only(
          top: showTopDivider ? SerlinkSpacing.md : 0,
          bottom: SerlinkSpacing.md,
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final localTile = _ConflictChoiceTile(
              title: localLabel,
              value: describeConflictValue(field.localValue),
              selected: !useRemote,
              onSelected: () => onChanged(field.key, false),
            );
            final remoteTile = _ConflictChoiceTile(
              title: remoteLabel,
              value: describeConflictValue(field.remoteValue),
              selected: useRemote,
              onSelected: () => onChanged(field.key, true),
            );
            if (constraints.maxWidth < 620) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  label,
                  const SizedBox(height: SerlinkSpacing.sm),
                  localTile,
                  const SizedBox(height: SerlinkSpacing.sm),
                  remoteTile,
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 104,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: label,
                  ),
                ),
                const SizedBox(width: SerlinkSpacing.md),
                Expanded(child: localTile),
                const SizedBox(width: SerlinkSpacing.sm),
                Expanded(child: remoteTile),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ConflictChoiceTile extends StatelessWidget {
  const _ConflictChoiceTile({
    required this.title,
    required this.value,
    required this.selected,
    required this.onSelected,
  });

  final String title;
  final String value;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final borderColor = selected
        ? t.accentPrimary.withValues(alpha: 0.72)
        : t.borderSubtle;
    final background = selected
        ? t.accentPrimary.withValues(alpha: 0.09)
        : t.surfaceSunken.withValues(alpha: 0.72);
    return SerlinkPressable(
      onTap: onSelected,
      borderRadius: SerlinkRadii.control,
      hoverColor: t.accentPrimary.withValues(alpha: 0.06),
      pressedColor: t.accentPrimary.withValues(alpha: 0.12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOut,
        constraints: const BoxConstraints(minHeight: 66),
        padding: const EdgeInsets.symmetric(
          horizontal: SerlinkSpacing.md,
          vertical: SerlinkSpacing.sm,
        ),
        decoration: BoxDecoration(
          borderRadius: SerlinkRadii.control,
          border: Border.all(color: borderColor),
          color: background,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  selected
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked_rounded,
                  size: 16,
                  color: selected ? t.accentPrimary : t.textMuted,
                ),
                const SizedBox(width: SerlinkSpacing.xs),
                Flexible(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: selected ? t.accentPrimary : t.textMuted,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: SerlinkSpacing.sm),
            Text(
              value,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: t.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SyncConflictUnsupportedCard extends StatelessWidget {
  const _SyncConflictUnsupportedCard({required this.conflict});

  final SyncRecordConflict conflict;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return SurfacePanel(
      padding: const EdgeInsets.all(SerlinkSpacing.lg),
      borderRadius: SerlinkRadii.dialog,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded, color: t.statusWarning, size: 22),
          const SizedBox(width: SerlinkSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  conflict.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: t.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: SerlinkSpacing.xs),
                Text(
                  conflict.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: t.textMuted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: SerlinkSpacing.xs),
                Text(
                  context.l10n.syncConflictUnsupportedBody,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: t.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
