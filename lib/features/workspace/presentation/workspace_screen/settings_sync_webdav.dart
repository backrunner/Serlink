part of '../workspace_screen.dart';

Future<void> _showWebDavSyncDialog(
  BuildContext context,
  WidgetRef ref,
  WebDavSyncSettings? settings,
) {
  return showSerlinkDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (context) => _WebDavSyncDialog(initialSettings: settings),
  );
}

class _WebDavSyncDialog extends ConsumerStatefulWidget {
  const _WebDavSyncDialog({required this.initialSettings});

  final WebDavSyncSettings? initialSettings;

  @override
  ConsumerState<_WebDavSyncDialog> createState() => _WebDavSyncDialogState();
}

class _WebDavSyncDialogState extends ConsumerState<_WebDavSyncDialog> {
  late final TextEditingController _endpointController;
  late final TextEditingController _usernameController;
  late final TextEditingController _passwordController;
  late final TextEditingController _basePathController;
  late bool _enabled;
  late bool _allowInsecureHttp;
  var _saving = false;
  String? _errorMessage;

  bool get _isEditing => widget.initialSettings != null;

  @override
  void initState() {
    super.initState();
    final settings = widget.initialSettings;
    _endpointController = TextEditingController(
      text: settings?.endpoint.toString() ?? '',
    );
    _usernameController = TextEditingController(text: settings?.username ?? '');
    _passwordController = TextEditingController();
    _basePathController = TextEditingController(
      text: settings?.basePath ?? '/serlink',
    );
    _enabled = settings?.enabled ?? true;
    _allowInsecureHttp = settings?.allowInsecureHttp ?? false;
  }

  @override
  void dispose() {
    _endpointController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _basePathController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SerlinkDialog(
      maxWidth: _adaptiveDialogWidth(context, _dialogWidthMedium),
      title: Text(l10n.webDavSyncTitle),
      content: SizedBox(
        width: 560,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.72,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SerlinkTextField(
                  key: const ValueKey('webdav-endpoint-field'),
                  controller: _endpointController,
                  decoration: InputDecoration(
                    labelText: l10n.webDavEndpointLabel,
                    hintText: l10n.webDavEndpointHint,
                  ),
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 12),
                SerlinkTextField(
                  key: const ValueKey('webdav-username-field'),
                  controller: _usernameController,
                  decoration: InputDecoration(
                    labelText: l10n.webDavUsernameLabel,
                  ),
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 12),
                SerlinkTextField(
                  key: const ValueKey('webdav-password-field'),
                  controller: _passwordController,
                  decoration: InputDecoration(
                    labelText: _isEditing
                        ? l10n.webDavPasswordKeepLabel
                        : l10n.webDavPasswordLabel,
                  ),
                  obscureText: true,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 12),
                SerlinkTextField(
                  key: const ValueKey('webdav-base-path-field'),
                  controller: _basePathController,
                  decoration: InputDecoration(
                    labelText: l10n.webDavBasePathLabel,
                  ),
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _save(),
                ),
                const SizedBox(height: 8),
                _WebDavOptionRow(
                  key: const ValueKey('webdav-enabled-row'),
                  value: _enabled,
                  label: l10n.webDavEnableTitle,
                  kind: _WebDavOptionKind.switchControl,
                  onChanged: (value) {
                    setState(() {
                      _enabled = value;
                    });
                  },
                ),
                const SizedBox(height: 8),
                _WebDavOptionRow(
                  key: const ValueKey('webdav-allow-http-row'),
                  value: _allowInsecureHttp,
                  label: l10n.webDavAllowHttpTitle,
                  kind: _WebDavOptionKind.checkbox,
                  onChanged: (value) {
                    setState(() {
                      _allowInsecureHttp = value;
                    });
                  },
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 8),
                  SerlinkAlert.danger(message: _errorMessage!, compact: true),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        if (_isEditing)
          SerlinkTextButton(
            onPressed: _saving ? null : _delete,
            child: Text(l10n.removeAction),
          ),
        SerlinkTextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: Text(l10n.cancelAction),
        ),
        SerlinkFilledButton(
          key: const ValueKey('webdav-save-button'),
          onPressed: _saving ? null : _save,
          child: Text(_saving ? l10n.savingAction : l10n.saveAction),
        ),
      ],
    );
  }

  Future<void> _save() async {
    final l10n = context.l10n;
    var allowInsecureHttp = _allowInsecureHttp;
    final endpoint = Uri.tryParse(_endpointController.text.trim());
    if (endpoint?.scheme == 'http' && !allowInsecureHttp) {
      final confirmed = await _confirmDialog(
        context,
        title: l10n.webDavUseHttpTitle,
        body: l10n.webDavUseHttpBody,
        confirmLabel: l10n.webDavAllowHttpAction,
        destructive: true,
      );
      if (!confirmed) {
        return;
      }
      allowInsecureHttp = true;
      if (mounted) {
        setState(() {
          _allowInsecureHttp = true;
        });
      }
    }

    setState(() {
      _saving = true;
      _errorMessage = null;
    });
    try {
      final draft = WebDavSyncSettingsDraft(
        endpoint: _endpointController.text,
        username: _usernameController.text,
        password: _passwordController.text,
        basePath: _basePathController.text,
        allowInsecureHttp: allowInsecureHttp,
        enabled: _enabled,
      );
      if (_enabled) {
        await ensureRemoteSyncCompatibleForEnable(
          await ref
              .read(syncSettingsServiceProvider)
              .buildWebDavProviderFromDraft(draft),
        );
      }
      await ref.read(syncSettingsServiceProvider).saveWebDav(draft);
      ref.invalidate(webDavSyncSettingsProvider);
      if (_enabled) {
        ref.read(autoSyncControllerProvider.notifier).requestSync();
      }
      if (mounted) {
        Navigator.of(context).pop();
        _showSnackBar(context, l10n.webDavSavedSnack);
      }
    } on Object catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _errorMessage = _syncSettingsErrorMessage(l10n, error);
        });
      }
    }
  }

  Future<void> _delete() async {
    final l10n = context.l10n;
    final confirmed = await _confirmDialog(
      context,
      title: l10n.webDavRemoveTitle,
      body: l10n.webDavRemoveBody,
      confirmLabel: l10n.removeAction,
      destructive: true,
    );
    if (!confirmed) {
      return;
    }
    setState(() {
      _saving = true;
      _errorMessage = null;
    });
    try {
      await ref.read(syncSettingsServiceProvider).deleteWebDav();
      ref.invalidate(webDavSyncSettingsProvider);
      if (mounted) {
        Navigator.of(context).pop();
        _showSnackBar(context, l10n.webDavRemovedSnack);
      }
    } on Object catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _errorMessage = _syncSettingsErrorMessage(l10n, error);
        });
      }
    }
  }
}

