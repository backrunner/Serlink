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
    return SerlinkDialog(
      maxWidth: _adaptiveDialogWidth(context, _dialogWidthReview),
      title: const Text('Review sync conflicts'),
      content: SizedBox(
        width: 820,
        height: 520,
        child: ListView.separated(
          itemCount: widget.conflicts.length,
          separatorBuilder: (_, _) => const SizedBox(height: 14),
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
          child: const Text('Cancel'),
        ),
        SerlinkFilledButton(
          onPressed: _saving ? null : _apply,
          child: Text(_saving ? 'Applying' : 'Apply merge'),
        ),
      ],
    );
  }

  Future<void> _apply() async {
    setState(() {
      _saving = true;
    });
    try {
      for (final conflict in widget.conflicts) {
        final fieldSet = conflict.fieldSet;
        if (fieldSet == null || !fieldSet.supportsFieldMerge) {
          continue;
        }
        final merged = ref
            .read(syncFieldMergeServiceProvider)
            .merge(
              fieldSet: fieldSet,
              useRemoteByField: _choices[conflict.id.value] ?? const {},
            );
        await ref
            .read(syncRunServiceProvider)
            .applyMergedRecord(recordId: conflict.id, mergedJson: merged);
      }
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop();
      await _resolveWebDavConflicts(
        context,
        ref,
        SyncConflictResolution.keepLocal,
      );
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _saving = false;
      });
      _showSnackBar(context, _syncSettingsErrorMessage(error));
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${conflict.type} · ${conflict.id.value}',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        for (final field in fieldSet.fields) ...[
          Text(field.label, style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: _ConflictChoiceTile(
                  title: 'Local',
                  value: describeConflictValue(field.localValue),
                  selected: !(useRemoteByField[field.key] ?? false),
                  onSelected: () => onChanged(field.key, false),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ConflictChoiceTile(
                  title: 'Remote',
                  value: describeConflictValue(field.remoteValue),
                  selected: useRemoteByField[field.key] ?? false,
                  onSelected: () => onChanged(field.key, true),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ],
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
    return SerlinkPressable(
      onTap: onSelected,
      borderRadius: SerlinkRadii.control,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          borderRadius: SerlinkRadii.control,
          border: Border.all(
            color: selected ? t.accentPrimary : t.borderSubtle,
          ),
          color: selected ? t.accentPrimary.withValues(alpha: 0.08) : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: 6),
            Text(
              value,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${conflict.type} · ${conflict.id.value}',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        const Text(
          'This record type currently requires whole-record resolution. Use the existing local or remote action for this conflict.',
        ),
      ],
    );
  }
}
