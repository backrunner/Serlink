part of '../workspace_screen.dart';

class _McpCommandApprovalSection extends ConsumerStatefulWidget {
  const _McpCommandApprovalSection();

  @override
  ConsumerState<_McpCommandApprovalSection> createState() =>
      _McpCommandApprovalSectionState();
}

class _McpCommandApprovalSectionState
    extends ConsumerState<_McpCommandApprovalSection> {
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final settings = ref.watch(mcpCommandApprovalSettingsProvider);
    return _McpCard(
      children: [
        _McpListItem(
          icon: Icons.fast_forward_outlined,
          title: l10n.settingsMcpBypassTitle,
          subtitle: settings.hasError
              ? l10n.settingsMcpBypassUnavailable
              : l10n.settingsMcpBypassDescription,
          action: _SettingsSwitch(
            key: const ValueKey('settings-mcp-command-bypass'),
            semanticsLabel: l10n.settingsMcpBypassTitle,
            value: settings.value?.bypass ?? false,
            onChanged: _saving || !settings.hasValue || settings.hasError
                ? null
                : (value) async {
                    setState(() => _saving = true);
                    try {
                      await ref
                          .read(mcpCommandApprovalProvider)
                          .saveBypass(value);
                      ref.invalidate(mcpCommandApprovalSettingsProvider);
                    } on Object {
                      if (context.mounted) {
                        _showSnackBar(
                          context,
                          l10n.settingsMcpBypassUnavailable,
                        );
                      }
                    } finally {
                      if (mounted) setState(() => _saving = false);
                    }
                  },
          ),
        ),
      ],
    );
  }
}

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
            data: (settings) => settings.enabled && !settings.dataSharingConsent
                ? l10n.settingsMcpGuardConsentRequired
                : settings.enabled
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
                await showSerlinkFormDialog<void>(
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
  late final _accountId = TextEditingController(
    text: widget.initial.connection.accountId,
  );
  late final _endpoint = TextEditingController(
    text: widget.initial.connection.endpoint,
  );
  final _scroll = ScrollController();
  late CommandDecisionProvider _provider = widget.initial.connection.provider;
  late bool _enabled = widget.initial.enabled;
  late bool _sharingConsent = widget.initial.dataSharingConsent;
  bool _saving = false;
  String? _error;

  CommandDecisionConnection get _connection => CommandDecisionConnection(
    provider: _provider,
    accountId: _accountId.text.trim(),
    endpoint: _endpoint.text.trim(),
  );
  bool get _hasSavedKey =>
      widget.initial.hasApiKey &&
      _connection.sameRecipient(widget.initial.connection);

  void _recipientEdited() => setState(() {
    _sharingConsent = false;
    _apiKey.clear();
    _error = null;
  });

  void _selectProvider(CommandDecisionProvider provider) {
    if (_saving || provider == _provider) return;
    setState(() {
      _provider = provider;
      _model.text = provider.defaultModel;
      _accountId.clear();
      _endpoint.text = provider == CommandDecisionProvider.local
          ? 'http://127.0.0.1:8000/v1/systemone'
          : '';
      _apiKey.clear();
      _sharingConsent = false;
      _error = null;
    });
  }

  @override
  void dispose() {
    _model.dispose();
    _apiKey.dispose();
    _accountId.dispose();
    _endpoint.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final muted = Theme.of(context).textTheme.bodySmall
        ?.copyWith(color: context.tokens.textMuted, height: 1.4);
    final local = _provider == CommandDecisionProvider.local;
    final privacyUrl = switch (_provider) {
      CommandDecisionProvider.typesafe =>
        'https://typesafe.ai/legal/privacy-policy',
      CommandDecisionProvider.gemini =>
        'https://ai.google.dev/gemini-api/terms',
      CommandDecisionProvider.cloudflare =>
        'https://developers.cloudflare.com/workers-ai/platform/data-usage/',
      CommandDecisionProvider.local => null,
    };
    return SerlinkDialog(
      maxWidth: _adaptiveDialogWidth(context, _dialogWidthMedium),
      title: Text(l10n.settingsMcpGuardDialogTitle),
      content: SerlinkScrollView(
        key: const ValueKey('settings-mcp-guard-scroll'),
        controller: _scroll,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: Text(l10n.settingsMcpGuardEnable)),
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
            const SizedBox(height: 20),
            Text(
              l10n.settingsMcpGuardProvider,
              style: Theme.of(context).textTheme.labelMedium,
            ),
            const SizedBox(height: 6),
            AbsorbPointer(
              absorbing: _saving,
              child: SerlinkSelect<CommandDecisionProvider>(
                key: const ValueKey('settings-mcp-guard-provider'),
                value: _provider,
                items: [
                  const SerlinkSelectItem(
                    value: CommandDecisionProvider.typesafe,
                    label: 'TypeSafe · Jev',
                  ),
                  const SerlinkSelectItem(
                    value: CommandDecisionProvider.gemini,
                    label: 'Google · Gemini Decision',
                  ),
                  const SerlinkSelectItem(
                    value: CommandDecisionProvider.cloudflare,
                    label: 'Cloudflare · Clef',
                  ),
                  SerlinkSelectItem(
                    value: CommandDecisionProvider.local,
                    label: l10n.settingsMcpGuardLocalProvider,
                  ),
                ],
                onChanged: _selectProvider,
              ),
            ),
            const SizedBox(height: 14),
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
            if (_provider == CommandDecisionProvider.cloudflare) ...[
              const SizedBox(height: 14),
              SerlinkTextField(
                key: const ValueKey('settings-mcp-guard-account'),
                controller: _accountId,
                enabled: !_saving,
                autocorrect: false,
                enableSuggestions: false,
                onChanged: (_) => _recipientEdited(),
                decoration: InputDecoration(
                  labelText: l10n.settingsMcpGuardAccountId,
                ),
              ),
            ],
            if (local) ...[
              const SizedBox(height: 14),
              SerlinkTextField(
                key: const ValueKey('settings-mcp-guard-endpoint'),
                controller: _endpoint,
                enabled: !_saving,
                autocorrect: false,
                enableSuggestions: false,
                keyboardType: TextInputType.url,
                onChanged: (_) => _recipientEdited(),
                decoration: InputDecoration(
                  labelText: l10n.settingsMcpGuardEndpoint,
                ),
              ),
              const SizedBox(height: 6),
              Text(l10n.settingsMcpGuardLocalHint, style: muted),
            ],
            const SizedBox(height: 14),
            SerlinkTextField(
              key: const ValueKey('settings-mcp-guard-api-key'),
              controller: _apiKey,
              enabled: !_saving,
              obscureText: true,
              autocorrect: false,
              enableSuggestions: false,
              decoration: InputDecoration(
                labelText: local
                    ? l10n.settingsMcpGuardOptionalKey
                    : l10n.settingsMcpGuardApiKey,
                hintText: _hasSavedKey
                    ? l10n.settingsMcpGuardKeySaved
                    : l10n.settingsMcpGuardKeyHint,
              ),
            ),
            const SizedBox(height: 18),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: SerlinkCheckboxListTile(
                    key: const ValueKey('settings-mcp-guard-sharing-consent'),
                    value: _sharingConsent,
                    onChanged: _saving
                        ? null
                        : (value) =>
                              setState(() => _sharingConsent = value ?? false),
                    title: Text(
                      l10n.settingsMcpGuardSharingConsent,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: context.tokens.textSecondary,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                SerlinkTextButton(
                  key: const ValueKey('settings-mcp-guard-privacy'),
                  size: SerlinkButtonSize.sm,
                  onPressed: () => _showPrivacy(privacyUrl),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 14,
                        color: context.tokens.textMuted,
                      ),
                      const SizedBox(width: 5),
                      Text(l10n.settingsMcpGuardPrivacyPolicy, style: muted),
                    ],
                  ),
                ),
              ],
            ),
            if (_hasSavedKey) ...[
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

  Future<void> _showPrivacy(String? privacyUrl) => showSerlinkDialog<void>(
    context: context,
    builder: (context) => SerlinkDialog(
      maxWidth: _adaptiveDialogWidth(context, 520),
      title: Text(context.l10n.settingsMcpGuardPrivacyPolicy),
      content: SerlinkScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _provider == CommandDecisionProvider.local
                  ? context.l10n.settingsMcpGuardLocalDescription
                  : context.l10n.settingsMcpGuardDescription,
            ),
            if (privacyUrl != null) ...[
              const SizedBox(height: 12),
              SerlinkTextButton(
                key: const ValueKey('settings-mcp-guard-provider-terms'),
                size: SerlinkButtonSize.sm,
                onPressed: () => unawaited(
                  launchUrl(
                    Uri.parse(privacyUrl),
                    mode: LaunchMode.externalApplication,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(context.l10n.settingsMcpGuardProviderTerms),
                    const SizedBox(width: 6),
                    const Icon(Icons.open_in_new, size: 14),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        SerlinkTextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.l10n.closeAction),
        ),
      ],
    ),
  );

  void _showError(String error) {
    setState(() => _error = error);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _scroll.hasClients) {
        unawaited(
          _scroll.animateTo(
            _scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOut,
          ),
        );
      }
    });
  }

  Future<void> _save({bool removeKey = false}) async {
    final l10n = context.l10n;
    if (!removeKey && _enabled && !_sharingConsent) {
      _showError(l10n.settingsMcpGuardConsentRequired);
      return;
    }
    if (!removeKey &&
        (!_connection.isValid(enabled: _enabled) ||
            !_connection.isValidModel(_model.text.trim()) ||
            (_enabled &&
                _provider.requiresApiKey &&
                !_hasSavedKey &&
                _apiKey.text.trim().isEmpty))) {
      _showError(l10n.settingsMcpGuardInvalid);
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
            connection: removeKey ? widget.initial.connection : _connection,
            apiKey: _apiKey.text,
            removeApiKey: removeKey,
            dataSharingConsent: !removeKey && _sharingConsent,
          );
      if (!mounted) return;
      _apiKey.clear();
      ref.invalidate(commandDecisionSettingsProvider);
      Navigator.of(context).pop();
    } on Object {
      if (mounted) {
        setState(() => _saving = false);
        _showError(l10n.settingsMcpGuardSaveFailed);
      }
    }
  }
}