enum _WebDavOptionKind { switchControl, checkbox }

class _WebDavOptionRow extends StatelessWidget {
  const _WebDavOptionRow({
    super.key,
    required this.value,
    required this.label,
    required this.onChanged,
    required this.kind,
  });

  final bool value;
  final String label;
  final ValueChanged<bool> onChanged;
  final _WebDavOptionKind kind;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final mobile = MediaQuery.sizeOf(context).width < 560;
    final control = switch (kind) {
      _WebDavOptionKind.switchControl => SerlinkSwitch(
        value: value,
        onChanged: onChanged,
        scale: mobile ? 0.62 : 0.72,
      ),
      _WebDavOptionKind.checkbox => SerlinkCheckbox(
        value: value,
        onChanged: (next) => onChanged(next ?? false),
      ),
    };

    return SerlinkPressable(
      onTap: () => onChanged(!value),
      borderRadius: SerlinkRadii.control,
      hoverColor: t.accentPrimary.withValues(alpha: 0.06),
      pressedColor: t.accentPrimary.withValues(alpha: 0.12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: t.surfaceSunken,
          borderRadius: SerlinkRadii.control,
          border: Border.all(color: t.borderSubtle),
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: mobile ? 10 : 12,
            vertical: mobile ? 8 : 9,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  mobile
                      ? _webDavOptionMobileLabel(context.l10n, label)
                      : label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: t.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: mobile ? 13 : 13.5,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              control,
            ],
          ),
        ),
      ),
    );
  }
}

String _webDavOptionMobileLabel(AppLocalizations l10n, String label) {
  if (label == l10n.webDavEnableTitle) {
    return _mobileText(l10n, zh: '启用同步', en: 'Enable sync', ja: '同期を有効化');
  }
  if (label == l10n.webDavAllowHttpTitle) {
    return _mobileText(l10n, zh: '允许 HTTP', en: 'Allow HTTP', ja: 'HTTP を許可');
  }
  return label;
}
