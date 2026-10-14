part of '../workspace_screen.dart';

class _McpCommandGuardSection extends ConsumerWidget {
  const _McpCommandGuardSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final settings = ref.watch(commandDecisionSettingsProvider);
    return _McpCard(
      children: [
        _McpListItem(
          icon: Icons.shield_outlined,
          title: l10n.settingsMcpGuardTitle,
          subtitle: settings.when(
            data: (settings) => settings.enabled
                ? l10n.settingsMcpGuardEnabled(settings.model)
                : l10n.settingsMcpGuardLocal,
            loading: () => l10n.settingsMcpGuardLoading,
            error: (_, _) => l10n.settingsMcpGuardUnavailable,
          ),
          action: _SettingsTextButton(
            key: const ValueKey('settings-mcp-guard-configure'),
            onPressed: () async {
              try {
                final initial = await ref.read(
                  commandDecisionSettingsProvider.future,
                );
                if (!context.mounted) return;
                await showSerlinkDialog<void>(
                  context: context,
                  barrierDismissible: false,
                  builder: (_) => _McpCommandGuardDialog(initial: initial),
                );
              } on Object {
                if (context.mounted) {
                  _showSnackBar(context, l10n.settingsMcpGuardUnavailable);
                }
              }
            },
            child: Text(l10n.settingsMcpGuardConfigure),
          ),
        ),
      ],
    );
  }
}

class _McpCommandGuardDialog extends ConsumerStatefulWidget {
  const _McpCommandGuardDialog({required this.initial});
  final CommandDecisionSettings initial;

  @override
  ConsumerState<_McpCommandGuardDialog> createState() =>
      _McpCommandGuardDialogState();
}

class _McpCommandGuardDialogState
    extends ConsumerState<_McpCommandGuardDialog> {
  late final _model = TextEditingController(text: widget.initial.model);
  final _apiKey = TextEditingController();
  late bool _enabled = widget.initial.enabled;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _model.dispose();
    _apiKey.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SerlinkDialog(
      maxWidth: _adaptiveDialogWidth(context, _dialogWidthMedium),
      title: Text(l10n.settingsMcpGuardDialogTitle),
      content: SerlinkScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.settingsMcpGuardDescription),
            const SizedBox(height: 18),
            _McpCard(
              children: [
                Row(
                  children: [
                    Expanded(child: Text(l10n.settingsMcpGuardEnable)),
                    const SizedBox(width: 12),
                    _SettingsSwitch(
                      key: const ValueKey('settings-mcp-guard-enable'),
                      semanticsLabel: l10n.settingsMcpGuardEnable,
                      value: _enabled,
                      onChanged: _saving
                          ? null
                          : (value) => setState(() => _enabled = value),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            SerlinkTextField(
              key: const ValueKey('settings-mcp-guard-model'),
              controller: _model,
              enabled: !_saving,
              autocorrect: false,
              enableSuggestions: false,
              decoration: InputDecoration(
                labelText: l10n.settingsMcpGuardModel,
              ),
            ),
            const SizedBox(height: 14),
            SerlinkTextField(
              key: const ValueKey('settings-mcp-guard-api-key'),
              controller: _apiKey,
              enabled: !_saving,
              obscureText: true,
              autocorrect: false,
              enableSuggestions: false,
              decoration: InputDecoration(
                labelText: l10n.settingsMcpGuardApiKey,
                hintText: widget.initial.hasApiKey
                    ? l10n.settingsMcpGuardKeySaved
                    : l10n.settingsMcpGuardKeyHint,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              l10n.settingsMcpGuardInputHint,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: context.tokens.textMuted),
            ),
            if (widget.initial.hasApiKey) ...[
              const SizedBox(height: 8),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: SerlinkTextButton(
                  key: const ValueKey('settings-mcp-guard-remove-key'),
                  size: SerlinkButtonSize.sm,
                  onPressed: _saving ? null : () => _save(removeKey: true),
                  child: Text(l10n.settingsMcpGuardRemoveKey),
                ),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: TextStyle(color: context.tokens.statusDanger),
              ),
            ],
          ],
        ),
      ),
      actions: [
        SerlinkTextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: Text(l10n.cancelAction),
        ),
        SerlinkFilledButton(
          key: const ValueKey('settings-mcp-guard-save'),
          size: SerlinkButtonSize.md,
          onPressed: _saving ? null : () => _save(),
          child: Text(l10n.saveAction),
        ),
      ],
    );
  }

  Future<void> _save({bool removeKey = false}) async {
    final l10n = context.l10n;
    if (!removeKey &&
        (!CommandDecisionGuard.isValidModel(_model.text.trim()) ||
            (_enabled &&
                !widget.initial.hasApiKey &&
                _apiKey.text.trim().isEmpty))) {
      setState(() => _error = l10n.settingsMcpGuardInvalid);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref
          .read(commandDecisionGuardProvider)
          .saveSettings(
            enabled: removeKey ? false : _enabled,
            model: removeKey ? widget.initial.model : _model.text,
            apiKey: _apiKey.text,
            removeApiKey: removeKey,
          );
      if (!mounted) return;
      _apiKey.clear();
      ref.invalidate(commandDecisionSettingsProvider);
      Navigator.of(context).pop();
    } on Object {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = l10n.settingsMcpGuardSaveFailed;
        });
      }
    }
  }
}
