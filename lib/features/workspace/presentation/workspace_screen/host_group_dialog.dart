part of '../workspace_screen.dart';

Future<void> _showCreateHostGroupDialog(BuildContext context) {
  return showSerlinkFormDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (context) => const _HostGroupDialog(),
  );
}

class _HostGroupDialog extends ConsumerStatefulWidget {
  const _HostGroupDialog();

  @override
  ConsumerState<_HostGroupDialog> createState() => _HostGroupDialogState();
}

class _HostGroupDialogState extends ConsumerState<_HostGroupDialog> {
  final _name = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    final l10n = context.l10n;
    final name = _name.text.trim();
    if (name.isEmpty || name == _kNewGroupSentinel) {
      setState(() => _error = l10n.hostGroupNameRequired);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final groups = ref.read(hostGroupRepositoryProvider);
      final names = {
        ...await groups.list(),
        for (final host in await ref.read(hostRepositoryProvider).list())
          if (host.groupId != null) host.groupId!,
      };
      if (!mounted) return;
      if (names.any(
        (existing) => existing.toLowerCase() == name.toLowerCase(),
      )) {
        setState(() {
          _saving = false;
          _error = l10n.hostGroupNameExists;
        });
        return;
      }
      await groups.save(name);
      if (!mounted) return;
      ref.invalidate(hostGroupNamesProvider);
      ref.read(_workspaceSearchQueryProvider.notifier).clear();
      Navigator.of(context).pop();
    } on Object {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = l10n.hostGroupSaveFailed;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return PopScope(
      canPop: !_saving,
      child: SerlinkDialog(
        maxWidth: _adaptiveDialogWidth(context, _dialogWidthCompact),
        title: Text(l10n.hostGroupCreateTitle),
        content: SerlinkTextField(
          key: const ValueKey('host-group-name-field'),
          controller: _name,
          autofocus: true,
          enabled: !_saving,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _save(),
          decoration: InputDecoration(
            labelText: l10n.hostGroupNewHint,
            errorText: _error,
          ),
        ),
        actions: [
          SerlinkTextButton(
            onPressed: _saving ? null : () => Navigator.of(context).pop(),
            child: Text(l10n.cancelAction),
          ),
          SerlinkFilledButton(
            key: const ValueKey('host-group-create-button'),
            onPressed: _saving ? null : _save,
            child: Text(_saving ? l10n.savingAction : l10n.createAction),
          ),
        ],
      ),
    );
  }
}
